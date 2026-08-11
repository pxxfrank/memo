import { useRef, useState } from 'react'
import { Hash, SendHorizontal } from 'lucide-react'
import { FormatToolbar } from '@/components/FormatToolbar'
import { RichEditor, type RichEditorHandle } from '@/components/RichEditor'

interface ComposerProps {
  onSubmit: (content: string) => void
}

export function Composer({ onSubmit }: ComposerProps) {
  const [md, setMd] = useState('')
  const editorRef = useRef<RichEditorHandle>(null)

  const submit = () => {
    const text = editorRef.current?.getMarkdown().trim() ?? ''
    if (!text) return
    onSubmit(text)
    setMd('') // 外部 value 变化 → RichEditor 清空内容
  }

  const onKeyDown = (e: React.KeyboardEvent) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      e.preventDefault()
      submit()
    }
  }

  return (
    <div
      className="rounded-xl bg-flomo-card border border-flomo-line shadow-[0_1px_3px_rgba(0,0,0,0.04)] focus-within:border-flomo-green/50 transition-colors"
      onKeyDown={onKeyDown}
    >
      <RichEditor
        ref={editorRef}
        value={md}
        onChange={setMd}
        placeholder="现在的想法是……"
        className="w-full px-4 pt-4 pb-2 text-[15px] leading-relaxed text-flomo-ink outline-none placeholder:text-flomo-faint"
      />
      <div className="flex items-center gap-1 px-3 pb-3">
        <FormatToolbar onFormat={(kind) => editorRef.current?.format(kind)} />
        <button
          title="插入标签"
          onClick={() => {
            const mdText = editorRef.current?.getMarkdown() ?? ''
            const suffix = mdText === '' || mdText.endsWith(' ') ? '#' : ' #'
            editorRef.current?.insertText(suffix)
          }}
          className="p-2 rounded-lg text-flomo-faint hover:text-flomo-greendark hover:bg-flomo-tagbg transition-colors"
        >
          <Hash className="w-[18px] h-[18px]" />
        </button>
        <span className="ml-auto hidden sm:block text-[11px] text-flomo-faint mr-2">Ctrl + Enter 发送</span>
        <button
          onClick={submit}
          disabled={!md.trim()}
          className="flex items-center gap-1.5 rounded-lg bg-flomo-green px-3.5 py-1.5 text-[13px] font-medium text-white hover:bg-flomo-greendark disabled:opacity-40 disabled:cursor-not-allowed transition-colors"
        >
          <SendHorizontal className="w-3.5 h-3.5" />
          发送
        </button>
      </div>
    </div>
  )
}
