# Add optional Extra Libraries (Wiktionary, Project Gutenberg, Stack Exchange Q&A, preparedness guides...).
# The list is in catalog\extra-libraries.txt. Opened from STATUS.bat, or run directly:
#   add-libraries.ps1                 (menu)
#   add-libraries.ps1 -List           (show the list and what is already added)
#   add-libraries.ps1 -Add se-diy,wiktionary-simple      (numbers from -List work too)
#   add-libraries.ps1 -Remove se-diy  (delete a collection you added)
# Downloads use the fastest mirror, resume if interrupted, are checked with SHA-256, and the
# library restarts by itself afterwards so the chat's "Ask the library" can use them right away.
param([switch]$List, [string]$Add = '', [string]$Remove = '', [switch]$Yes)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Continue'
Ensure-Dirs
$cat = @(Get-ExtraCatalog)
if ($cat.Count -eq 0) { Write-Host 'The Extra Libraries list (catalog\extra-libraries.txt) is missing.' -ForegroundColor Red; exit 1 }

function Restart-LibraryIfRunning {
  if (Get-KitProcess 'kiwix') { Write-Host 'Restarting the library so the new collections show up...'; Start-KitKiwix | Out-Null }
  else { Write-Host 'The kit is not running; the new collections appear the next time you start it.' }
}

if ($List) { Write-Host 'Extra Libraries:'; Show-ExtraCatalog $cat; exit 0 }

if ($Remove) {
  $sel = @(Resolve-ExtraIds $Remove $cat)
  $wasRunning = [bool](Get-KitProcess 'kiwix')
  foreach ($e in $sel) {
    $f = Get-ExtraInstalled $e
    if (-not $f) { Write-Host "  Not added: $($e.Id)"; continue }
    if (Get-KitProcess 'kiwix') { Stop-KitProcess 'kiwix'; Start-Sleep -Milliseconds 500 }
    Remove-Item -LiteralPath (Join-Path $Library $f), (Join-Path $VerifiedDir $f) -Force -ErrorAction SilentlyContinue
    Write-Host "  Removed $($e.Id) ($f)" -ForegroundColor Green
    Write-Log 'zim-downloads.log' "REMOVED $f"
  }
  if ($wasRunning) { Start-KitKiwix | Out-Null }
  exit 0
}

if (-not $Add) {
  Write-Host '=================================================='
  Write-Host '  Add Extra Libraries (needs internet while downloading)'
  Write-Host '=================================================='
  Show-ExtraCatalog $cat
  Write-Host ("  Free space on this drive: {0}" -f (Format-GB (Get-FreeBytes $Library)))
  Write-Host ''
  $Add = Read-Host 'Type the numbers or names to add (e.g. 1,3), "all", or press Enter to go back'
  if (-not $Add) { exit 0 }
}
$sel = @(Resolve-ExtraIds $Add $cat)
if ($sel.Count -eq 0) { Write-Host 'Nothing chosen.'; exit 0 }
$gb = 0.0; foreach ($e in $sel) { if (-not (Get-ExtraInstalled $e)) { $gb += $e.GB } }
Write-Host ("Adding {0} collection(s), about {1} to download." -f $sel.Count, (Format-Size $gb))
if ($gb -gt 50 -and -not $Yes) {
  $a = Read-Host 'That is a very big download. Continue? (Y/N)'
  if ($a -notmatch '^[Yy]') { exit 0 }
}
$failed = @(); $added = 0
foreach ($e in $sel) {
  try { if (Install-ExtraLibrary $e) { $added++ } else { $failed += $e.Id } }
  catch { Write-Host "    Problem: $($_.Exception.Message)" -ForegroundColor Yellow; $failed += $e.Id }
}
if ($added -gt 0) { Restart-LibraryIfRunning }
if ($failed.Count) { Write-Host ('Not added (run again to retry; downloads resume): ' + ($failed -join ', ')) -ForegroundColor Yellow; Write-Host 'RESULT: ADD LIBRARIES FINISHED WITH PROBLEMS'; exit 1 }
Write-Host 'RESULT: ADD LIBRARIES OK' -ForegroundColor Green
