/**
 * 富文本（Markdown 子集）解析：加粗 **x**、下划线 <u>x</u>、#标签、
 * 行首缩进（4 空格=1 级）、无序列表 "- "、有序列表 "1. "
 * 存储为纯文本（同步协议不变），渲染端按此规则显示。
 * 标签匹配/清洗规则统一来自 lib/tags.ts。
 */

import { TAG_BODY, cleanTag } from '@/lib/tags'

export type SpanType = 'bold' | 'underline' | 'tag' | 'text'
export interface RichSpan {
  type: SpanType
  text: string
  /** 标签点击用的纯标签名（去 # 与首尾非词字符） */
  tag?: string
}
export interface RichLine {
  indent: number
  list: 'ul' | 'ol' | null
  spans: RichSpan[]
}

/** 编辑器格式类型（WYSIWYG 用 execCommand 实现，见 RichEditor.tsx） */
export type FormatKind = 'bold' | 'underline' | 'ul' | 'ol' | 'indent' | 'outdent'

function inlineRe(): RegExp {
  // 每次新建（带 g 的正则含 lastIndex 状态）
  return new RegExp(`(\\*\\*[^*]+\\*\\*|<u>[^<]+</u>|#${TAG_BODY})`, 'g')
}

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
  for (const m of text.matchAll(inlineRe())) {
    if (m.index! > last) spans.push({ type: 'text', text: text.slice(last, m.index) })
    const token = m[0]
    if (token.startsWith('**')) {
      spans.push({ type: 'bold', text: token.slice(2, -2) })
    } else if (token.startsWith('<u>')) {
      spans.push({ type: 'underline', text: token.slice(3, -4) })
    } else if (token.startsWith('#')) {
      spans.push({ type: 'tag', text: token, tag: cleanTag(token.slice(1)) })
    }
    last = m.index! + token.length
  }
  if (last < text.length) spans.push({ type: 'text', text: text.slice(last) })
  return spans
}
