@echo off
rem EASY INSTALL: no questions. Picks the right version for this computer, installs, then starts.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1" -Easy %*
echo.
pause
