/* MEMO 笔记 · Electron 主进程
 * 职责：拉起后端 exe（API+SQLite）→ 加载前端窗口 → 托盘 / 全局热键 / 回顾通知 / 快速记录窗
 * 移动端架构预留：前端 React 通过 REST API 与后端通信，未来安卓/iOS 直接复用同一 API 层
 */
const { app, BrowserWindow, Tray, Menu, globalShortcut, Notification, ipcMain } = require('electron')
const { spawn } = require('child_process')
const path = require('path')
const fs = require('fs')
const http = require('http')

const PORT = 8900
const BASE_URL = `http://127.0.0.1:${PORT}`
const DEFAULT_HOTKEY = 'ctrl+shift+m'

let win = null
let tray = null
let backend = null
let captureWin = null
let quitting = false
let lastReviewDate = ''

const DATA_DIR = path.join(app.getPath('userData'), 'data')

// ---------------------------------------------------------------------------
// 路径
// ---------------------------------------------------------------------------
function iconPath() {
  const candidates = [
    path.join(__dirname, 'build', 'icon.ico'),
    path.join(__dirname, '..', 'app', 'icon-512.png'),
  ]
  return candidates.find((p) => fs.existsSync(p)) || ''
}

function backendPath() {
  // 打包后：resources/backend/memo-backend.exe；开发时：项目根 dist/memo-backend.exe
  const candidates = [
    path.join(process.resourcesPath, 'backend', 'memo-backend.exe'),
    path.join(__dirname, '..', 'dist', 'memo-backend', 'memo-backend.exe'),
  ]
  const found = candidates.find((p) => fs.existsSync(p))
  if (!found) throw new Error('找不到后端 memo-backend.exe')
  return found
}

// ---------------------------------------------------------------------------
// 后端
// ---------------------------------------------------------------------------
function startBackend() {
  fs.mkdirSync(DATA_DIR, { recursive: true })
  backend = spawn(backendPath(), ['--no-gui', '--port', String(PORT)], {
    env: { ...process.env, MEMO_DATA_DIR: DATA_DIR },
    windowsHide: true,
    stdio: 'ignore',
  })
  backend.on('exit', () => {
    // 后端退出后延迟确认（PyInstaller onedir 无引导进程，此处为真实退出）
    setTimeout(() => {
      if (!quitting) {
        const req = http.get(`${BASE_URL}/api/health`, (res) => {
          res.resume()
          // 还能响应则不退出
        })
        req.on('error', () => {
          console.error('后端进程退出，应用将关闭')
          app.quit()
        })
      }
    }, 2000)
  })
}

function waitHealth(timeoutMs = 20000) {
  return new Promise((resolve, reject) => {
    const start = Date.now()
    const tick = () => {
      const req = http.get(`${BASE_URL}/api/health`, (res) => {
        res.resume()
        if (res.statusCode === 200) return resolve()
        retry()
      })
      req.on('error', retry)
      function retry() {
        if (Date.now() - start > timeoutMs) return reject(new Error('后端启动超时'))
        setTimeout(tick, 500)
      }
    }
    tick()
  })
}

function apiGet(p) {
  return new Promise((resolve, reject) => {
    http.get(BASE_URL + p, (res) => {
      let body = ''
      res.on('data', (c) => (body += c))
      res.on('end', () => {
        try {
          resolve(JSON.parse(body))
        } catch {
          reject(new Error('响应解析失败'))
        }
      })
    }).on('error', reject)
  })
}

// ---------------------------------------------------------------------------
// 主窗口
// ---------------------------------------------------------------------------
function createWindow() {
  win = new BrowserWindow({
    width: 1160,
    height: 780,
    minWidth: 840,
    minHeight: 600,
    title: 'MEMO 笔记',
    icon: iconPath(),
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  })
  win.loadURL(BASE_URL)
  win.on('close', (e) => {
    // 点关闭 = 隐藏到托盘（不退出）
    if (!quitting) {
      e.preventDefault()
      win.hide()
    }
  })
}

function toggleWindow() {
  if (!win) return
  if (win.isVisible() && win.isFocused()) win.hide()
  else {
    win.show()
    win.focus()
  }
}

// ---------------------------------------------------------------------------
// 托盘
// ---------------------------------------------------------------------------
function createTray() {
  tray = new Tray(iconPath())
  tray.setToolTip('MEMO 笔记')
  const menu = Menu.buildFromTemplate([
    { label: '打开 / 隐藏', click: () => toggleWindow() },
    { label: '快速记录', click: () => showCapture() },
    { type: 'separator' },
    { label: '退出', click: () => quit() },
  ])
  tray.setContextMenu(menu)
  tray.on('double-click', () => toggleWindow())
}

// ---------------------------------------------------------------------------
// 全局热键（呼出快速记录窗）
// ---------------------------------------------------------------------------
function toAccelerator(hk) {
  if (!hk) return null
  const parts = hk
    .split('+')
    .map((k) => k.trim())
    .filter(Boolean)
  if (!parts.length) return null
  return parts.map((k) => k.charAt(0).toUpperCase() + k.slice(1)).join('+')
}

function registerHotkey() {
  const register = (acc) => {
    try {
      globalShortcut.unregisterAll()
      if (acc) globalShortcut.register(acc, showCapture)
    } catch {
      /* 热键冲突时忽略 */
    }
  }
  register(toAccelerator(DEFAULT_HOTKEY))
  // 用户可在设置里改热键，启动后读取应用
  setTimeout(async () => {
    try {
      const cfg = await apiGet('/api/config')
      register(toAccelerator(cfg.hotkey))
    } catch {
      /* 保持默认 */
    }
  }, 3000)
}

// ---------------------------------------------------------------------------
// 快速记录窗（替代微信输入：全局热键一键记）
// ---------------------------------------------------------------------------
function showCapture() {
  if (captureWin && !captureWin.isDestroyed()) {
    captureWin.focus()
    return
  }
  captureWin = new BrowserWindow({
    width: 600,
    height: 140,
    frame: false,
    alwaysOnTop: true,
    resizable: false,
    skipTaskbar: true,
    show: false,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      preload: path.join(__dirname, 'capture-preload.js'),
    },
  })
  captureWin.loadFile(path.join(__dirname, 'capture.html'))
  captureWin.once('ready-to-show', () => captureWin.show())
  captureWin.on('closed', () => {
    captureWin = null
  })
}

ipcMain.handle('capture-save', async (_e, content) => {
  const text = (content || '').trim()
  if (!text) return { ok: false }
  try {
    const res = await fetch(`${BASE_URL}/v1/memo`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content: text }),
    })
    const data = await res.json()
    return { ok: res.ok, id: data?.data?.id }
  } catch {
    return { ok: false }
  }
})

ipcMain.handle('capture-close', () => {
  if (captureWin && !captureWin.isDestroyed()) captureWin.close()
})

// ---------------------------------------------------------------------------
// 每日回顾（主进程定时调度 + 系统通知）
// ---------------------------------------------------------------------------
async function doReview(cfg) {
  try {
    const n = Math.max(1, cfg.review_count || 3)
    const data = await apiGet('/api/memos?limit=200')
    const all = data.items || []
    const yesterday = Date.now() - 86400000
    const pool = all.filter((m) => m.created_at < yesterday)
    const src = pool.length ? pool : all
    const picked = src.sort(() => Math.random() - 0.5).slice(0, Math.min(n, src.length))
    if (!picked.length) return
    const lines = picked.map((m) => '· ' + m.content.split('\n')[0].slice(0, 36))
    new Notification({
      title: `每日回顾 · ${new Date().toLocaleDateString('zh-CN', { month: 'long', day: 'numeric' })}`,
      body: lines.join('\n'),
    }).show()
  } catch {
    /* 服务不可用则跳过 */
  }
}

function startReviewScheduler() {
  setInterval(async () => {
    try {
      const cfg = await apiGet('/api/config')
      const now = new Date()
      const hm =
        String(now.getHours()).padStart(2, '0') + ':' + String(now.getMinutes()).padStart(2, '0')
      const localDate = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(
        now.getDate(),
      ).padStart(2, '0')}`
      if (cfg.review_time && hm === cfg.review_time && lastReviewDate !== localDate) {
        lastReviewDate = localDate
        doReview(cfg)
      }
    } catch {
      /* ignore */
    }
  }, 30000)
}

// ---------------------------------------------------------------------------
// 生命周期
// ---------------------------------------------------------------------------
function quit() {
  quitting = true
  globalShortcut.unregisterAll()
  if (captureWin && !captureWin.isDestroyed()) captureWin.close()
  if (backend) backend.kill()
  app.quit()
}

app.whenReady().then(async () => {
  try {
    startBackend()
    await waitHealth()
  } catch (e) {
    console.error('后端启动失败:', e.message)
    app.exit(1)
    return
  }
  createWindow()
  createTray()
  registerHotkey()
  startReviewScheduler()
})

app.on('window-all-closed', (e) => {
  // 保留在托盘，不退出
})

app.on('before-quit', () => {
  quitting = true
})
