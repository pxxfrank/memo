/**
 * 时间格式化工具（Timeline / MemoCard / ReviewView 共用，避免多处重复实现）
 */

/** 按天分组键 */
export function dayKey(ts: number): string {
  return new Date(ts).toDateString()
}

const startOfDay = (d: Date): number =>
  new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()

/** 相对日期标签：今天 / 昨天 / M月D日 / YYYY年M月D日 */
export function dayLabel(ts: number): string {
  const d = new Date(ts)
  const today = new Date()
  const diff = Math.round((startOfDay(today) - startOfDay(d)) / 86400_000)
  if (diff === 0) return '今天'
  if (diff === 1) return '昨天'
  if (d.getFullYear() === today.getFullYear()) return `${d.getMonth() + 1}月${d.getDate()}日`
  return `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`
}

/** HH:mm（24 小时制，补零） */
export function fmtTime(ts: number): string {
  const d = new Date(ts)
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
}
