export interface Memo {
  id: number
  content: string
  createdAt: number
  pinned: boolean
}

// 标签规则统一收敛到 lib/tags.ts（富文本渲染与标签提取共用，与后端一致）
export { extractTags } from '@/lib/tags'
