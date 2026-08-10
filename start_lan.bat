@echo off
chcp 65001 >nul
title MEMO 局域网访问
cd /d "%~dp0"
echo ============================================
echo  MEMO 局域网访问服务
echo ============================================
echo  1. 手机连【同一 WiFi】
echo  2. 浏览器访问 http://本机IP:8901
echo     （本机 IP 可用 ipconfig 查看，或下方输出提示）
echo  3. 首次访问输入令牌（下方输出，或桌面版设置页查看）
echo  4. 数据与桌面版同一份（%APPDATA%\memo\data）
echo ============================================
echo.
"%~dp0dist\memo-backend\memo-backend.exe" --no-gui --host 0.0.0.0 --port 8901
pause
