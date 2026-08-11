/**
 * 统计页：总量/今日/本周/连续记录/常用标签（与 Windows/Android 端一致）
 */
import { MemoStore, Stats, TagCount } from '../model/MemoStore';

@Component
export struct StatsView {
  @State stats: Stats | null = null;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.stats = await MemoStore.stats();
  }

  @Builder
  statCard(value: string, label: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#34996B')
      Text(label)
        .fontSize(11)
        .fontColor('#B5B2AA')
    }
    .width('48%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E9E7E1' })
  }

  build() {
    Column() {
      Text('统计')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#37352F')
        .width('100%')
        .padding({ left: 18, right: 18, top: 16, bottom: 12 })

      if (this.stats !== null) {
        Column() {
          Row({ space: 10 }) {
            this.statCard(this.stats.total.toString(), '累计笔记')
            this.statCard(this.stats.todayNew.toString(), '今日新增')
          }
          .width('100%')

          Row({ space: 10 }) {
            this.statCard(this.stats.weekNew.toString(), '本周新增')
            this.statCard(this.stats.streak.toString() + ' 天', '连续记录')
          }
          .width('100%')
          .margin({ top: 10 })

          Column() {
            Text('常用标签')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#37352F')
              .width('100%')
              .margin({ bottom: 8 })
            if (this.stats.topTags.length === 0) {
              Text('还没有标签，记笔记时用 #标签 即可')
                .fontSize(12)
                .fontColor('#B5B2AA')
                .width('100%')
                .padding({ top: 6, bottom: 6 })
            } else {
              ForEach(this.stats.topTags, (t: TagCount) => {
                Row() {
                  Text(t.name)
                    .fontSize(13)
                    .fontColor('#34996B')
                  Blank()
                  Text(t.count.toString() + ' 条')
                    .fontSize(12)
                    .fontColor('#B5B2AA')
                }
                .width('100%')
                .padding({ top: 6, bottom: 6 })
              }, (t: TagCount) => t.name)
            }
          }
          .width('100%')
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#E9E7E1' })
          .margin({ top: 10 })
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 14 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F6F3')
  }
}
