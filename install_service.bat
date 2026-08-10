@echo off
chcp 65001 >nul
rem 注册开机自启（登录时后台运行，无窗口）
set PY=C:\Python314\pythonw.exe
set SCRIPT=%~dp0service.py
schtasks /Create /TN "MemoLocalService" /TR "\"%PY%\" \"%SCRIPT%\"" /SC ONLOGON /RL LIMITED /F
if %errorlevel%==0 (
  echo 已注册开机自启任务 "MemoLocalService"
  echo 立即启动服务...
  start "" "%PY%" "%SCRIPT%"
) else (
  echo 注册失败，请以管理员身份重试
)
pause
