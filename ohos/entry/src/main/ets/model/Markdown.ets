/**
 * Markdown 子集解析（与 Windows/Android/macOS 端同一规则）：
 * **加粗**、<u>下划线</u>、#标签、行首 4 空格=1 级缩进、- 无序、1. 有序。
 * 存储为纯文本，渲染端解析显示。
 */

export class RenderSpan {
  text: string = '';
  bold: boolean = false;
  underline: boolean = false;
  isTag: boolean = false;
}

export class RenderLine {
  indent: number = 0;
  listType: number = 0; // 0 无列表 / 1 无序 / 2 有序
  marker: string = '';  // 列表前缀（• 或序号）
  spans: RenderSpan[] = [];
}

const INLINE_RE: RegExp =
  new RegExp('(\\*\\*[^*]+\\*\\*|<u>[\\s\\S]*?</u>|#[^\\s#，。！？!?,;；:："“”‘’（）()【】\\[\\]<>《》]+)');
const UL_RE: RegExp = new RegExp('^[-*] (.*)$');
const OL_RE: RegExp = new RegExp('^\\d+[.)] (.*)$');
const TAG_STRIP_RE: RegExp = new RegExp('[，。！？；、,.!?;:]+$');

function parseInline(text: string, bold: boolean, underline: boolean,
  spans: RenderSpan[]): void {
  let last = 0;
  let m: RegExpExecArray | null = INLINE_RE.exec(text);
  while (m !== null) {
    if (m.index > last) {
      const s = new RenderSpan();
      s.text = text.substring(last, m.index);
      s.bold = bold;
      s.underline = underline;
      spans.push(s);
    }
    const token = m[0];
    if (token.startsWith('**')) {
      parseInline(token.substring(2, token.length - 2), true, underline, spans);
    } else if (token.startsWith('<u>')) {
      parseInline(token.substring(3, token.length - 4), bold, true, spans);
    } else if (token.startsWith('#')) {
      const s = new RenderSpan();
      s.text = token;
      s.isTag = true;
      spans.push(s);
    }
    last = m.index + token.length;
    m = INLINE_RE.exec(text);
  }
  if (last < text.length) {
    const s = new RenderSpan();
    s.text = text.substring(last);
    s.bold = bold;
    s.underline = underline;
    spans.push(s);
  }
}

export function parseMarkdown(content: string): RenderLine[] {
  const lines = content.split('\n');
  const result: RenderLine[] = [];
  for (const raw of lines) {
    const line = new RenderLine();
    let text: string = raw;
    let lead = 0;
    while (lead < text.length && text.charAt(lead) === ' ') {
      lead++;
    }
    text = text.substring(lead);
    line.indent = Math.floor(lead / 4);

    const ul = UL_RE.exec(text);
    const ol = OL_RE.exec(text);
    if (ul !== null) {
      line.listType = 1;
      text = ul[1];
    } else if (ol !== null) {
      line.listType = 2;
      text = ol[1];
    }
    parseInline(text, false, false, line.spans);
    result.push(line);
  }
  // 计算列表前缀（有序列表序号跨行累计）
  let ol = 0;
  for (const line of result) {
    if (line.listType === 1) {
      line.marker = '• ';
    } else if (line.listType === 2) {
      ol++;
      line.marker = ol.toString() + '. ';
    } else {
      ol = 0;
    }
  }
  return result;
}
