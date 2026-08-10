# MEMO · flomo 平替（本地私有版）

像发微博一样记笔记，数据 100% 保存在本地。保留 flomo 的核心特性：快速记录、标签体系、时间线、每日回顾、随机漫步、全文搜索、统计、导出、API 写入、MCP 供 AI 读取；**不含语音输入**。

## 桌面版（推荐）

安装 `desktop/release/MEMO-笔记-Setup-1.1.0.exe`：

- 开始菜单 / 桌面图标打开**独立窗口**（UI 与网页版一致）
- **数据本地私有**：`%APPDATA%\memo\data\memo.db`（SQLite）
- 内置**托盘**（右下角图标）、**全局热键**（Ctrl+Shift+M 任意界面快速记录，设置可改）、**每日回顾通知**
- 桌面版使用端口 **8900**；旧网页版（8899）可共存，二选一使用即可
- 首次使用前把旧数据迁移到新数据目录（见下方"数据迁移"）

> 重新打包安装程序：先 `PyInstaller` 重打后端（见下），再在 `desktop/` 下执行 `npm run dist`。

## 网页版（轻量模式）

```bat
start.bat   # 或 python service.py --open（端口 8899，浏览器打开）
```

浏览器 / PWA 使用，数据在项目目录 `memo.db`。适合不想安装、临时使用的场景。

## 功能

| 功能 | 说明 |
|---|---|
| 快速记录 | 主输入框 Ctrl+Enter 保存，新笔记置顶 |
| 全局热键快速记录 | 任意界面按 **Ctrl+Shift+M** 呼出小窗（替代微信输入） |
| 标签体系 | `#标签`、多级 `#父/子`，自动解析、侧栏筛选 |
| 时间线 | 按天分组（今天/昨天/日期），置顶笔记优先 |
| 全文搜索 | 关键词 + 标签叠加筛选 |
| 每日回顾 | 设定时间随机回顾历史笔记（系统通知），也可手动 🎲 |
| 数据统计 | 连续记录天数、近一年热力图、本周新增、常用标签 |
| 导出/导入 | JSON / Markdown / CSV，可迁移备份 |
| 编辑 / 置顶 / 删除 / 复制 | 卡片悬浮操作 |
| PWA | 网页版可安装为应用 |
| MCP | 供 AI Agent 按标签/日期范围读取与写入 |
| 私有 | 全部数据本地存储，零上传 |

## 云同步（坚果云 · 变更日志方案）

桌面端与手机端各自本地编辑，经坚果云**交换变更日志**实现双向同步（详见 `SYNC-DESIGN.md`）。核心原则：坚果云只传输小文本日志，**绝不直接同步 SQLite 文件**（避免损坏）。

- 桌面端写操作自动追加日志到 `{坚果云目录}/desktop.jsonl`，并定时（15s）拉取其他设备日志合并
- 合并规则：按 `id + ts`，后写者胜（last-write-wins）；删除走墓碑，可跨设备生效
- 每端设备名必须不同：桌面端 `--device desktop`（默认），手机端 `--device mobile`
- 首次启用时自动把存量数据 dump 为全量日志，新设备可从日志完整重建
- **端到端加密（可选）**：设置页填写"同步口令"后，日志以 AES-256-GCM 密文存储（PBKDF2 派生密钥），
  坚果云/账号泄露者只能看到密文；所有设备须使用同一口令；旧明文日志自动无损转换为密文

**使用（当前为 API 配置，UI 即将上线）**：
1. 在坚果云本地同步文件夹下建子目录，如 `D:\Nutstore\memo-sync`
2. 设置页/接口配置：`POST /api/config {"sync":{"dir":"D:\\Nutstore\\memo-sync"}}`
3. 之后写操作自动记录，每 15 秒自动同步；也可手动 `POST /api/sync/now`
4. 手机端（未来 APP）用 `--device mobile` 指向同一目录

## 局域网访问（手机用）

数据与桌面版**同一份**（`%APPDATA%\memo\data`），无需同步。

1. 双击 **`start_lan.bat`**（后端自带，无需 Python 环境）
2. 手机连**同一 WiFi**，浏览器访问 `http://<电脑IP>:8901`（IP 用 `ipconfig` 查看，或看 bat 窗口提示）
3. 首次访问输入**访问令牌**（令牌在 bat 窗口输出，或桌面版 → 设置 → 局域网访问 查看/复制）

安全说明：
- 仅监听局域网，非本机访问一律要求令牌（`Authorization: Bearer` / `X-Memo-Token` / `?token=`）
- 本机访问（桌面版/网页版）免令牌，体验不变
- 设置页可随时**重置令牌**（旧令牌立即失效）
- 如需公网访问：先用 Tailscale / ZeroTier 组网，再访问组网 IP；**切勿直接端口映射暴露公网**

## 架构（移动端预留）

```
┌─ 前端（React，UI 层）─────────────────────────┐
│  桌面窗口（Electron）· 网页/PWA · 未来移动端    │
└───────────────┬──────────────────────────────┘
                │ REST API（localhost:8900 / 8899）
┌───────────────▼──────────────────────────────┐
│ 后端（Python 服务 / 打包 exe）                 │
│  笔记 API · 标签 · 统计 · 导出 · flomo 兼容写入 │
│  SQLite（memo.db）本地存储                     │
└──────────────────────────────────────────────┘
```

移动端（安卓/iOS）无需重写：前端组件可复用（React Native / WebView），后端 REST API 直接部署到服务器即可远程访问，存储层不变。MCP 接口（`mcp_server.py`）同样可部署到服务器供云端 Agent 使用。

## 安装与启动

```bat
pip install -r requirements.txt     # 安装依赖（pystray keyboard pillow）
start.bat                           # 启动服务（开发/调试，带窗口）
```

启动后打开 http://127.0.0.1:8899/ 即可使用。

**开机自启（推荐）**：双击 `install_service.bat`，注册为登录自启的后台服务（无窗口、常驻托盘，提供热键与每日回顾推送）。卸载：`uninstall_service.bat`。

> 注意：`start.bat` / `install_service.bat` 默认使用 `C:\Python314\python.exe`，若你的 Python 路径不同，请修改 bat 文件顶部的路径。

## 常用操作

- **记一条**：顶部输入框，Enter 保存
- **标签**：正文写 `#工作/日报` 即自动归类；点侧栏标签筛选
- **搜索**：顶部搜索框，可与标签叠加
- **回顾**：右上 🎲 回顾（随机抽取历史笔记）；设置里可配每日定时回顾
- **数据**：设置 → 导出/导入/清空

## 外部写入 API（flomo 兼容）

任何脚本/工具可向本地服务写入笔记：

```bash
curl -X POST http://127.0.0.1:8899/v1/memo \
  -H "Content-Type: application/json" \
  -d '{"content": "随手记一条 #测试"}'
```

配合 PowerToys Run / 输入法快捷指令 / 自动化脚本，即可实现"全局任意时刻快速记录"（微信输入的本地替代）。

## 目录结构

```
service.py          本地常驻服务（HTTP + API + 热键 + 托盘 + 回顾）
app/                前端应用（React 构建产物 + PWA）
flomo/              前端源码（React + Vite + Tailwind，改动后 npm run build 重新生成到 app/）
memo.db             数据文件（SQLite，自动创建）
config.json         配置（热键、回顾时间等，应用内可改）
start.bat           手动启动
install_service.bat 注册开机自启
uninstall_service.bat 移除自启
```

前端为 Kimi 生成的 React 页面，数据层已改为对接本服务 API（`/api/memos`、`/api/stats`），与全局热键、托盘、每日回顾共用同一份本地数据。

## MCP 接口（供 AI Agent 读取/写入）

通过 [MCP](https://modelcontextprotocol.io) 协议，让 Claude Desktop、Cherry Studio、Cline、Cursor 等任何 AI 客户端读取本机笔记。**读取必须按范围进行**：支持标签、日期、关键词筛选 + 分页 + 截断，避免全文倒库。

### 提供 6 个工具

| 工具 | 说明 |
|---|---|
| `list_tags()` | 所有标签及使用次数 |
| `count_memos(tags?, start_date?, end_date?, query?)` | 先探数量再决定是否读取 |
| `list_memos(tags?, start_date?, end_date?, query?, limit?, offset?, preview_length?)` | 范围筛选 + 分页 + 可选截断 |
| `get_memo(memo_id)` | 单条全文 |
| `add_memo(content, created_at?)` | 写入（支持 `#标签`、多级 `#父/子`） |
| `get_stats()` | 总数 / 连续天数 / 本周新增 |

- `tags`：标签路径数组，如 `["工作"]` 会匹配 `工作/项目` 等全部子标签
- 日期：`YYYY-MM-DD`，含边界，按本地时区

### 连接方式（二选一）

**安装桌面版后，MCP 已内置**：`<安装目录>\resources\mcp\memo-mcp.exe`，自动读取桌面版数据目录（`%APPDATA%\memo\data\memo.db`），无需 Python 环境。

**① stdio（Claude Desktop / 本地 CLI）**：配置启动命令即可，无需预启动。

Claude Desktop 的 `claude_desktop_config.json`：

```json
{
  "mcpServers": {
    "memo": {
      "command": "C:\\Program Files\\MEMO 笔记\\resources\\mcp\\memo-mcp.exe",
      "args": []
    }
  }
}
```

> 安装目录默认 `C:\Program Files\MEMO 笔记`，若自定义安装目录请按实际路径填写；未安装桌面版时也可用源码模式（`C:\Python314\python.exe mcp_server.py`）。

**② Streamable HTTP（Cherry Studio / Cursor / Cline 等）**：先启动 MCP 服务，再在客户端添加：

```bat
"<安装目录>\resources\mcp\memo-mcp.exe" --http --port 8898
```

```
地址: http://127.0.0.1:8898/mcp
类型: Streamable HTTP（MCP）
```

> MCP 服务直接读取 `memo.db`，与桌面版 / 网页版共享同一份数据。

## 数据迁移

**旧网页版数据 → 桌面版**（首次安装桌面版时）：

```bat
# 用 SQLite 在线备份（含 WAL），不要直接复制文件
C:\Python314\python.exe -c "import sqlite3,os; s=sqlite3.connect(r'项目目录\memo.db'); d=sqlite3.connect(os.path.join(os.environ['APPDATA'],'memo','data','memo.db')); s.backup(d); d.close(); s.close(); print('已迁移')"
```

**换电脑 / 备份**：桌面版设置 → 导出 JSON → 新机器导入；或直接备份 `%APPDATA%\memo\data\memo.db`。
