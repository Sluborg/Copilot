@echo off
setlocal

set "ROOT=C:\Dev\Copilot\Magentic2"
set "SCRIPT=%ROOT%\scripts\startup-smart.ps1"

if not exist "%SCRIPT%" (
  powershell -NoProfile -Command "Write-Host 'TUNNEL DOWN: Script not found: %SCRIPT%' -ForegroundColor Red"
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Minimized -File "%SCRIPT%"
if errorlevel 1 (
  powershell -NoProfile -Command "Write-Host 'TUNNEL DOWN: Startup health check failed. Keep this window open and fix it.' -ForegroundColor Red"
  pause
  exit /b 1
)

exit /b 0
