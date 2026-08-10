import { useMemo } from 'react'
import type { Memo } from '@/types/memo'
import { MemoCard } from './MemoCard'

interface TimelineProps {
  memos: Memo[]
  onTogglePin: (id: number) => void
  onRemove: (id: number) => void
  onEdit: (memo: Memo) => void
  onTagClick: (tag: string) => void
}

function dayLabel(ts: number): string {
  const d = new Date(ts)
  const today = new Date()
  const startOf = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime()
  const diff = Math.round((startOf(today) - startOf(d)) / 86400_000)
  if (diff === 0) return '今天'
  if (diff === 1) return '昨天'
  if (d.getFullYear() === today.getFullYear()) return `${d.getMonth() + 1}月${d.getDate()}日`
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`
}

export function Timeline({ memos, onTogglePin, onRemove, onEdit, onTagClick }: TimelineProps) {
  const groups = useMemo(() => {
    const sorted = [...memos].sort((a, b) => b.createdAt - a.createdAt)
    const map = new Map<string, Memo[]>()
    for (const m of sorted) {
      const key = new Date(m.createdAt).toDateString()
      if (!map.has(key)) map.set(key, [])
      map.get(key)!.push(m)
    }
    // 组内：置顶优先
    return Array.from(map.entries()).map(([key, list]) => ({
      key,
      label: dayLabel(list[0].createdAt),
      list: list.sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.createdAt - a.createdAt),
    }))
  }, [memos])

  if (groups.length === 0) {
    return (
      <div className="py-16 text-center">
        <div className="text-[32px]">🍃</div>
        <p className="mt-2 text-[13px] text-flomo-faint">这里空空如也，写下第一条 memo 吧</p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {groups.map((g) => (
        <section key={g.key}>
          <div className="mb-2.5 flex items-baseline gap-2">
            <h2 className="text-[13px] font-semibold text-flomo-ink">{g.label}</h2>
            <span className="text-[11px] text-flomo-faint">{g.list.length} 条</span>
            <div className="flex-1 border-t border-flomo-line translate-y-[-2px]" />
          </div>
          <div className="space-y-2.5">
            {g.list.map((m) => (
              <MemoCard key={m.id} memo={m} onTogglePin={onTogglePin} onRemove={onRemove} onEdit={onEdit} onTagClick={onTagClick} />
            ))}
          </div>
        </section>
      ))}
    </div>
  )
}
