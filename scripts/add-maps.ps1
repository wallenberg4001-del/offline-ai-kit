# Add optional regional offline maps (OpenStreetMap data in Kiwix ZIM files).
# The list is in catalog\maps.txt. Opened from STATUS.bat, or run directly:
#   add-maps.ps1                 (menu)
#   add-maps.ps1 -List           (show the list and what is already added)
#   add-maps.ps1 -Add alberta,europe      (numbers from -List work too; "all" = every map file)
#   add-maps.ps1 -Remove alberta (drops that region; the shared Canada file stays if another region still uses it)
# Vancouver Island, British Columbia and Alberta are the same Canada file and download once.
# Downloads use the fastest mirror, resume if interrupted, are checked with SHA-256, and the
# library restarts afterwards. Phones on Share on Wi-Fi open the maps through port 8091.
param([switch]$List, [string]$Add = '', [string]$Remove = '', [switch]$Yes)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Continue'
Ensure-Dirs
$cat = @(Get-MapCatalog)
if ($cat.Count -eq 0) { Write-Host 'The maps list (catalog\maps.txt) is missing.' -ForegroundColor Red; exit 1 }

function Restart-LibraryIfRunning {
  Write-MapsIndex
  if (Get-KitProcess 'kiwix') { Write-Host 'Restarting the library so the new maps show up...'; Start-KitKiwix | Out-Null }
  else { Write-Host 'The kit is not running; the new maps appear the next time you start it.' }
}

if ($List) { Write-Host 'Offline maps:'; Show-MapCatalog $cat; exit 0 }

if ($Remove) {
  $sel = @(Resolve-MapIds $Remove $cat)
  $wasRunning = [bool](Get-KitProcess 'kiwix')
  $removedFiles = @{}
  foreach ($e in $sel) {
    $f = Get-PrefixInstalled $e.Prefix
    if (-not $f) { Write-Host "  Not added: $($e.Id)"; continue }
    # A shared file (the Canada map) stays until every region that uses it is removed together.
    $others = @($cat | Where-Object { $_.Prefix -eq $e.Prefix -and $_.Id -ne $e.Id })
    $also = @($sel | Where-Object { $_.Prefix -eq $e.Prefix -and $_.Id -ne $e.Id })
    if ($others.Count -gt $also.Count) {
      Write-Host "  $($e.Id) uses the same file as another region ($f). The file stays." -ForegroundColor Yellow
      continue
    }
    if (-not $removedFiles.ContainsKey($f)) {
      if (Get-KitProcess 'kiwix') { Stop-KitProcess 'kiwix'; Start-Sleep -Milliseconds 500 }
      Remove-Item -LiteralPath (Join-Path $Library $f), (Join-Path $VerifiedDir $f) -Force -ErrorAction SilentlyContinue
      $removedFiles[$f] = 1
      Write-Log 'zim-downloads.log' "REMOVED $f"
    }
    Write-Host "  Removed $($e.Id) ($f)" -ForegroundColor Green
  }
  if ($wasRunning) { Start-KitKiwix | Out-Null }
  Write-MapsIndex
  exit 0
}

if (-not $Add) {
  Write-Host '=================================================='
  Write-Host '  Add offline maps (needs internet while downloading)'
  Write-Host '  Vancouver Island, British Columbia and Alberta are one Canada file (about 10 GB).'
  Write-Host '=================================================='
  Show-MapCatalog $cat
  Write-Host ("  Free space on this drive: {0}" -f (Format-GB (Get-FreeBytes $Library)))
  Write-Host ''
  $Add = Read-Host 'Type the numbers or names to add (e.g. 1,4), "all", or press Enter to go back'
  if (-not $Add) { exit 0 }
}
$sel = @(Resolve-MapIds $Add $cat)
if ($sel.Count -eq 0) { Write-Host 'Nothing chosen.'; exit 0 }
$files = @(Get-MapDownloadSet $sel)
$gb = Get-MapDownloadGB $sel
Write-Host ("Adding {0} region(s), {1} file(s), about {2} to download." -f $sel.Count, $files.Count, (Format-Size $gb))
if ($gb -gt 50 -and -not $Yes) {
  $a = Read-Host 'That is a very big download. Continue? (Y/N)'
  if ($a -notmatch '^[Yy]') { exit 0 }
}
Start-StayAwake
Set-Content -LiteralPath (Get-PidFile 'add-maps') -Value $PID
$failed = @(); $added = 0
foreach ($e in $files) {
  try { if (Install-Map $e) { $added++ } else { $failed += $e.Id } }
  catch { Write-Host "    Problem: $($_.Exception.Message)" -ForegroundColor Yellow; $failed += $e.Id }
}
Remove-Item -LiteralPath (Get-PidFile 'add-maps') -Force -ErrorAction SilentlyContinue
$prev = @((Get-Setting 'MAPS' '') -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
$ids = @($prev + @($sel | ForEach-Object { $_.Id }) | Select-Object -Unique)
Set-KitSetting 'MAPS' ($ids -join ',')
if ($added -gt 0) { Restart-LibraryIfRunning } else { Write-MapsIndex }
if ($failed.Count) { Write-Host ('Not added (run again to retry; downloads resume): ' + ($failed -join ', ')) -ForegroundColor Yellow; Write-Host 'RESULT: ADD MAPS FINISHED WITH PROBLEMS'; exit 1 }
Write-Host 'RESULT: ADD MAPS OK' -ForegroundColor Green
