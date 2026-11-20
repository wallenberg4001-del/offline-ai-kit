# Shows what is running and how the Wikipedia download is going, then offers a small menu:
# Share on Wi-Fi on/off, add Extra Libraries, add offline maps, check for updates.
#   status.ps1 -Once                 (just the status, no menu)
#   status.ps1 -ShareWifi on|off     (turn Share on Wi-Fi on or off and apply it now)
#   status.ps1 -CheckUpdates         (ask GitHub for a newer version; needs internet)
param([switch]$Once, [string]$ShareWifi = '', [switch]$CheckUpdates)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Continue'
Ensure-Dirs

function Show([string]$name, [int]$port) { if (Test-Port $port) { Write-Host ("  {0,-22} running  (http://127.0.0.1:{1})" -f $name, $port) -ForegroundColor Green } else { Write-Host ("  {0,-22} stopped" -f $name) -ForegroundColor Yellow } }
function Show-Status {
  Write-Host "Offline AI Kit status (version $KitVersion)"
  Show 'Offline Library' $LibraryPort
  Show 'AI model server' $OllamaPort
  Show 'Chat page' $ChatPort
  Show-ShareStatus
  Write-Host ''
  Write-Host 'Verified library collections:'
  Get-VerifiedZims | ForEach-Object { Write-Host ('  {0}  ({1})' -f (Split-Path -Leaf $_), (Format-GB (Get-Item -LiteralPath $_).Length)) }
  $pf = Join-Path $LogDir 'wikipedia-progress.json'
  Write-Host ''
  if (Get-ChildItem -LiteralPath $VerifiedDir -Filter "$WikipediaPrefix*.zim" -ErrorAction SilentlyContinue) { Write-Host 'Full Wikipedia: ready' -ForegroundColor Green }
  elseif ($SkipWikipedia) { Write-Host 'Full Wikipedia: switched off (SKIP_WIKIPEDIA=yes)' }
  elseif (Test-Path -LiteralPath $pf) { $s = Get-Content -LiteralPath $pf -Raw | ConvertFrom-Json; Write-Host "Full Wikipedia: $($s.state) - $($s.message)" }
  else { Write-Host 'Full Wikipedia: not started yet (it starts with START-OFFLINE-AI.bat)' }
  if ((Get-KitProcess 'wikipedia-download') -and -not (Get-ChildItem -LiteralPath $VerifiedDir -Filter "$WikipediaPrefix*.zim" -ErrorAction SilentlyContinue)) { Write-Host '  (download window is open)' }
}

function Switch-Share([bool]$On) {
  if ($On) {
    Write-Host ''
    Write-Host 'Turning Share on Wi-Fi ON.' -ForegroundColor Yellow
    Write-WifiWarning
  } else { Write-Host ''; Write-Host 'Turning Share on Wi-Fi off (only this computer can use the kit).' }
  Set-ShareOnWifi $On -Apply
  Show-ShareStatus
}

if ($ShareWifi) {
  if ($ShareWifi -match '^(?i)(on|1|yes|true)$') { Switch-Share $true } elseif ($ShareWifi -match '^(?i)(off|0|no|false)$') { Switch-Share $false }
  else { Write-Host 'Use -ShareWifi on or -ShareWifi off' -ForegroundColor Red; exit 1 }
  exit 0
}
if ($CheckUpdates) { $null = Invoke-UpdateCheck; exit 0 }

Show-Status
if ($Once -or [Console]::IsInputRedirected) { exit 0 }
while ($true) {
  $state = 'off'; if ($ShareOnWifi) { $state = 'ON' }
  Write-Host ''
  Write-Host 'What would you like to do?'
  Write-Host "  1) Turn Share on Wi-Fi $(if ($ShareOnWifi) { 'OFF' } else { 'ON' })   (now: $state - lets phones/tablets on your home Wi-Fi use the kit)"
  Write-Host '  2) Add Extra Libraries   (Wiktionary, Project Gutenberg, Stack Exchange Q&A, preparedness guides...)'
  Write-Host '  3) Add offline maps      (Vancouver Island / BC / Alberta, and broader regions)'
  Write-Host '  4) Check for updates     (needs internet; nothing is downloaded or changed)'
  Write-Host '  5) Show the status again'
  $c = Read-Host 'Type 1-5, or just press Enter to close'
  switch ($c.Trim()) {
    '1' { Switch-Share (-not $ShareOnWifi) }
    '2' { & (Join-Path $PSScriptRoot 'add-libraries.ps1') }
    '3' { & (Join-Path $PSScriptRoot 'add-maps.ps1') }
    '4' { Write-Host ''; $null = Invoke-UpdateCheck }
    '5' { Write-Host ''; Show-Status }
    default { exit 0 }
  }
}
