# MEMO · macOS（M 系列）构建指南

MEMO 手机/桌面移动端已为 macOS 平台做好准备（`mobile/` 工程的 `macos/` 目录已生成并配置）。

> macOS 应用**必须在 Mac 上构建**（需要 Xcode + Apple 工具链），Windows 无法交叉编译。

## 前置条件（M 系列 Mac）

1. **Xcode**：App Store 安装，首次启动接受协议（`sudo xcodebuild -license`）
2. **Flutter SDK**（macOS arm64）：
   ```bash
   # 官方中国镜像安装（与 Windows 同版本 3.44.x 最佳）
   git clone -b stable https://github.com/flutter/flutter.git ~/flutter
   export PATH="$PATH:$HOME/flutter/bin"
   flutter doctor   # 确认 macOS + Xcode 两项为绿色
   ```

## 运行 / 构建

```bash
cd mobile
flutter pub get

# 直接运行（调试）
flutter run -d macos

# 发布版（未签名，本机可运行；上架需 Apple Developer 证书）
flutter build macos --release
```

产物：`build/macos/Build/Products/Release/MEMO.app`

## 已完成的 macOS 适配

| 项 | 状态 |
|---|---|
| `macos/` 平台工程 | ✅ 已生成（`flutter create --platforms=macos`） |
| 应用名 | ✅ `MEMO`（`AppInfo.xcconfig`） |
| Bundle ID | ✅ `com.memo.app` |
| 网络权限（坚果云 WebDAV） | ✅ `Release.entitlements` 已加 `com.apple.security.network.client` |
| 数据库 | ✅ sqflite 不支持 macOS，已走 `sqflite_common_ffi`（系统自带 sqlite3） |
| 云同步 | ✅ 与 Windows/Android 共用坚果云变更日志协议（端到端加密） |

## 数据互通说明

- 每台设备（Windows 桌面 / Android 手机 / macOS）**各自本地存储** SQLite（含 UUID）；
- 设备间通过坚果云同步目录交换加密变更日志，**last-write-wins 合并**，无需手动导入导出；
- 首次使用在「设置 → 云同步」填写坚果云 WebDAV 地址 + 应用密码 + 同步口令即可互通。

## 版本号

当前 `1.3.0`（与 Windows 桌面版、Android APK 同步；发布新版本时三处同步：
`desktop/package.json`、`mobile/pubspec.yaml`、`service.py` 的 `APP_VERSION`）。
