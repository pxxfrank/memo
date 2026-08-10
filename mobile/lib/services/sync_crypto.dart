/// 端到端加密（与桌面端 sync.py 的 SyncCrypto 协议完全一致）
///
/// 协议：PBKDF2-SHA256(口令, salt, 200000次) → AES-256-GCM
/// 日志行格式：base64(nonce12 + tag16 + ciphertext)
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

const int kPbkdf2Iterations = 200000;

class SyncCrypto {
  final String? _passphrase;
  List<int>? _salt;
  SecretKey? _key;

  /// passphrase 为空 → 明文模式（与桌面端未加密日志兼容）
  SyncCrypto({String? passphrase, List<int>? salt})
      : _passphrase = passphrase,
        _salt = salt;

  bool get enabled => (_passphrase?.isNotEmpty ?? false);
  String? get passphrase => _passphrase;
  List<int>? get salt => _salt;
  String get saltHex => _salt == null ? '' : _salt!.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> randomSalt() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256));
  }

  static List<int> randomNonce() {
    final r = Random.secure();
    return List.generate(12, (_) => r.nextInt(256));
  }

  /// 首次使用时派生密钥并缓存（PBKDF2 200k 迭代较慢，只跑一次）
  Future<SecretKey> _getKey() async {
    if (_key == null) {
      final pbkdf2 = Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: kPbkdf2Iterations,
        bits: 256,
      );
      _key = await pbkdf2.deriveKeyFromPassword(
        password: _passphrase!,
        nonce: _salt!,
      );
    }
    return _key!;
  }

  /// 加密一行文本 → base64(nonce+tag+ct)；明文模式原样返回
  Future<String> encryptLine(String text, {List<int>? nonce}) async {
    if (!enabled) return text;
    final algo = AesGcm.with256bits();
    final box = await algo.encrypt(
      utf8.encode(text),
      secretKey: await _getKey(),
      nonce: nonce ?? randomNonce(),
    );
    final raw = [...box.nonce, ...box.mac.bytes, ...box.cipherText];
    return base64Encode(raw);
  }

  /// 解密一行；口令错误/非法格式抛异常
  Future<String> decryptLine(String line) async {
    if (!enabled) return line;
    final raw = base64Decode(line.trim());
    if (raw.length < 28) throw const FormatException('密文过短');
    final algo = AesGcm.with256bits();
    final box = SecretBox(
      raw.sublist(28),
      nonce: raw.sublist(0, 12),
      mac: Mac(raw.sublist(12, 28)),
    );
    final clear = await algo.decrypt(box, secretKey: await _getKey());
    return utf8.decode(clear);
  }
}
