# Stops everything the kit started (never touches a normal Ollama on port 11434).
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Continue'
Ensure-Dirs
if ((-not $UseSystemOllama -and -not (Get-OllamaExe)) -or -not (Get-KiwixServeExe)) { Write-MissingPlatform }
Write-Host 'Stopping the Offline AI Kit...'
foreach ($n in @('kiwix','ollama','chat-server','add-libraries','add-maps','wikipedia-download')) { Stop-KitProcess $n }
# Any curl the Wikipedia downloader left behind (only ones writing into this kit's library).
try {
  Get-CimInstance Win32_Process -Filter "Name='curl.exe'" -ErrorAction Stop |
    Where-Object { $_.CommandLine -and $_.CommandLine.Contains($Library) } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
} catch {}
Write-Host 'Stopped. (A partly downloaded Wikipedia is kept and resumes next time you start.)' -ForegroundColor Green
