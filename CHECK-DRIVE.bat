@echo off
rem Double-click me. Checks this drive. Nothing is downloaded.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\check-drive.ps1" %*
echo.
pause
