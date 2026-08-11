import { useCallback, useMemo, useRef, useState } from 'react'
import { useMemos } from '@/hooks/useMemos'
import { extractTags } from '@/types/memo'
import { Sidebar, type View } from '@/sections/Sidebar'
import { Composer } from '@/sections/Composer'
import { Timeline } from '@/sections/Timeline'
import { ReviewView } from '@/sections/ReviewView'
import { StatsView } from '@/sections/StatsView'
import { SettingsView } from '@/sections/SettingsView'
import { X } from 'lucide-react'
import type { Memo } from '@/types/memo'
import { applyFormat, type FormatKind } from '@/lib/rich'
import { FormatToolbar } from '@/components/FormatToolbar'

function useToast() {
  const [msg, setMsg] = useState<string | null>(null)
  const timer = useRef<number | undefined>(undefined)
  const show = useCallback((m: string) => {
    setMsg(m)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => setMsg(null), 2200)
  }, [])
  return { msg, show }
}

export default function Home() {
  const { memos, addMemo, togglePin, updateMemo, removeMemo, tags, streakDays, refresh } = useMemos()
  const [view, setView] = useState<View>('timeline')
  const [search, setSearch] = useState('')
  const [activeTag, setActiveTag] = useState<string | null>(null)
  const [pinnedOnly, setPinnedOnly] = useState(false)
  const [editing, setEditing] = useState<Memo | null>(null)
  const [editText, setEditText] = useState('')
  const editRef = useRef<HTMLTextAreaElement>(null)
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

  const openEdit = (m: Memo) => {
    setEditing(m)
    setEditText(m.content)
  }
  const saveEdit = async () => {
    if (!editing) return
    const text = editText.trim()
    if (!text) return
    await updateMemo(editing.id, text)
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
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4"
          onClick={() => setEditing(null)}
        >
          <div
            className="w-[min(92vw,520px)] rounded-xl bg-flomo-card border border-flomo-line p-5 shadow-xl"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-[15px] font-semibold mb-3">编辑笔记</h3>
            <textarea
              ref={editRef}
              value={editText}
              onChange={(e) => setEditText(e.target.value)}
              rows={5}
              autoFocus
              className="w-full resize-none rounded-lg border border-flomo-line bg-flomo-bg px-3.5 py-3 text-[14px] leading-relaxed outline-none focus:border-flomo-green/60 transition-colors"
            />
            <div className="mt-2 flex items-center gap-1">
              <FormatToolbar
                onFormat={(kind: FormatKind) => {
                  const el = editRef.current
                  if (!el) return
                  applyFormat(el, kind)
                  setEditText(el.value)
                }}
              />
            </div>
            <div className="mt-4 flex justify-end gap-2">
              <button
                onClick={() => setEditing(null)}
                className="rounded-lg border border-flomo-line px-4 py-2 text-[13px] text-flomo-sub hover:text-flomo-ink transition-colors"
              >
                取消
              </button>
              <button
                onClick={saveEdit}
                disabled={!editText.trim()}
                className="rounded-lg bg-flomo-green px-4 py-2 text-[13px] font-medium text-white hover:bg-flomo-greendark disabled:opacity-40 transition-colors"
              >
                保存
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Toast */}
      {msg && (
        <div className="fixed left-1/2 bottom-8 z-[60] -translate-x-1/2 rounded-full bg-flomo-ink px-5 py-2.5 text-[13px] text-white shadow-lg">
          {msg}
        </div>
      )}
    </div>
  )
}
