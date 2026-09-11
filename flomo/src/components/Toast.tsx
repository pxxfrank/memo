interface ToastProps {
  message: string | null
}

export function Toast({ message }: ToastProps) {
  if (!message) return null
  return (
    <div className="fixed left-1/2 bottom-8 z-[60] -translate-x-1/2 rounded-full bg-flomo-ink px-5 py-2.5 text-[13px] text-white shadow-lg dark:text-flomo-bg">
      {message}
    </div>
  )
}
