import { parseRich } from '@/lib/rich'

interface RichContentProps {
  content: string
  onTagClick?: (tag: string) => void
}

/** 富文本渲染：缩进/列表/加粗/下划线/#标签 */
export function RichContent({ content, onTagClick }: RichContentProps) {
  const lines = parseRich(content)
  let olIndex = 0
  return (
    <div className="whitespace-pre-wrap text-[14px] leading-[1.75] text-flomo-ink break-words">
      {lines.map((line, li) => {
        const marker = line.list === 'ul' ? <span className="mr-1.5 text-flomo-sub">•</span>
          : line.list === 'ol' ? <span className="mr-1.5 text-flomo-sub">{++olIndex}.</span> : null
        if (line.list !== 'ol') olIndex = 0
        return (
          <div
            key={li}
            className="flex"
            style={{ paddingLeft: `${line.indent * 20}px` }}
          >
            {marker && <span className="shrink-0">{marker}</span>}
            <span className="min-w-0 flex-1">
              {line.spans.map((span, si) => {
                if (span.type === 'bold') {
                  return (
                    <strong key={si} className="font-semibold text-flomo-ink">
                      {span.text}
                    </strong>
                  )
                }
                if (span.type === 'underline') {
                  return (
                    <u key={si} className="underline decoration-flomo-greendark/50 underline-offset-2">
                      {span.text}
                    </u>
                  )
                }
                if (span.type === 'tag' && onTagClick) {
                  return (
                    <button
                      key={si}
                      onClick={(e) => {
                        e.stopPropagation()
                        onTagClick(span.tag!)
                      }}
                      className="text-flomo-greendark hover:underline underline-offset-2"
                    >
                      {span.text}
                    </button>
                  )
                }
                return <span key={si}>{span.text}</span>
              })}
            </span>
          </div>
        )
      })}
    </div>
  )
}
