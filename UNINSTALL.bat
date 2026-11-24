@echo off
rem Double-click me. Removes this copy of the Offline AI Kit after you type YES.
cd /d "%TEMP%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall.ps1" %*
echo.
pause
