/// 云同步引擎（与桌面端 sync.py 协议一致）
///
/// - 本地写操作 → 追加 {device}.jsonl（AES-GCM 加密，口令=同步口令）
/// - 加密日志首行为 `#salt=<hex>`（salt 非敏感，供其他设备自动对齐）
/// - 定时/手动同步：上传自己的日志 → 下载其他设备日志 → 解密合并（last-write-wins）
/// - 断点：本地 sync-state.json 记录各设备日志已处理行号（幂等重放，行号仅性能优化）
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../db/database.dart';
import '../models/memo.dart';
import 'sync_crypto.dart';

/// 日志传输层抽象：坚果云 WebDAV / 本地目录（测试）
abstract class SyncTransport {
  /// 上传文件（整文件覆盖）
  Future<void> upload(String fileName, String content);

  /// 下载文件；不存在返回 null
  Future<String?> download(String fileName);
}

/// 本地目录传输（开发/测试用，模拟坚果云同步目录）
class LocalDirTransport implements SyncTransport {
  final String dir;
  LocalDirTransport(this.dir);

  @override
  Future<void> upload(String fileName, String content) async {
    final f = File(p.join(dir, fileName));
    await f.parent.create(recursive: true);
    await f.writeAsString(content, flush: true);
  }

  @override
  Future<String?> download(String fileName) async {
    final f = File(p.join(dir, fileName));
    if (!await f.exists()) return null;
    return f.readAsString();
  }
}

class SyncEngine {
  final String device;
  final String logDir;
  final SyncTransport transport;
  final String statePath;

  /// 从远端日志发现 salt 时回调（上层持久化，保证重启后仍可解密）
  final void Function(String saltHex)? onSaltDiscovered;

  SyncCrypto crypto;
  SyncEngine({
    required this.device,
    required this.logDir,
    required SyncCrypto crypto,
    required this.transport,
    this.onSaltDiscovered,
    String? statePath,
  })  : crypto = crypto,
        statePath = statePath ?? p.join(logDir, 'sync-state.json');

  static SyncEngine? instance;

  String get _logPath => p.join(logDir, '$device.jsonl');

  Map<String, int> _state = {};

  /// 采用远端盐（同口令重建密钥；口令为空则忽略）
  Future<void> useSalt(String saltHex) async {
    final pp = crypto.passphrase;
    if (pp == null || pp.isEmpty) return;
    if (crypto.saltHex == saltHex) return;
    crypto = SyncCrypto(passphrase: pp, salt: _hexToBytes(saltHex));
    onSaltDiscovered?.call(saltHex);
  }

  // ---------- 日志读写 ----------

  /// 本地写操作 → 追加日志
  Future<void> logOp(String op, {Memo? memo, String? id, int? ts, int? pinned, String? content, int? createdAt}) async {
    final entry = <String, dynamic>{
      'op': op,
      'ts': ts ?? DateTime.now().millisecondsSinceEpoch,
      'dev': device,
    };
    if (memo != null) {
      entry['id'] = memo.uuid;
      entry['content'] = memo.content;
      entry['created_at'] = memo.createdAt;
      entry['pinned'] = memo.pinned;
    } else {
      if (id != null) entry['id'] = id;
      if (content != null) entry['content'] = content;
      if (createdAt != null) entry['created_at'] = createdAt;
      if (pinned != null) entry['pinned'] = pinned == 1;
    }
    final f = File(_logPath);
    await f.parent.create(recursive: true);
    if (crypto.enabled && !(await f.exists() && await f.length() > 0)) {
      await f.writeAsString('#salt=${crypto.saltHex}\n', mode: FileMode.append, flush: true);
    }
    final out = crypto.enabled ? await crypto.encryptLine(jsonEncode(entry)) : jsonEncode(entry);
    await f.writeAsString(out + '\n', mode: FileMode.append, flush: true);
  }

  // ---------- 同步流程 ----------

  /// 一键同步：上传自己的日志 + 拉取其他设备日志合并
  /// 返回 (拉取应用条数, 解密失败条数)
  Future<(int, int)> syncNow() async {
    // 上传原始日志文件内容（密文保持密文）
    final f = File(_logPath);
    final raw = await f.exists() ? await f.readAsString() : '';
    await transport.upload('$device.jsonl', raw);
    return pullAndMerge();
  }

  /// 拉取其他设备日志并合并（多端通用）
  Future<(int, int)> pullAndMerge() async {
    int total = 0;
    int fail = 0;
    // 已知设备名集合，运行时排除自己（多端扩展时在此追加）
    final others = {'desktop', 'mobile'};
    for (final dev in others) {
      if (dev == device) continue;
      final content = await transport.download('$dev.jsonl');
      if (content == null) continue;
      final rawLines = content.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      // 第一遍：识别 salt 头并采用（保证能解密该设备的密文）
      for (final ln in rawLines) {
        if (ln.startsWith('#salt=')) {
          await useSalt(ln.substring(6));
        }
      }

      final lines = <String>[];
      for (final ln in rawLines) {
        if (ln.startsWith('#')) continue;
        if (crypto.enabled) {
          try {
            lines.add(await crypto.decryptLine(ln));
          } catch (_) {
            lines.add(ln);
            fail++;
          }
        } else {
          lines.add(ln);
        }
      }

      await _loadState();
      final key = 'line_$dev';
      var start = _state[key] ?? 0;
      if (start > lines.length) start = 0; // 远端被替换过，从头重放（幂等）
      for (final ln in lines.skip(start)) {
        try {
          final entry = jsonDecode(ln) as Map<String, dynamic>;
          if (await MemoDb.applySyncEntry(entry)) total++;
        } catch (_) {
          fail++;
        }
      }
      _state[key] = lines.length;
      await _saveState();
    }
    return (total, fail);
  }

  Future<void> _loadState() async {
    final f = File(statePath);
    if (!await f.exists()) return;
    try {
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _state = m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      _state = {};
    }
  }

  Future<void> _saveState() async {
    final f = File(statePath);
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(_state), flush: true);
  }

  /// 首次启用时把存量数据 dump 为 add 日志（保证远端可全量重建）
  Future<void> ensureFullDump() async {
    final f = File(_logPath);
    if (await f.exists() && await f.length() > 0) return;
    final all = await MemoDb.list();
    for (final m in all) {
      await logOp('add', memo: m, ts: (m.createdAt - 1).clamp(1, 1 << 62));
    }
  }
}

List<int> _hexToBytes(String hex) {
  return List.generate(
      hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}
