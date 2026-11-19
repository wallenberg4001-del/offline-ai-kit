@echo off
rem Double-click me. Runs scripts\stop.ps1 with Windows PowerShell (no install needed).
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\stop.ps1" %*
echo.
pause
