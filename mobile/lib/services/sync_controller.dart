/// 同步引擎生命周期管理：启动时按配置创建、保存配置后重建、定时同步
library;

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_settings.dart';
import 'sync_crypto.dart';
import 'sync_engine.dart';
import 'webdav_transport.dart';

class SyncController {
  static Timer? _timer;
  static bool _syncing = false;
  static int lastApplied = 0;
  static int lastFail = 0;
  static String? lastResult;

  /// 是否已配置坚果云同步
  static bool get configured => SyncEngine.instance != null;

  /// APP 启动时初始化
  static Future<void> init() async {
    await AppSettings.load();
    await apply();
  }

  /// 按当前配置创建/重建引擎并启动定时同步
  static Future<void> apply() async {
    _timer?.cancel();
    _timer = null;
    SyncEngine.instance = null;
    if (!AppSettings.syncConfigured) return;

    final docs = await getApplicationDocumentsDirectory();
    SyncEngine.instance = SyncEngine(
      device: 'mobile',
      logDir: p.join(docs.path, 'sync'),
      crypto: SyncCrypto(
        passphrase: AppSettings.passphrase,
        salt: AppSettings.salt.isNotEmpty ? hexToBytes(AppSettings.salt) : null,
      ),
      transport: WebDavTransport(
        baseUrl: AppSettings.webdavUrl,
        username: AppSettings.username,
        password: AppSettings.appPassword,
      ),
      onSaltDiscovered: (saltHex) => AppSettings.saveSalt(saltHex),
    );
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => syncNow());
    await syncNow(); // 启动即同步一次
  }

  /// 立即同步（定时与手动共用；避免并发）
  static Future<void> syncNow() async {
    final engine = SyncEngine.instance;
    if (engine == null || _syncing) return;
    _syncing = true;
    try {
      await engine.ensureFullDump();
      final (applied, fail) = await engine.syncNow();
      lastApplied = applied;
      lastFail = fail;
      lastResult = fail > 0 ? '同步完成，解密失败 $fail 行（口令不一致？）' : '同步完成，应用 $applied 条';
    } catch (e) {
      lastResult = '同步失败：$e';
    } finally {
      _syncing = false;
    }
  }
}
