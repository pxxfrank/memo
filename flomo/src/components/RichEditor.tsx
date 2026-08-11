import { forwardRef, useEffect, useImperativeHandle, useRef } from 'react'
import { htmlToMd, mdToHtml } from '@/lib/md'
import type { FormatKind } from '@/lib/rich'

export interface RichEditorHandle {
  /** 应用格式（execCommand 作用于当前选区，所见即所得） */
  format: (kind: FormatKind) => void
  /** 插入文本（如 # 标签） */
  insertText: (text: string) => void
  /** 取当前 Markdown 内容 */
  getMarkdown: () => string
}

interface RichEditorProps {
  value: string
  onChange: (md: string) => void
  placeholder?: string
  autoFocus?: boolean
  className?: string
}

const EXEC: Record<FormatKind, string> = {
  bold: 'bold',
  underline: 'underline',
  ul: 'insertUnorderedList',
  ol: 'insertOrderedList',
  indent: 'indent',
  outdent: 'outdent',
}

/**
 * 所见即所得编辑器：contenteditable 显示真实效果，
 * 存储/提交始终为 Markdown 子集（htmlToMd / mdToHtml 转换）。
 */
export const RichEditor = forwardRef<RichEditorHandle, RichEditorProps>(
  function RichEditor({ value, onChange, placeholder, autoFocus, className }, ref) {
    const divRef = useRef<HTMLDivElement>(null)
    const editing = useRef(false) // 内部编辑中，避免外部 value 覆盖光标
    const lastValue = useRef(value)

    // 外部 value 变化（如提交后清空）时同步到编辑器
    useEffect(() => {
      if (editing.current || value === lastValue.current) return
      lastValue.current = value
      const el = divRef.current
      if (el) {
        el.innerHTML = mdToHtml(value)
        if (autoFocus) el.focus()
      }
    }, [value, autoFocus])

    const emit = () => {
      const el = divRef.current
      if (!el) return
      editing.current = true
      const md = htmlToMd(el)
      lastValue.current = md
      onChange(md)
      // 异步清除标记，确保后续外部 value 更新可生效
      requestAnimationFrame(() => {
        editing.current = false
      })
    }

    useImperativeHandle(ref, () => ({
      format(kind) {
        const el = divRef.current
        if (!el) return
        el.focus()
        // execCommand 对当前选区生效
        document.execCommand(EXEC[kind])
        emit()
      },
      insertText(text) {
        const el = divRef.current
        if (!el) return
        el.focus()
        document.execCommand('insertText', false, text)
        emit()
      },
      getMarkdown() {
        return divRef.current ? htmlToMd(divRef.current) : ''
      },
    }))

    return (
      <div
        ref={divRef}
        contentEditable
        suppressContentEditableWarning
        role="textbox"
        aria-multiline="true"
        onInput={emit}
        onBlur={emit}
        onPaste={(e) => {
          // 粘贴仅取纯文本，避免格式污染
          e.preventDefault()
          const text = e.clipboardData.getData('text/plain')
          document.execCommand('insertText', false, text)
          emit()
        }}
        data-placeholder={placeholder}
        className={`rich-editor ${className ?? ''}`}
      />
    )
  },
)
