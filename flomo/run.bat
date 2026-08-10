@echo off
REM ============================================================
REM flomo 风格前端项目 —— 一键构建/预览脚本（Windows 双击可用）
REM 用法:
REM   run.bat install   安装依赖（首次运行）
REM   run.bat build     生产构建，输出到 dist\
REM   run.bat dev       启动开发服务器（默认 3000 端口）
REM   run.bat dev 3100  指定端口启动
REM ============================================================
setlocal

set "NODE_DIR=C:\Users\huawei\AppData\Local\Programs\kimi-desktop\resources\resources\runtime\node"
set "PATH=%NODE_DIR%;%PATH%"

cd /d "%~dp0"

if "%~1"=="install" (
  call npm install --no-audit --no-fund
) else if "%~1"=="dev" (
  if "%~2"=="" (call npm run dev -- --port 3000) else (call npm run dev -- --port %~2)
) else (
  call npm run build
)

endlocal
