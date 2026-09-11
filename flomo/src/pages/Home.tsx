import { useMemo, useState } from 'react'
import { useMemos } from '@/hooks/useMemos'
import { useToast } from '@/hooks/useToast'
import { extractTags } from '@/lib/tags'
import { Sidebar, type View } from '@/sections/Sidebar'
import { Composer } from '@/sections/Composer'
import { Timeline } from '@/sections/Timeline'
import { ReviewView } from '@/sections/ReviewView'
import { StatsView } from '@/sections/StatsView'
import { SettingsView } from '@/sections/SettingsView'
import { EditMemoDialog } from '@/components/EditMemoDialog'
import { Toast } from '@/components/Toast'
import { X } from 'lucide-react'
import type { Memo } from '@/types/memo'

export default function Home() {
  const { memos, addMemo, togglePin, updateMemo, removeMemo, tags, streakDays, refresh } = useMemos()
  const [view, setView] = useState<View>('timeline')
  const [search, setSearch] = useState('')
  const [activeTag, setActiveTag] = useState<string | null>(null)
  const [pinnedOnly, setPinnedOnly] = useState(false)
  const [editing, setEditing] = useState<Memo | null>(null)
  const { msg, show } = useToast()

  const goTimeline = () => setView('timeline')

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return memos.filter((m) => {
      if (pinnedOnly && !m.pinned) return false
      if (activeTag && !extractTags(m.content).includes(activeTag)) return false
      if (q && !m.content.toLowerCase().includes(q)) return false
      return true
    })
  }, [memos, search, activeTag, pinnedOnly])

  const onTagClick = (tag: string | null) => {
    setPinnedOnly(false)
    setActiveTag(tag)
    goTimeline()
  }

  const openEdit = (m: Memo) => setEditing(m)

  const saveEdit = async (text: string) => {
    if (!editing) return
    const t = text.trim()
    if (!t) return
    await updateMemo(editing.id, t)
    setEditing(null)
    show('已保存')
  }

  return (
    <div className="flex min-h-screen bg-flomo-bg text-flomo-ink">
      <Sidebar
        tags={tags}
        total={memos.length}
        streakDays={streakDays}
        search={search}
        onSearch={setSearch}
        activeTag={activeTag}
        onTagClick={onTagClick}
        pinnedOnly={pinnedOnly}
        onPinnedToggle={() => {
          setActiveTag(null)
          setPinnedOnly((v) => !v)
          goTimeline()
        }}
        view={view}
        onViewChange={setView}
      />

      <main className="flex-1 min-w-0">
        {view === 'review' ? (
          <ReviewView onBack={goTimeline} onToast={show} />
        ) : view === 'stats' ? (
          <StatsView onBack={goTimeline} />
        ) : view === 'settings' ? (
          <SettingsView onBack={goTimeline} onToast={show} onDataChanged={refresh} />
        ) : (
          <div className="mx-auto max-w-[680px] px-5 pt-10 pb-24">
            {/* 顶部问候 */}
            <div className="mb-5 flex items-baseline justify-between">
              <h1 className="text-[20px] font-semibold tracking-tight">
                {new Date().getHours() < 12 ? '早上好' : new Date().getHours() < 18 ? '下午好' : '晚上好'}，记录者
              </h1>
              <span className="text-[12px] text-flomo-faint">
                {new Date().toLocaleDateString('zh-CN', { month: 'long', day: 'numeric', weekday: 'long' })}
              </span>
            </div>

            <Composer onSubmit={addMemo} />

            {/* 过滤状态条 */}
            {(activeTag || pinnedOnly || search) && (
              <div className="mt-5 flex items-center gap-2 text-[12px]">
                <span className="text-flomo-faint">筛选中：</span>
                <span className="inline-flex items-center gap-1 rounded-full bg-flomo-tagbg text-flomo-greendark px-2.5 py-1 font-medium">
                  {activeTag ? `#${activeTag}` : pinnedOnly ? '置顶' : `“${search}”`}
                  <button
                    onClick={() => {
                      setActiveTag(null)
                      setPinnedOnly(false)
                      setSearch('')
                    }}
                    className="hover:text-flomo-ink"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </span>
                <span className="text-flomo-faint">{filtered.length} 条结果</span>
              </div>
            )}

            <div className="mt-6">
              <Timeline
                memos={filtered}
                onTogglePin={togglePin}
                onRemove={removeMemo}
                onEdit={openEdit}
                onTagClick={onTagClick}
              />
            </div>
          </div>
        )}
      </main>

      {/* 编辑弹窗 */}
      {editing && (
        <EditMemoDialog
          initial={editing.content}
          onCancel={() => setEditing(null)}
          onSave={saveEdit}
        />
      )}

      <Toast message={msg} />
    </div>
  )
}
