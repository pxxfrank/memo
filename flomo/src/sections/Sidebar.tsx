import { Search, StickyNote, Hash, Pin, Flame, Dices, BarChart3, Settings } from 'lucide-react'
import type { TagStat } from '@/hooks/useMemos'

export type View = 'timeline' | 'review' | 'stats' | 'settings'

const TAG_COLORS = ['#43B581', '#F5A623', '#5B8DEF', '#E86A92', '#8B6DD8', '#4FB6C6', '#E0874A']

function tagColor(name: string) {
  let h = 0
  for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) >>> 0
  return TAG_COLORS[h % TAG_COLORS.length]
}

interface SidebarProps {
  tags: TagStat[]
  total: number
  streakDays: number
  search: string
  onSearch: (v: string) => void
  activeTag: string | null
  onTagClick: (tag: string | null) => void
  pinnedOnly: boolean
  onPinnedToggle: () => void
  view: View
  onViewChange: (v: View) => void
}

export function Sidebar({
  tags,
  total,
  streakDays,
  search,
  onSearch,
  activeTag,
  onTagClick,
  pinnedOnly,
  onPinnedToggle,
  view,
  onViewChange,
}: SidebarProps) {
  const navBtn = (active: boolean) =>
    `w-full flex items-center gap-2.5 rounded-lg px-3 py-2 text-[13px] transition-colors ${
      active ? 'bg-white text-flomo-ink font-medium shadow-sm' : 'text-flomo-sub hover:bg-white/60 hover:text-flomo-ink'
    }`
  return (
    <aside className="hidden md:flex w-[248px] shrink-0 flex-col bg-flomo-sidebar border-r border-flomo-line h-screen sticky top-0">
      {/* Logo */}
      <div className="px-5 pt-6 pb-4">
        <div className="flex items-center gap-2">
          <span className="text-[22px] font-bold tracking-tight text-flomo-ink">flomo</span>
          <span className="w-2 h-2 rounded-full bg-flomo-green translate-y-[3px]" />
        </div>
        <p className="mt-1 text-[11px] text-flomo-faint">持续不断记录，意义自然浮现</p>
      </div>

      {/* Search */}
      <div className="px-4 pb-3">
        <div className="flex items-center gap-2 rounded-lg bg-white/70 border border-flomo-line px-3 h-9 focus-within:border-flomo-green/50 transition-colors">
          <Search className="w-3.5 h-3.5 text-flomo-faint" />
          <input
            value={search}
            onChange={(e) => onSearch(e.target.value)}
            placeholder="搜索 MEMO"
            className="bg-transparent outline-none text-[13px] w-full placeholder:text-flomo-faint text-flomo-ink"
          />
        </div>
      </div>

      {/* Nav */}
      <nav className="px-3 space-y-0.5">
        <button
          onClick={() => onViewChange('timeline')}
          className={navBtn(view === 'timeline' && !activeTag && !pinnedOnly)}
        >
          <StickyNote className="w-4 h-4 text-flomo-green" />
          MEMO
          <span className="ml-auto text-[11px] text-flomo-faint">{total}</span>
        </button>
        <button
          onClick={onPinnedToggle}
          className={navBtn(view === 'timeline' && pinnedOnly)}
        >
          <Pin className="w-4 h-4 text-flomo-pin" />
          置顶
        </button>
        <button
          onClick={() => onViewChange('review')}
          className={navBtn(view === 'review')}
        >
          <Dices className="w-4 h-4 text-flomo-greendark" />
          回顾
        </button>
        <button
          onClick={() => onViewChange('stats')}
          className={navBtn(view === 'stats')}
        >
          <BarChart3 className="w-4 h-4 text-flomo-greendark" />
          统计
        </button>
        <button
          onClick={() => onViewChange('settings')}
          className={navBtn(view === 'settings')}
        >
          <Settings className="w-4 h-4 text-flomo-greendark" />
          设置
        </button>
      </nav>

      {/* Tags */}
      <div className="mt-5 px-5 flex items-center gap-2 text-[11px] font-medium text-flomo-faint uppercase tracking-wider">
        <Hash className="w-3 h-3" />
        标签
      </div>
      <div className="mt-1 flex-1 overflow-y-auto px-3 pb-3 space-y-0.5">
        {tags.length === 0 && (
          <p className="px-3 py-2 text-[12px] text-flomo-faint">还没有标签，写一条带 #标签 的 memo 试试</p>
        )}
        {tags.map((t) => (
          <button
            key={t.name}
            onClick={() => onTagClick(activeTag === t.name ? null : t.name)}
            className={`w-full flex items-center gap-2.5 rounded-lg px-3 py-1.5 text-[13px] transition-colors ${
              activeTag === t.name
                ? 'bg-white text-flomo-ink font-medium shadow-sm'
                : 'text-flomo-sub hover:bg-white/60 hover:text-flomo-ink'
            }`}
          >
            <span className="w-1.5 h-1.5 rounded-full" style={{ background: tagColor(t.name) }} />
            <span className="truncate">{t.name}</span>
            <span className="ml-auto text-[11px] text-flomo-faint">{t.count}</span>
          </button>
        ))}
      </div>

      {/* Stats + user */}
      <div className="border-t border-flomo-line px-5 py-4">
        <div className="flex items-center gap-2 text-[12px] text-flomo-sub">
          <Flame className="w-3.5 h-3.5 text-flomo-green" />
          已记录 <span className="font-semibold text-flomo-ink">{total}</span> 条 ·{' '}
          <span className="font-semibold text-flomo-ink">{streakDays}</span> 天
        </div>
        <div className="mt-3 flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-full bg-flomo-green/15 text-flomo-greendark flex items-center justify-center text-[13px] font-semibold">
            浮
          </div>
          <div className="leading-tight">
            <div className="text-[13px] font-medium text-flomo-ink">本地私有版</div>
            <div className="text-[11px] text-flomo-faint">数据存于本机 SQLite</div>
          </div>
        </div>
      </div>
    </aside>
  )
}
