import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:memo_mobile/db/database.dart';
import 'package:memo_mobile/services/sync_crypto.dart';
import 'package:memo_mobile/services/sync_engine.dart';

/// 测试端：独立临时库 + 引擎 + 共享云端目录
class TestEnd {
  final String name;
  final Directory cloud;
  final SyncEngine engine;
  TestEnd(this.name, this.cloud, {String? passphrase, List<int>? salt})
      : engine = SyncEngine(
          device: name,
          logDir: '${Directory.systemTemp.path}/memo_sync_test_${name}_${DateTime.now().microsecondsSinceEpoch}',
          crypto: SyncCrypto(
            passphrase: passphrase,
            salt: salt ?? (passphrase == null ? null : [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]),
          ),
          transport: LocalDirTransport(cloud.path),
        );

  Future<void> use() async {
    MemoDb.setOpenOverride(() async {
      sqfliteFfiInit();
      return databaseFactoryFfi.openDatabase(
        '${engine.logDir}/test.db',
        options: OpenDatabaseOptions(version: 1, onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE memos(
              id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT,
              content TEXT NOT NULL, created_at INTEGER NOT NULL,
              updated_at INTEGER, pinned INTEGER DEFAULT 0)
          ''');
          await db.execute('''
            CREATE TABLE memo_tags(
              memo_id INTEGER NOT NULL, name TEXT NOT NULL,
              PRIMARY KEY(memo_id, name))
          ''');
          await db.execute(
              'CREATE TABLE tags(name TEXT PRIMARY KEY, count INTEGER DEFAULT 0)');
        }),
      );
    });
    SyncEngine.instance = engine;
  }

  Future<int> count() async => (await MemoDb.list()).length;
}

void main() {
  late Directory root;
  late Directory cloud;
  late TestEnd desktop;
  late TestEnd mobile;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('memo_sync_test_');
    cloud = Directory('${root.path}/cloud')..createSync();
    desktop = TestEnd('desktop', cloud);
    mobile = TestEnd('mobile', cloud);
  });

  tearDown(() async {
    SyncEngine.instance = null;
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('M1 桌面→手机：写操作记录日志，手机同步获得全部', () async {
    await desktop.use();
    await MemoDb.create('桌面笔记一 #工作');
    await MemoDb.create('桌面笔记二 #学习');
    await desktop.engine.syncNow(); // 桌面上传日志到云端

    await mobile.use();
    final (applied, fail) = await mobile.engine.syncNow();
    expect(applied, 2, reason: '应用 2 条 add');
    expect(fail, 0);
    expect(await mobile.count(), 2);
    final memos = await MemoDb.list();
    final allTags = memos.expand((m) => m.tags).toSet();
    expect(allTags, containsAll(['工作', '学习']));
  });

  test('M2 手机→桌面：反向同步', () async {
    await mobile.use();
    await MemoDb.create('手机笔记一 #生活');
    await mobile.engine.syncNow(); // 上传

    await desktop.use();
    final (applied, fail) = await desktop.engine.syncNow();
    expect(applied, 1);
    expect(fail, 0);
    expect(await desktop.count(), 1);
  });

  test('M3 双向并发：各写各的，互相同步后一致', () async {
    await desktop.use();
    await MemoDb.create('桌面 A #标签');
    await MemoDb.create('桌面 B #标签');
    await desktop.engine.syncNow();

    await mobile.use();
    await MemoDb.create('手机 C #标签');
    await mobile.engine.syncNow();
    await desktop.engine.syncNow();
    await mobile.engine.syncNow();

    expect(await desktop.count(), 3);
    expect(await mobile.count(), 3);
  });

  test('M4 冲突：双端改同一笔记，后写者胜', () async {
    await desktop.use();
    await MemoDb.create('原始内容 #冲突');
    await desktop.engine.syncNow();

    await mobile.use();
    await mobile.engine.syncNow();
    final memos = await MemoDb.list();
    final uuid = memos.firstWhere((x) => x.content == '原始内容 #冲突').uuid;

    // 双端各自编辑同一笔记（手机先改，桌面后改 → 桌面 ts 更大应胜出）
    await MemoDb.update(memos.firstWhere((x) => x.uuid == uuid).id!, '手机修改版');
    await mobile.engine.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await desktop.use();
    await desktop.engine.syncNow();
    final dMemos = await MemoDb.list();
    final dId = dMemos.firstWhere((x) => x.uuid == uuid).id!;
    await MemoDb.update(dId, '桌面修改版(后)');
    await desktop.engine.syncNow();

    await mobile.use();
    await mobile.engine.syncNow();
    await desktop.engine.syncNow();

    final after = await MemoDb.list();
    final winner = after.firstWhere((x) => x.uuid == uuid);
    expect(winner.content, '桌面修改版(后)', reason: '后写者（桌面 ts 更大）胜');
  });

  test('M5 删除同步（墓碑）', () async {
    await desktop.use();
    await MemoDb.create('将被删除 #旧');
    final keep = await MemoDb.create('保留 #新');
    await desktop.engine.syncNow();

    await mobile.use();
    await mobile.engine.syncNow();
    expect(await mobile.count(), 2);

    // 手机删除一条 → 桌面同步后也删除
    final memos = await MemoDb.list();
    final del = memos.firstWhere((x) => x.uuid != keep.uuid);
    await MemoDb.remove(del.id!);
    await mobile.engine.syncNow();

    await desktop.use();
    await desktop.engine.syncNow();
    final remaining = await MemoDb.list();
    expect(remaining.length, 1);
    expect(remaining.first.content, '保留 #新');
  });

  test('M6 幂等重放：重复同步无副作用', () async {
    await desktop.use();
    await MemoDb.create('内容一 #a');
    await desktop.engine.syncNow();

    await mobile.use();
    await mobile.engine.syncNow();
    final before = await mobile.count();
    for (var i = 0; i < 3; i++) {
      await mobile.engine.pullAndMerge();
    }
    expect(await mobile.count(), before);
  });

  test('M7 加密：带口令双向同步，云端日志为密文', () async {
    final encDesktop = TestEnd('desktop', cloud, passphrase: 'secret');
    final encMobile = TestEnd('mobile', cloud, passphrase: 'secret');

    await encDesktop.use();
    await MemoDb.create('加密笔记 #密文');
    await encDesktop.engine.syncNow();

    await encMobile.use();
    final (applied, fail) = await encMobile.engine.syncNow();
    expect(applied, 1);
    expect(fail, 0);
    expect(await encMobile.count(), 1);

    // 云端是密文：明文不出现在日志文件
    final raw = File('${cloud.path}/desktop.jsonl').readAsStringSync();
    expect(raw.contains('加密笔记'), false, reason: '云端日志必须为密文');
  });

  test('M8 错误口令：解密失败且不产生脏数据', () async {
    final encDesktop = TestEnd('desktop', cloud, passphrase: 'secret');
    await encDesktop.use();
    await MemoDb.create('机密 #密');
    await encDesktop.engine.syncNow();

    final wrong = TestEnd('mobile', cloud, passphrase: 'wrong-pass');
    await wrong.use();
    final (applied, fail) = await wrong.engine.syncNow();
    expect(applied, 0);
    expect(fail, greaterThan(0));
    expect(await wrong.count(), 0);
  });

  test('M9 新设备重建：从桌面日志全量恢复', () async {
    await desktop.use();
    for (var i = 0; i < 3; i++) {
      await MemoDb.create('历史笔记$i #历史');
    }
    await desktop.engine.syncNow();

    final newPhone = TestEnd('mobile', cloud);
    await newPhone.use();
    await newPhone.engine.syncNow();
    expect(await newPhone.count(), 3);
  });
}
