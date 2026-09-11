import { useCallback, useRef, useState } from 'react'

/** 轻量 Toast：show(msg) 后 2.2 秒自动消失 */
export function useToast() {
  const [msg, setMsg] = useState<string | null>(null)
  const timer = useRef<number | undefined>(undefined)
  const show = useCallback((m: string) => {
    setMsg(m)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => setMsg(null), 2200)
  }, [])
  return { msg, show }
}
