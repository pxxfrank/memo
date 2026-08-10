@echo off
chcp 65001 >nul
title MEMO 本地服务
cd /d "%~dp0"
echo 启动 MEMO 本地服务...
echo 应用地址: http://127.0.0.1:8899/
echo 全局热键: Ctrl+Shift+M（可在应用内"设置"修改）
echo 关闭本窗口即停止服务
"C:\Python314\python.exe" service.py --open
pause
