import { useCallback, useEffect, useMemo, useState } from 'react'
import type { Memo } from '@/types/memo'
import { extractTags } from '@/lib/tags'
import { request, toMemo, type MemoDTO } from '@/lib/api'

export interface TagStat {
  name: string
  count: number
}

export function useMemos() {
  const [memos, setMemos] = useState<Memo[]>([])
  const [streakDays, setStreakDays] = useState(0)

  const refresh = useCallback(async () => {
    try {
      const data = await request<{ items: MemoDTO[] }>('GET', '/api/memos?limit=500')
      setMemos(data.items.map(toMemo))
    } catch {
      /* 服务未启动时保持空列表 */
    }
    try {
      const s = await request<{ streak: number }>('GET', '/api/stats')
      setStreakDays(s.streak)
    } catch {
      /* ignore */
    }
  }, [])

  useEffect(() => {
    refresh()
  }, [refresh])

  const addMemo = useCallback(async (content: string) => {
    const text = content.trim()
    if (!text) return
    try {
      const m = await request<MemoDTO>('POST', '/api/memos', { content: text })
      setMemos((prev) => [toMemo(m), ...prev])
    } catch {
      /* ignore */
    }
  }, [])

  const togglePin = useCallback(
    async (id: number) => {
      const target = memos.find((m) => m.id === id)
      if (!target) return
      setMemos((prev) => prev.map((m) => (m.id === id ? { ...m, pinned: !m.pinned } : m)))
      try {
        await request('PUT', `/api/memos/${id}`, { pinned: !target.pinned })
      } catch {
        refresh()
      }
    },
    [memos, refresh],
  )

  const updateMemo = useCallback(
    async (id: number, content: string) => {
      const text = content.trim()
      if (!text) return
      try {
        const m = await request<MemoDTO>('PUT', `/api/memos/${id}`, { content: text })
        setMemos((prev) => prev.map((x) => (x.id === id ? toMemo(m) : x)))
      } catch {
        refresh()
      }
    },
    [refresh],
  )

  const removeMemo = useCallback(
    async (id: number) => {
      setMemos((prev) => prev.filter((m) => m.id !== id))
      try {
        await request('DELETE', `/api/memos/${id}`)
      } catch {
        refresh()
      }
    },
    [refresh],
  )

  const tags: TagStat[] = useMemo(() => {
    const counter = new Map<string, number>()
    for (const m of memos) {
      for (const t of extractTags(m.content)) {
        counter.set(t, (counter.get(t) ?? 0) + 1)
      }
    }
    return Array.from(counter.entries())
      .map(([name, count]) => ({ name, count }))
      .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name, 'zh'))
  }, [memos])

  return { memos, addMemo, togglePin, updateMemo, removeMemo, tags, streakDays, refresh }
}
