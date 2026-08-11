/**
 * 富文本渲染组件：Markdown 子集 → ArkUI 文本（加粗/下划线/标签/缩进/列表）
 * 与 Windows/Android/macOS 端显示一致。
 */
import { RenderLine, RenderSpan, parseMarkdown } from '../model/Markdown';

@Component
export struct RichText {
  @Prop content: string = '';
  @Prop fontSize: number = 14.5;
  @Prop inkColor: string = '#37352F';
  @Prop tagColor: string = '#34996B';

  build() {
    Column() {
      ForEach(this.parsed(), (line: RenderLine, li: number) => {
        Row() {
          if (line.marker.length > 0) {
            Text(line.marker)
              .fontSize(this.fontSize)
              .fontColor(this.inkColor)
              .fontWeight(FontWeight.Normal)
          }
          Text() {
            ForEach(line.spans, (span: RenderSpan, si: number) => {
              Span(span.text)
                .fontSize(this.fontSize)
                .fontWeight(span.bold ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(span.isTag ? this.tagColor : this.inkColor)
                .decoration({
                  type: span.underline ? TextDecorationType.Underline : TextDecorationType.None,
                  color: '#8034996B',
                })
            }, (span: RenderSpan, si: number) => si.toString())
          }
        }
        .width('100%')
        .padding({ left: line.indent * 20 })
      }, (line: RenderLine, li: number) => li.toString())
    }
    .alignItems(HorizontalAlign.Start)
  }

  private parsed(): RenderLine[] {
    return parseMarkdown(this.content);
  }
}
