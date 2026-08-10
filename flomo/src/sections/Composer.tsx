import { useEffect, useRef, useState } from 'react'
import { Image, Hash, Sparkles, SendHorizontal } from 'lucide-react'

interface ComposerProps {
  onSubmit: (content: string) => void
}

export function Composer({ onSubmit }: ComposerProps) {
  const [value, setValue] = useState('')
  const ref = useRef<HTMLTextAreaElement>(null)

  // 自动增高
  useEffect(() => {
    const el = ref.current
    if (!el) return
    el.style.height = 'auto'
    el.style.height = Math.min(el.scrollHeight, 260) + 'px'
  }, [value])

  const submit = () => {
    if (!value.trim()) return
    onSubmit(value)
    setValue('')
  }

  const onKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault()
      submit()
    }
  }

  return (
    <div className="rounded-xl bg-flomo-card border border-flomo-line shadow-[0_1px_3px_rgba(0,0,0,0.04)] focus-within:border-flomo-green/50 transition-colors">
      <textarea
        ref={ref}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={onKeyDown}
        rows={3}
        placeholder="现在的想法是……"
        className="w-full resize-none bg-transparent px-4 pt-4 pb-2 text-[15px] leading-relaxed text-flomo-ink outline-none placeholder:text-flomo-faint"
      />
      <div className="flex items-center gap-1 px-3 pb-3">
        <button
          title="插入图片"
          className="p-2 rounded-lg text-flomo-faint hover:text-flomo-greendark hover:bg-flomo-tagbg transition-colors"
        >
          <Image className="w-[18px] h-[18px]" />
        </button>
        <button
          title="插入标签"
          onClick={() => setValue((v) => v + (v.endsWith(' ') || v === '' ? '' : ' ') + '#')}
          className="p-2 rounded-lg text-flomo-faint hover:text-flomo-greendark hover:bg-flomo-tagbg transition-colors"
        >
          <Hash className="w-[18px] h-[18px]" />
        </button>
        <button
          title="AI 联想"
          className="p-2 rounded-lg text-flomo-faint hover:text-flomo-greendark hover:bg-flomo-tagbg transition-colors"
        >
          <Sparkles className="w-[18px] h-[18px]" />
        </button>
        <span className="ml-auto hidden sm:block text-[11px] text-flomo-faint mr-2">Ctrl + Enter 发送</span>
        <button
          onClick={submit}
          disabled={!value.trim()}
          className="flex items-center gap-1.5 rounded-lg bg-flomo-green px-3.5 py-1.5 text-[13px] font-medium text-white hover:bg-flomo-greendark disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          <SendHorizontal className="w-3.5 h-3.5" />
          发送
        </button>
      </div>
    </div>
  )
}
