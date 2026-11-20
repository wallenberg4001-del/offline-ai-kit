# Download Kiwix and Ollama into runtime/<platform>/. Dotted by setup.ps1 after common.ps1.
# One shared library, models and maps. No symlinks: archives are unpacked and any
# link inside them is turned into a real copy (Repair-ExtractedLinks).

# Static zstd v1.5.6-bcr2. Same pins as mac/lib.sh. Stock tar on some PCs cannot read .tar.zst.
$script:ZstdToolBase = 'https://github.com/aspect-build/zstd-prebuilt/releases/download/v1.5.6-bcr2'
$script:HostZstdSha = @{
  'zstd_darwin_amd64' = 'd81be8618553d7d658e09da669ffd68ec76d8095161a590c9b8a1a99fce67ca8'
  'zstd_darwin_arm64' = '9848858f7332effb071818f282b3ac3052085e3dafa9ae09f0060b7e211a80dc'
  'zstd_linux_amd64' = '190c196b46883a234238d9c52a211c1494df79bb170fbe30c6fc22639d5d4731'
  'zstd_linux_arm64' = '4fa2386a975c2120f91f3103bd4268a19a341cb9063417f3829018e94f28c8c6'
  'zstd_windows_x86_64.exe' = '8765d39af6a89f5b7b05854d08027e739c8f2245c4488c8365b3ddaf5cdbcf28'
  'zstd_windows_arm64.exe' = 'ef983e169862f9d32652c9017e500052bd31ce5a2c7cb16bccdb71bcfa90c884'
}

function Get-HostZstd {
  # A zstd.exe for this PC, from PATH or a checksum-checked download. Empty if this PC has no pin.
  $cmd = Get-Command zstd.exe -ErrorAction SilentlyContinue
  if (-not $cmd) { $cmd = Get-Command zstd -ErrorAction SilentlyContinue }
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  $arch = $env:PROCESSOR_ARCHITECTURE
  if ($env:PROCESSOR_ARCHITEW6432) { $arch = $env:PROCESSOR_ARCHITEW6432 }
  $name = 'zstd_windows_x86_64.exe'
  if ($arch -eq 'ARM64') { $name = 'zstd_windows_arm64.exe' }
  $want = $script:HostZstdSha[$name]
  if (-not $want) { return '' }
  $dir = Join-Path $Runtime '_host-tools'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $dest = Join-Path $dir $name
  $ok = $false
  if (Test-Path -LiteralPath $dest) {
    if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower() -eq $want) { $ok = $true }
  }
  if (-not $ok) {
    Write-Host '  Getting a small zstd program so this computer can open Linux archives...'
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
    Save-ResumableFile -Url ($script:ZstdToolBase + '/' + $name) -OutFile $dest -Label 'zstd' -MaxTries 5
    if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLower() -ne $want) {
      Remove-Item -LiteralPath $dest -Force
      throw 'The zstd program was damaged (checksum mismatch). Run setup again.'
    }
  }
  return $dest
}

function Expand-ZstdTar([string]$File, [string]$Dest, [string]$Zstd) {
  # Stream zstd into tar. PowerShell's pipe would corrupt the bytes, so this uses the process streams.
  $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
  $psiZ = New-Object System.Diagnostics.ProcessStartInfo
  $psiZ.FileName = $Zstd
  $psiZ.Arguments = '-dc "' + $File + '"'
  $psiZ.RedirectStandardOutput = $true
  $psiZ.UseShellExecute = $false
  $psiZ.CreateNoWindow = $true
  $pz = New-Object System.Diagnostics.Process
  $pz.StartInfo = $psiZ
  [void]$pz.Start()
  $psiT = New-Object System.Diagnostics.ProcessStartInfo
  $psiT.FileName = $tar
  $psiT.Arguments = '-xf - -C "' + $Dest + '"'
  $psiT.RedirectStandardInput = $true
  $psiT.UseShellExecute = $false
  $psiT.CreateNoWindow = $true
  $pt = New-Object System.Diagnostics.Process
  $pt.StartInfo = $psiT
  [void]$pt.Start()
  try { $pz.StandardOutput.BaseStream.CopyTo($pt.StandardInput.BaseStream) }
  finally { try { $pt.StandardInput.Close() } catch {} }
  $pz.WaitForExit()
  $pt.WaitForExit()
  if ($pz.ExitCode -ne 0 -or $pt.ExitCode -ne 0) { throw "Could not unpack $File" }
}

function Expand-ProgramArchive([string]$File, [string]$Dest) {
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  if ($File -match '\.zip$') {
    Expand-Archive -LiteralPath $File -DestinationPath $Dest -Force
  } else {
    & tar.exe -xf $File -C $Dest
    if ($LASTEXITCODE -ne 0) {
      if ($File -notmatch '\.tar\.zst$' -and $File -notmatch '\.zst$') { throw "Could not unpack $File" }
      Get-ChildItem -LiteralPath $Dest -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
      $z = Get-HostZstd
      if (-not $z) { throw "Could not unpack $File. This file is compressed with zstd, and this computer could not read it." }
      Expand-ZstdTar $File $Dest $z
    }
  }
  Repair-ExtractedLinks $Dest
}

function Copy-ProgramTree([string]$Src, [string]$Dest) {
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
  Copy-Item -LiteralPath $Src -Destination $Dest -Recurse -Force
  Repair-ExtractedLinks $Dest
}

function Get-LatestKiwixAsset([string]$Regex) {
  $html = Invoke-CurlText "$KiwixBase/release/kiwix-tools/"
  $vers = [regex]::Matches($html, $Regex) | ForEach-Object {
    $b = 0; if ($_.Groups[5].Success) { $b = [int]$_.Groups[5].Value }
    [pscustomobject]@{ File = $_.Groups[1].Value; Key = ('{0:D4}{1:D4}{2:D4}{3:D4}' -f [int]$_.Groups[2].Value, [int]$_.Groups[3].Value, [int]$_.Groups[4].Value, $b) }
  }
  return @($vers | Sort-Object Key | Select-Object -Last 1)
}

function Get-OllamaSha([string]$Base, [string]$Asset) {
  $sums = Invoke-CurlText ($Base + 'sha256sum.txt')
  foreach ($line in ($sums -split "`n")) {
    $t = $line.Trim()
    if ($t -match ('^([0-9a-fA-F]{64})\s+\*?\.?/?\.?/?' + [regex]::Escape($Asset) + '\s*$')) { return $Matches[1].ToLower() }
  }
  return ''
}

function Install-KiwixAsset([string]$Dest, [string]$Regex, [string]$Label, [string]$LibcFile) {
  Write-Host "  Library program for $Label..."
  if (Test-TreeFile $Dest @('kiwix-serve.exe', 'kiwix-serve')) { Write-Host '  Already installed.' -ForegroundColor Green; return }
  $k = Get-LatestKiwixAsset $Regex
  if (-not $k -or -not $k.File) { throw "Could not find kiwix-tools for $Label on download.kiwix.org" }
  $rel = "$KiwixBase/release/kiwix-tools/"
  Write-Host "  Downloading $($k.File)"
  $zip = Join-Path $Runtime $k.File
  Save-ResumableFile -Url ($rel + $k.File) -OutFile $zip -Label "Downloading $($k.File)" -MaxTries 20
  $md5 = ((Invoke-CurlText ($rel + $k.File + '.md5')) -split '\s+')[0].Trim().ToLower()
  if ((Get-FileHash -LiteralPath $zip -Algorithm MD5).Hash.ToLower() -ne $md5) {
    Remove-Item -LiteralPath $zip -Force
    throw 'kiwix-tools download was damaged (checksum mismatch). Run setup again.'
  }
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
  Expand-ProgramArchive $zip $Dest
  Remove-Item -LiteralPath $zip -Force
  if ($LibcFile) { Set-Content -LiteralPath $LibcFile -Value "glibc`n" -Encoding ASCII }
  if (-not (Test-TreeFile $Dest @('kiwix-serve.exe', 'kiwix-serve'))) { throw "kiwix-tools for $Label did not unpack as expected." }
  Write-Host '  Installed.' -ForegroundColor Green
}

function Install-OllamaAsset([string]$Dest, [string]$Asset, [string]$Base, [string]$PinnedSha) {
  Write-Host "  AI program ($Asset)..."
  if (Test-TreeFile $Dest @('ollama.exe', 'ollama')) { Write-Host '  Already installed.' -ForegroundColor Green; return }
  $want = Get-OllamaSha $Base $Asset
  if (-not $want -and $Asset.EndsWith('.tgz')) {
    $Asset = $Asset.Substring(0, $Asset.Length - 4) + '.tar.zst'
    Write-Host "  Using $Asset (this release has no .tgz)."
    $want = Get-OllamaSha $Base $Asset
  }
  if (-not $want) { throw 'Could not read the Ollama checksum list.' }
  if ($PinnedSha -and ($want -ne $PinnedSha.ToLower())) { throw "The Ollama checksum online does not match the one built into this kit. Not installing it." }
  $zip = Join-Path $Runtime $Asset
  # A failed unpack leaves this file. Reuse it when the checksum still matches.
  $have = ''
  if (Test-Path -LiteralPath $zip) { $have = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() }
  if ($have -eq $want) {
    Write-Host "  Using the checked download already on the drive: $Asset"
  } else {
    Save-ResumableFile -Url ($Base + $Asset) -OutFile $zip -Label "Downloading Ollama ($Asset)" -MaxTries 20
    if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() -ne $want) {
      Remove-Item -LiteralPath $zip -Force
      throw 'Ollama download was damaged (checksum mismatch). Run setup again.'
    }
  }
  # Unpack beside the platform folder. A failure leaves that folder, and a checked .tar.zst, alone.
  $tmp = Join-Path $Runtime ('_unpack-' + $Asset)
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  Write-Host '  Unpacking...'
  try { Expand-ProgramArchive $zip $tmp }
  catch {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    if ($Asset -like '*.tar.zst' -or $Asset -like '*.zst') { Write-Host "Left the checked download in place: $zip" -ForegroundColor Yellow }
    else { Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue }
    throw
  }
  if (-not (Test-TreeFile $tmp @('ollama.exe', 'ollama'))) {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    if ($Asset -like '*.tar.zst' -or $Asset -like '*.zst') { Write-Host "Left the checked download in place: $zip" -ForegroundColor Yellow }
    else { Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue }
    throw 'Ollama did not unpack as expected.'
  }
  $parent = Split-Path -Parent $Dest
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
  Move-Item -LiteralPath $tmp -Destination $Dest
  Remove-Item -LiteralPath $zip -Force
  Write-Host '  Installed.' -ForegroundColor Green
}

function Install-DarwinOllamaCopies([string]$Channel) {
  $base = 'https://github.com/ollama/ollama/releases/latest/download/'
  $destName = 'ollama'
  $pin = ''
  if ($Channel -eq 'pinned') {
    $base = "https://github.com/ollama/ollama/releases/download/$OllamaPinVersion/"
    $destName = "ollama-$OllamaPinVersion"
    $pin = $OllamaPinSha
  }
  $arm = Join-Path $Runtime "mac-arm64\$destName"
  $intel = Join-Path $Runtime "mac-x64\$destName"
  $armOk = Test-TreeFile $arm @('ollama')
  $intelOk = Test-TreeFile $intel @('ollama')
  if ($armOk -and $intelOk) { Write-Host "  Mac AI program ($destName) already installed for both chips." -ForegroundColor Green; return }
  $asset = 'ollama-darwin.tgz'
  $want = Get-OllamaSha $base $asset
  if (-not $want) { throw 'Could not read the Ollama checksum list for the Mac build.' }
  if ($pin -and ($want -ne $pin.ToLower())) { throw "The Ollama checksum online does not match the one built into this kit. Not installing it." }
  $zip = Join-Path $Runtime "ollama-darwin-$Channel.tgz"
  Save-ResumableFile -Url ($base + $asset) -OutFile $zip -Label "Downloading Ollama for Mac ($asset)" -MaxTries 20
  if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() -ne $want) {
    Remove-Item -LiteralPath $zip -Force
    throw 'Ollama for Mac was damaged (checksum mismatch). Run setup again.'
  }
  $tmp = Join-Path $Runtime "_unpack-darwin-$Channel"
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  Expand-ProgramArchive $zip $tmp
  Remove-Item -LiteralPath $zip -Force
  foreach ($pair in @(@($arm, $armOk), @($intel, $intelOk))) {
    if ($pair[1]) { continue }
    Copy-ProgramTree $tmp $pair[0]
  }
  Remove-Item -LiteralPath $tmp -Recurse -Force
  Write-Host "  Installed the Mac AI program into runtime\mac-arm64 and runtime\mac-x64 ($destName)." -ForegroundColor Green
}

function Install-WindowsPrograms {
  Write-Host '[1/4] Library program (kiwix-tools)...'
  $legacyK = Join-Path $Runtime 'kiwix'
  $destK = Join-Path $Runtime 'windows-x64\kiwix'
  if (Test-TreeFile $destK @('kiwix-serve.exe')) { Write-Host '  Already installed.' -ForegroundColor Green }
  elseif (Test-TreeFile $legacyK @('kiwix-serve.exe')) { Write-Host '  Already installed (older folder runtime\kiwix).' -ForegroundColor Green }
  else {
    Install-KiwixAsset $destK 'href="(kiwix-tools_win-x86_64-(\d+)\.(\d+)\.(\d+)(?:-(\d+))?\.zip)"' 'Windows x64' ''
  }
  Write-Host '[2/4] AI program (Ollama, portable)...'
  if ($UseSystemOllama) { Write-Host "  Using your own Ollama on port $OllamaPort (USE_SYSTEM_OLLAMA) - not downloading one."; return }
  $legacyO = Join-Path $Runtime 'ollama'
  $destO = Join-Path $Runtime 'windows-x64\ollama'
  if (Test-TreeFile $destO @('ollama.exe')) { Write-Host '  Already installed.' -ForegroundColor Green }
  elseif (Test-TreeFile $legacyO @('ollama.exe')) { Write-Host '  Already installed (older folder runtime\ollama).' -ForegroundColor Green }
  else {
    Install-OllamaAsset $destO 'ollama-windows-amd64.zip' 'https://github.com/ollama/ollama/releases/latest/download/' ''
  }
  Resolve-KitRuntime
}

function Install-UniversalPrograms {
  Write-Host 'All computers (universal drive): programs for Windows, Mac and Linux.'
  Write-Host 'Models, Wikipedia, extra libraries and maps stay one shared copy.'
  # One platform failing must not skip the rest, and must not remove folders that already installed.
  $failed = @()
  $rel = 'href="(kiwix-tools_{0}-(\d+)\.(\d+)\.(\d+)(?:-(\d+))?{1})"'
  $ollamaBase = 'https://github.com/ollama/ollama/releases/latest/download/'
  $steps = @(
    @{ Name = 'windows'; Action = { Install-WindowsPrograms } }
    @{ Name = 'mac-arm64/kiwix'; Action = { Install-KiwixAsset (Join-Path $Runtime 'mac-arm64\kiwix') ($rel -f 'macos-arm64', '\.tar\.gz') 'macOS Apple chip' '' } }
    @{ Name = 'mac-x64/kiwix'; Action = { Install-KiwixAsset (Join-Path $Runtime 'mac-x64\kiwix') ($rel -f 'macos-x86_64', '\.tar\.gz') 'macOS Intel' '' } }
    @{ Name = 'linux-x64/kiwix'; Action = { Install-KiwixAsset (Join-Path $Runtime 'linux-x64\kiwix') ($rel -f 'linux-x86_64', '\.tar\.gz') 'Linux 64-bit PC' (Join-Path $Runtime 'linux-x64\LIBC') } }
    @{ Name = 'linux-arm64/kiwix'; Action = { Install-KiwixAsset (Join-Path $Runtime 'linux-arm64\kiwix') ($rel -f 'linux-aarch64', '\.tar\.gz') 'Linux ARM' (Join-Path $Runtime 'linux-arm64\LIBC') } }
    @{ Name = 'mac-ollama'; Action = { Install-DarwinOllamaCopies 'current' } }
    @{ Name = 'mac-ollama-v0.12.9'; Action = { Install-DarwinOllamaCopies 'pinned' } }
    @{ Name = 'linux-x64/ollama'; Action = { Install-OllamaAsset (Join-Path $Runtime 'linux-x64\ollama') 'ollama-linux-amd64.tgz' $ollamaBase '' } }
    @{ Name = 'linux-arm64/ollama'; Action = { Install-OllamaAsset (Join-Path $Runtime 'linux-arm64\ollama') 'ollama-linux-arm64.tgz' $ollamaBase '' } }
  )
  foreach ($step in $steps) {
    try { & $step.Action }
    catch {
      Write-Host $_.Exception.Message -ForegroundColor Red
      $failed += $step.Name
    }
  }
  Resolve-KitRuntime
  if ($failed.Count -gt 0) {
    Write-Host ('Some programs for other computers were not installed: ' + ($failed -join ', ')) -ForegroundColor Red
    Write-Host 'Programs that installed were left in place. Run setup again to finish the rest.'
    Write-Host 'A checked .tar.zst is kept, so a failed Linux download is not fetched again.'
    throw 'Universal program install was incomplete.'
  }
}
