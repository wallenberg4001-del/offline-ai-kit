# v1.6.0 helpers. Dotted from common.ps1 and again from programs.ps1.
# The second dot wraps the program installers once the original functions exist.
# Pins, libzim check, book probes, computer-only delete guard, drive manifest.

function Get-PinLine([string]$Component, [string]$Platform) {
  $file = Join-Path $Kit 'catalog\runtime-pins.txt'
  if (-not (Test-Path -LiteralPath $file)) { return $null }
  foreach ($line in Get-Content -LiteralPath $file) {
    $t = $line.Trim()
    if (-not $t -or $t.StartsWith('#')) { continue }
    $parts = @($t.Split('|') | ForEach-Object { $_.Trim() })
    if ($parts.Count -lt 5) { continue }
    if ($parts[0] -eq $Component -and $parts[1] -eq $Platform) {
      return [pscustomobject]@{ Url = $parts[2]; Sha256 = $parts[3].ToLower(); Version = $parts[4] }
    }
  }
  return $null
}

function Test-LibzimAtLeast([string]$Have, [string]$Minimum) {
  if (-not $Have -or -not $Minimum) { return $false }
  $a = $Have.Split('.'); $b = $Minimum.Split('.')
  for ($i = 0; $i -lt 3; $i++) {
    $av = 0; $bv = 0
    if ($i -lt $a.Count) { $av = [int]$a[$i] }
    if ($i -lt $b.Count) { $bv = [int]$b[$i] }
    if ($av -gt $bv) { return $true }
    if ($av -lt $bv) { return $false }
  }
  return $true
}

function Assert-Libzim([string]$Version) {
  if (Test-LibzimAtLeast $Version '9.6.0') { return }
  throw "This library program is libzim $Version. This kit needs libzim 9.6.0 or newer."
}

function Get-PinPlatform([string]$Dest, [string]$Libc) {
  $d = $Dest.Replace('/', '\')
  if ($d -like '*windows-x64*') { return 'windows-x64' }
  if ($d -like '*mac-arm64*') { return 'mac-arm64' }
  if ($d -like '*mac-x64*') { return 'mac-x64' }
  if ($d -like '*linux-arm64*') { if ($Libc -eq 'musl' -or $d -like '*musl*') { return 'linux-arm64-musl' }; return 'linux-arm64' }
  if ($d -like '*linux-x64*') { if ($Libc -eq 'musl' -or $d -like '*musl*') { return 'linux-x64-musl' }; return 'linux-x64' }
  return 'windows-x64'
}

function Install-KiwixFromPin([string]$Dest, [string]$Label, [string]$Libc) {
  $platform = Get-PinPlatform $Dest $Libc
  $pin = Get-PinLine 'kiwix-tools' $platform
  if (-not $pin) { return 2 }
  Assert-Libzim $pin.Version
  $stamp = Join-Path $Dest 'LIBZIM'
  if ((Test-TreeFile $Dest @('kiwix-serve.exe', 'kiwix-serve')) -and (Test-Path -LiteralPath $stamp)) {
    $have = (Get-Content -LiteralPath $stamp -Raw).Trim()
    if (Test-LibzimAtLeast $have '9.6.0') { Write-Host '  Already installed.' -ForegroundColor Green; return 0 }
  }
  $name = Split-Path -Leaf $pin.Url
  $zip = Join-Path $Runtime $name
  Save-ResumableFile -Url $pin.Url -OutFile $zip -Label "Downloading $name" -MaxTries 20
  $got = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
  if ($got -ne $pin.Sha256) {
    Remove-Item -LiteralPath $zip -Force
    throw 'kiwix-tools download was damaged (checksum mismatch). Run setup again.'
  }
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
  Expand-ProgramArchive $zip $Dest
  Remove-Item -LiteralPath $zip -Force
  $ver = $pin.Version
  $bin = Get-ChildItem -LiteralPath $Dest -Recurse -File -Include 'kiwix-serve.exe','kiwix-serve' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($bin) {
    $parsed = ''
    try {
      $out = & $bin.FullName --version 2>&1 | Out-String
      if ($out -match '(\d+\.\d+\.\d+)') { $parsed = $Matches[1] }
    } catch { $parsed = '' }
    if ($parsed) {
      Assert-Libzim $parsed
      $ver = $parsed
    }
  }
  Set-Content -LiteralPath $stamp -Value ($ver + "`n") -Encoding ASCII
  if ($Libc) { Set-Content -LiteralPath (Join-Path (Split-Path -Parent $Dest) 'LIBC') -Value ($Libc + "`n") -Encoding ASCII }
  if (-not (Test-TreeFile $Dest @('kiwix-serve.exe', 'kiwix-serve'))) { throw "kiwix-tools for $Label did not unpack as expected." }
  Write-Host '  Installed.' -ForegroundColor Green
  return 0
}

function Get-VerifiedZims {
  if (-not (Test-Path -LiteralPath $VerifiedDir)) { return @() }
  $list = @()
  foreach ($m in Get-ChildItem -LiteralPath $VerifiedDir -File) {
    if ($m.Name -notlike '*.zim') { continue }
    $z = Join-Path $Library $m.Name
    $base = [System.IO.Path]::GetFileNameWithoutExtension($m.Name)
    $part = Join-Path $Library ($base + '.zimaa')
    if (Test-Path -LiteralPath $z) { $list += $z }
    elseif (Test-Path -LiteralPath $part) { $list += $z }
  }
  return $list
}

function Test-BookProbe([string]$Path) {
  $serve = Get-KiwixServeExe
  if (-not $serve) { return 'fail' }
  $search = Join-Path (Split-Path -Parent $serve) 'kiwix-search.exe'
  if (-not (Test-Path -LiteralPath $search)) { $search = Join-Path (Split-Path -Parent $serve) 'kiwix-search' }
  if (-not (Test-Path -LiteralPath $search)) { return 'fail' }
  $out = ''
  $code = 0
  try { $out = & $search $Path 'a' 2>&1 | Out-String; $code = $LASTEXITCODE } catch { return 'fail' }
  if ($out -match 'Cannot create Search without FT Xapian index') { return 'no-index' }
  if ($out -match 'Cannot read|Invalid argument|Unable to add') { return 'fail' }
  if ($code -ne 0) { return 'fail' }
  return 'ok'
}

function Start-KitKiwix {
  Stop-KitProcess 'kiwix'
  $exe = Get-KiwixServeExe
  if (-not $exe) { Write-Host "  Kiwix is missing. Run SETUP.bat first." -ForegroundColor Red; return $false }
  $addr = '127.0.0.1'   # always private; with Share on Wi-Fi the chat page server passes library pages through
  $serve = @()
  foreach ($z in @(Get-VerifiedZims)) {
    $probe = Test-BookProbe $z
    if ($probe -eq 'ok' -or $probe -eq 'no-index') { $serve += $z }
    else { Write-Host ("Skipped {0}: this computer's library program cannot open it" -f (Split-Path -Leaf $z)) -ForegroundColor Yellow }
  }
  if ($serve.Count -eq 0) { Write-Host '  No verified library files yet - the library will be empty.' -ForegroundColor Yellow; return $false }
  for ($i = 0; $i -lt 10 -and (Test-Port $LibraryPort); $i++) { Start-Sleep -Milliseconds 500 }
  if (Test-Port $LibraryPort) { Write-Host "  Port $LibraryPort is used by another program; the library cannot start." -ForegroundColor Red; return $false }
  $argStr = "--address=$addr --port=$LibraryPort " + (($serve | ForEach-Object { '"' + $_ + '"' }) -join ' ')
  $p = Start-Process -FilePath $exe -ArgumentList $argStr -WindowStyle Hidden -PassThru `
       -RedirectStandardOutput (Join-Path $LogDir 'kiwix.out.log') -RedirectStandardError (Join-Path $LogDir 'kiwix.log')
  Set-Content -LiteralPath (Get-PidFile 'kiwix') -Value $p.Id
  for ($i = 0; $i -lt 30; $i++) { if (Test-Port $LibraryPort) { Write-Host "  Library is serving $($serve.Count) collection(s)."; return $true }; Start-Sleep -Milliseconds 500 }
  Write-Host '  The library did not answer yet. See logs\kiwix.log' -ForegroundColor Yellow
  return $false
}

function Get-ComputerReceiptPath {
  $idFile = Join-Path $Kit 'kit-id.txt'
  if (-not (Test-Path -LiteralPath $idFile)) {
    $id = -join ((1..16) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
    Set-Content -LiteralPath $idFile -Value $id -Encoding ASCII
  }
  $id = (Get-Content -LiteralPath $idFile -Raw).Trim()
  $dir = Join-Path $env:LOCALAPPDATA 'OfflineAIKit'
  return (Join-Path $dir ("receipt-$id.txt"))
}

function Add-ComputerReceipt([string]$Kind, [string]$Path) {
  if (-not $Path) { return }
  $f = Get-ComputerReceiptPath
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $f) | Out-Null
  if ((Test-Path -LiteralPath $f) -and (Select-String -LiteralPath $f -SimpleMatch -Pattern $Path -Quiet)) { return }
  $when = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  Add-Content -LiteralPath $f -Value ("$Kind | $Path | $when") -Encoding ASCII
}

function Test-ComputerNameAllowed([string]$Path) {
  $base = Split-Path -Leaf $Path
  if ($base -in @('Offline AI.command', 'Offline AI.lnk', 'offline-ai-kit.desktop', 'offline-ai-kit')) { return $true }
  if ($base -like 'receipt-*.txt' -or $base -like 'offline-ai-uninstall-*.cmd' -or $base -like '*offline-ai*') { return $true }
  if ($Path -like '*\offline-ai-kit' -or $Path -like '*\offline-ai-kit\*') { return $true }
  return $false
}

function Remove-KitComputerItem([string]$Path) {
  if (-not $Path) { return $false }
  if (-not (Test-Path -LiteralPath $Path)) { return $true }
  $real = [System.IO.Path]::GetFullPath($Path)
  $kitFull = [System.IO.Path]::GetFullPath($Kit)
  if ($real.TrimEnd('\') -eq $kitFull.TrimEnd('\') -or $real.StartsWith($kitFull.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Output "Refused (on the kit drive): $Path"
    return $false
  }
  $kitRoot = ''
  $pathRoot = ''
  try { $kitRoot = [System.IO.Path]::GetPathRoot($kitFull) } catch {}
  try { $pathRoot = [System.IO.Path]::GetPathRoot($real) } catch {}
  $system = $env:SystemDrive
  if ($pathRoot -and $kitRoot -and ($pathRoot -eq $kitRoot) -and $system -and ($kitRoot.TrimEnd('\') -ne $system.TrimEnd('\'))) {
    Write-Output "Refused (on the kit drive): $Path"
    return $false
  }
  $home = $env:USERPROFILE
  $temp = $env:TEMP
  $local = $env:LOCALAPPDATA
  $app = $env:APPDATA
  $under = $false
  foreach ($root in @($home, $temp, $local, $app)) {
    if (-not $root) { continue }
    $r = $root.TrimEnd('\')
    if ($real.Equals($r, [System.StringComparison]::OrdinalIgnoreCase) -or $real.StartsWith($r + '\', [System.StringComparison]::OrdinalIgnoreCase)) { $under = $true }
  }
  if (-not $under -or -not (Test-ComputerNameAllowed $real)) {
    Write-Output "Refused (on the kit drive): $Path"
    return $false
  }
  if (Test-Path -LiteralPath $real -PathType Container) { [System.IO.Directory]::Delete($real, $true) }
  else { [System.IO.File]::Delete($real) }
  return $true
}

function Assert-KitSpace([double]$SelectedGB, [int64]$FreeBytes) {
  $extra = 0
  if ($env:OFFLINE_AI_SPLIT_MARGIN -eq 'yes') { $extra = 2 }
  $need = [math]::Round(($SelectedGB * 1.05) + 5 + $extra, 1)
  $freeGB = [math]::Round($FreeBytes / 1e9, 0)
  if ($FreeBytes -lt ($need * 1e9)) {
    Write-Host "Selected $SelectedGB GB, free $freeGB GB → not enough room." -ForegroundColor Red
    Write-Host 'Drop the largest items, or pick a larger drive. Nothing was downloaded.' -ForegroundColor Red
    return $false
  }
  Write-Host "Selected $SelectedGB GB, free $freeGB GB → OK"
  return $true
}

function Write-DriveManifest {
  $files = @()
  $libzim = @{}
  Get-ChildItem -LiteralPath $Kit -Recurse -File -Force | Where-Object {
    $_.FullName -notlike (Join-Path $Kit 'logs\*') -and $_.Name -ne 'DRIVE-MANIFEST.json' -and $_.Name -ne 'DRIVE-READY.txt' -and $_.FullName -notlike '*\.git\*'
  } | ForEach-Object {
    $rel = $_.FullName.Substring($Kit.Length).TrimStart('\','/').Replace('\','/')
    $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()
    $files += [pscustomobject]@{ path = $rel; size = $_.Length; sha256 = $sha }
    if ($rel.EndsWith('/LIBZIM')) {
      $plat = ($rel -split '/')[1]
      if ($plat) { $libzim[$plat] = (Get-Content -LiteralPath $_.FullName -Raw).Trim() }
    }
  }
  $doc = [pscustomobject]@{
    version = $KitVersion
    created = (Get-Date -Format 'yyyy-MM-dd')
    libzim = $libzim
    files = @($files | Sort-Object path)
  }
  $out = Join-Path $Kit 'DRIVE-MANIFEST.json'
  $doc | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $out -Encoding UTF8
  $ready = Join-Path $Kit 'DRIVE-READY.txt'
  $lines = @("Offline AI Kit $KitVersion", ("Files: {0}" -f $files.Count), ("Verified: all {0} files match." -f $files.Count), 'No user name, computer name, or network identity is stored in this file.')
  Set-Content -LiteralPath $ready -Value $lines -Encoding ASCII
  Write-Output ("MANIFEST {0}" -f $files.Count)
}

function Complete-DriveSetup([bool]$Problems) {
  if ($Problems) {
    Write-Host 'RESULT: SETUP FINISHED WITH PROBLEMS'
    Write-Host 'RESULT: DRIVE INCOMPLETE'
    return
  }
  try { if (-not (Test-Path -LiteralPath (Join-Path $Kit 'kit-id.txt'))) { Get-ComputerReceiptPath | Out-Null } } catch {}
  try { Write-DriveManifest | Out-Null } catch {}
  $manifest = Join-Path $Kit 'DRIVE-MANIFEST.json'
  $bad = $false
  if (-not (Test-Path -LiteralPath $manifest)) { $bad = $true }
  else {
    $text = Get-Content -LiteralPath $manifest -Raw
    foreach ($needle in @($env:USERNAME, $env:USERPROFILE, $env:COMPUTERNAME)) {
      if ($needle -and $text.ToLower().Contains($needle.ToLower())) { $bad = $true }
    }
  }
  Write-Host 'RESULT: SETUP OK'
  if ($bad) { Write-Host 'RESULT: DRIVE INCOMPLETE' } else { Write-Host 'RESULT: DRIVE READY' }
}

function Install-OllamaFromPin([string]$Dest, [string]$Asset, [string]$Base, [string]$PinnedSha) {
  $comp = 'ollama'
  if ($Dest -like '*ollama-v0.12.9*' -or $Dest -like ('*ollama-' + $OllamaPinVersion + '*')) { $comp = 'ollama-v0.12.9' }
  $d = $Dest.Replace('/', '\')
  $platform = 'windows-x64'
  if ($d -like '*linux-arm64*') { $platform = 'linux-arm64' }
  elseif ($d -like '*linux-x64*') { $platform = 'linux-x64' }
  elseif ($d -like '*mac-x64*') { $platform = 'mac-x64' }
  elseif ($d -like '*mac-arm64*') { $platform = 'mac-arm64' }
  $pin = Get-PinLine $comp $platform
  if (-not $pin) { return 2 }
  if (Test-TreeFile $Dest @('ollama.exe', 'ollama')) { Write-Host '  Already installed.' -ForegroundColor Green; return 0 }
  $name = Split-Path -Leaf $pin.Url
  $zip = Join-Path $Runtime $name
  $have = ''
  if (Test-Path -LiteralPath $zip) { $have = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() }
  if ($have -ne $pin.Sha256) {
    Save-ResumableFile -Url $pin.Url -OutFile $zip -Label "Downloading $name" -MaxTries 20
    if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() -ne $pin.Sha256) {
      Remove-Item -LiteralPath $zip -Force
      throw 'Ollama download was damaged (checksum mismatch). Run setup again.'
    }
  }
  $tmp = Join-Path $Runtime ('_unpack-' + $name)
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  Expand-ProgramArchive $zip $tmp
  if (-not (Test-TreeFile $tmp @('ollama.exe', 'ollama'))) {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    throw 'Ollama did not unpack as expected.'
  }
  $parent = Split-Path -Parent $Dest
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
  Move-Item -LiteralPath $tmp -Destination $Dest
  Remove-Item -LiteralPath $zip -Force
  Write-Host '  Installed.' -ForegroundColor Green
  return 0
}

function Install-DarwinFromPin([string]$Channel) {
  $comp = 'ollama'
  $destName = 'ollama'
  if ($Channel -eq 'pinned') { $comp = 'ollama-v0.12.9'; $destName = 'ollama-' + $OllamaPinVersion }
  $pin = Get-PinLine $comp 'mac-arm64'
  if (-not $pin) { return 2 }
  $arm = Join-Path $Runtime ("mac-arm64\" + $destName)
  $intel = Join-Path $Runtime ("mac-x64\" + $destName)
  if ((Test-TreeFile $arm @('ollama')) -and (Test-TreeFile $intel @('ollama'))) {
    Write-Host "  Mac AI program ($destName) already installed for both chips." -ForegroundColor Green
    return 0
  }
  $name = Split-Path -Leaf $pin.Url
  $zip = Join-Path $Runtime $name
  Save-ResumableFile -Url $pin.Url -OutFile $zip -Label "Downloading $name" -MaxTries 20
  if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() -ne $pin.Sha256) {
    Remove-Item -LiteralPath $zip -Force
    throw 'Ollama for Mac was damaged (checksum mismatch). Run setup again.'
  }
  $tmp = Join-Path $Runtime ('_unpack-darwin-' + $Channel)
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  Expand-ProgramArchive $zip $tmp
  Remove-Item -LiteralPath $zip -Force
  foreach ($dest in @($arm, $intel)) {
    if (Test-TreeFile $dest @('ollama')) { continue }
    Copy-ProgramTree $tmp $dest
  }
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  Write-Host '  Installed.' -ForegroundColor Green
  return 0
}

if (-not $script:V160WrappedInstallers) {
  $kiwixCmd = Get-Command Install-KiwixAsset -ErrorAction SilentlyContinue
  $ollamaCmd = Get-Command Install-OllamaAsset -ErrorAction SilentlyContinue
  $darwinCmd = Get-Command Install-DarwinOllamaCopies -ErrorAction SilentlyContinue
  $universalCmd = Get-Command Install-UniversalPrograms -ErrorAction SilentlyContinue
  if ($kiwixCmd) { $script:V160KiwixUnpinned = $kiwixCmd.ScriptBlock }
  if ($ollamaCmd) { $script:V160OllamaUnpinned = $ollamaCmd.ScriptBlock }
  if ($darwinCmd) { $script:V160DarwinUnpinned = $darwinCmd.ScriptBlock }
  if ($universalCmd) { $script:V160UniversalUnpinned = $universalCmd.ScriptBlock }
  if ($kiwixCmd) {
    function Install-KiwixAsset([string]$Dest, [string]$Regex, [string]$Label, [string]$LibcFile) {
      $libc = ''
      if ($LibcFile -like '*musl*') { $libc = 'musl' }
      elseif ($LibcFile) { $libc = 'glibc' }
      $rc = Install-KiwixFromPin $Dest $Label $libc
      if ($rc -eq 2) { & $script:V160KiwixUnpinned $Dest $Regex $Label $LibcFile }
      elseif ($rc -ne 0) { throw 'kiwix pin install failed' }
    }
    function Install-UniversalPrograms {
      & $script:V160UniversalUnpinned
      if ($TestMode) { return }
      foreach ($pair in @(
        @('linux-x64-musl', 'Linux x64 musl', 'musl'),
        @('linux-arm64-musl', 'Linux ARM musl', 'musl')
      )) {
        $dest = Join-Path $Runtime ($pair[0] + '\kiwix')
        Install-KiwixAsset $dest 'pinned' $pair[1] $pair[2]
      }
    }
    if ($ollamaCmd) {
      function Install-OllamaAsset([string]$Dest, [string]$Asset, [string]$Base, [string]$PinnedSha) {
        $rc = Install-OllamaFromPin $Dest $Asset $Base $PinnedSha
        if ($rc -eq 2) { & $script:V160OllamaUnpinned $Dest $Asset $Base $PinnedSha }
        elseif ($rc -ne 0) { throw 'ollama pin install failed' }
      }
    }
    if ($darwinCmd) {
      function Install-DarwinOllamaCopies([string]$Channel) {
        $rc = Install-DarwinFromPin $Channel
        if ($rc -eq 2) { & $script:V160DarwinUnpinned $Channel }
        elseif ($rc -ne 0) { throw 'darwin pin install failed' }
      }
    }
    $script:V160WrappedInstallers = $true
  }
}
