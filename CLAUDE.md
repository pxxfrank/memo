# CLAUDE.md — MEMO 项目协作指南

本文件为 AI 助手（Claude 等）维护本项目提供上下文。修改代码前先读本文件。

## 项目概览

**MEMO**：flomo（浮墨笔记）的本地私有平替。像发微博一样记笔记，数据 100% 存本机 SQLite，零上传。
核心特性：快速记录、多级标签（`#父/子`）、时间线、全文搜索、每日回顾、统计热力图、导出/导入、编辑/置顶、全局热键快速记录、MCP 供 AI 按标签/日期范围读取。**无语音输入**（明确不做）。

交付形态（三选一/并存）：
1. **桌面版（推荐）**：Electron 壳 + Python 后端 exe + React 前端，NSIS 安装包
2. **网页版**：Python 服务 + 浏览器/PWA
3. **MCP 接口**：AI Agent 读取/写入

## 技术栈与架构

```
React 前端（UI 层，flomo/ 源码 → 构建到 app/）
  ├─ 桌面窗口（Electron 壳 desktop/，加载后端托管的前端）
  ├─ 网页 / PWA（http://127.0.0.1:8899）
  └─ 未来移动端（复用 REST API，架构已预留，未实现）
        │ REST API
Python 后端（service.py → PyInstaller 打包 dist/memo-backend/）
  └─ SQLite（memo.db）本地存储
MCP Server（mcp_server.py → PyInstaller 打包 dist/memo-mcp/）
```

- 前端：React 19 + Vite 7 + Tailwind 3 + shadcn 风格（Kimi 生成后集成），TypeScript
- 后端：Python 3.14（`C:\Python314\python.exe`，**PATH 里的 `python` 是 chrys venv，无 pip 无依赖，勿用**），stdlib HTTP 服务
- 桌面壳：Electron 33 + electron-builder 25（NSIS 安装包）
- MCP：`mcp` Python SDK 1.x（FastMCP），注意 mcp 2.x 重构无 fastmcp，**勿升级**

## 目录结构

| 路径 | 说明 |
|---|---|
| `service.py` | 后端主服务：REST API + flomo 兼容写入 + 静态托管 + (GUI: 托盘/热键/回顾) |
| `mcp_server.py` | MCP Server：6 个工具（list_tags/count_memos/list_memos/get_memo/add_memo/get_stats） |
| `app/` | 前端**构建产物** + PWA（manifest.json、sw.js、icon-*.png） |
| `flomo/` | 前端**源码**（React/Vite），改这里后 `npm run build` 输出到 `flomo/dist/` |
| `desktop/` | Electron 壳（main.js 主进程、capture.html 快速记录窗、build/icon.ico） |
| `dist/` | PyInstaller 产物：`memo-backend/`（onedir）、`memo-mcp/`（onedir） |
| `memo.db*` | 网页版模式数据（项目目录）；桌面版数据在 `%APPDATA%\memo\data\` |
| `start.bat` / `install_service.bat` / `uninstall_service.bat` | 网页版服务管理 |
| `README.md` | 用户文档（功能/安装/MCP 配置/数据迁移） |

## 关键命令

```bat
REM 环境：Python 一律用 C:\Python314\python.exe；pip 用清华镜像 -i https://pypi.tuna.tsinghua.edu.cn/simple

REM 网页版（源码模式）
C:\Python314\python.exe service.py --no-gui --port 8899   REM 无 GUI；默认 8899 含托盘/热键

REM 前端构建（改 flomo/ 源码后）→ 部署到 app/
cd flomo && npm ci && npm run build
REM 然后复制 dist/index.html + dist/assets/ 到 app/，并更新 app/sw.js 的 CACHE 版本号与 ASSETS 文件名

REM 后端打包（PyInstaller，必须 --onedir 不能用 --onefile！）
C:\Python314\python.exe -m PyInstaller --noconfirm --onedir --name memo-backend ^
  --exclude-module tkinter --exclude-module pystray --exclude-module keyboard --exclude-module PIL ^
  --add-data "app;app" service.py

REM MCP 打包（保留 console 子系统以支持 stdio 管道）
C:\Python314\python.exe -m PyInstaller --noconfirm --onedir --name memo-mcp ^
  --exclude-module tkinter --exclude-module pystray --exclude-module keyboard --exclude-module PIL ^
  --hidden-import uvicorn --hidden-import uvicorn.loops.auto --hidden-import uvicorn.loops.asyncio ^
  --hidden-import uvicorn.protocols.http.auto --hidden-import uvicorn.protocols.http.h11_impl ^
  --hidden-import uvicorn.lifespan.on mcp_server.py

REM 桌面版打包（需先完成前端构建+后端打包；国内网络需镜像）
cd desktop
set ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/
set ELECTRON_BUILDER_BINARIES_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/
npx electron-builder --win        REM 输出 desktop/release/MEMO-笔记-Setup-1.1.0.exe

REM MCP 运行
dist\memo-mcp\memo-mcp.exe                        REM stdio
dist\memo-mcp\memo-mcp.exe --http --port 8898     REM Streamable HTTP
```

## 端口与数据约定

| 端口 | 用途 |
|---|---|
| 8899 | 网页版后端（service.py 源码模式，数据在项目目录 memo.db） |
| 8900 | 桌面版后端（Electron 拉起 memo-backend.exe，数据在 `%APPDATA%\memo\data\memo.db`） |
| 8901 | 局域网访问（start_lan.bat 启动，`--host 0.0.0.0`，与桌面版同数据目录） |
| 8898 | MCP HTTP 模式 |

## 鉴权机制（局域网模式）

- `service.py --host 0.0.0.0` 时：非本机来源（client IP ≠ 127.0.0.1/::1）访问 `/api/*`、`/v1/*` 一律要求令牌；本机免令牌
- 令牌自动生成存于 `config.json`（`token` 字段），`ensure_token()` / `reset_token()` 管理；校验用 `hmac.compare_digest`
- 令牌传递：`Authorization: Bearer <t>` / `X-Memo-Token` / `?token=` 均可
- 前端：`api.ts` 请求自动带 `Authorization`（localStorage `memo-token`）；401 触发 `memo:unauthorized` 事件 → index.html 弹 prompt 输入 → 保存并 reload
- 桌面版（Electron spawn 后端默认 127.0.0.1）与源码网页版默认不受影响（免令牌）
- 打包版 exe 数据目录默认 `%APPDATA%\memo\data`（无需 MEMO_DATA_DIR）；MCP 直接读 SQLite 不走 HTTP 鉴权（本地工具）

## 数据约定

- 数据目录统一由 `MEMO_DATA_DIR` 环境变量覆盖；打包版默认 `%APPDATA%\memo\data`
- 前端所有数据经 REST API（不直接读写 SQLite）；MCP 直接读 SQLite（与后端同库，WAL 并发安全）
- **旧网页版服务（pythonw 8899）受保护杀不掉，桌面版用 8900 规避；两者数据分家，迁移用 SQLite backup API（勿直接复制文件，会丢 WAL）**

## 版本迭代规范（每次迭代必须执行）

当前版本：**1.1.0**（云同步 + 端到端加密 + 手机端 S2）。语义化版本 `x.y.z`，功能迭代升 `y`、修复升 `z`。

每次迭代发布前，**必须同步更新以下版本号**（缺一不可）：

| 位置 | 文件 | 作用 |
|---|---|---|
| 桌面版 | `desktop/package.json` → `"version"` | 决定安装包名 `MEMO-笔记-Setup-{version}.exe` |
| 手机端 | `mobile/pubspec.yaml` → `version: x.y.z+n` | Android/iOS 版本号（n 为构建号） |
| 后端 | `service.py` → `APP_VERSION` | `/api/health` 返回，可查运行时版本 |

然后重新构建并回归：
1. 前端 `cd flomo && npm run build` → 部署 `app/` + 更新 `sw.js` 缓存版本
2. 后端 `PyInstaller` 重打 → `desktop` 里 `npx electron-builder --win`
3. 手机端 `flutter build windows`（如需发布 Android：`flutter build apk`）
4. 回归：`_run_api_tests.py` / `_run_sync_tests.py` / `_run_sync_e2e.py` / `_run_desktop_tests.ps1` / `flutter test`

检查当前各端版本号：
```
grep '"version"' desktop/package.json
grep '^version:' mobile/pubspec.yaml
grep 'APP_VERSION' service.py
```

## 云同步引擎（坚果云 · 变更日志）

- 设计文档：`SYNC-DESIGN.md`；实现：`sync.py`（SyncEngine）
- 写操作（create/update/pin/delete/clear/import/flomo 写入）经 `SYNC.log_op` 追加到 `{sync.dir}/{device}.jsonl`
- `pull_and_merge()` 扫描 `{sync.dir}` 下**除自己设备外**所有 `.jsonl`，按 `id+ts` 合并（last-write-wins），幂等可重放；断点存 `{data_dir}/sync-state.json`
- 设备名：`--device` 参数（默认 desktop，多端必须不同）；日志文件名 = `{device}.jsonl`
- 合并写库直接用 `sqlite3`（非 WAL），事务内批量应用；`set_memo_tags` 会重算标签计数
- 首次启用：`ensure_full_dump()` 把存量数据 dump 为 add 日志（文件非空则跳过）
- 定时：main() 启动 `SYNC.loop(15s)` 后台线程；`POST /api/sync/now` 手动触发
- 数据模型：`memos.uuid`（全局唯一，多端对应同一笔记）；存量库 init_db 自动迁移补 uuid
- **注意**：`api_list_memos` 的 SELECT 必须包含 `m.uuid`（memo_row_to_dict 依赖）；任何返回 memo dict 的查询同理
- **端到端加密**：`sync.SyncCrypto`（AES-256-GCM + PBKDF2 200k 迭代）；口令/盐存 `config.json sync.passphrase/salt`（本地），日志文件全密文；读行先解密、失败按明文兼容；`log_op` 检测明文日志自动无损转换；`pull_and_merge` 返回解密失败数（口令错误时同步静默失效，UI 状态可查）；依赖 `cryptography`（PyInstaller 内置 hook 已收集）

## 已知坑与注意事项

1. **`python` 命令**解析到 chrys venv（无 pip/依赖）——所有 Python 操作必须用 `C:\Python314\python.exe`
2. **PowerShell 5.1 读 UTF-8 文件**要 `Get-Content -Raw -Encoding UTF8`，否则中文乱码
3. **PyInstaller 必须 onedir**：onefile 的引导进程会 spawn 子进程后退出，Electron 误判后端死亡而自杀
4. **service.py 的 `import keyboard/pystray` 必须留在 main() 的 GUI 分支**（打包时已 exclude，headless 模式 import 会崩）；同理 tkinter/PIL 仅在 GUI 路径使用
5. **Electron 主进程**：spawn 后端 exe 传 `--no-gui --port 8900` + `env.MEMO_DATA_DIR`；后端 exit 后有 2s 延迟确认（防误判）；窗口关闭=隐藏到托盘；退出时 kill 后端
6. **前端发布后必须同步更新 `app/sw.js`**：CACHE 版本号 +1、ASSETS 换成新 hash 文件名，否则 PWA 缓存旧版
7. **mcp SDK 已锁定 1.x**（FastMCP）；2.x 重构删除了 fastmcp
8. npm 安装/打包慢时用 `ELECTRON_MIRROR`、`ELECTRON_BUILDER_BINARIES_MIRROR`（npmmirror）；npm ci 前确认无 vite dev server 占用 esbuild（`Get-Process esbuild`）
9. **测试方法**：后端 `--no-gui` 启动后 curl `/api/health`、`/api/memos`；MCP 用 `mcp.client.stdio` / `streamablehttp_client`（注意该 client 返回三元组 `(read, write, get_session_id)`）写脚本验证；Electron 用 `desktop\release\win-unpacked\MEMO 笔记.exe`（等价安装环境）验证
10. React 19：`useRef<T>()` 无参调用报 TS 错，需 `useRef<T | undefined>(undefined)`

## 移动端预留（未实现）

- 前端 React 组件可复用（React Native/WebView）；后端 REST API 部署到服务器即可远程访问
- MCP 同样可迁服务器供云端 Agent 使用
- 目前无鉴权（仅监听 127.0.0.1），公网部署前必须加登录/Token
