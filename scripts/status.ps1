# Shows what is running and how the Wikipedia download is going.
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Continue'
Ensure-Dirs
function Show([string]$name, [int]$port) { if (Test-Port $port) { Write-Host ("  {0,-22} running  (http://127.0.0.1:{1})" -f $name, $port) -ForegroundColor Green } else { Write-Host ("  {0,-22} stopped" -f $name) -ForegroundColor Yellow } }
Write-Host 'Offline AI Kit status'
Show 'Offline Library' $LibraryPort
Show 'AI model server' $OllamaPort
Show 'Chat page' $ChatPort
Write-Host ''
Write-Host 'Verified library collections:'
Get-VerifiedZims | ForEach-Object { Write-Host ('  {0}  ({1})' -f (Split-Path -Leaf $_), (Format-GB (Get-Item -LiteralPath $_).Length)) }
$pf = Join-Path $LogDir 'wikipedia-progress.json'
Write-Host ''
if (Get-ChildItem -LiteralPath $VerifiedDir -Filter "$WikipediaPrefix*.zim" -ErrorAction SilentlyContinue) { Write-Host 'Full Wikipedia: ready' -ForegroundColor Green }
elseif (Test-Path -LiteralPath $pf) { $s = Get-Content -LiteralPath $pf -Raw | ConvertFrom-Json; Write-Host "Full Wikipedia: $($s.state) - $($s.message)" }
else { Write-Host 'Full Wikipedia: not started yet (it starts with START-OFFLINE-AI.bat)' }
if (Get-KitProcess 'wikipedia-download') { Write-Host '  (download window is open)' }
