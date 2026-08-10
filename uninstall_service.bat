@echo off
chcp 65001 >nul
schtasks /End /TN "MemoLocalService" 2>nul
schtasks /Delete /TN "MemoLocalService" /F
if %errorlevel%==0 (
  echo 已移除开机自启任务 "MemoLocalService"
) else (
  echo 未找到自启任务，或需要管理员权限
)
pause
