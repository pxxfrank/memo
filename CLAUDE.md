# CLAUDE.md — MEMO 项目协作手册

面向在本仓库工作的开发者 / AI 助手：记录项目结构、约定、关键命令与已知坑。

## 项目概览

MEMO 是一款 flomo 平替的**本地私有笔记应用**：数据 100% 存在本机，
通过坚果云交换**端到端加密**的变更日志实现多端同步。

多端形态：Windows 桌面版（Electron + Python 后端）、网页版 / PWA、Android（Flutter）、
HarmonyOS 6（ArkTS + ArkUI）、macOS（Flutter）。

## 技术栈与架构

- **后端**：Python 3.12+，标准库 `http.server`（无框架）+ SQLite + `cryptography`（AES-256-GCM）
- **前端**：React + Vite + Tailwind（`flomo/` 源码 → 构建到 `app/`，PWA）
- **桌面壳**：Electron（`desktop/`，拉起后端 exe + 载入 `app/`）
- **手机端**：Flutter（`mobile/`，Android + macOS）
- **鸿蒙端**：ArkTS + ArkUI（`ohos/`）
- **AI 接口**：MCP（`mcp_server.py`）

数据流：前端（多端）→ REST API → 后端（SQLite）。同步：各端本地库 + 坚果云变更日志。

## 目录结构

```
service.py          常驻服务：REST API + 静态托管 + 托盘/热键/回顾
sync.py             云同步引擎（坚果云变更日志 + AES-256-GCM）
mcp_server.py       MCP AI 接口（stdio / Streamable HTTP）
memo_common.py      共享基础模块：标签/时间/路径/数据库/统计（三端共用，勿再复制）
flomo/              前端源码（React），npm run build → app/
app/                前端构建产物 + PWA（service.py 静态托管）
desktop/            Electron 桌面壳（main.js + 打包配置）
mobile/             Flutter 手机端（android/ + macos/）
ohos/               HarmonyOS 6 原生工程（ArkTS）
dist/               PyInstaller 产物（memo-backend onedir）
```

## 关键命令

```bat
REM 网页版 / 后端开发
uv venv .venv --python 3.12
uv pip install -r requirements.txt
start.bat                                  REM 或 python service.py --no-gui

REM 前端构建（产物需拷到 app/）
cd flomo && npm install && npm run build

REM 打包桌面版
.venv\Scripts\python.exe -m PyInstaller --noconfirm --onedir --name memo-backend ^
  --exclude-module tkinter --exclude-module pystray --exclude-module keyboard ^
  --exclude-module PIL --add-data "app;app" --clean service.py
cd desktop && npx electron-builder --win
```

## 端口与数据约定

| 端口 | 用途 |
|---|---|
| 8899 | 网页版 |
| 8900 | 桌面版（Electron 内后端） |
| 8901 | 局域网访问（`start_lan.bat`） |
| 8898 | MCP HTTP |
| 8911–8918 | 测试脚本 |

**数据目录（已统一）**：

- 桌面版：固定 `%APPDATA%\memo\data\memo.db`（`main.js` 用 `app.setPath('userData', %APPDATA%\memo)`，
  不随 app name 漂移；首次启动会从旧的 `%APPDATA%\memo-desktop\data` 迁移）
- 网页版：项目目录 `memo.db`
- 统一由环境变量 `MEMO_DATA_DIR` 覆盖（测试 / 多实例 / 桌面版注入）
- MCP 独立运行时的回退目录与桌面版一致

**数据库表**：`memos(id, uuid, content, created_at, updated_at, pinned)`、
`memo_tags(memo_id, name)`、`tags(name, count)`。字段与各端完全一致，同步按 `uuid` 互通。

## 鉴权机制

- 局域网模式（`--host 0.0.0.0`）下非本机来源**强制令牌**：
  `Authorization: Bearer` / `X-Memo-Token` / `?token=`，用 `hmac.compare_digest` 比对（令牌存 `config.json`）
- 桌面版 / 本机（127.0.0.1 / ::1）免鉴权

## 版本迭代规范（每次发布必须执行）

版本号需**四处同步**：

- `desktop/package.json` 的 `version`
- `mobile/pubspec.yaml` 的 `version`
- `service.py` 的 `APP_VERSION`
- `ohos/AppScope/app.json5` 的 `versionName` / `versionCode`

发布流程：改版本号 → 重建前端 → 重打后端 exe → 重打安装包 → 跑全部测试 → 提交。

## 云同步引擎

- 每台设备写自己的日志 `{device}.jsonl`（`desktop` / `mobile` / `ohos`），
  变更条目 `{op, id, ts, dev, ...}`，`op` ∈ add / update / pin / delete
- 合并规则：按 `id + ts` **last-write-wins**，幂等可重放，删除走墓碑
- **端到端加密**：配置口令后日志全密文（AES-256-GCM + PBKDF2 200k 迭代），
  口令 / 盐存 `config.json` 的 `sync.*`；旧明文日志自动无损转密文
- 15 秒定时拉取 + `POST /api/sync/now` 手动触发

## 已知坑与注意事项

- **⚠️ PowerShell 5.1 编码坑（务必避免）**：不要用
  `(Get-Content file -Raw) -replace ... | Set-Content file -Encoding UTF8` 修改含中文的文件——
  `Get-Content` 默认按 ANSI(GBK) 读取 UTF-8 文件会得到乱码，再写回即**永久损坏**（本仓库 README /
  CLAUDE.md 曾因此损坏）。**改用 Python 读写（`open(..., encoding='utf-8')`）或专用编辑工具**。
- PyInstaller 必须 `--onedir`（才能带上 `app/` 静态资源）
- `service.py` 的 `keyboard` / `pystray` 延迟导入（配合打包 `--exclude-module`）
- MCP SDK 锁定 1.x：`mcp>=1.0,<2`
- npm 安装 Electron 用镜像：`ELECTRON_MIRROR=https://npmmirror.com/mirrors/electron/`
- `api_list_memos` 的 SELECT **必须包含 `m.uuid`**（同步依赖）
- 后端依赖：`requirements.txt` 必须含 `cryptography` / `mcp`
- 测试统一用项目 `.venv`（`uv venv` + `uv pip install`）；测试脚本用环境变量 `MEMO_PYTHON`
  或默认 `.venv\Scripts\python.exe` 定位解释器（勿硬编码 Python 路径）

## 后端与前端重构记录（v1.3.0）

- **`memo_common.py`** 为唯一来源：`parse_tags` / 时间工具 / `resolve_data_dir` /
  `connect` / `db_session` / `init_schema` / `insert_memo` / `compute_stats` 等；
  `service.py`、`sync.py`、`mcp_server.py` 全部改为导入，禁止再各自复制
- 修复：MCP 写库补 `uuid`；`POST /api/config` 的 `sync` 深合并（不再冲掉口令/盐）；
  全量 dump 设备名；加密缓存加指纹；DB 连接改用 `db_session`（消除泄漏）；同步循环记日志
- 前端：标签规则唯一来源 `lib/tags.ts`（与后端对齐，修复"点击标签筛不出"）、
  时间格式化 `lib/time.ts`、`hooks/useToast.ts`、`components/Toast.tsx` / `EditMemoDialog.tsx`
- 统计字段统一为 `thisWeek` / `streak`（REST 与 MCP 共用 `compute_stats`）

## 手机端 / 鸿蒙 / macOS

- **Android**：`mobile/`，`flutter build apk --release`。
  Gradle 用阿里云 maven 镜像 + 腾讯 Gradle 镜像；`kotlin.incremental=false` 规避
  `quill_native_bridge_android` 的 Kotlin 增量编译 bug；**勿在 settings 用
  `dependencyResolutionManagement(PREFER_SETTINGS)`**（会屏蔽 Flutter 本地引擎仓库）
- **鸿蒙**：`ohos/`，用 DevEco Studio 构建（详见 `OHOS-BUILD.md`）
- **macOS**：`mobile/macos/`，需在 Mac 上 `flutter build macos`（详见 `MACOS-BUILD.md`）
