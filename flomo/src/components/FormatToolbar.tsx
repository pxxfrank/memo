import { Bold, Underline, List, ListOrdered, IndentIncrease, IndentDecrease } from 'lucide-react'
import type { FormatKind } from '@/lib/rich'

interface FormatToolbarProps {
  onFormat: (kind: FormatKind) => void
}

const BTNS: { kind: FormatKind; title: string; icon: React.ReactNode }[] = [
  { kind: 'bold', title: '加粗', icon: <Bold className="w-4 h-4" /> },
  { kind: 'underline', title: '下划线', icon: <Underline className="w-4 h-4" /> },
  { kind: 'ul', title: '无序列表', icon: <List className="w-4 h-4" /> },
  { kind: 'ol', title: '有序列表', icon: <ListOrdered className="w-4 h-4" /> },
  { kind: 'indent', title: '右缩进', icon: <IndentIncrease className="w-4 h-4" /> },
  { kind: 'outdent', title: '左缩进', icon: <IndentDecrease className="w-4 h-4" /> },
]

export function FormatToolbar({ onFormat }: FormatToolbarProps) {
  return (
    <div className="flex items-center gap-0.5">
      {BTNS.map((b) => (
        <button
          key={b.kind}
          title={b.title}
          onMouseDown={(e) => e.preventDefault() /* 保持 textarea 焦点 */}
          onClick={() => onFormat(b.kind)}
          className="p-1.5 rounded-md text-flomo-faint hover:text-flomo-greendark hover:bg-flomo-tagbg transition-colors"
        >
          {b.icon}
        </button>
      ))}
    </div>
  )
}
