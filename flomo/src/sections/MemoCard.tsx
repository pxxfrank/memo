import { useState } from 'react'
import { Pin, PinOff, Copy, Check, Pencil, Trash2 } from 'lucide-react'
import type { Memo } from '@/types/memo'
import { RichContent } from '@/components/RichContent'

interface MemoCardProps {
  memo: Memo
  onTogglePin: (id: number) => void
  onRemove: (id: number) => void
  onEdit: (memo: Memo) => void
  onTagClick: (tag: string) => void
}

export function MemoCard({ memo, onTogglePin, onRemove, onEdit, onTagClick }: MemoCardProps) {
  const [copied, setCopied] = useState(false)
  const time = new Date(memo.createdAt)
  const hhmm = `${String(time.getHours()).padStart(2, '0')}:${String(time.getMinutes()).padStart(2, '0')}`

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(memo.content)
      setCopied(true)
      setTimeout(() => setCopied(false), 1200)
    } catch {
      /* clipboard 不可用时静默 */
    }
  }

  return (
    <div
      className={`group relative rounded-xl bg-flomo-card border shadow-[0_1px_3px_rgba(0,0,0,0.04)] px-4 py-3.5 transition-colors ${
        memo.pinned ? 'border-flomo-pin/40' : 'border-flomo-line hover:border-flomo-green/30'
      }`}
    >
      {memo.pinned && (
        <div className="absolute -top-2 right-4 rounded-full bg-flomo-pin/10 border border-flomo-pin/30 px-2 py-0.5 text-[10px] font-medium text-flomo-pin flex items-center gap-1">
          <Pin className="w-2.5 h-2.5" />
          置顶
        </div>
      )}
      <RichContent content={memo.content} onTagClick={onTagClick} />
      <div className="mt-2 flex items-center">
        <span className="text-[11px] text-flomo-faint">{hhmm}</span>
        <div className="ml-auto flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            title={memo.pinned ? '取消置顶' : '置顶'}
            onClick={() => onTogglePin(memo.id)}
            className="p-1.5 rounded-md text-flomo-faint hover:text-flomo-pin hover:bg-flomo-pin/10 transition-colors"
          >
            {memo.pinned ? <PinOff className="w-3.5 h-3.5" /> : <Pin className="w-3.5 h-3.5" />}
          </button>
          <button
            title="编辑"
            onClick={() => onEdit(memo)}
            className="p-1.5 rounded-md text-flomo-faint hover:text-flomo-greendark hover:bg-flomo-tagbg transition-colors"
          >
            <Pencil className="w-3.5 h-3.5" />
          </button>
          <button
            title="复制"
            onClick={copy}
            className="p-1.5 rounded-md text-flomo-faint hover:text-flomo-greendark hover:bg-flomo-tagbg transition-colors"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-flomo-green" /> : <Copy className="w-3.5 h-3.5" />}
          </button>
          <button
            title="删除"
            onClick={() => onRemove(memo.id)}
            className="p-1.5 rounded-md text-flomo-faint hover:text-red-500 hover:bg-red-50 transition-colors"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    </div>
  )
}
