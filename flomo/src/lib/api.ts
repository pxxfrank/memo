import type { Memo } from '@/types/memo'

/** 服务端 API 返回的 Memo（下划线字段） */
export interface MemoDTO {
  id: number
  content: string
  created_at: number
  updated_at: number | null
  pinned: boolean
  tags: string[]
}

export function toMemo(d: MemoDTO): Memo {
  return { id: d.id, content: d.content, createdAt: d.created_at, pinned: d.pinned }
}

const TOKEN_KEY = 'memo-token'

export function getToken(): string {
  return localStorage.getItem(TOKEN_KEY) || ''
}

/** 401 时通知 UI 弹出令牌输入（监听 window 'memo:unauthorized'） */
export async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const headers: Record<string, string> = {}
  const token = getToken()
  if (token) headers['Authorization'] = 'Bearer ' + token
  if (body !== undefined) {
    headers['Content-Type'] = 'application/json'
  }
  const res = await fetch(path, {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
  if (res.status === 401) {
    window.dispatchEvent(new Event('memo:unauthorized'))
    throw new Error('unauthorized')
  }
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error((data as { error?: string }).error || `请求失败 ${res.status}`)
  return data as T
}
