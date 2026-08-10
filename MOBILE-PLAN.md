# MEMO 手机 APP（S2）规划

> 目标：安卓/iOS 手机 APP，本地 SQLite 离线可用，经坚果云 WebDAV 与桌面端**双向同步**（复用 S1 变更日志 + 端到端加密协议）。
> 技术栈（用户选定）：**Flutter**。

## 一、技术选型

| 项 | 选择 | 理由 |
|---|---|---|
| 框架 | **Flutter（Dart）** | 用户选定；性能好，单代码库 Android/iOS |
| 本地存储 | `sqflite` | 表结构与桌面 SQLite 一致（memos + memo_tags + tags + uuid） |
| 加密 | `cryptography`（纯 Dart） | AES-256-GCM + PBKDF2 跨平台一致，无原生依赖差异 |
| 坚果云 | `http` 包 + WebDAV（`dav.jianguoyun.com/dav/`）+ `flutter_secure_storage` | 账号 + **应用密码**（坚果云网页端生成） |
| 通知 | `flutter_local_notifications` | 本地每日回顾提醒 |
| 打包 | `flutter build apk`（需 Android SDK）；iOS 需 Mac/EAS 类云构建 | 见"限制" |

## 二、开发调试策略（当前无 Android SDK）

- **开发期**：Flutter **Windows 桌面目标**（`flutter run -d windows`）调试 UI 与同步引擎——无需 Android SDK/真机
- **Android 发布**：安装 Android SDK + 真机/模拟器后 `flutter build apk`
- **iOS**：需 Mac 或云构建服务（Flutter 官方无 EAS，可用 Codemagic/自建），本期默认不做

## 三、架构

```
手机 APP（Flutter）
  ├─ UI 层（重写 flomo 风格：时间线/卡片/输入/标签/回顾/统计/设置）
  ├─ 数据层：本地 SQLite（sqflite，uuid 主键，与桌面表结构一致）
  ├─ 同步引擎（Dart 重写 S1 协议）
  │    ├─ 写操作 → mobile.jsonl（AES-GCM 加密，口令=同步口令）
  │    ├─ 定时拉取 desktop.jsonl → 解密 → last-write-wins 合并
  │    └─ WebDAV 上传/下载（坚果云账号 + 应用密码，SecureStorage）
  └─ 通知：每日回顾（flutter_local_notifications）
```

与桌面端的关系：同一个坚果云目录，桌面写 `desktop.jsonl`、手机写 `mobile.jsonl`，互为读写。设备名 = `mobile`。

## 四、与桌面协议兼容清单（必须一致）

1. 日志格式：`{op,id,ts,dev,content?,created_at?,pinned?}`，op ∈ add/update/pin/delete
2. 加密：PBKDF2-SHA256(口令, salt, 200000) → AES-256-GCM，行格式 `base64(nonce12+tag16+ct)`
3. 合并：按 `id+ts`，后写者胜；delete 墓碑；幂等重放
4. 标签解析：`#标签`、多级 `#父/子`，规则与桌面 `parse_tags` 一致
5. 数据表：memos(uuid, content, created_at, updated_at, pinned) + memo_tags + tags
6. **salt 共享（决策 D）**：桌面 `config.json` 的 `sync.salt` 需手机端拿到——推荐方案 A：salt 明文写入日志文件头（`#salt=hex`，salt 非敏感，随坚果云同步）

## 五、实施阶段（每阶段独立可交付）

| 阶段 | 内容 | 交付 |
|---|---|---|
| S2.0 | 环境：安装 Flutter SDK（Windows 桌面支持），创建项目 | ✅ 完成（Flutter 3.44.9 / JDK17 / Android SDK 36） |
| S2.1 | UI 移植：时间线/输入框/卡片（编辑/置顶/删除/复制/标签）/标签栏 | ✅ 完成 |
| S2.2 | 数据层：sqflite CRUD + 标签解析（回顾/统计页待补） | ✅ 核心完成 |
| S2.3 | **同步引擎 Dart 版**：变更日志 + 加密 + WebDAV + 合并 + 定时 | ✅ 完成（含跨语言联调） |
| S2.4 | 设置页（坚果云凭据/同步口令/状态）+ 通知 + 打磨 | ✅ 完成（设置页/控制器/定时同步；通知待补） |
| S2.5 | Android APK（需 Android SDK/设备）；iOS 待定 | ⬜ 下一步（SDK 已就绪，待真机） |

## 六、工作量与顺序

- S2.0 环境：Flutter SDK 下载安装（约 1-2GB，镜像加速）——**需用户确认**
- S2.1–S2.2 UI+数据层：约 3 轮
- S2.3 同步引擎（风险最高，先做协议对齐测试）：约 2 轮
- S2.4–S2.5 集成与发布：约 2 轮
- 总计约 8 轮；每轮 `flutter run -d windows` 可运行验证

## 七、风险与前置条件

1. **Flutter SDK 未安装**：需先安装（含 Dart SDK、Windows 桌面支持）；Android 打包还需 Android SDK（后续）
2. **iOS**：Windows 环境无法构建，需 Mac/Codemagic 云构建，本期默认不做
3. **坚果云应用密码**：用户需在坚果云网页端 → 安全设置 → 生成"应用密码"
4. **加密协议**：纯 Dart `cryptography` 包实现，避免平台差异；桌面端协议不变
5. 首次启用：手机端从坚果云拉 `desktop.jsonl` 全量重建（S1 已保证）
6. 冲突语义与桌面一致（后写者胜），不做字段级合并

## 八、待用户确认

- B. 同意安装 Flutter SDK（镜像加速，含 Windows 桌面调试目标）？
- C. iOS 是否本期要做（默认不做，只 Android）
- D. salt 共享：接受"明文写入日志头部"方案 A？

