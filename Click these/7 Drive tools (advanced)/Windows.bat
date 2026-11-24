@echo off
cd /d "%~dp0..\.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\scripts\drive-tools.ps1" %*
echo.
pause
