/**
 * 同步配置（偏好存储）与全局设置。
 * 与 Windows/Android/macOS 端一致：坚果云 WebDAV + 同步口令（端到端加密）。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME = 'memo_prefs';

export class SyncConfig {
  webdavUrl: string = '';
  username: string = '';
  appPassword: string = '';
  passphrase: string = '';
  salt: string = '';
  deviceName: string = 'ohos'; // 设备名固定 ohos，与桌面 desktop / 手机 mobile 区分

  get configured(): boolean {
    return this.webdavUrl.length > 0 && this.username.length > 0 &&
      this.appPassword.length > 0;
  }
}

export class AppSettings {
  static darkMode: boolean = false;
  static reviewCount: number = 3;

  private static prefs: preferences.Preferences | null = null;

  static async init(context: common.UIAbilityContext): Promise<void> {
    if (AppSettings.prefs !== null) {
      return;
    }
    AppSettings.prefs = await preferences.getPreferences(context, PREF_NAME);
  }

  static async load(): Promise<SyncConfig> {
    const cfg = new SyncConfig();
    if (AppSettings.prefs === null) {
      return cfg;
    }
    cfg.webdavUrl = AppSettings.prefs.getSync('webdav_url', '') as string;
    cfg.username = AppSettings.prefs.getSync('username', '') as string;
    cfg.appPassword = AppSettings.prefs.getSync('app_password', '') as string;
    cfg.passphrase = AppSettings.prefs.getSync('passphrase', '') as string;
    cfg.salt = AppSettings.prefs.getSync('salt', '') as string;
    AppSettings.darkMode = AppSettings.prefs.getSync('dark_mode', false) as boolean;
    AppSettings.reviewCount = AppSettings.prefs.getSync('review_count', 3) as number;
    return cfg;
  }

  static async saveSync(cfg: SyncConfig): Promise<void> {
    if (AppSettings.prefs === null) {
      return;
    }
    await AppSettings.prefs.put('webdav_url', cfg.webdavUrl);
    await AppSettings.prefs.put('username', cfg.username);
    await AppSettings.prefs.put('app_password', cfg.appPassword);
    await AppSettings.prefs.put('passphrase', cfg.passphrase);
    await AppSettings.prefs.put('salt', cfg.salt);
    await AppSettings.prefs.flush();
  }

  static async setDarkMode(dark: boolean): Promise<void> {
    AppSettings.darkMode = dark;
    if (AppSettings.prefs !== null) {
      await AppSettings.prefs.put('dark_mode', dark);
      await AppSettings.prefs.flush();
    }
  }

  static async setReviewCount(n: number): Promise<void> {
    AppSettings.reviewCount = n;
    if (AppSettings.prefs !== null) {
      await AppSettings.prefs.put('review_count', n);
      await AppSettings.prefs.flush();
    }
  }
}
