/// 本地数据库（表结构与桌面端 SQLite 一致）
/// Android/iOS 用 sqflite 原生；Windows/Linux 桌面用 sqflite_common_ffi
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../models/memo.dart';
import '../services/sync_engine.dart';
import '../services/tags.dart';

const _uuid = Uuid();

Future<Database> _open() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'memo_mobile.db');
  final opts = OpenDatabaseOptions(version: 1, onCreate: _onCreate);
  // Windows/Linux/macOS 桌面用 sqflite_common_ffi（sqflite 原生仅支持 Android/iOS）
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    return databaseFactoryFfi.openDatabase(path, options: opts);
  }
  return openDatabase(path, options: opts);
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE memos(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT,
      content TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER,
      pinned INTEGER DEFAULT 0)
  ''');
  await db.execute('''
    CREATE TABLE memo_tags(
      memo_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      PRIMARY KEY(memo_id, name))
  ''');
  await db.execute('''
    CREATE TABLE tags(
      name TEXT PRIMARY KEY,
      count INTEGER DEFAULT 0)
  ''');
  await db.execute('CREATE INDEX idx_memos_created ON memos(created_at DESC)');
}

Future<void> _rebuildTagCounts(Database db) async {
  await db.delete('tags');
  await db.rawInsert(
      'INSERT INTO tags(name, count) SELECT name, COUNT(*) FROM memo_tags GROUP BY name');
}

Future<void> _setMemoTags(Database db, int memoId, Set<String> tags) async {
  await db.delete('memo_tags', where: 'memo_id = ?', whereArgs: [memoId]);
  for (final t in tags.toList()..sort()) {
    await db.insert('memo_tags', {'memo_id': memoId, 'name': t},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  await _rebuildTagCounts(db);
}

class MemoDb {
  MemoDb._();
  static Database? _db;
  static Future<Database> Function()? _openOverride;

  /// 测试注入：替换数据库打开方式（独立临时库）
  static void setOpenOverride(Future<Database> Function() f) {
    _openOverride = f;
    _db = null;
  }

  static Future<Database> get db async => _db ??= await (_openOverride?.call() ?? _open());

  static Future<List<Memo>> list({String? tag, String? query}) async {
    final d = await db;
    final where = <String>[];
    final args = <Object?>[];
    if (tag != null && tag.isNotEmpty) {
      where.add('m.id IN (SELECT memo_id FROM memo_tags WHERE name = ?)');
      args.add(tag);
    }
    if (query != null && query.isNotEmpty) {
      where.add('m.content LIKE ?');
      args.add('%$query%');
    }
    final wsql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await d.rawQuery('''
      SELECT m.*, GROUP_CONCAT(t.name) AS tag_list
      FROM memos m LEFT JOIN memo_tags t ON m.id = t.memo_id
      $wsql
      GROUP BY m.id
      ORDER BY m.pinned DESC, m.created_at DESC
    ''', args);
    return rows.map((r) {
      final tags = (r['tag_list'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [];
      return Memo.fromMap({...r, 'tags': tags});
    }).toList();
  }

  static Future<Memo> create(String content, {int? createdAt}) async {
    final d = await db;
    final ts = createdAt ?? DateTime.now().millisecondsSinceEpoch;
    final id = await d.insert('memos', {
      'uuid': _uuid.v4(),
      'content': content,
      'created_at': ts,
    });
    await _setMemoTags(d, id, parseTags(content));
    final memo = (await list()).firstWhere((m) => m.id == id);
    if (SyncEngine.instance != null) {
      await SyncEngine.instance!.logOp('add', memo: memo);
    }
    return memo;
  }

  static Future<void> update(int id, String content) async {
    final d = await db;
    final rows = await d.query('memos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    await d.update('memos', {'content': content, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
    await _setMemoTags(d, id, parseTags(content));
    if (SyncEngine.instance != null) {
      await SyncEngine.instance!.logOp('update', memo: Memo.fromMap({...rows.first, 'content': content}));
    }
  }

  static Future<void> setPinned(int id, bool pinned) async {
    final d = await db;
    final rows = await d.query('memos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    await d.update('memos', {'pinned': pinned ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    if (SyncEngine.instance != null) {
      await SyncEngine.instance!.logOp('pin', memo: Memo.fromMap({...rows.first, 'pinned': pinned ? 1 : 0}));
    }
  }

  static Future<void> remove(int id) async {
    final d = await db;
    final rows = await d.query('memos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    await d.delete('memos', where: 'id = ?', whereArgs: [id]);
    await d.delete('memo_tags', where: 'memo_id = ?', whereArgs: [id]);
    await _rebuildTagCounts(d);
    if (SyncEngine.instance != null) {
      await SyncEngine.instance!.logOp('delete', id: rows.first['uuid'] as String);
    }
  }

  static Future<List<Map<String, Object?>>> tags() async {
    final d = await db;
    return d.query('tags', where: 'count > 0',
        orderBy: 'count DESC, name ASC');
  }

  // ---------- 云同步合并（与桌面端 sync.py _apply 逻辑一致） ----------

  /// 应用一条远端变更日志；返回是否产生了修改
  static Future<bool> applySyncEntry(Map<String, dynamic> e) async {
    final d = await db;
    final op = e['op'] as String?;
    final eid = e['id'] as String?;
    final ts = (e['ts'] as num?)?.toInt() ?? 0;
    if (eid == null || eid.isEmpty) return false;

    final rows = await d.query('memos', where: 'uuid = ?', whereArgs: [eid]);
    final r = rows.isEmpty ? null : rows.first;
    int localTs() {
      if (r == null) return 0;
      return ((r['updated_at'] as int?) ?? (r['created_at'] as int?) ?? 0);
    }

    if (op == 'delete') {
      if (r != null && ts > localTs()) {
        await d.delete('memos', where: 'uuid = ?', whereArgs: [eid]);
        await d.delete('memo_tags', where: 'memo_id = ?', whereArgs: [r['id']]);
        await _rebuildTagCounts(d);
        return true;
      }
      return false;
    }

    if (op == 'pin') {
      if (r != null && ts > localTs()) {
        await d.update('memos', {'pinned': e['pinned'] == true ? 1 : 0},
            where: 'uuid = ?', whereArgs: [eid]);
        return true;
      }
      return false;
    }

    if (op == 'add' || op == 'update') {
      if (r != null && ts <= localTs()) return false;
      final content = (e['content'] as String?) ?? (r?['content'] as String? ?? '');
      if (content.isEmpty) return false;
      final created = (e['created_at'] as num?)?.toInt() ??
          (r?['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch);
      final pinned = e['pinned'] == true ? 1 : 0;
      int mid;
      if (r != null) {
        await d.update(
            'memos', {'content': content, 'created_at': created, 'updated_at': ts, 'pinned': pinned},
            where: 'uuid = ?', whereArgs: [eid]);
        mid = r['id'] as int;
      } else {
        mid = await d.insert('memos',
            {'uuid': eid, 'content': content, 'created_at': created, 'updated_at': ts, 'pinned': pinned});
      }
      await _setMemoTags(d, mid, parseTags(content));
      return true;
    }
    return false;
  }

  /// 按 uuid 查询（同步引擎用）
  static Future<Memo?> byUuid(String uuid) async {
    final d = await db;
    final rows = await d.query('memos', where: 'uuid = ?', whereArgs: [uuid]);
    if (rows.isEmpty) return null;
    return Memo.fromMap(rows.first);
  }

  /// 统计（回顾/统计页用）
  static Future<Map<String, Object?>> stats() async {
    final d = await db;
    final now = DateTime.now();
    final week = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    final month = now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    Future<int> c(String sql, [List<Object?>? args]) async =>
        Sqflite.firstIntValue(await d.rawQuery(sql, args)) ?? 0;
    final total = await c('SELECT COUNT(*) FROM memos');
    final weekCount = await c('SELECT COUNT(*) FROM memos WHERE created_at >= ?', [week]);
    final monthCount = await c('SELECT COUNT(*) FROM memos WHERE created_at >= ?', [month]);
    final chars = await c('SELECT SUM(LENGTH(content)) FROM memos');
    final pinned = await c('SELECT COUNT(*) FROM memos WHERE pinned = 1');
    final topTags = await d.query('tags',
        where: 'count > 0', orderBy: 'count DESC, name ASC', limit: 8);
    return {
      'total': total,
      'week': weekCount,
      'month': monthCount,
      'chars': chars,
      'pinned': pinned,
      'topTags': topTags,
    };
  }
}
