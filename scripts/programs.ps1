# Download Kiwix and Ollama into runtime/<platform>/. Dotted by setup.ps1 after common.ps1.
# One shared library, models and maps. No symlinks: archives are unpacked and any
# link inside them is turned into a real copy (Repair-ExtractedLinks).

function Expand-ProgramArchive([string]$File, [string]$Dest) {
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  if ($File -match '\.zip$') {
    Expand-Archive -LiteralPath $File -DestinationPath $Dest -Force
  } else {
    & tar.exe -xf $File -C $Dest
    if ($LASTEXITCODE -ne 0) { throw "Could not unpack $File" }
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
  Save-ResumableFile -Url ($Base + $Asset) -OutFile $zip -Label "Downloading Ollama ($Asset)" -MaxTries 20
  if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() -ne $want) {
    Remove-Item -LiteralPath $zip -Force
    throw 'Ollama download was damaged (checksum mismatch). Run setup again.'
  }
  if (Test-Path -LiteralPath $Dest) { Remove-Item -LiteralPath $Dest -Recurse -Force }
  Write-Host '  Unpacking...'
  Expand-ProgramArchive $zip $Dest
  Remove-Item -LiteralPath $zip -Force
  if (-not (Test-TreeFile $Dest @('ollama.exe', 'ollama'))) { throw 'Ollama did not unpack as expected.' }
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
  Install-WindowsPrograms
  $rel = 'href="(kiwix-tools_{0}-(\d+)\.(\d+)\.(\d+)(?:-(\d+))?{1})"'
  Install-KiwixAsset (Join-Path $Runtime 'mac-arm64\kiwix') ($rel -f 'macos-arm64', '\.tar\.gz') 'macOS Apple chip' ''
  Install-KiwixAsset (Join-Path $Runtime 'mac-x64\kiwix') ($rel -f 'macos-x86_64', '\.tar\.gz') 'macOS Intel' ''
  Install-KiwixAsset (Join-Path $Runtime 'linux-x64\kiwix') ($rel -f 'linux-x86_64', '\.tar\.gz') 'Linux 64-bit PC' (Join-Path $Runtime 'linux-x64\LIBC')
  Install-KiwixAsset (Join-Path $Runtime 'linux-arm64\kiwix') ($rel -f 'linux-aarch64', '\.tar\.gz') 'Linux ARM' (Join-Path $Runtime 'linux-arm64\LIBC')
  Install-DarwinOllamaCopies 'current'
  Install-DarwinOllamaCopies 'pinned'
  $ollamaBase = 'https://github.com/ollama/ollama/releases/latest/download/'
  Install-OllamaAsset (Join-Path $Runtime 'linux-x64\ollama') 'ollama-linux-amd64.tgz' $ollamaBase ''
  Install-OllamaAsset (Join-Path $Runtime 'linux-arm64\ollama') 'ollama-linux-arm64.tgz' $ollamaBase ''
  Resolve-KitRuntime
}
