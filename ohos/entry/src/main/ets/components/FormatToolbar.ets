/**
 * 富文本格式工具栏：在 TextArea 选区上插入 Markdown 子集标记
 * （与 Windows/Android 端标记式一致；卡片渲染端显示真实效果）
 */

export class FormatResult {
  text: string = '';
  start: number = 0;
  end: number = 0;
}

export enum FormatKind {
  Bold = 0,
  Underline = 1,
  Ul = 2,
  Ol = 3,
  Indent = 4,
  Outdent = 5,
}

export function applyFormatToText(v: string, s: number, e: number,
  kind: FormatKind): FormatResult {
  const r = new FormatResult();
  const sel = v.substring(s, e);
  switch (kind) {
    case FormatKind.Bold:
      if (sel.length === 0) {
        r.text = v.substring(0, s) + '****' + v.substring(e);
        r.start = s + 2;
        r.end = s + 2;
      } else {
        r.text = v.substring(0, s) + '**' + sel + '**' + v.substring(e);
        r.start = s + 2;
        r.end = e + 2;
      }
      return r;
    case FormatKind.Underline:
      if (sel.length === 0) {
        r.text = v.substring(0, s) + '<u></u>' + v.substring(e);
        r.start = s + 3;
        r.end = s + 3;
      } else {
        r.text = v.substring(0, s) + '<u>' + sel + '</u>' + v.substring(e);
        r.start = s + 3;
        r.end = e + 3;
      }
      return r;
    default:
      break;
  }
  // 行级操作：选区覆盖的完整行
  let lineStart = s;
  while (lineStart > 0 && v.charAt(lineStart - 1) !== '\n') {
    lineStart--;
  }
  let lineEnd = e;
  while (lineEnd < v.length && v.charAt(lineEnd) !== '\n') {
    lineEnd++;
  }
  const block = v.substring(lineStart, lineEnd);
  const lines = block.split('\n');
  const processed: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    const ln = lines[i];
    if (kind === FormatKind.Ul) {
      if (new RegExp('^\\s*[-*] ').test(ln)) {
        processed.push(ln.replace(new RegExp('^\\s*[-*] '), ''));
      } else {
        processed.push('- ' + ln);
      }
    } else if (kind === FormatKind.Ol) {
      if (new RegExp('^\\s*\\d+[.)] ').test(ln)) {
        processed.push(ln.replace(new RegExp('^\\s*\\d+[.)] '), ''));
      } else {
        processed.push((i + 1).toString() + '. ' + ln);
      }
    } else if (kind === FormatKind.Indent) {
      processed.push('    ' + ln);
    } else if (kind === FormatKind.Outdent) {
      processed.push(ln.startsWith('    ') ? ln.substring(4) : ln);
    } else {
      processed.push(ln);
    }
  }
  const joined = processed.join('\n');
  r.text = v.substring(0, lineStart) + joined + v.substring(lineEnd);
  r.start = lineStart;
  r.end = lineStart + joined.length;
  return r;
}

@Component
export struct FormatToolbar {
  onFormat: (kind: FormatKind) => void = () => {};

  build() {
    Row({ space: 2 }) {
      this.toolBtn('B', '加粗', FormatKind.Bold)
      this.toolBtn('U̲', '下划线', FormatKind.Underline)
      this.toolBtn('•', '无序列表', FormatKind.Ul)
      this.toolBtn('1.', '有序列表', FormatKind.Ol)
      this.toolBtn('→', '右缩进', FormatKind.Indent)
      this.toolBtn('←', '左缩进', FormatKind.Outdent)
    }
  }

  @Builder
  toolBtn(label: string, tip: string, kind: FormatKind) {
    Text(label)
      .fontSize(14)
      .fontWeight(FontWeight.Bold)
      .fontColor('#8E8B84')
      .padding({ left: 9, right: 9, top: 6, bottom: 6 })
      .borderRadius(6)
      .backgroundColor('#00000000')
      .onClick(() => {
        this.onFormat(kind);
      })
  }
}
