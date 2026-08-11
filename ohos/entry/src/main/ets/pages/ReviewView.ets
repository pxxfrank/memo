/**
 * 每日回顾：历史优先，随机抽取 N 条（与 Windows/Android 端一致）
 */
import { Memo, MemoStore } from '../model/MemoStore';
import { AppSettings } from '../model/SyncConfig';
import { RichText } from '../components/RichText';

@Component
export struct ReviewView {
  @State cards: Memo[] = [];

  aboutToAppear(): void {
    this.pick();
  }

  private async pick(): Promise<void> {
    const all = await MemoStore.list();
    const n = Math.min(AppSettings.reviewCount, all.length);
    // Fisher-Yates 洗牌取前 n
    const arr = all.slice();
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const t = arr[i];
      arr[i] = arr[j];
      arr[j] = t;
    }
    this.cards = arr.slice(0, n);
  }

  private dayLabel(ts: number): string {
    const d = new Date(ts);
    const today = new Date();
    const sameDay = (a: Date, b: Date): boolean =>
      a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() &&
      a.getDate() === b.getDate();
    if (sameDay(d, today)) {
      return '今天';
    }
    const yest = new Date(today.getTime() - 86400000);
    if (sameDay(d, yest)) {
      return '昨天';
    }
    return d.getFullYear() + '-' + (d.getMonth() + 1).toString().padStart(2, '0') +
      '-' + d.getDate().toString().padStart(2, '0');
  }

  build() {
    Column() {
      Row() {
        Text('每日回顾')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#37352F')
        Blank()
        Text('🎲')
          .fontSize(18)
          .onClick(() => {
            this.pick();
          })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 16, bottom: 12 })

      if (this.cards.length === 0) {
        Column({ space: 8 }) {
          Text('🎉')
            .fontSize(40)
          Text('没有可回顾的笔记')
            .fontSize(14)
            .fontColor('#B5B2AA')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.cards, (m: Memo) => {
            ListItem() {
              Column() {
                RichText({ content: m.content, fontSize: 15 })
                Row() {
                  Text('📅 ' + this.dayLabel(m.createdAt))
                    .fontSize(11)
                    .fontColor('#B5B2AA')
                }
                .width('100%')
                .margin({ top: 10 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .border({ width: 1, color: '#E9E7E1' })
            }
          }, (m: Memo) => m.uuid)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 14, right: 14, bottom: 14 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F6F3')
  }
}
