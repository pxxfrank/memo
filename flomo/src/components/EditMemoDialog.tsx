import { useRef, useState } from 'react'
import { FormatToolbar } from '@/components/FormatToolbar'
import { RichEditor, type RichEditorHandle } from '@/components/RichEditor'

interface EditMemoDialogProps {
  initial: string
  onCancel: () => void
  onSave: (text: string) => void
}

/** 笔记编辑弹窗（WYSIWYG 富文本） */
export function EditMemoDialog({ initial, onCancel, onSave }: EditMemoDialogProps) {
  const [text, setText] = useState(initial)
  const ref = useRef<RichEditorHandle>(null)

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4"
      onClick={onCancel}
    >
      <div
        className="w-[min(92vw,520px)] rounded-xl bg-flomo-card border border-flomo-line p-5 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-[15px] font-semibold mb-3">编辑笔记</h3>
        <RichEditor
          ref={ref}
          value={text}
          onChange={setText}
          placeholder="修改内容……"
          autoFocus
          className="w-full rounded-lg border border-flomo-line bg-flomo-bg px-3.5 py-3 text-[14px] leading-relaxed outline-none focus:border-flomo-green/60 transition-colors min-h-[120px]"
        />
        <div className="mt-2 flex items-center gap-1">
          <FormatToolbar onFormat={(kind) => ref.current?.format(kind)} />
        </div>
        <div className="mt-4 flex justify-end gap-2">
          <button
            onClick={onCancel}
            className="rounded-lg border border-flomo-line px-4 py-2 text-[13px] text-flomo-sub hover:text-flomo-ink transition-colors"
          >
            取消
          </button>
          <button
            onClick={() => onSave(text)}
            disabled={!text.trim()}
            className="rounded-lg bg-flomo-green px-4 py-2 text-[13px] font-medium text-white hover:bg-flomo-greendark disabled:opacity-40 transition-colors"
          >
            保存
          </button>
        </div>
      </div>
    </div>
  )
}
