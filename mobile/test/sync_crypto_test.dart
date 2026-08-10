import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:memo_mobile/services/sync_crypto.dart';

void main() {
  const salt = 'aabbccddeeff00112233445566778899';
  const passphrase = 'interop-test-pass';

  // Python (cryptography) 生成的密文：证明 Dart 与桌面端协议互操作
  const pyLines = [
    'AQIDBAUGBwgJCgsMGcqJ8YSCMfYaNy82BcdleOYzjcbIU7tfN4YUQer8XooorZMn7v3tvrcWs+upsJdTO0uEbhQvTt5oGyu0UbHbnOowL7xdDEqFBGSm3KCgxXNKJuItREo+J1mIFHa3GQgC8JF3sqvoA/NIqV/IlmMdj1I8y3xy14NwGhLQjovqm5eE1kshQkIdrimALmMc7UAZIO1XzBqxfuCtEJZ2ZmfOzri3Wk1YDFHX6rvObFKZ',
    'AQIDBAUGBwgJCgsMT+YqrMEAy6O87jgIPrwh5OYzjcbIU7tfI5IUArK5XtJ7rd10/fD1ubMbtuiss5ZTO1eUfFxqGpg3TSvqFODUjfYref8NDA/BBDfi3PvihCYdc/Q0UkpxaBWfHna3XlxW8E3KNafXBPN/olDOgGIRu5WzuiN5gx7P00Hq4cL1HJmI1AojTk0Hrin9dTdKpRVNag==',
  ];

  test('Dart 解密 Python 加密的日志行（协议互操作）', () async {
    final crypto = SyncCrypto(passphrase: passphrase, salt: _hexToBytes(salt));
    final d1 = jsonDecode(await crypto.decryptLine(pyLines[0]));
    expect(d1['op'], 'add');
    expect(d1['content'], '来自桌面的笔记 #测试');
    expect(d1['id'], 'abc123');

    final d2 = jsonDecode(await crypto.decryptLine(pyLines[1]));
    expect(d2['op'], 'update');
    expect(d2['content'], '中文更新 #工作/汇报');
    expect(d2['pinned'], true);
  });

  test('Dart 加密后可自行解密（自洽）', () async {
    final crypto = SyncCrypto(passphrase: passphrase, salt: _hexToBytes(salt));
    final line = await crypto.encryptLine('自洽测试 #标签', nonce: _hexToBytes('0102030405060708090a0b0c'));
    final back = await crypto.decryptLine(line);
    expect(back, '自洽测试 #标签');
  });

  test('错误口令解密失败', () async {
    final good = SyncCrypto(passphrase: passphrase, salt: _hexToBytes(salt));
    final wrong = SyncCrypto(passphrase: 'wrong', salt: _hexToBytes(salt));
    final line = await good.encryptLine('秘密内容');
    await expectLater(wrong.decryptLine(line), throwsA(anything));
  });

  test('明文模式原样透传（未加密日志兼容）', () async {
    final plain = SyncCrypto();
    expect(plain.enabled, false);
    expect(await plain.encryptLine('{"op":"add"}'), '{"op":"add"}');
    expect(await plain.decryptLine('{"op":"add"}'), '{"op":"add"}');
  });
}

List<int> _hexToBytes(String hex) {
  return List.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}
