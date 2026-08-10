import { useCallback, useEffect, useState } from 'react'
import { RefreshCcw, ArrowLeft } from 'lucide-react'
import type { Memo } from '@/types/memo'
import { request, toMemo, type MemoDTO } from '@/lib/api'

interface ReviewViewProps {
  onBack: () => void
  onToast: (msg: string) => void
}

function shuffle<T>(a: T[]): T[] {
  const b = [...a]
  for (let i = b.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[b[i], b[j]] = [b[j], b[i]]
  }
  return b
}

function dayLabel(ts: number): string {
  const d = new Date(ts)
  const today = new Date()
  const startOf = (x: Date) => new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime()
  const diff = Math.round((startOf(today) - startOf(d)) / 86400_000)
  if (diff === 0) return '今天'
  if (diff === 1) return '昨天'
  return `${d.getMonth() + 1}月${d.getDate()}日`
}

export function ReviewView({ onBack, onToast }: ReviewViewProps) {
  const [cards, setCards] = useState<Memo[] | null>(null)

  const pick = useCallback(async () => {
    try {
      const cfg = await request<{ review_count?: number }>('GET', '/api/config')
      const n = Math.max(1, cfg.review_count ?? 3)
      const data = await request<{ items: MemoDTO[] }>('GET', '/api/memos?limit=500')
      const all = data.items.map(toMemo)
      const pool = all.filter((m) => m.createdAt < Date.now() - 86400_000) // 优先回顾历史
      const src = pool.length ? pool : all
      const picked = shuffle(src).slice(0, Math.min(n, src.length))
      setCards(picked)
      if (!picked.length) onToast('还没有可回顾的笔记')
    } catch {
      onToast('加载失败，服务未启动？')
    }
  }, [onToast])

  useEffect(() => {
    pick()
  }, [pick])

  return (
    <div className="mx-auto max-w-[680px] px-5 pt-10 pb-24">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h2 className="text-[20px] font-semibold tracking-tight">每日回顾</h2>
          <p className="mt-1 text-[12px] text-flomo-faint">随机翻出过去的笔记，让记忆重新浮现</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={pick}
            className="flex items-center gap-1.5 rounded-lg bg-flomo-green px-3.5 py-2 text-[13px] font-medium text-white hover:bg-flomo-greendark transition-colors"
          >
            <RefreshCcw className="w-3.5 h-3.5" />
            再抽一组
          </button>
          <button
            onClick={onBack}
            className="flex items-center gap-1.5 rounded-lg border border-flomo-line px-3.5 py-2 text-[13px] text-flomo-sub hover:text-flomo-ink transition-colors"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            返回
          </button>
        </div>
      </div>

      {cards === null ? (
        <div className="py-16 text-center text-[13px] text-flomo-faint">抽取中…</div>
      ) : cards.length === 0 ? (
        <div className="py-16 text-center">
          <div className="text-[32px]">🎲</div>
          <p className="mt-2 text-[13px] text-flomo-faint">还没有可回顾的笔记，先去记几条吧</p>
        </div>
      ) : (
        <div className="space-y-3">
          {cards.map((m) => (
            <div
              key={m.id}
              className="rounded-xl bg-flomo-card border border-flomo-line px-5 py-4 shadow-[0_1px_3px_rgba(0,0,0,0.04)]"
            >
              <p className="whitespace-pre-wrap text-[15px] leading-[1.8] text-flomo-ink break-words">
                {m.content}
              </p>
              <div className="mt-3 flex items-center gap-2 text-[11px] text-flomo-faint">
                <span>📅 {dayLabel(m.createdAt)}</span>
                <span>·</span>
                <span>{new Date(m.createdAt).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}</span>
                {m.pinned && <span className="text-flomo-pin">📌 置顶</span>}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
