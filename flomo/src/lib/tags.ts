/**
 * 标签规则（唯一来源）：富文本渲染（lib/rich.ts）与标签提取共用，
 * 并与后端 memo_common.parse_tags 保持一致（#标签、#父/子 多级展开）。
 */

/** 标签正文匹配片段（不含 # 与终止标点/空白） */
export const TAG_BODY = '[^\\s#，。！？!?,;；:："“”‘’（）()【】\\[\\]<>《》]+'

const TAG_STRIP = /^[^\w\u4e00-\u9fff]+|[^\w\u4e00-\u9fff]+$/g

/** 去掉标签首尾的非词字符（与后端 _TAG_STRIP 一致） */
export function cleanTag(raw: string): string {
  return raw.replace(TAG_STRIP, '')
}

/**
 * 从正文提取 #标签（支持中文、字母、数字、下划线、斜杠层级）。
 * 多级标签展开为各级路径：'#工作/日报' → ['工作', '工作/日报']（与后端一致）。
 */
export function extractTags(content: string): string[] {
  const re = new RegExp(`#(${TAG_BODY})`, 'g')
  const out = new Set<string>()
  for (const m of content.matchAll(re)) {
    const parts = cleanTag(m[1]).split('/').filter(Boolean)
    const path: string[] = []
    for (const p of parts) {
      path.push(p)
      out.add(path.join('/'))
    }
  }
  return Array.from(out)
}
