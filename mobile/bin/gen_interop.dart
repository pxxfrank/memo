import 'dart:io';

import 'package:memo_mobile/models/memo.dart';
import 'package:memo_mobile/services/sync_crypto.dart';
import 'package:memo_mobile/services/sync_engine.dart';

Memo _memo(String uuid, String content, int createdAt) =>
    Memo(uuid: uuid, content: content, createdAt: createdAt, pinned: false);

/// 联调工具：用手机端引擎生成加密日志到指定目录（模拟手机写操作）
/// 用法: dart run bin/gen_interop.dart <目录> [口令]
Future<void> main(List<String> args) async {
  final dir = args.isNotEmpty ? args[0] : '../sync_interop';
  final pass = args.length > 1 ? args[1] : 'interop-pass';

  final engine = SyncEngine(
    device: 'mobile',
    logDir: dir, // 日志直接写目标目录（模拟上传后的云端）
    crypto: SyncCrypto(passphrase: pass),
    transport: LocalDirTransport(dir),
  );
  await engine.logOp('add', memo: _memo('mobile-uuid-1', '手机端第一条 #同步验证', 1786354000000), ts: 1786354000000);
  await engine.logOp('add', memo: _memo('mobile-uuid-2', '手机端第二条 #工作/汇报', 1786354100000), ts: 1786354100000);
  final f = File('$dir/mobile.jsonl');
  await f.writeAsString(await f.readAsString(), flush: true);
  stdout.writeln('已生成 $dir/mobile.jsonl（salt 头 + 2 行加密，口令: $pass）');
}
