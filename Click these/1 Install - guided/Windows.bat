@echo off
rem Guided installer. Opens a browser and explains every choice before anything downloads.
cd /d "%~dp0..\.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\scripts\install-gui.ps1"
echo.
pause
