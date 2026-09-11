# MEMO · flomo 平替（本地私有版）

像发微博一样记笔记，**数据 100% 保存在本地**。保留 flomo 的核心体验：快速记录、标签体系、
时间线、每日回顾、随机漫游、全文搜索、数据统计、导出 / 导入、外部 API 写入，
并提供 **MCP 接口**让 AI 安全地读取你的笔记。**不含语音输入**。

支持多端互通：Windows 桌面版 / 网页版(PWA) / Android / HarmonyOS 6 / macOS。
各端本地各自存储（SQLite），通过坚果云交换**端到端加密**的变更日志实现双向同步。

---

## 平台与交付物

| 平台 | 形态 | 位置 / 启动方式 |
|---|---|---|
| **Windows** | 桌面版安装包（Electron + Python 后端） | `desktop/release/MEMO-笔记-Setup-1.3.0.exe` |
| Windows / 任意 | 网页版 / PWA（免安装） | 双击 `start.bat` → http://127.0.0.1:8899 |
| **Android** | 手机 App（Flutter） | `mobile/release/MEMO-1.3.0.apk` |
| **HarmonyOS 6** | 原生应用（ArkTS + ArkUI） | `ohos/`（用 DevEco Studio 构建，见 `OHOS-BUILD.md`） |
| **macOS** | 桌面 App（Flutter） | `mobile/macos/`（需在 Mac 上构建，见 `MACOS-BUILD.md`） |
| 任意 | 局域网网页（手机浏览器访问电脑） | 双击 `start_lan.bat` |
| 任意 | MCP 接口（给 AI Agent 用） | `mcp_server.py` |

当前版本：**v1.3.0**

---

## 快速开始

### ① Windows 桌面版（推荐）

1. 双击 `desktop/release/MEMO-笔记-Setup-1.3.0.exe`，按向导安装
2. 从开始菜单 / 桌面图标打开
3. 托盘图标常驻，右键可用：快速记录 / 打开应用 / 立即回顾 / 退出
4. 任意界面按 **`Ctrl+Shift+M`** 呼出快速记录小窗（回车保存，Esc 关闭）

> 数据位置：`%APPDATA%\memo\data\memo.db`（本地 SQLite，不上传）。桌面版使用端口 **8900**。

### ② 网页版（免安装，轻量）

```bat
start.bat          REM 或：python service.py --open
```
浏览器打开 http://127.0.0.1:8899 ，数据存项目目录 `memo.db`。可「安装」为 PWA 应用。

### ③ 手机端

- **Android App**：安装 `mobile/release/MEMO-1.3.0.apk`，打开即用，设置里配云同步后与电脑互通
- **不装 App**：双击 `start_lan.bat`，手机连**同一 WiFi**，浏览器访问 `http://<电脑IP>:8901`，
  首次需输入访问令牌（令牌见 bat 窗口，或桌面版「设置 → 局域网访问」）

---

## 功能与操作

| 功能 | 用法 |
|---|---|
| 快速记录 | 顶部输入框 `Ctrl+Enter` 保存，或全局热键 `Ctrl+Shift+M` |
| 标签体系 | 正文写 `#标签` 或 `#父/子`（多级标签自动解析，侧栏可筛选） |
| 富文本 | 选中文字 → 工具栏 **B** 加粗 / **U** 下划线 / 列表 / 缩进（**所见即所得**） |
| 全文搜索 | 顶部搜索框，可与标签叠加过滤 |
| 时间线 | 按天分组，置顶笔记优先 |
| 每日回顾 | 托盘「立即回顾」或设置定时；随机抽取历史笔记 |
| 数据统计 | 累计笔记、连续记录天数、本周新增、常用标签、热力图 |
| 暗黑模式 | 设置 → 外观 → 暗黑模式 |
| 编辑 / 置顶 / 复制 / 删除 | 悬停卡片，右侧操作按钮 |
| 导出 / 导入 | 设置 → 数据管理（JSON / Markdown / CSV） |

---

## 多设备云同步（坚果云 · 端到端加密）

各端本地编辑，经坚果云交换**变更日志**实现双向同步（详见 `SYNC-DESIGN.md`）。
核心原则：坚果云只传输小文本日志，**绝不直接同步 SQLite 文件**。

**配置步骤：**

1. 注册[坚果云](https://www.jianguoyun.com) → 账户信息 → 安全选项 → **添加应用密码**
2. 各端「设置 → 云同步」填写：
   - **WebDAV 地址**：`https://dav.jianguoyun.com/dav/memo-sync`（可自定义子目录）
   - **用户名**：坚果云登录邮箱
   - **应用密码**：上一步生成的密码
   - **同步口令**：自定义密码，**所有设备保持一致**
3. 保存后每 15 秒自动同步一次；也可「立即同步」

**加密**：填入同步口令后，日志以 AES-256-GCM 密文存储（PBKDF2 派生密钥），
坚果云 / 账号泄露者只能看到密文。旧明文日志自动无损转密文。

---

## 数据与安全

- 所有笔记默认**只存本机**；只有启用云同步后才会经坚果云交换**加密**日志
- 数据文件：`%APPDATA%\memo\data\memo.db`（桌面版）/ 项目目录 `memo.db`（网页版）
- 局域网访问需**令牌**鉴权（非本机一律校验），建议仅在可信 WiFi 使用
- **备份**：设置 → 数据管理 → 导出；或直接拷贝 `memo.db`

---

## MCP：让 AI 读写你的笔记

`mcp_server.py` 提供 6 个工具：`list_tags` / `count_memos` / `list_memos` /
`get_memo` / `add_memo` / `get_stats`。可在 Claude Desktop / Cherry Studio / Cursor 等客户端配置使用，
AI 便能按标签、日期范围、关键词检索并写入你的笔记。

```bat
python mcp_server.py                    REM stdio 模式
python mcp_server.py --http --port 8898 REM Streamable HTTP 模式
```

---

## 开发

### 目录结构

```
service.py          本地常驻服务：REST API + 静态托管 + 托盘/热键/回顾
sync.py             云同步引擎（坚果云变更日志 + AES-256-GCM 加密）
mcp_server.py       MCP AI 接口
memo_common.py      共享基础模块（标签/时间/路径/数据库/统计，三端共用）
flomo/              前端源码（React + Vite + Tailwind），改动后 npm run build 生成到 app/
app/                前端构建产物（PWA）
desktop/            Electron 桌面壳（含打包配置）
mobile/             Flutter 手机端（Android / macOS）
ohos/               HarmonyOS 6 原生工程（ArkTS）
memo.db             网页版数据文件（自动创建）
```

### 环境要求与构建

- **Python** 3.12+ ，依赖见 `requirements.txt`（cryptography / mcp / pystray / keyboard / pillow）
- **Node.js** 18+（前端构建）
- **Flutter** 3.x（手机端，可选）；**DevEco Studio**（鸿蒙，可选）

```bat
REM 网页版 / 后端
uv venv .venv --python 3.12
uv pip install -r requirements.txt
start.bat

REM 前端
cd flomo && npm install && npm run build    REM 产物需拷到 app/

REM 打包桌面版
python -m PyInstaller --onedir --name memo-backend --add-data "app;app" service.py
cd desktop && npx electron-builder --win
```

### 测试

```bat
python _run_api_tests.py       REM 后端 API
python _run_sync_tests.py      REM 同步引擎
python _run_mcp_tests.py       REM MCP
python _run_sync_e2e.py        REM 双端端到端同步
powershell -File _run_desktop_tests.ps1   REM 桌面版打包冒烟
```

---

## 外部写入 API（flomo 兼容）

```bash
curl -X POST http://127.0.0.1:8899/v1/memo \
  -H "Content-Type: application/json" \
  -d '{"content": "随手记一条 #测试"}'
```

可配合 PowerToys Run / 快捷指令 / 自动化脚本，实现「全局任意时刻快速记录」。

---

## 文档

- `CLAUDE.md` — 项目协作手册（约定、端口、已知坑、版本规范）
- `SYNC-DESIGN.md` — 云同步协议设计
- `OHOS-BUILD.md` — 鸿蒙构建指南
- `MACOS-BUILD.md` — macOS 构建指南
- `MOBILE-PLAN.md` — 手机端规划
