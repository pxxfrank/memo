/// 应用配置（本地存储，与桌面端 config.json 语义一致）
library;

import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static String webdavUrl = '';    // 如 https://dav.jianguoyun.com/dav/memo-sync
  static String username = '';     // 坚果云账号
  static String appPassword = '';  // 坚果云应用密码
  static String passphrase = '';   // 同步口令（端到端加密，各端一致）
  static String salt = '';         // hex；首次由本端生成，可从远端日志自动对齐

  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    webdavUrl = sp.getString('sync_webdav') ?? '';
    username = sp.getString('sync_user') ?? '';
    appPassword = sp.getString('sync_pass') ?? '';
    passphrase = sp.getString('sync_phrase') ?? '';
    salt = sp.getString('sync_salt') ?? '';
  }

  static Future<void> saveAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('sync_webdav', webdavUrl);
    await sp.setString('sync_user', username);
    await sp.setString('sync_pass', appPassword);
    await sp.setString('sync_phrase', passphrase);
    await sp.setString('sync_salt', salt);
  }

  static Future<void> saveSalt(String saltHex) async {
    salt = saltHex;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('sync_salt', saltHex);
  }

  static bool get syncConfigured => webdavUrl.isNotEmpty;
}

List<int> hexToBytes(String hex) {
  return List.generate(
      hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16));
}
