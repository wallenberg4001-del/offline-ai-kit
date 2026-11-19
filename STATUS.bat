@echo off
rem Double-click me. Runs scripts\status.ps1 with Windows PowerShell (no install needed).
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\status.ps1" %*
echo.
pause
