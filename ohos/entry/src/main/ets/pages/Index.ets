/**
 * MEMO 主界面：底部导航（笔记 / 回顾 / 统计 / 设置）
 */
import { TimelineView } from './TimelineView';
import { ReviewView } from './ReviewView';
import { StatsView } from './StatsView';
import { SettingsView } from './SettingsView';

@Component
export struct Index {
  @State current: number = 0;

  @Builder
  tabItem(index: number, label: string, icon: string) {
    Column({ space: 2 }) {
      Text(icon)
        .fontSize(19)
      Text(label)
        .fontSize(10)
    }
    .width('100%')
    .height(52)
    .justifyContent(FlexAlign.Center)
    .fontColor(this.current === index ? '#34996B' : '#B5B2AA')
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.current }) {
      TabContent() {
        TimelineView()
      }
      .tabBar(this.tabItem(0, '笔记', '📝'))

      TabContent() {
        ReviewView()
      }
      .tabBar(this.tabItem(1, '回顾', '🎲'))

      TabContent() {
        StatsView()
      }
      .tabBar(this.tabItem(2, '统计', '📊'))

      TabContent() {
        SettingsView()
      }
      .tabBar(this.tabItem(3, '设置', '⚙️'))
    }
    .scrollable(false)
    .barHeight(56)
    .onChange((index: number) => {
      this.current = index;
    })
    .backgroundColor('#F7F6F3')
  }
}
