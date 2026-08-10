import { useEffect, useState } from 'react'
import { ArrowLeft, Flame, CalendarDays, Hash } from 'lucide-react'
import { request } from '@/lib/api'
import type { TagStat } from '@/hooks/useMemos'

interface StatsViewProps {
  onBack: () => void
}

interface StatsData {
  days: { date: string; count: number }[]
  streak: number
  total: number
  thisWeek: number
}

function heatLevel(c: number): number {
  if (c === 0) return 0
  if (c === 1) return 1
  if (c <= 3) return 2
  if (c <= 6) return 3
  return 4
}

export function StatsView({ onBack }: StatsViewProps) {
  const [stats, setStats] = useState<StatsData | null>(null)
  const [tags, setTags] = useState<TagStat[]>([])

  useEffect(() => {
    Promise.all([
      request<StatsData>('GET', '/api/stats?days=365'),
      request<{ tags: TagStat[] }>('GET', '/api/tags'),
    ])
      .then(([s, t]) => {
        setStats(s)
        setTags(t.tags)
      })
      .catch(() => setStats(null))
  }, [])

  if (!stats) {
    return (
      <div className="mx-auto max-w-[680px] px-5 pt-20 text-center text-[13px] text-flomo-faint">
        统计加载中…
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-[680px] px-5 pt-10 pb-24">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h2 className="text-[20px] font-semibold tracking-tight">数据统计</h2>
          <p className="mt-1 text-[12px] text-flomo-faint">记录会说话，看看你的积累</p>
        </div>
        <button
          onClick={onBack}
          className="flex items-center gap-1.5 rounded-lg border border-flomo-line px-3.5 py-2 text-[13px] text-flomo-sub hover:text-flomo-ink transition-colors"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          返回
        </button>
      </div>

      {/* 指标卡 */}
      <div className="grid grid-cols-3 gap-3">
        <div className="rounded-xl bg-flomo-card border border-flomo-line p-4 text-center">
          <div className="text-[28px] font-bold text-flomo-ink leading-none">{stats.total}</div>
          <div className="mt-1.5 text-[12px] text-flomo-faint">全部笔记</div>
        </div>
        <div className="rounded-xl bg-flomo-card border border-flomo-line p-4 text-center">
          <div className="flex items-center justify-center gap-1 text-[28px] font-bold text-flomo-green leading-none">
            <Flame className="w-5 h-5" />
            {stats.streak}
          </div>
          <div className="mt-1.5 text-[12px] text-flomo-faint">连续记录天数</div>
        </div>
        <div className="rounded-xl bg-flomo-card border border-flomo-line p-4 text-center">
          <div className="flex items-center justify-center gap-1 text-[28px] font-bold text-flomo-greendark leading-none">
            <CalendarDays className="w-5 h-5" />
            {stats.thisWeek}
          </div>
          <div className="mt-1.5 text-[12px] text-flomo-faint">本周新增</div>
        </div>
      </div>

      {/* 热力图 */}
      <div className="mt-7">
        <div className="flex items-center gap-2 mb-3">
          <h3 className="text-[14px] font-semibold">近一年记录热力图</h3>
          <div className="ml-auto flex items-center gap-1 text-[11px] text-flomo-faint">
            <span>少</span>
            {[0, 1, 2, 3, 4].map((l) => (
              <span key={l} className={`w-[10px] h-[10px] rounded-[2px] ${l === 0 ? 'bg-flomo-line' : `heat-l${l}`}`} />
            ))}
            <span>多</span>
          </div>
        </div>
        <div className="rounded-xl bg-flomo-card border border-flomo-line p-4">
          <div className="heatmap">
            {stats.days.map((d) => (
              <span
                key={d.date}
                title={`${d.date}：${d.count} 条`}
                className={`hcell ${d.count ? `heat-l${heatLevel(d.count)}` : 'bg-flomo-line'}`}
              />
            ))}
          </div>
        </div>
      </div>

      {/* 常用标签 */}
      <div className="mt-7">
        <div className="flex items-center gap-2 mb-3">
          <Hash className="w-4 h-4 text-flomo-green" />
          <h3 className="text-[14px] font-semibold">常用标签</h3>
        </div>
        {tags.length === 0 ? (
          <p className="text-[12px] text-flomo-faint">还没有标签，写一条带 #标签 的 memo 试试</p>
        ) : (
          <div className="flex flex-wrap gap-2">
            {tags.slice(0, 15).map((t) => (
              <span
                key={t.name}
                className="inline-flex items-center gap-1.5 rounded-full bg-flomo-tagbg text-flomo-greendark px-3 py-1.5 text-[12px] font-medium"
              >
                {t.name}
                <span className="text-[10px] opacity-70">{t.count}</span>
              </span>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
