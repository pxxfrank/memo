/**
 * 设置页：坚果云同步配置（WebDAV + 口令）、暗黑模式、回顾条数、关于
 * 同步引擎（WebDAV + 端到端加密）见 SyncEngine（下一迭代接入）。
 */
import { AppSettings, SyncConfig } from '../model/SyncConfig';

@Component
export struct SettingsView {
  @State url: string = '';
  @State user: string = '';
  @State pass: string = '';
  @State phrase: string = '';
  @State dark: boolean = false;
  @State reviewCount: number = 3;
  @State savedTip: string = '';

  aboutToAppear(): void {
    AppSettings.load().then((cfg: SyncConfig) => {
      this.url = cfg.webdavUrl;
      this.user = cfg.username;
      this.pass = cfg.appPassword;
      this.phrase = cfg.passphrase;
      this.dark = AppSettings.darkMode;
      this.reviewCount = AppSettings.reviewCount;
    });
  }

  private async save(): Promise<void> {
    const cfg = new SyncConfig();
    cfg.webdavUrl = this.url.trim();
    cfg.username = this.user.trim();
    cfg.appPassword = this.pass.trim();
    cfg.passphrase = this.phrase.trim();
    await AppSettings.saveSync(cfg);
    this.savedTip = '已保存（云同步引擎即将上线）';
    setTimeout(() => {
      this.savedTip = '';
    }, 2500);
  }

  @Builder
  field(label: string, value: string, onChange: (v: string) => void, secret: boolean) {
    Column() {
      Text(label)
        .fontSize(11)
        .fontColor('#B5B2AA')
        .width('100%')
      TextInput({ text: value, placeholder: label, type: secret ? InputType.Password : InputType.Normal })
        .fontSize(13)
        .onChange(onChange)
        .margin({ top: 4 })
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor('#37352F')
      .width('100%')
      .margin({ top: 18, bottom: 8 })
  }

  build() {
    Scroll() {
      Column() {
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#37352F')
          .width('100%')
          .padding({ left: 18, right: 18, top: 16, bottom: 12 })

        Column() {
          this.sectionTitle('云同步（坚果云）')
          Text('与 Windows / Android / macOS 端双向同步。\n填写坚果云 WebDAV 地址与账号，各端填写相同的「同步口令」即可端到端加密互通。')
            .fontSize(12)
            .fontColor('#B5B2AA')
            .lineHeight(19)
            .width('100%')

          this.field('WebDAV 地址（如 https://dav.jianguoyun.com/dav/memo-sync）', this.url,
            (v: string) => { this.url = v; }, false)
          this.field('坚果云用户名（邮箱）', this.user,
            (v: string) => { this.user = v; }, false)
          this.field('应用密码', this.pass,
            (v: string) => { this.pass = v; }, true)
          this.field('同步口令（端到端加密，各端一致）', this.phrase,
            (v: string) => { this.phrase = v; }, true)

          Button(this.savedTip.length > 0 ? this.savedTip : '保存配置')
            .width('100%')
            .height(38)
            .fontSize(13)
            .backgroundColor('#43B581')
            .margin({ top: 6 })
            .onClick(() => {
              this.save();
            })

          this.sectionTitle('外观')
          Row() {
            Text('暗黑模式')
              .fontSize(13)
              .fontColor('#8E8B84')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.dark })
              .selectedColor('#43B581')
              .onChange((isOn: boolean) => {
                this.dark = isOn;
                AppSettings.setDarkMode(isOn);
              })
          }
          .width('100%')

          this.sectionTitle('每日回顾')
          Row() {
            Text('抽取条数：' + this.reviewCount.toString())
              .fontSize(13)
              .fontColor('#8E8B84')
            Blank()
            Text('−')
              .fontSize(18)
              .fontColor('#8E8B84')
              .padding(8)
              .onClick(() => {
                if (this.reviewCount > 1) {
                  this.reviewCount--;
                  AppSettings.setReviewCount(this.reviewCount);
                }
              })
            Text('+')
              .fontSize(18)
              .fontColor('#43B581')
              .padding(8)
              .onClick(() => {
                if (this.reviewCount < 10) {
                  this.reviewCount++;
                  AppSettings.setReviewCount(this.reviewCount);
                }
              })
          }
          .width('100%')

          this.sectionTitle('关于')
          Text('MEMO 手机端 · HarmonyOS 原生版 v1.3.0\n数据存储于本机，云端仅交换加密日志。')
            .fontSize(12)
            .fontColor('#B5B2AA')
            .lineHeight(19)
            .width('100%')
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 30 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F6F3')
    .align(Alignment.TopStart)
  }
}
