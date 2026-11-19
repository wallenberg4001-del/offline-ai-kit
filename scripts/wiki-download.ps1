# Background downloader for FULL English Wikipedia (wikipedia_en_all_maxi, ~127 GB).
# Started automatically by START-OFFLINE-AI.bat when Wikipedia is not yet verified.
# - Resumes where it left off (safe to close, reboot or lose internet).
# - Checks the SHA256 published by Kiwix before the file is used.
# - When verified, restarts the library so Wikipedia appears without you doing anything.
param([switch]$Foreground)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'
Ensure-Dirs
$Host.UI.RawUI.WindowTitle = 'Offline AI - downloading full Wikipedia (you can minimise this)'
$progress = Join-Path $LogDir 'wikipedia-progress.json'
Set-Content -LiteralPath (Get-PidFile 'wikipedia-download') -Value $PID
$WarnBytes = [int64]140e9
if ($TestMode) { $WarnBytes = [int64]1e9; Write-Host 'TEST MODE: downloading the small Wikipedia stand-in.' -ForegroundColor Yellow }

function Finish([int]$code) {
  Remove-Item -LiteralPath (Get-PidFile 'wikipedia-download') -Force -ErrorAction SilentlyContinue
  if ($code -ne 0 -and -not $Foreground) { Write-Host ''; Read-Host 'Press Enter to close this window' | Out-Null }
  exit $code
}

try {
  Write-Host '=================================================='
  Write-Host '  Full English Wikipedia - background download'
  Write-Host '  Everything else in the kit already works while this runs.'
  Write-Host '=================================================='
  $entry = $ZimCatalog | Where-Object { $_.Prefix -eq $WikipediaPrefix } | Select-Object -First 1

  # Already have a verified copy (any date)? Then nothing to do.
  $have = Get-ChildItem -LiteralPath $VerifiedDir -Filter "$WikipediaPrefix*.zim" -ErrorAction SilentlyContinue |
          Where-Object { Test-Path -LiteralPath (Join-Path $Library $_.Name) } | Select-Object -First 1
  if ($have) {
    Write-ProgressFile -ProgressFile $progress -State 'done' -Percent 100 -Message "Wikipedia ready: $($have.Name)"
    Write-Host "Wikipedia is already downloaded and verified: $($have.Name)" -ForegroundColor Green
    Finish 0
  }

  Write-ProgressFile -ProgressFile $progress -State 'starting' -Message 'Looking up the newest Wikipedia file...'
  # Prefer finishing a partial download we already started, even if a newer edition came out.
  $partial = Get-ChildItem -LiteralPath $Library -Filter "$WikipediaPrefix*.zim*" -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
  $z = $null
  if ($partial) {
    $file = $partial.Name -replace '\.part$',''
    $dirUrl = "$KiwixBase/$($entry.Dir)/"
    $z = [pscustomobject]@{ Id='wikipedia'; File=$file; Url="$dirUrl$file"; ShaUrl="$dirUrl$file.sha256"; About=$entry.About }
    if ((Get-RemoteSize $z.Url) -le 0) { $z = $null }   # edition no longer on the server
  }
  if (-not $z) { $z = Resolve-LatestZim $entry }
  Write-Host "File: $($z.File)"
  $total = Get-RemoteSize $z.Url
  if ($total -le 0) { throw 'Could not get the Wikipedia file size from download.kiwix.org (no internet?).' }

  $dest = Join-Path $Library $z.File
  $already = [int64]0
  if (Test-Path -LiteralPath "$dest.part") { $already = (Get-Item -LiteralPath "$dest.part").Length }
  if (Test-Path -LiteralPath $dest) { $already = $total }
  $needed = $total - $already
  $free = Get-FreeBytes $Library
  Write-Host ("Size: {0}. Already downloaded: {1}. Free space on this drive: {2}." -f (Format-GB $total), (Format-GB $already), (Format-GB $free))
  if ($free -lt ($needed + [int64]2e9)) {
    $msg = "Not enough free space: Wikipedia needs {0} more but only {1} is free on this drive. Free up space (or move the kit to a bigger drive) and start the kit again." -f (Format-GB $needed), (Format-GB $free)
    Write-ProgressFile -ProgressFile $progress -State 'no-space' -Have $already -Total $total -Message $msg
    Write-Host $msg -ForegroundColor Red
    Finish 2
  }
  if ($free -lt $WarnBytes -and $already -eq 0) {
    Write-Host ("WARNING: only {0} free. Wikipedia needs about {1}; that leaves very little room for anything else." -f (Format-GB $free), (Format-GB $total)) -ForegroundColor Yellow
  }

  Write-Log 'wikipedia-download.log' "START $($z.File) total=$total already=$already free=$free"
  if (-not (Test-Path -LiteralPath $dest)) {
    Save-ResumableFile -Url $z.Url -OutFile $dest -ExpectedSize $total -ProgressFile $progress -Label "Downloading full Wikipedia ($($z.File))"
  }
  $ok = Get-Zim -Z $z -ProgressFile $progress
  if (-not $ok) {
    Write-ProgressFile -ProgressFile $progress -State 'failed' -Message 'Checksum did not match; the damaged file was deleted. It will download again next time you start the kit.'
    Finish 3
  }
  Write-ProgressFile -ProgressFile $progress -State 'done' -Have $total -Total $total -Percent 100 -Message "Wikipedia ready: $($z.File)"
  Write-Log 'wikipedia-download.log' "DONE $($z.File)"

  # Serve it now if the kit is running (otherwise it is picked up on the next start).
  if (Get-KitProcess 'kiwix') {
    Write-Host 'Restarting the library so Wikipedia shows up...'
    Start-KitKiwix | Out-Null
  }
  Write-Host 'Full Wikipedia is ready in the Offline Library.' -ForegroundColor Green
  Start-Sleep -Seconds 10
  Finish 0
} catch {
  $err = $_.Exception.Message
  Write-Log 'wikipedia-download.log' "ERROR $err"
  Write-ProgressFile -ProgressFile $progress -State 'error' -Message "Paused: $err (it will continue next time you start the kit)"
  Write-Host "Wikipedia download paused: $err" -ForegroundColor Yellow
  Write-Host 'It will pick up where it left off the next time you start the kit.'
  Finish 1
}
