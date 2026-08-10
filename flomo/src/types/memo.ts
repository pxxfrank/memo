export interface Memo {
  id: number
  content: string
  createdAt: number
  pinned: boolean
}

/** 从正文中提取 #标签（支持中文、字母、数字、下划线、连字符、斜杠层级） */
export function extractTags(content: string): string[] {
  const matches = content.match(/#[^\s#]+/g) ?? []
  const tags = matches.map((m) => m.slice(1).replace(/[，。！？；、,.!?;:]+$/, ''))
  return Array.from(new Set(tags))
}
