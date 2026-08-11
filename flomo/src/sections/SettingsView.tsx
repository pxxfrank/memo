import { useEffect, useState } from 'react'
import { ArrowLeft, Save, Download, Upload, Trash2, KeyRound } from 'lucide-react'
import { request } from '@/lib/api'

interface SettingsViewProps {
  onBack: () => void
  onToast: (msg: string) => void
  onDataChanged: () => void
}

interface Config {
  hotkey: string
  review_time: string
  review_count: number
  token?: string
}

const EXPORTS = [
  { label: 'JSON', fmt: 'json', desc: '完整数据' },
  { label: 'Markdown', fmt: 'md', desc: '按日期分组' },
  { label: 'CSV', fmt: 'csv', desc: '表格' },
]

export function SettingsView({ onBack, onToast, onDataChanged }: SettingsViewProps) {
  const [cfg, setCfg] = useState<Config>({ hotkey: '', review_time: '09:30', review_count: 3 })
  const [token, setToken] = useState('')
  const [saving, setSaving] = useState(false)
  const [syncDir, setSyncDir] = useState('')
  const [syncEnabled, setSyncEnabled] = useState(false)
  const [syncPass, setSyncPass] = useState('')
  const [hasPassphrase, setHasPassphrase] = useState(false)
  const [syncing, setSyncing] = useState(false)
  const [dark, setDark] = useState(
    () => typeof document !== 'undefined' && document.documentElement.classList.contains('dark'),
  )

  const toggleDark = () => {
    const next = !dark
    setDark(next)
    if (next) {
      document.documentElement.classList.add('dark')
      localStorage.setItem('memo-dark', '1')
    } else {
      document.documentElement.classList.remove('dark')
      localStorage.removeItem('memo-dark')
    }
  }

  useEffect(() => {
    request<Config>('GET', '/api/config')
      .then((c) => {
        setCfg({
          hotkey: c.hotkey || 'ctrl+shift+m',
          review_time: c.review_time || '09:30',
          review_count: c.review_count || 3,
        })
        setToken(c.token || '')
      })
      .catch(() => onToast('配置加载失败，服务未启动？'))
    request<{ enabled: boolean; dir: string; has_passphrase: boolean }>('GET', '/api/sync/status')
      .then((s) => {
        setSyncDir(s.dir || '')
        setSyncEnabled(s.enabled)
        setHasPassphrase(s.has_passphrase)
      })
      .catch(() => {})
  }, [onToast])

  const saveSyncDir = async () => {
    const dir = syncDir.trim()
    try {
      await request('POST', '/api/config', {
        sync: { dir },
        passphrase: syncPass.trim(),  // 空串 = 清除加密
      })
      setSyncEnabled(!!dir)
      setHasPassphrase(!!syncPass.trim())
      setSyncPass('')
      onToast(dir ? '同步目录已保存' + (syncPass.trim() ? '（已启用端到端加密）' : '') : '已关闭云同步')
    } catch {
      onToast('保存失败')
    }
  }

  const syncNow = async () => {
    if (!syncEnabled) return
    setSyncing(true)
    try {
      const r = await request<{ ok: boolean; applied: number }>('POST', '/api/sync/now')
      onToast(r.ok ? `同步完成，应用 ${r.applied} 条` : '同步失败')
    } catch {
      onToast('同步失败，目录不可访问？')
    }
    setSyncing(false)
  }

  const save = async () => {
    setSaving(true)
    try {
      await request('POST', '/api/config', {
        hotkey: cfg.hotkey.trim() || 'ctrl+shift+m',
        review_time: cfg.review_time || '09:30',
        review_count: Math.max(1, Math.min(10, Number(cfg.review_count) || 3)),
      })
      onToast('已保存（热键与回顾时间重启服务后生效）')
    } catch {
      onToast('保存失败')
    }
    setSaving(false)
  }

  const importFile = async (f: File | undefined) => {
    if (!f) return
    try {
      const data = JSON.parse(await f.text())
      const res = await request<{ imported: number }>('POST', '/api/import', { data })
      onToast(`导入 ${res.imported} 条`)
      onDataChanged()
    } catch {
      onToast('导入失败，请检查 JSON 格式')
    }
  }

  const clearAll = async () => {
    if (!window.confirm('确定清空全部笔记？此操作不可恢复！建议先导出备份。')) return
    try {
      await request('DELETE', '/api/memos')
      onToast('已清空')
      onDataChanged()
    } catch {
      onToast('清空失败')
    }
  }

  const resetToken = async () => {
    if (!window.confirm('重置后旧的访问令牌立即失效，需在手机等设备上重新输入。确定重置？')) return
    try {
      const r = await request<{ token?: string }>('POST', '/api/config', { reset_token: true })
      setToken(r.token || '')
      onToast('令牌已重置，请在其他设备重新输入')
    } catch {
      onToast('重置失败')
    }
  }

  const copyToken = async () => {
    try {
      await navigator.clipboard.writeText(token)
      onToast('令牌已复制')
    } catch {
      onToast('复制失败')
    }
  }

  const rowCls = 'flex items-center justify-between py-3.5'
  const labelCls = 'text-[13px] font-medium text-flomo-ink'
  const descCls = 'text-[11px] text-flomo-faint mt-0.5'
  const inputCls =
    'rounded-lg border border-flomo-line bg-flomo-bg px-3 h-9 text-[13px] outline-none focus:border-flomo-green/60 transition-colors'

  return (
    <div className="mx-auto max-w-[680px] px-5 pt-10 pb-24">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h2 className="text-[20px] font-semibold tracking-tight">设置</h2>
          <p className="mt-1 text-[12px] text-flomo-faint">本地私有 · 数据存于本机 SQLite</p>
        </div>
        <button
          onClick={onBack}
          className="flex items-center gap-1.5 rounded-lg border border-flomo-line px-3.5 py-2 text-[13px] text-flomo-sub hover:text-flomo-ink transition-colors"
        >
          <ArrowLeft className="w-3.5 h-3.5" />
          返回
        </button>
      </div>

      {/* 常规 */}
      <div className="rounded-xl bg-flomo-card border border-flomo-line px-5 py-2">
        <div className={rowCls}>
          <div>
            <div className={labelCls}>全局热键</div>
            <div className={descCls}>任意界面呼出快速记录窗（重启服务后生效）</div>
          </div>
          <div className="flex items-center gap-1.5 text-[12px] text-flomo-sub">
            <KeyRound className="w-3.5 h-3.5" />
            <input
              value={cfg.hotkey}
              onChange={(e) => setCfg({ ...cfg, hotkey: e.target.value })}
              className={`${inputCls} w-[140px]`}
            />
          </div>
        </div>
        <div className={rowCls}>
          <div>
            <div className={labelCls}>每日回顾时间</div>
            <div className={descCls}>到点推送系统通知，随机回顾历史笔记</div>
          </div>
          <input
            type="time"
            value={cfg.review_time}
            onChange={(e) => setCfg({ ...cfg, review_time: e.target.value })}
            className={inputCls}
          />
        </div>
        <div className={rowCls}>
          <div>
            <div className={labelCls}>每次回顾条数</div>
          </div>
          <input
            type="number"
            min={1}
            max={10}
            value={cfg.review_count}
            onChange={(e) => setCfg({ ...cfg, review_count: Number(e.target.value) })}
            className={`${inputCls} w-[72px]`}
          />
        </div>
      </div>

      {/* 数据 */}
      <h3 className="mt-7 mb-3 text-[13px] font-semibold text-flomo-ink">数据管理</h3>
      <div className="rounded-xl bg-flomo-card border border-flomo-line px-5 py-4">
        <div className="flex items-center gap-2 mb-3 text-[13px] font-medium">
          <Download className="w-4 h-4 text-flomo-green" />
          导出备份
        </div>
        <div className="flex gap-2">
          {EXPORTS.map((e) => (
            <a
              key={e.fmt}
              href={`/api/export?format=${e.fmt}`}
              className="flex-1 rounded-lg border border-flomo-line px-3 py-2.5 text-center hover:border-flomo-green/50 hover:bg-flomo-tagbg transition-colors"
            >
              <div className="text-[13px] font-medium text-flomo-ink">{e.label}</div>
              <div className="text-[11px] text-flomo-faint">{e.desc}</div>
            </a>
          ))}
        </div>

        <div className="mt-5 flex items-center gap-2 mb-3 text-[13px] font-medium">
          <Upload className="w-4 h-4 text-flomo-green" />
          导入（JSON，见导出格式）
        </div>
        <label className="flex items-center justify-center gap-2 rounded-lg border border-dashed border-flomo-line px-3 py-3 text-[13px] text-flomo-sub cursor-pointer hover:border-flomo-green/50 hover:text-flomo-greendark transition-colors">
          <Upload className="w-4 h-4" />
          选择 JSON 文件
          <input type="file" accept=".json,application/json" className="hidden" onChange={(e) => importFile(e.target.files?.[0])} />
        </label>

        <div className="mt-5 border-t border-flomo-line pt-4">
          <button
            onClick={clearAll}
            className="flex items-center gap-1.5 text-[13px] text-red-500 hover:text-red-600 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
            清空全部数据（不可恢复）
          </button>
        </div>
      </div>

      {/* 云同步（坚果云） */}
      <h3 className="mt-7 mb-3 text-[13px] font-semibold text-flomo-ink">云同步（坚果云）</h3>
      <div className="rounded-xl bg-flomo-card border border-flomo-line px-5 py-4">
        <p className="text-[12px] text-flomo-faint leading-relaxed">
          各端本地编辑，经坚果云交换变更日志实现双向同步（手机端 APP 即将支持）。
          填写坚果云本地同步文件夹下的子目录即可启用，如{' '}
          <code className="bg-flomo-bg px-1 rounded">D:\Nutstore\memo-sync</code>。
        </p>
        <div className="mt-3">
          <label className="text-[11px] text-flomo-faint">坚果云同步目录（本地路径，留空关闭）</label>
          <div className="mt-1.5 flex gap-2">
            <input
              value={syncDir}
              onChange={(e) => setSyncDir(e.target.value)}
              placeholder="D:\Nutstore\memo-sync"
              className={`${inputCls} flex-1 font-mono text-[12px]`}
            />
            <button
              onClick={saveSyncDir}
              className="rounded-lg border border-flomo-line px-3 h-9 text-[12px] text-flomo-sub hover:text-flomo-greendark transition-colors"
            >
              保存目录
            </button>
            <button
              onClick={syncNow}
              disabled={!syncEnabled || syncing}
              className="rounded-lg bg-flomo-green px-3 h-9 text-[12px] font-medium text-white hover:bg-flomo-greendark disabled:opacity-40 transition-colors"
            >
              {syncing ? '同步中…' : '立即同步'}
            </button>
          </div>
        </div>
        <div className="mt-3">
          <label className="text-[11px] text-flomo-faint">同步口令（端到端加密，留空不加密；各设备须一致）</label>
          <div className="mt-1.5 flex gap-2">
            <input
              type="password"
              value={syncPass}
              onChange={(e) => setSyncPass(e.target.value)}
              placeholder={hasPassphrase ? '已启用加密，输入新口令可修改' : '设置口令以加密日志'}
              className={`${inputCls} flex-1 font-mono text-[12px]`}
            />
          </div>
        </div>
        <p className="mt-2.5 text-[11px] text-flomo-faint">
          状态：{syncEnabled ? `已启用（${syncDir}）· 每 15 秒自动同步` : '未启用'} · 设备名
          desktop · 冲突按"后写者胜" · {hasPassphrase ? '🔒 端到端加密' : '未加密'}
        </p>
      </div>

      {/* 局域网访问 */}
      <h3 className="mt-7 mb-3 text-[13px] font-semibold text-flomo-ink">局域网访问（手机等设备）</h3>
      <div className="rounded-xl bg-flomo-card border border-flomo-line px-5 py-4">
        <p className="text-[12px] text-flomo-faint leading-relaxed">
          用 <code className="bg-flomo-bg px-1 rounded">start_lan.bat</code> 开启后，手机连同一 WiFi 访问{' '}
          <code className="bg-flomo-bg px-1 rounded">http://{window.location.hostname}:8901</code>，
          输入下方令牌即可使用（数据与桌面版同一份）。
        </p>
        <div className="mt-3 flex items-center gap-2">
          <input
            readOnly
            value={token}
            onFocus={(e) => e.target.select()}
            className={`${inputCls} flex-1 font-mono text-[12px]`}
            placeholder="正在获取令牌…"
          />
          <button
            onClick={copyToken}
            className="rounded-lg border border-flomo-line px-3 h-9 text-[12px] text-flomo-sub hover:text-flomo-greendark transition-colors"
          >
            复制
          </button>
          <button
            onClick={resetToken}
            className="rounded-lg border border-red-200 px-3 h-9 text-[12px] text-red-500 hover:bg-red-50 transition-colors"
          >
            重置
          </button>
        </div>
      </div>

      {/* API */}
      <h3 className="mt-7 mb-3 text-[13px] font-semibold text-flomo-ink">外部写入 API（flomo 兼容）</h3>
      <div className="rounded-xl bg-flomo-card border border-flomo-line px-5 py-4">
        <p className="text-[12px] text-flomo-faint leading-relaxed">
          供脚本 / PowerToys Run / 输入法快捷指令调用，实现任意时刻快速记录：
        </p>
        <pre className="mt-2.5 rounded-lg bg-flomo-bg border border-flomo-line px-3.5 py-3 text-[12px] leading-relaxed text-flomo-sub overflow-x-auto whitespace-pre-wrap">
{`POST ${window.location.origin}/v1/memo
{"content": "随手记一条 #测试"}`}
        </pre>
      </div>

      {/* 外观 */}
      <h3 className="mt-7 mb-3 text-[13px] font-semibold text-flomo-ink">外观</h3>
      <div className="rounded-xl bg-flomo-card border border-flomo-line px-5 py-4">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-[13px] text-flomo-ink font-medium">暗黑模式</div>
            <div className="text-[11px] text-flomo-faint mt-0.5">深色主题，夜间使用更舒适</div>
          </div>
          <button
            onClick={toggleDark}
            className={`relative w-10 h-[22px] rounded-full transition-colors ${
              dark ? 'bg-flomo-green' : 'bg-flomo-line'
            }`}
          >
            <span
              className={`absolute top-[2px] w-[18px] h-[18px] rounded-full bg-white shadow transition-all ${
                dark ? 'left-[20px]' : 'left-[2px]'
              }`}
            />
          </button>
        </div>
      </div>

      <div className="mt-6 flex justify-end">
        <button
          onClick={save}
          disabled={saving}
          className="flex items-center gap-1.5 rounded-lg bg-flomo-green px-4 py-2 text-[13px] font-medium text-white hover:bg-flomo-greendark disabled:opacity-50 transition-colors"
        >
          <Save className="w-3.5 h-3.5" />
          保存设置
        </button>
      </div>
    </div>
  )
}
