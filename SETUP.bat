@echo off
rem Double-click me. Runs scripts\setup.ps1 with Windows PowerShell (no install needed).
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1" %*
echo.
pause
