# MEMO 测试用例

测试对象：MEMO（flomo 平替）桌面版 / 网页版 / MCP。
标记：**[自动]** 可脚本执行，**[人工]** 需人工操作验证。

## A. 后端 API（service.py，--no-gui，独立测试库）

| ID | 用例 | 步骤 | 预期 |
|---|---|---|---|
| TC-A01 | 健康检查 **[自动]** | GET /api/health | 200，`ok=true` |
| TC-A02 | 创建笔记 **[自动]** | POST /api/memos `{content}` | 201，返回 id/content/tags/created_at(毫秒) |
| TC-A03 | 多级标签解析 **[自动]** | 内容含 `#工作/项目/游戏` | tags=[工作, 工作/项目, 工作/项目/游戏] |
| TC-A04 | 补记时间 **[自动]** | created_at=`2026-08-08 21:30` | 时间戳正确（毫秒） |
| TC-A05 | 列表倒序分页 **[自动]** | GET /api/memos?limit&offset | total 正确，created_at 倒序 |
| TC-A06 | 标签筛选 **[自动]** | tag=工作 / tag=工作/项目 | 父标签含子级；精确路径匹配 |
| TC-A07 | 关键词搜索 **[自动]** | q=跑步 | LIKE 匹配 |
| TC-A08 | 标签+搜索叠加 **[自动]** | tag + q 同时 | AND 语义 |
| TC-A09 | 编辑 **[自动]** | PUT /api/memos/:id {content} | 内容/tags 更新，updated_at 非空 |
| TC-A10 | 置顶 **[自动]** | PUT {pinned:true} | 列表排序优先 |
| TC-A11 | 删除 **[自动]** | DELETE /api/memos/:id | 数据消失，tags 计数同步 |
| TC-A12 | 清空 **[自动]** | DELETE /api/memos | total=0 |
| TC-A13 | 标签列表 **[自动]** | GET /api/tags | name/count 正确 |
| TC-A14 | 统计 **[自动]** | GET /api/stats?days=30 | days/streak/total/thisWeek 结构正确 |
| TC-A15 | flomo 兼容写入 **[自动]** | POST /v1/memo（JSON + 表单） | 均写入成功 |
| TC-A16 | 导出 **[自动]** | /api/export?format=json\|md\|csv | 三种格式返回 200 且内容完整 |
| TC-A17 | 导入闭环 **[自动]** | 导出 JSON → 清空 → 导入 | 条数还原 |
| TC-A18 | 配置读写 **[自动]** | GET/POST /api/config | 保存后读回一致 |
| TC-A19 | 静态托管 **[自动]** | GET /、/assets/*、/manifest.json | 200 |
| TC-A20 | 错误处理 **[自动]** | 空 content → 400；不存在 id → 404 | 正确状态码+error 信息 |
| TC-A21 | 特殊字符 **[自动]** | 内容含 `<script>` 等 | 原样存储（前端负责转义） |

## B. 桌面版（Electron）

| ID | 用例 | 步骤 | 预期 |
|---|---|---|---|
| TC-B01 | 安装包完整 **[自动]** | 检查 Setup exe / win-unpacked / resources | 存在；resources 含 backend/ 与 mcp/ |
| TC-B02 | 应用启动 **[自动]** | 启动 win-unpacked 应用 | 进程存活 |
| TC-B03 | 后端自动拉起 **[自动]** | 启动后查 :8900/api/health | ok=true |
| TC-B04 | 窗口加载前端 **[自动]** | GET :8900/ | 200 |
| TC-B05 | 数据目录创建 **[自动]** | 检查 userData 下 memo.db | 存在 |
| TC-B06 | 写入链路 **[自动]** | POST /v1/memo → GET /api/memos | 数据可见，测后清理 |
| TC-B07 | 退出无残留 **[自动]** | 关闭应用 | 无 electron/backend 残留进程 |
| TC-B08 | 托盘菜单 **[人工]** | 右下角图标右键 | 打开/隐藏、快速记录、退出可用 |
| TC-B09 | 全局热键 **[人工]** | 任意界面按 Ctrl+Shift+M | 弹出快速记录窗，Enter 保存成功 |
| TC-B10 | 每日回顾通知 **[人工]** | 设置回顾时间到点 | 系统通知弹出 |
| TC-B11 | 窗口关闭行为 **[人工]** | 点窗口 X | 隐藏到托盘不退出 |

## C. MCP

| ID | 用例 | 步骤 | 预期 |
|---|---|---|---|
| TC-C01 | 工具发现 **[自动]** | stdio 连接 list_tools | 6 个工具 |
| TC-C02 | list_tags **[自动]** | 调用 | 返回标签+计数 |
| TC-C03 | count_memos **[自动]** | tags/start_date/end_date/query 组合 | 计数正确 |
| TC-C04 | list_memos 范围读取 **[自动]** | 父标签匹配子级、日期、limit、preview_length | 正确筛选/分页/截断 |
| TC-C05 | get_memo **[自动]** | 按 id | 全文+标签 |
| TC-C06 | add_memo **[自动]** | 含多级标签 | 写入成功 |
| TC-C07 | get_stats **[自动]** | 调用 | 结构正确 |
| TC-C08 | HTTP 模式 **[自动]** | streamable http 连接 | 工具发现+调用 |
| TC-C09 | 数据一致性 **[自动]** | MCP 写入 → 后端 API 读取 | 同库可见 |

## D. 前端

| ID | 用例 | 步骤 | 预期 |
|---|---|---|---|
| TC-D01 | 构建产物完整 **[自动]** | 检查 app/ 下 index.html/assets/manifest/sw | 文件齐全且相互引用一致 |
| TC-D02 | 类型检查 **[自动]** | flomo/ 下 tsc | 无错误 |
| TC-D03 | 记录→时间线 **[人工]** | 输入框记录，回车 | 新笔记置顶显示 |
| TC-D04 | 标签筛选 **[人工]** | 点卡片/侧栏标签 | 筛选生效，多级匹配 |
| TC-D05 | 搜索 **[人工]** | 关键词搜索 | 实时过滤 |
| TC-D06 | 回顾页 **[人工]** | 侧栏"回顾" | 随机抽取展示，可再抽 |
| TC-D07 | 统计页 **[人工]** | 侧栏"统计" | 指标卡/热力图/标签 |
| TC-D08 | 设置页 **[人工]** | 侧栏"设置" | 配置/导出/导入/清空可用 |
| TC-D09 | 编辑/置顶/删除 **[人工]** | 卡片操作 | 各自生效 |
