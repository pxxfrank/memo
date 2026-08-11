/**
 * 富文本（Markdown 子集）解析：加粗 **x**、下划线 <u>x</u>、#标签、
 * 行首缩进（4 空格=1 级）、无序列表 "- "、有序列表 "1. "
 * 存储为纯文本（同步协议不变），渲染端按此规则显示。
 */

export type SpanType = 'bold' | 'underline' | 'tag' | 'text'
export interface RichSpan {
  type: SpanType
  text: string
  /** 标签点击的纯标签名（去 # 和尾标点） */
  tag?: string
}
export interface RichLine {
  indent: number
  list: 'ul' | 'ol' | null
  spans: RichSpan[]
}

const TAG_STRIP = /[，。！？；、,.!?;:]+$/

export function parseRich(content: string): RichLine[] {
  return content.split('\n').map((line) => {
    const lead = line.match(/^ */)?.[0].length ?? 0
    const rest = line.slice(lead)
    let list: RichLine['list'] = null
    let text = rest
    const ul = rest.match(/^[-*] (.*)$/)
    const ol = rest.match(/^\d+[.)] (.*)$/)
    if (ul) {
      list = 'ul'
      text = ul[1]
    } else if (ol) {
      list = 'ol'
      text = ol[1]
    }
    return { indent: Math.floor(lead / 4), list, spans: parseInline(text) }
  })
}

function parseInline(text: string): RichSpan[] {
  const spans: RichSpan[] = []
  let last = 0
  const re = /(\*\*[^*]+\*\*|<u>[^<]+<\/u>|#[^\s#，。！？!?,;；:："“”‘’（）()【】\[\]<>《》]+)/g
  for (const m of text.matchAll(re)) {
    if (m.index! > last) spans.push({ type: 'text', text: text.slice(last, m.index) })
    const token = m[0]
    if (token.startsWith('**')) {
      spans.push({ type: 'bold', text: token.slice(2, -2) })
    } else if (token.startsWith('<u>')) {
      spans.push({ type: 'underline', text: token.slice(3, -4) })
    } else if (token.startsWith('#')) {
      const tag = token.slice(1).replace(TAG_STRIP, '')
      spans.push({ type: 'tag', text: token, tag })
    }
    last = m.index! + token.length
  }
  if (last < text.length) spans.push({ type: 'text', text: text.slice(last) })
  return spans
}

export type FormatKind = 'bold' | 'underline' | 'ul' | 'ol' | 'indent' | 'outdent'

/** 对 textarea 选区应用格式；返回是否发生了变化 */
export function applyFormat(el: HTMLTextAreaElement, kind: FormatKind): boolean {
  const { selectionStart: s, selectionEnd: e, value } = el
  if (s === e && (kind === 'bold' || kind === 'underline')) {
    const marker = kind === 'bold' ? '**' : '<u></u>'
    el.value = value.slice(0, s) + marker + value.slice(e)
    el.selectionStart = s + 2
    el.selectionEnd = s + 2
    el.focus()
    return true
  }
  const sel = value.slice(s, e)
  if (kind === 'bold') {
    el.value = value.slice(0, s) + `**${sel}**` + value.slice(e)
    el.selectionStart = s + 2
    el.selectionEnd = e + 2
    el.focus()
    return true
  }
  if (kind === 'underline') {
    el.value = value.slice(0, s) + `<u>${sel}</u>` + value.slice(e)
    el.selectionStart = s + 3
    el.selectionEnd = e + 3
    el.focus()
    return true
  }
  // 行级操作：作用于选区覆盖的完整行
  const lineStart = value.lastIndexOf('\n', s - 1) + 1
  const lineEndIdx = value.indexOf('\n', e)
  const end = lineEndIdx === -1 ? value.length : lineEndIdx
  const lines = value.slice(lineStart, end).split('\n')
  const processed = lines.map((ln, i) => {
    if (kind === 'ul') {
      return /^\s*[-*] /.test(ln) ? ln.replace(/^\s*[-*] /, '') : `- ${ln}`
    }
    if (kind === 'ol') {
      return /^\s*\d+[.)] /.test(ln) ? ln.replace(/^\s*\d+[.)] /, '') : `${i + 1}. ${ln}`
    }
    if (kind === 'indent') return `    ${ln}`
    if (kind === 'outdent') return ln.replace(/^    /, '')
    return ln
  })
  const joined = processed.join('\n')
  el.value = value.slice(0, lineStart) + joined + value.slice(end)
  el.selectionStart = lineStart
  el.selectionEnd = lineStart + joined.length
  el.focus()
  return true
}
