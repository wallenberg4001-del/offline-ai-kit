# Starts the Offline AI Kit: library (Kiwix), AI models (Ollama), chat page.
# Also starts the full-Wikipedia background download if it is not finished yet.
#   -ShareWifi / -NoShareWifi : turn Share on Wi-Fi on or off (remembered in kit-settings.ini)
param([switch]$ShareWifi, [switch]$NoShareWifi)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Continue'
Ensure-Dirs
$Host.UI.RawUI.WindowTitle = 'Offline AI - starting'
$ownTranscript = $false
if (-not $global:KitTranscript) { try { Start-Transcript -LiteralPath (Join-Path $LogDir 'start-latest.log') | Out-Null; $ownTranscript = $true } catch {} }
if ($TestMode) { Write-Host 'TEST MODE is on (kit-settings.ini).' -ForegroundColor Yellow }
Write-Host '=============================================='
Write-Host '  Offline AI Kit'
Write-Host "  $Kit"
Write-Host ('  ' + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
Write-Host '=============================================='
if ($ShareWifi) { Set-ShareOnWifi $true; Write-Host 'Share on Wi-Fi: turned ON (remembered; turn off with STATUS.bat or -NoShareWifi).' -ForegroundColor Yellow }
if ($NoShareWifi) { Set-ShareOnWifi $false; Write-Host 'Share on Wi-Fi: turned off (remembered).' }

if ((-not $UseSystemOllama -and -not (Get-OllamaExe)) -or -not (Get-KiwixServeExe)) {
  Write-Host 'The kit is not set up yet. Double-click SETUP.bat first (needs internet once).' -ForegroundColor Red
  exit 1
}

Write-Host ''
Write-Host '[1/4] Offline Library...'
Start-KitKiwix | Out-Null

Write-ChatConfig
if ($UseSystemOllama) { Write-Host "[2/4] AI model server: using your own Ollama on port $OllamaPort..." }
else { Write-Host "[2/4] AI model server (port $OllamaPort, separate from any normal Ollama)..." }
Start-KitOllama | Out-Null

Write-Host '[3/4] Chat page...'
if ($ShareOnWifi) { Write-Host '  Share on Wi-Fi is ON: the chat page and library are also open to your home network.' -ForegroundColor Yellow }
Stop-KitProcess 'chat-server'   # restart it so it listens the way Share on Wi-Fi says now
for ($i = 0; $i -lt 20 -and (Get-KitProcess 'chat-server'); $i++) { Start-Sleep -Milliseconds 250 }
for ($i = 0; $i -lt 12 -and (Test-Port $ChatPort); $i++) { Start-Sleep -Milliseconds 250 }
Start-ChatServer | Out-Null

Write-Host '[4/4] Full English Wikipedia...'
$wv = Get-ChildItem -LiteralPath $VerifiedDir -Filter "$WikipediaPrefix*.zim" -ErrorAction SilentlyContinue |
      Where-Object { Test-Path -LiteralPath (Join-Path $Library $_.Name) } | Select-Object -First 1
if ($wv) { Write-Host "  Ready: $($wv.Name)" -ForegroundColor Green }
elseif ($SkipWikipedia) { Write-Host '  Switched off (SKIP_WIKIPEDIA=yes in kit-settings.ini). Everything else works.' }
elseif (Get-KitProcess 'wikipedia-download') { Write-Host '  Still downloading in its own window (look for it on the taskbar).' }
else {
  $ps = Join-Path $PSHOME 'powershell.exe'
  if (-not (Test-Path -LiteralPath $ps)) { $ps = (Get-Process -Id $PID).Path }
  $dl = Join-Path $PSScriptRoot 'wiki-download.ps1'
  Start-Process -FilePath $ps -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $dl + '"')) -WindowStyle Minimized | Out-Null
  Write-Host ('  Not downloaded yet - started downloading it in the background (about {0}).' -f (Format-GB ($WikipediaGB * 1e9))) -ForegroundColor Yellow
  Write-Host '  A minimised window on the taskbar shows progress. Everything else works meanwhile.'
  Write-Host '  It resumes automatically if interrupted, and appears in the library when finished.'
}

$chatUrl = "http://127.0.0.1:$ChatPort/chat.html"
if (-not (Test-Port $ChatPort)) { $chatUrl = Join-Path $WwwDir 'chat.html' }
if ($env:OFFLINE_AI_NO_BROWSER -notmatch '^(?i)(1|yes|true)$') {
  Write-Host ''
  Write-Host 'Opening the chat page and the Offline Library in your browser...'
  Start-Process $chatUrl
  if (Test-Port $LibraryPort) { Start-Process "http://127.0.0.1:$LibraryPort/" }
}

Write-Host ''
Write-Host 'READY.' -ForegroundColor Green
Write-Host "  Chat:     $chatUrl"
Write-Host "  Library:  http://127.0.0.1:$LibraryPort/"
Write-Host '  Stop:     double-click STOP-OFFLINE-AI.bat'
Write-Host "  Logs:     $LogDir"
Write-Host "  Version:  $KitVersion"
Show-ShareStatus
if ($ShareOnWifi) { $u = Get-ShareUrls; if ($u) { Write-Host "SHARE URL: $($u.Chat)" } }
Write-Host ''
Write-Host 'You can close this window; the kit keeps running until you stop it or restart the PC.'
Write-Host 'RESULT: START OK'
if ($ownTranscript) { try { Stop-Transcript | Out-Null } catch {} }
