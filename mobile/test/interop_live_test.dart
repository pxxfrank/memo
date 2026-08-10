import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:memo_mobile/db/database.dart';
import 'package:memo_mobile/services/sync_crypto.dart';
import 'package:memo_mobile/services/sync_engine.dart';

/// 跨语言联调（B/C 步）：Dart 手机端连接 Python 桌面端写入的共享目录
/// 共享目录：G:/AI_Project/06-New flomo/sync_interop2（由 Python _interop_live.py 准备，联调后保留）
const cloud = r'G:\AI_Project\06-New flomo\sync_interop2';
const passphrase = 'interop-pass';

void main() {
  test('联调：Python 加密日志 → Dart 解密合并；Dart 写回 → 上传', () async {
    if (!Directory(cloud).existsSync()) {
      markTestSkipped('共享目录不存在（先运行 _interop_live.py write 准备）');
      return;
    }
    final logDir = '${Directory.systemTemp.path}/memo_interop_mobile_${DateTime.now().millisecondsSinceEpoch}';
    sqfliteFfiInit();
    MemoDb.setOpenOverride(() => databaseFactoryFfi.openDatabase(
          p.join(logDir, 'test.db'),
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
        ));

    final engine = SyncEngine(
      device: 'mobile',
      logDir: logDir,
      // 无 salt：应从桌面日志的 #salt= 头自动采用
      crypto: SyncCrypto(passphrase: passphrase),
      transport: LocalDirTransport(cloud),
    );
    SyncEngine.instance = engine;

    // B 步：拉取桌面日志并合并（Python 加密 → Dart 解密）
    final (applied, fail) = await engine.syncNow();
    expect(fail, 0, reason: '应能从 salt 头自动对齐解密');
    expect(applied, 2, reason: '合并桌面 2 条');
    expect(await MemoDb.list().then((l) => l.length), 2);
    expect(engine.crypto.saltHex.isNotEmpty, true, reason: '已采用远端 salt');

    // C 步：手机写 1 条 → 上传（Dart 加密 → Python 拉取解密）
    await MemoDb.create('手机写一条 #联调');
    await engine.syncNow();
    expect(await MemoDb.list().then((l) => l.length), 3);
    // ignore: avoid_print
    print('B/C 联调完成：Dart 端已合并桌面数据并回传手机写入');
    SyncEngine.instance = null;
  }, timeout: const Timeout(Duration(minutes: 2)));
}
