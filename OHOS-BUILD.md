# MEMO · HarmonyOS 6 原生版（ArkTS + ArkUI）

MEMO 笔记的鸿蒙原生客户端。`ohos/` 目录为完整 DevEco Studio 工程，
与 Windows / Android / macOS 端**数据互通**（Markdown 子集存储 + 坚果云 JSONL 同步协议）。

## 构建（需要 DevEco Studio）

1. 从华为官网下载安装 **DevEco Studio**（developer.huawei.com，需登录华为账号）
2. 首次启动按向导安装 HarmonyOS SDK（建议 HarmonyOS 6 / API 20+）并接受许可
3. **File → Open** 打开本目录 `ohos/`
4. 等待同步完成后 **Build → Build Hap(s)/APP(s) → Build Hap(s)**（或直接 Run 到模拟器/真机）
   - 产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`
5. 真机安装需在 **File → Project Structure → Signing Configs** 登录华为账号自动签名

## 命令行构建（可选）

DevEco Studio 自带 `hvigorw`（项目根目录）：

```bat
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

## 当前实现（v1.3.0）

| 模块 | 状态 |
|---|---|
| 本地数据（relationalStore，表结构与桌面端一致） | ✅ 增删改查 / 置顶 / 统计 / UUID |
| 时间线（输入 + 富文本卡片 + 格式工具栏） | ✅ 加粗/下划线/列表/缩进（标记式存储，渲染显示效果） |
| 回顾页（随机抽取 N 条） | ✅ |
| 统计页（总量/今日/本周/连续/标签 Top5） | ✅ |
| 设置页（坚果云配置/暗黑/回顾条数） | ✅ 表单已存偏好 |
| **云同步引擎**（WebDAV + AES-256-GCM 端到端加密） | 🔜 下一迭代（与 Python/Dart 端协议对齐） |
| 真机/模拟器验证 | ⏳ 待 DevEco Studio 编译 |

## 工程结构

```
ohos/
├── AppScope/                应用级配置（bundleName com.memo.app, v1.3.0）
├── entry/
│   └── src/main/ets/
│       ├── entryability/    EntryAbility（初始化数据库 → 加载首页）
│       ├── pages/           四个页签：Timeline / Review / Stats / Settings
│       ├── components/      RichText（Markdown 渲染）、FormatToolbar
│       └── model/           MemoStore（数据层）、Markdown（解析）、SyncConfig（偏好）
├── build-profile.json5      构建配置（compatibleSdkVersion 5.0.0(12)）
└── hvigorfile.ts
```

## 版本

`1.3.0`，与 Windows 桌面版 / Android APK / macOS 同步。发布新版本时同步：
`desktop/package.json`、`mobile/pubspec.yaml`、`service.py` 的 `APP_VERSION`、
`ohos/AppScope/app.json5` 的 `versionName` 与 `versionCode`。
