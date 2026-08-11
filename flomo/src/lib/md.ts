/**
 * Markdown 子集 ↔ HTML 双向转换（WYSIWYG 编辑器用）
 * 存储格式始终是 Markdown 子集（同步/导出不变），仅编辑与渲染时转换。
 * 规则与 rich.ts 一致：**加粗**、<u>下划线</u>、- 无序、1. 有序、4 空格=1 级缩进。
 */

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

function inlineToHtml(text: string): string {
  // 先转义，再把 **x** 转 strong、<u>x</u> 保留下划线标签
  const escaped = escapeHtml(text)
  return escaped
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/&lt;u&gt;([^<]+)&lt;\/u&gt;/g, '<u>$1</u>')
}

/** HTML 行内内容 → Markdown 行内文本（并还原实体） */
function inlineFromHtml(html: string): string {
  let s = html
    .replace(/<strong>(.*?)<\/strong>/g, '**$1**')
    .replace(/<u>(.*?)<\/u>/g, '<u>$1</u>')
    .replace(/<[^>]+>/g, '') // 去掉残留标签（如 <br>、<span>）
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
  return s
}

/** 取元素缩进级数（margin-left / padding-left，每 20px = 1 级） */
function indentOf(el: HTMLElement): number {
  const ml = parseInt(el.style.marginLeft || '0', 10)
  const pl = parseInt(el.style.paddingLeft || '0', 10)
  return Math.max(ml, pl) / 20
}

/** Markdown → HTML（初始化 contenteditable） */
export function mdToHtml(content: string): string {
  const html: string[] = []
  let listType: 'ul' | 'ol' | null = null
  for (const raw of content.split('\n')) {
    const lead = raw.match(/^ */)?.[0].length ?? 0
    const rest = raw.slice(lead)
    const indent = Math.floor(lead / 4)
    const ul = rest.match(/^[-*] (.*)$/)
    const ol = rest.match(/^\d+[.)] (.*)$/)
    const type = ul ? 'ul' : ol ? 'ol' : null

    if (type && type !== listType) {
      if (listType) html.push(`</${listType}>`)
      html.push(`<${type}>`)
      listType = type
    } else if (!type && listType) {
      html.push(`</${listType}>`)
      listType = null
    }

    if (type) {
      const body = type === 'ul' ? ul![1] : ol![1]
      html.push(`<li style="margin-left:${indent * 20}px">${inlineToHtml(body)}</li>`)
    } else {
      html.push(`<div${indent ? ` style="margin-left:${indent * 20}px"` : ''}>${inlineToHtml(rest)}</div>`)
    }
  }
  if (listType) html.push(`</${listType}>`)
  return html.join('')
}

/** 从 contenteditable 的 DOM 提取 Markdown（保存时调用） */
export function htmlToMd(el: HTMLElement): string {
  const lines: string[] = []
  const root = document.createElement('div')
  root.innerHTML = el.innerHTML

  const walk = (node: HTMLElement) => {
    for (const child of Array.from(node.childNodes)) {
      if (child.nodeType === Node.TEXT_NODE) {
        const t = (child.textContent ?? '').trim()
        if (t) lines.push(inlineFromHtml(t))
        continue
      }
      const elm = child as HTMLElement
      const tag = elm.tagName.toLowerCase()
      if (tag === 'ul' || tag === 'ol') {
        const items = Array.from(elm.children)
        items.forEach((li, i) => {
          const liEl = li as HTMLElement
          const indent = indentOf(liEl)
          const marker = tag === 'ol' ? `${i + 1}. ` : '- '
          // li 内可能嵌套子列表，先取第一层文本再递归子列表
          const inner = liEl.cloneNode(true) as HTMLElement
          inner.querySelectorAll('ul,ol').forEach((s) => s.remove())
          lines.push('    '.repeat(indent) + marker + inlineFromHtml(inner.innerHTML))
          walk(liEl) // 处理嵌套子列表（其行首缩进+1）
        })
        continue
      }
      if (tag === 'li') continue
      if (tag === 'div' || tag === 'p') {
        const indent = indentOf(elm)
        lines.push('    '.repeat(indent) + inlineFromHtml(elm.innerHTML))
        continue
      }
      // 其他标签（br/span 等）：提取文本
      const t = elm.textContent?.trim()
      if (t) lines.push(inlineFromHtml(t))
    }
  }
  walk(root)
  // 清理多余空行
  return lines.join('\n').replace(/\n{3,}/g, '\n\n').trim()
}
