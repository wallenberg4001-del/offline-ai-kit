# Shared settings and helpers for the Offline AI Kit.
# Works with Windows PowerShell 5.1 (built into Windows 10/11) and PowerShell 7.
# Everything lives inside the kit folder; nothing is installed system-wide.

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

$script:IsWin = ($env:OS -eq 'Windows_NT')

# ---------- Paths (all relative to the kit folder) ----------
$Kit        = Split-Path -Parent $PSScriptRoot
$Runtime    = Join-Path $Kit 'runtime'
$OllamaDir  = Join-Path $Runtime 'ollama'
$KiwixDir   = Join-Path $Runtime 'kiwix'
$Library    = Join-Path $Kit 'library'
$Checksums  = Join-Path $Library 'checksums'
$VerifiedDir= Join-Path $Checksums 'VERIFIED'
$ModelsDir  = Join-Path $Kit 'ollama-models'
$HomeDir    = Join-Path $Kit 'home'
$LogDir     = Join-Path $Kit 'logs'
$WwwDir     = Join-Path $Kit 'www'
$ConfigFile = Join-Path $Kit 'kit-config.json'

# ---------- Ports (the kit never uses the normal Ollama port 11434) ----------
$SettingsFile = Join-Path $Kit 'kit-settings.ini'

function Read-KitSettings {
  # Optional KEY=VALUE file for power users (see ADVANCED.md). Lines starting with # are comments.
  $h = @{}
  if (Test-Path -LiteralPath $SettingsFile) {
    foreach ($line in Get-Content -LiteralPath $SettingsFile) {
      if ($line -match '^\s*([A-Za-z_]+)\s*=\s*(.*?)\s*$' -and -not $line.TrimStart().StartsWith('#')) { $h[$Matches[1].ToUpper()] = $Matches[2] }
    }
  }
  return $h
}
function Get-Setting([string]$Key, [string]$Default) {
  if ($KitSettings.ContainsKey($Key) -and $KitSettings[$Key] -ne '') { return $KitSettings[$Key] }
  return $Default
}
function Set-KitSetting([string]$Key, [string]$Value) {
  $lines = @()
  if (Test-Path -LiteralPath $SettingsFile) { $lines = @(Get-Content -LiteralPath $SettingsFile) }
  $found = $false
  for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match ('^\s*' + $Key + '\s*=')) { $lines[$i] = "$Key=$Value"; $found = $true } }
  if (-not $found) { $lines += "$Key=$Value" }
  Set-Content -LiteralPath $SettingsFile -Value $lines -Encoding ASCII
  $script:KitSettings[$Key] = $Value
}
$KitSettings = Read-KitSettings
$UseSystemOllama = ((Get-Setting 'USE_SYSTEM_OLLAMA' 'no') -match '^(?i)(yes|true|1)$')
$SkipWikipedia   = ((Get-Setting 'SKIP_WIKIPEDIA' 'no') -match '^(?i)(yes|true|1)$')
$LibraryPort = [int](Get-Setting 'LIBRARY_PORT' '8090')
$defaultOllamaPort = '11435'; if ($UseSystemOllama) { $defaultOllamaPort = '11434' }
$OllamaPort  = [int](Get-Setting 'OLLAMA_PORT' $defaultOllamaPort)
$ChatPort    = [int](Get-Setting 'CHAT_PORT' '8091')
# Share on Wi-Fi (off by default): library + chat page listen on the home network so phones can use them.
# The AI server (Ollama) ALWAYS stays on 127.0.0.1; phones reach it only through the chat page's /ollama/ proxy.
$ShareOnWifi = ((Get-Setting 'SHARE_ON_WIFI' '0') -match '^(?i)(yes|true|1|on)$')
$KitVersion = '0.0.0'
try { $KitVersion = ((Get-Content -LiteralPath (Join-Path $Kit 'VERSION') -ErrorAction Stop | Select-Object -First 1).Trim()) } catch {}
$ExtraCatalogFile = Join-Path $Kit 'catalog\extra-libraries.txt'
$ReleasesApi = 'https://api.github.com/repos/wallenberg4001-del/offline-ai-kit/releases/latest'

$KiwixBase   = 'https://download.kiwix.org'

# ---------- Library catalog ----------
# Prefix = file name without the _YYYY-MM.zim date. The newest dated file is picked at run time.
$ZimCatalog = @(
  @{ Id='knots';         Dir='zim/other';          Prefix='zimgit-knots_en';                     Tier='essentials';  About='Knots (how to tie them)' }
  @{ Id='medicine';      Dir='zim/other';          Prefix='zimgit-medicine_en';                  Tier='essentials';  About='Medicine survival guides' }
  @{ Id='food';          Dir='zim/other';          Prefix='zimgit-food-preparation_en';          Tier='essentials';  About='Food preparation and preserving' }
  @{ Id='water';         Dir='zim/other';          Prefix='zimgit-water_en';                     Tier='essentials';  About='Water: finding, cleaning, storing' }
  @{ Id='postdisaster';  Dir='zim/other';          Prefix='zimgit-post-disaster_en';             Tier='essentials';  About='Post-disaster survival library' }
  @{ Id='usda';          Dir='zim/other';          Prefix='usda-2015_en';                        Tier='essentials';  About='USDA home canning / food safety' }
  @{ Id='appropedia';    Dir='zim/other';          Prefix='appropedia_en_all_maxi';              Tier='essentials';  About='Appropedia: low-tech and sustainable how-tos' }
  @{ Id='mdwiki';        Dir='zim/other';          Prefix='mdwiki_en_all_maxi';                  Tier='essentials';  About='WikiMed (mdwiki): medical encyclopedia' }
  @{ Id='wpmed';         Dir='zim/wikipedia';      Prefix='wikipedia_en_medicine_maxi';          Tier='recommended'; About='Wikipedia medicine articles' }
  @{ Id='wikivoyage';    Dir='zim/wikivoyage';     Prefix='wikivoyage_en_all_maxi';              Tier='recommended'; About='Wikivoyage travel guide' }
  @{ Id='gardening';     Dir='zim/stack_exchange'; Prefix='gardening.stackexchange.com_en_all';  Tier='recommended'; About='Gardening Q&A' }
  @{ Id='ifixit';        Dir='zim/ifixit';         Prefix='ifixit_en_all';                       Tier='recommended'; About='iFixit repair guides' }
  @{ Id='wikipedia';     Dir='zim/wikipedia';      Prefix='wikipedia_en_all_maxi';               Tier='always';      About='FULL English Wikipedia with pictures (~127 GB)' }
)
$WikipediaPrefix = 'wikipedia_en_all_maxi'

# ---------- AI models (checked against the Ollama library at setup time) ----------
# Sized for a 12 GB VRAM laptop GPU (RTX 5070 Ti Laptop). Sizes are download sizes.
$ModelCatalog = @(
  @{ Name='qwen3.5:9b';   GB=6.6; Set='core'; Hint='Best all-rounder (default)' }
  @{ Name='llama3.2:3b';  GB=2.0; Set='lite'; Hint='Fastest / battery saver' }
  @{ Name='phi4-mini';    GB=2.5; Set='core'; Hint='Small and practical' }
  @{ Name='medgemma:4b';  GB=3.3; Set='lite'; Hint='Medical-tuned (still check the library)' }
  @{ Name='gemma3:4b';    GB=3.3; Set='full'; Hint='Light, can read photos' }
  @{ Name='gemma3:12b';   GB=8.2; Set='full'; Hint='Stronger answers, can read photos' }
  @{ Name='qwen3:14b';    GB=9.3; Set='full'; Hint='Strongest; uses most of the GPU' }
)
# lite = 2 small models; core = lite + 2 more; full = everything.
function Get-ModelsForSet([string]$Set) {
  $rank = @{ lite=1; core=2; full=3 }
  $want = $rank[$Set]; if (-not $want) { $want = 3 }
  return @($ModelCatalog | Where-Object { $rank[$_.Set] -le $want })
}

# Hardware profiles used by EASY-INSTALL (and suggested by SETUP).
#   LITE     - no NVIDIA GPU, under 16 GB RAM, or small disk: Essentials library + lite models
#   STANDARD - NVIDIA GPU with under 12 GB: Recommended library + core models
#   FULL     - NVIDIA GPU with 12 GB or more: Recommended library + all models
$Profiles = [ordered]@{
  full     = @{ Tier='recommended'; Models='full'; LibGB=11.2; Label='FULL (strong NVIDIA GPU)' }
  standard = @{ Tier='recommended'; Models='core'; LibGB=11.2; Label='STANDARD (NVIDIA GPU)' }
  lite     = @{ Tier='essentials';  Models='lite'; LibGB=3.8;  Label='LITE (lighter computer)' }
}
$WikipediaGB = 127.4

# ---------- Test mode (for trying the kit quickly) ----------
# OFFLINE_AI_TEST=1 (env), -Test (setup) or TEST_MODE=yes (kit-settings.ini):
#   tiny library (3 files), one small model, and a 13 MB Wikipedia stand-in
#   (wikipedia_en_knots_maxi) so the background download / verify / library restart is exercised.
# OFFLINE_AI_SKIP_WIKIPEDIA=1 (env) skips Wikipedia entirely.
$TestMode = (($env:OFFLINE_AI_TEST -match '^(?i)(1|yes|true)$') -or ((Get-Setting 'TEST_MODE' 'no') -match '^(?i)(yes|true|1)$'))
if ($env:OFFLINE_AI_SKIP_WIKIPEDIA -match '^(?i)(1|yes|true)$') { $SkipWikipedia = $true }
function Enable-TestMode {
  $script:TestMode = $true
  $script:WikipediaPrefix = 'wikipedia_en_knots_maxi'
  $script:WikipediaGB = 0.02
  foreach ($e in $ZimCatalog) { if ($e.Id -eq 'wikipedia') { $e.Prefix = 'wikipedia_en_knots_maxi'; $e.About = 'TEST stand-in for full Wikipedia (13 MB)' } }
  # Small searchable medical stand-in (~170 MB) so 'Ask the library' can be tested with a first-aid question.
  foreach ($e in $ZimCatalog) { if ($e.Id -eq 'wpmed') { $e.Prefix = 'wikipedia_en_medicine_mini'; $e.About = 'TEST stand-in for Wikipedia medicine (intros only, ~170 MB)' } }
}
if ($TestMode) { Enable-TestMode }
$ProgramsGB  = 2.5

function Get-ProfileNeedGB([string]$Name) {
  $p = $Profiles[$Name]; $gb = $ProgramsGB + $p.LibGB
  foreach ($m in (Get-ModelsForSet $p.Models)) { $gb += $m.GB }
  return [math]::Round($gb, 1)
}

function Get-Hardware {
  $ram = 0; $gpu = ''; $vram = 0
  try { $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory / 1GB) } catch {}
  $smi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
  $smiPath = $null
  if ($smi) { $smiPath = $smi.Source } elseif ($script:IsWin -and (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'))) { $smiPath = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe' }
  if ($smiPath) {
    try {
      $line = (& $smiPath --query-gpu=name,memory.total --format=csv,noheader,nounits 2>$null | Select-Object -First 1)
      if ($line) { $parts = $line.Split(','); $gpu = $parts[0].Trim(); $vram = [math]::Round([double]$parts[1].Trim() / 1024, 1) }
    } catch {}
  }
  if (-not $gpu) {
    try {
      $vc = Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.Name -match 'NVIDIA' } | Select-Object -First 1
      if ($vc) { $gpu = $vc.Name; $vram = 0 }   # AdapterRAM is unreliable above 4 GB, so treat as unknown
    } catch {}
  }
  $free = [math]::Round((Get-FreeBytes $Kit) / 1e9, 1)
  return [pscustomobject]@{ RamGB=$ram; Gpu=$gpu; VramGB=$vram; FreeGB=$free }
}

function Get-HardwareProfile($Hw) {
  if (-not $Hw.Gpu -or ($Hw.RamGB -gt 0 -and $Hw.RamGB -lt 16)) { return 'lite' }
  if ($Hw.VramGB -ge 11.5) { return 'full' }
  return 'standard'
}

function Select-ProfileForDisk([string]$Preferred, [double]$FreeGB) {
  # Prefer keeping Wikipedia: try each profile (biggest first) with Wikipedia, then without.
  $names = @($Profiles.Keys)
  $start = [array]::IndexOf($names, $Preferred)
  foreach ($withWiki in @($true, $false)) {
    for ($i = $start; $i -lt $names.Count; $i++) {
      $need = Get-ProfileNeedGB $names[$i]
      if ($withWiki) { $need += $WikipediaGB + 12 }
      if ($FreeGB -ge $need) { return [pscustomobject]@{ Profile=$names[$i]; Wikipedia=$withWiki; NeedGB=$need } }
    }
  }
  return $null
}

# ---------- Helpers ----------
function Ensure-Dirs {
  foreach ($d in @($Runtime,$OllamaDir,$KiwixDir,$Library,$Checksums,$VerifiedDir,$ModelsDir,$HomeDir,$LogDir)) {
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
  }
}

function Write-Log([string]$File, [string]$Text) {
  $line = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $Text
  try { Add-Content -LiteralPath (Join-Path $LogDir $File) -Value $line } catch {}
}

function Get-CurlExe {
  if ($script:IsWin) {
    $c = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path -LiteralPath $c) { return $c }
  }
  $cmd = Get-Command curl.exe -ErrorAction SilentlyContinue
  if (-not $cmd) { $cmd = Get-Command curl -CommandType Application -ErrorAction SilentlyContinue }
  if ($cmd) { return ($cmd | Select-Object -First 1).Source }
  throw 'curl.exe was not found. It is built into Windows 10 (1803+) and Windows 11. Please update Windows.'
}

function Invoke-CurlText([string]$Url) {
  $curl = Get-CurlExe
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'   # see setup.ps1: stderr + redirection
  $out = & $curl -sSL --fail --retry 3 --connect-timeout 20 $Url 2>&1 | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
  $code = $LASTEXITCODE; $ErrorActionPreference = $eap
  if ($code -ne 0) { throw "Could not read $Url (curl exit $code)" }
  return ($out -join "`n")
}

function Get-RemoteSize([string]$Url) {
  # Follows Kiwix mirror redirects and returns the final Content-Length (bytes), or 0.
  $curl = Get-CurlExe
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $hdr = & $curl -sSIL --retry 3 --connect-timeout 20 $Url 2>&1 | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
  $ErrorActionPreference = $eap
  $size = [int64]0
  foreach ($l in $hdr) {
    if ($l -match '^(?i)content-length:\s*(\d+)') { $size = [int64]$Matches[1] }
  }
  return $size
}

function Resolve-LatestZim($Entry) {
  # Reads the Kiwix folder listing and returns the newest file for this prefix.
  $dirUrl = "$KiwixBase/$($Entry.Dir)/"
  $html = Invoke-CurlText $dirUrl
  $pattern = 'href="(' + [regex]::Escape($Entry.Prefix) + '_(\d{4}-\d{2})\.zim)"'
  $found = [regex]::Matches($html, $pattern) | ForEach-Object { [pscustomobject]@{ File=$_.Groups[1].Value; Date=$_.Groups[2].Value } }
  if (-not $found) { throw "No file found for $($Entry.Prefix) in $dirUrl" }
  $latest = $found | Sort-Object Date | Select-Object -Last 1
  return [pscustomobject]@{
    Id     = $Entry.Id
    File   = $latest.File
    Url    = "$dirUrl$($latest.File)"
    ShaUrl = "$dirUrl$($latest.File).sha256"
    About  = $Entry.About
  }
}

function Get-ExpectedSha([string]$ShaUrl) {
  $t = Invoke-CurlText $ShaUrl
  if ($t -match '([0-9a-fA-F]{64})') { return $Matches[1].ToLower() }
  throw "Checksum file at $ShaUrl did not contain a SHA256."
}

function Test-ZimVerified([string]$File) {
  return (Test-Path -LiteralPath (Join-Path $VerifiedDir $File)) -and (Test-Path -LiteralPath (Join-Path $Library $File))
}

function Get-VerifiedZims {
  if (-not (Test-Path -LiteralPath $VerifiedDir)) { return @() }
  $list = @()
  foreach ($m in Get-ChildItem -LiteralPath $VerifiedDir -File) {
    $z = Join-Path $Library $m.Name
    if ($m.Name -like '*.zim' -and (Test-Path -LiteralPath $z)) { $list += $z }
  }
  return $list
}

function Get-FreeBytes([string]$Path) {
  $root = [System.IO.Path]::GetPathRoot((Resolve-Path -LiteralPath $Path).Path)
  return ([System.IO.DriveInfo]::new($root)).AvailableFreeSpace
}

function Format-GB([double]$Bytes) { if ($Bytes -lt 1e9) { return ('{0:N0} MB' -f ($Bytes / 1e6)) }; return ('{0:N1} GB' -f ($Bytes / 1e9)) }

# Big Kiwix files: download.kiwix.org sends each request to a random mirror, and some mirrors
# crawl at 0.2 MB/s (that would be 5+ days for Wikipedia). For big files we quickly time a few
# well-known mirrors and use the fastest. Safe: the SHA256 always comes from download.kiwix.org.
$KiwixMirrors = @($KiwixBase, 'https://mirrors.dotsrc.org/kiwix', 'https://ftp.fau.de/kiwix', 'https://mirror.accum.se/mirror/kiwix.org')

function Select-FastestUrl([string]$Url) {
  # Returns @{ Url; Speed } for the fastest mirror that has the same file (falls back to Url).
  if (-not $Url.StartsWith($KiwixBase + '/')) { return @{ Url = $Url; Speed = 0 } }
  $path = $Url.Substring($KiwixBase.Length)
  $curl = Get-CurlExe
  $best = @{ Url = $Url; Speed = 0 }
  Write-Host '  Finding the fastest download server...'
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  foreach ($m in $KiwixMirrors) {
    $u = $m + $path
    $r = & $curl -s -L -o NUL --connect-timeout 5 --max-time 6 -r 0-300000000 -w '%{http_code} %{speed_download}' $u 2>$null
    $parts = "$r" -split ' '
    if ($parts.Count -ge 2 -and $parts[0] -eq '206') {
      $sp = [double]::Parse($parts[1], [Globalization.CultureInfo]::InvariantCulture)
      if ($sp -gt $best.Speed) { $best = @{ Url = $u; Speed = $sp } }
    }
  }
  $ErrorActionPreference = $eap
  if ($best.Speed -gt 0) { Write-Host ('  Using {0} ({1:N1} MB/s in a quick test)' -f ([uri]$best.Url).Host, ($best.Speed / 1e6)) }
  return $best
}

function Save-ResumableFile {
  # Downloads Url to OutFile with resume support (curl -C -), retrying on failure.
  # Progress is shown in the window and optionally written to a JSON progress file.
  param([string]$Url, [string]$OutFile, [int64]$ExpectedSize = 0, [string]$ProgressFile = '', [string]$Label = '', [int]$MaxTries = 1000)
  $curl = Get-CurlExe
  $part = "$OutFile.part"
  if (-not $Label) { $Label = Split-Path -Leaf $OutFile }
  if ($ExpectedSize -le 0) { $ExpectedSize = Get-RemoteSize $Url }
  $try = 0
  while ($true) {
    $have = [int64]0
    if (Test-Path -LiteralPath $part) { $have = (Get-Item -LiteralPath $part).Length }
    if ($ExpectedSize -gt 0 -and $have -eq $ExpectedSize) { break }
    if ($ExpectedSize -gt 0 -and $have -gt $ExpectedSize) { Remove-Item -LiteralPath $part -Force; $have = 0 }
    $try++
    if ($try -gt $MaxTries) { throw "Gave up downloading $Label after $MaxTries tries." }
    $src = @{ Url = $Url; Speed = 0 }
    if ($ExpectedSize -gt 500MB) { $src = Select-FastestUrl $Url }
    $argList = @('-sS','-L','--fail','--retry','5','--retry-delay','10','--connect-timeout','30','--speed-limit','1000','--speed-time','120','-C','-','-o',('"' + $part + '"'),('"' + $src.Url + '"'))
    $p = Start-Process -FilePath $curl -ArgumentList $argList -NoNewWindow -PassThru
    $null = $p.Handle   # Windows PowerShell only reports ExitCode if the handle is opened right away
    $lastBytes = $have; $lastTime = Get-Date; $speed = 0; $slowSince = $null; $switched = $false
    while (-not $p.HasExited) {
      Start-Sleep -Seconds 2
      $now = [int64]0
      if (Test-Path -LiteralPath $part) { $now = (Get-Item -LiteralPath $part).Length }
      $dt = ((Get-Date) - $lastTime).TotalSeconds
      if ($dt -ge 5) { $speed = ($now - $lastBytes) / $dt; $lastBytes = $now; $lastTime = Get-Date }
      # If the server slows to under a quarter of its tested speed for 3 minutes, pick a server again.
      if ($src.Speed -gt 0 -and $speed -gt 0 -and $speed -lt ($src.Speed / 4)) { if (-not $slowSince) { $slowSince = Get-Date } } else { $slowSince = $null }
      if ($slowSince -and ((Get-Date) - $slowSince).TotalSeconds -ge 180) {
        Write-Host ''; Write-Host '  This server got slow - switching to a faster one...' -ForegroundColor Yellow
        try { $p.Kill() } catch {}; $p.WaitForExit(); $switched = $true; break
      }
      Show-DownloadProgress -Label $Label -Have $now -Total $ExpectedSize -Speed $speed -ProgressFile $ProgressFile -State 'downloading'
    }
    $p.WaitForExit()
    $code = $p.ExitCode
    $have = [int64]0
    if (Test-Path -LiteralPath $part) { $have = (Get-Item -LiteralPath $part).Length }
    if ($code -eq 0 -and ($ExpectedSize -le 0 -or $have -eq $ExpectedSize)) { break }
    if ($switched) { $try--; continue }
    Write-Host ''
    Write-Host "  Connection problem (curl code $code). Will resume in 30 seconds... (try $try)" -ForegroundColor Yellow
    Show-DownloadProgress -Label $Label -Have $have -Total $ExpectedSize -Speed 0 -ProgressFile $ProgressFile -State 'waiting-for-internet'
    Start-Sleep -Seconds 30
  }
  Write-Progress -Activity $Label -Completed
  if (Test-Path -LiteralPath $OutFile) { Remove-Item -LiteralPath $OutFile -Force }
  Move-Item -LiteralPath $part -Destination $OutFile
}

function Show-DownloadProgress([string]$Label, [int64]$Have, [int64]$Total, [double]$Speed, [string]$ProgressFile, [string]$State) {
  $pct = 0
  if ($Total -gt 0) { $pct = [math]::Round(100.0 * $Have / $Total, 1) }
  $eta = ''
  if ($Speed -gt 0 -and $Total -gt 0) {
    $secs = ($Total - $Have) / $Speed
    $ts = [TimeSpan]::FromSeconds([math]::Min($secs, 8640000))
    if ($ts.TotalDays -ge 1) { $left = '{0} d {1} h' -f [int][math]::Floor($ts.TotalDays), $ts.Hours }
    elseif ($ts.TotalHours -ge 1) { $left = '{0} h {1} min' -f $ts.Hours, $ts.Minutes }
    else { $left = '{0} min' -f [math]::Max(1, [int][math]::Ceiling($ts.TotalMinutes)) }
    $eta = " - about $left left"
  }
  $status = ('{0} of {1} ({2}%) at {3:N1} MB/s{4}' -f (Format-GB $Have), (Format-GB $Total), $pct, ($Speed/1e6), $eta)
  $pc = [int][math]::Min(100, [math]::Max(0, $pct))
  Write-Progress -Activity $Label -Status $status -PercentComplete $pc
  if ($ProgressFile) { Write-ProgressFile -ProgressFile $ProgressFile -State $State -Have $Have -Total $Total -Percent $pct -Speed $Speed -Message $status }
}

function Write-ProgressFile([string]$ProgressFile, [string]$State, [int64]$Have = 0, [int64]$Total = 0, [double]$Percent = 0, [double]$Speed = 0, [string]$Message = '') {
  $o = [ordered]@{ state=$State; bytes=$Have; total=$Total; percent=$Percent; mbps=[math]::Round($Speed/1e6,1); message=$Message; updated=(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') }
  try { ($o | ConvertTo-Json -Compress) | Set-Content -LiteralPath $ProgressFile -Encoding UTF8 } catch {}
}

function Confirm-FileSha([string]$File, [string]$Expected, [string]$ProgressFile = '') {
  Write-Host "  Checking the file is complete and undamaged (SHA256). Big files take a while..."
  if ($ProgressFile) { Write-ProgressFile -ProgressFile $ProgressFile -State 'verifying' -Message 'Checking SHA256 (this can take 10-30 minutes for Wikipedia)' }
  $got = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLower()
  return ($got -eq $Expected.ToLower())
}

function Get-Zim {
  # Download + verify one resolved ZIM. Returns $true when verified.
  param($Z, [string]$ProgressFile = '')
  if (Test-ZimVerified $Z.File) { Write-Host "  Already verified: $($Z.File)" -ForegroundColor Green; return $true }
  $dest = Join-Path $Library $Z.File
  $sha  = Get-ExpectedSha $Z.ShaUrl
  if (-not (Test-Path -LiteralPath $dest)) {
    Save-ResumableFile -Url $Z.Url -OutFile $dest -ProgressFile $ProgressFile -Label ("Downloading " + $Z.File)
  }
  if (Confirm-FileSha -File $dest -Expected $sha -ProgressFile $ProgressFile) {
    Set-Content -LiteralPath (Join-Path $VerifiedDir $Z.File) -Value $sha
    Write-Log 'zim-downloads.log' "VERIFIED $($Z.File) $sha"
    Write-Host "  Verified: $($Z.File)" -ForegroundColor Green
    return $true
  } else {
    Write-Log 'zim-downloads.log' "SHA256_MISMATCH $($Z.File) - deleted"
    Write-Host "  The file was damaged in transit and has been deleted: $($Z.File). Run again to re-download." -ForegroundColor Red
    Remove-Item -LiteralPath $dest -Force
    return $false
  }
}

function Test-Port([int]$Port) {
  $c = New-Object System.Net.Sockets.TcpClient
  try {
    $ar = $c.BeginConnect('127.0.0.1', $Port, $null, $null)
    $ok = $ar.AsyncWaitHandle.WaitOne(700)
    if ($ok) { $c.EndConnect($ar); return $true }
    return $false
  } catch { return $false } finally { $c.Close() }
}

function Get-PidFile([string]$Name) { return (Join-Path $LogDir "$Name.pid") }

function Get-KitProcess([string]$Name) {
  $pf = Get-PidFile $Name
  if (-not (Test-Path -LiteralPath $pf)) { return $null }
  $procId = 0
  [int]::TryParse(((Get-Content -LiteralPath $pf -ErrorAction SilentlyContinue) | Select-Object -First 1), [ref]$procId) | Out-Null
  if ($procId -le 0) { return $null }
  $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
  if (-not $p) { return $null }
  # Guard against Windows re-using the PID for an unrelated program.
  $expected = @{ 'kiwix'=@('kiwix-serve'); 'ollama'=@('ollama'); 'chat-server'=@('powershell','pwsh'); 'wikipedia-download'=@('powershell','pwsh') }
  if ($expected.ContainsKey($Name) -and ($expected[$Name] -notcontains $p.ProcessName.ToLower())) { return $null }
  return $p
}

function Stop-KitProcess([string]$Name) {
  $p = Get-KitProcess $Name
  if ($p) {
    if ($script:IsWin) { & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null } else { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
    Write-Host "  Stopped $Name (pid $($p.Id))"
  }
  Remove-Item -LiteralPath (Get-PidFile $Name) -Force -ErrorAction SilentlyContinue
}

function Get-OllamaExe {
  $exe = Get-ChildItem -LiteralPath $OllamaDir -Recurse -Filter 'ollama.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($exe) { return $exe.FullName }
  return $null
}

function Get-KiwixServeExe {
  $exe = Get-ChildItem -LiteralPath $KiwixDir -Recurse -Filter 'kiwix-serve.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($exe) { return $exe.FullName }
  return $null
}

function Start-KitOllama {
  if (Test-Port $OllamaPort) { Write-Host "  AI model server already running on port $OllamaPort."; return $true }
  if ($UseSystemOllama) { Write-Host "  USE_SYSTEM_OLLAMA is on, but nothing answers on port $OllamaPort. Start your Ollama app first." -ForegroundColor Yellow; return $false }
  $exe = Get-OllamaExe
  if (-not $exe) { Write-Host "  Ollama is missing. Run SETUP.bat first." -ForegroundColor Red; return $false }
  Ensure-Dirs
  # Environment for the kit's own Ollama only (child process inherits it).
  $saved = @{ OLLAMA_HOST=$env:OLLAMA_HOST; OLLAMA_MODELS=$env:OLLAMA_MODELS; OLLAMA_ORIGINS=$env:OLLAMA_ORIGINS; USERPROFILE=$env:USERPROFILE; HOME=$env:HOME; OLLAMA_KEEP_ALIVE=$env:OLLAMA_KEEP_ALIVE }
  $env:OLLAMA_HOST    = "127.0.0.1:$OllamaPort"
  $env:OLLAMA_MODELS  = $ModelsDir
  # '*' (not 'null') so the page also works if opened as a file; a bad origin entry makes Ollama refuse to start.
  $env:OLLAMA_ORIGINS = '*'
  $env:OLLAMA_KEEP_ALIVE = '10m'
  $env:USERPROFILE    = $HomeDir
  $env:HOME           = $HomeDir
  try {
    $p = Start-Process -FilePath $exe -ArgumentList 'serve' -WindowStyle Hidden -PassThru `
         -RedirectStandardOutput (Join-Path $LogDir 'ollama.out.log') -RedirectStandardError (Join-Path $LogDir 'ollama.log')
    Set-Content -LiteralPath (Get-PidFile 'ollama') -Value $p.Id
  } finally {
    foreach ($k in $saved.Keys) { Set-Item -Path "env:$k" -Value $saved[$k] -ErrorAction SilentlyContinue; if ($null -eq $saved[$k]) { Remove-Item "env:$k" -ErrorAction SilentlyContinue } }
  }
  for ($i = 0; $i -lt 40; $i++) { if (Test-Port $OllamaPort) { return $true }; Start-Sleep -Milliseconds 500 }
  Write-Host "  The AI server did not answer yet. See logs\ollama.log" -ForegroundColor Yellow
  return $false
}

function Start-KitKiwix {
  # (Re)starts kiwix-serve with every verified ZIM.
  Stop-KitProcess 'kiwix'
  $exe = Get-KiwixServeExe
  if (-not $exe) { Write-Host "  Kiwix is missing. Run SETUP.bat first." -ForegroundColor Red; return $false }
  $zims = @(Get-VerifiedZims)
  if ($zims.Count -eq 0) { Write-Host "  No verified library files yet - the library will be empty." -ForegroundColor Yellow; return $false }
  for ($i = 0; $i -lt 10 -and (Test-Port $LibraryPort); $i++) { Start-Sleep -Milliseconds 500 }
  if (Test-Port $LibraryPort) { Write-Host "  Port $LibraryPort is used by another program; the library cannot start." -ForegroundColor Red; return $false }
  $addr = '127.0.0.1'; if ($ShareOnWifi) { $addr = '0.0.0.0' }
  $argStr = "--address=$addr --port=$LibraryPort " + (($zims | ForEach-Object { '"' + $_ + '"' }) -join ' ')
  $p = Start-Process -FilePath $exe -ArgumentList $argStr -WindowStyle Hidden -PassThru `
       -RedirectStandardOutput (Join-Path $LogDir 'kiwix.out.log') -RedirectStandardError (Join-Path $LogDir 'kiwix.log')
  Set-Content -LiteralPath (Get-PidFile 'kiwix') -Value $p.Id
  for ($i = 0; $i -lt 30; $i++) { if (Test-Port $LibraryPort) { Write-Host "  Library is serving $($zims.Count) collection(s)."; return $true }; Start-Sleep -Milliseconds 500 }
  Write-Host "  The library did not answer yet. See logs\kiwix.log" -ForegroundColor Yellow
  return $false
}

function Get-KitConfig {
  if (Test-Path -LiteralPath $ConfigFile) { return (Get-Content -LiteralPath $ConfigFile -Raw | ConvertFrom-Json) }
  return $null
}

function Write-ChatConfig {
  # Tells the chat page which ports to use (read by www/chat.html).
  $share = 'false'; $lan = ''
  if ($ShareOnWifi) { $share = 'true'; $ip = Get-LanIp; if ($ip) { $lan = "http://${ip}:$ChatPort/" } }
  $js = "window.KIT_CONFIG = { ollamaPort: $OllamaPort, libraryPort: $LibraryPort, chatPort: $ChatPort, shareOnWifi: $share, lanUrl: `"$lan`", version: `"$KitVersion`" };"
  try { Set-Content -LiteralPath (Join-Path $WwwDir 'kit-config.js') -Value $js -Encoding ASCII } catch {}
}

function New-DesktopShortcut {
  try {
    $desk = [Environment]::GetFolderPath('Desktop')
    $ws = New-Object -ComObject WScript.Shell
    $lnk = $ws.CreateShortcut((Join-Path $desk 'Offline AI.lnk'))
    $lnk.TargetPath = Join-Path $Kit 'START-OFFLINE-AI.bat'
    $lnk.WorkingDirectory = $Kit
    $lnk.Description = 'Start the Offline AI Kit'
    $lnk.IconLocation = "$env:SystemRoot\System32\shell32.dll,13"
    $lnk.Save()
    Write-Host "  Put an 'Offline AI' shortcut on the Desktop." -ForegroundColor Green
  } catch { Write-Host '  Could not create the Desktop shortcut (not a problem; use START-OFFLINE-AI.bat).' -ForegroundColor Yellow }
}

# ---------- Share on Wi-Fi ----------
function Get-LanIp {
  # The address phones on the same Wi-Fi use to reach this computer (IPv4), or '' if none.
  # 1) Ask Windows which local address it would use for the default route (no packet is sent).
  try {
    $s = New-Object System.Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Dgram, [Net.Sockets.ProtocolType]::Udp)
    try { $s.Connect('8.8.8.8', 53); $ip = $s.LocalEndPoint.Address.ToString() } finally { $s.Close() }
    if ($ip -and $ip -notmatch '^(127\.|169\.254\.|0\.)') { return $ip }
  } catch {}
  # 2) No internet route (outage, router still on): pick a private address on an adapter that is up.
  try {
    $cands = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object {
      $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)' -and $_.InterfaceAlias -notmatch 'vEthernet|WSL|Hyper-V|VirtualBox|VMware|Tailscale|Loopback' }
    $c = $cands | Sort-Object { if ($_.IPAddress -like '192.168.*') { 0 } else { 1 } } | Select-Object -First 1
    if ($c) { return $c.IPAddress }
  } catch {}
  return ''
}

function Get-ShareUrls {
  $ip = Get-LanIp
  if (-not $ip) { return $null }
  return [pscustomobject]@{ Ip = $ip; Chat = "http://${ip}:$ChatPort/"; Library = "http://${ip}:$LibraryPort/" }
}

function Write-WifiWarning {
  Write-Host '  Only use this at home on Wi-Fi you trust - never on public Wi-Fi (cafes, hotels, airports).' -ForegroundColor Yellow
  Write-Host '  Anyone on the same Wi-Fi can open the chat and the library. The AI server itself stays private.' -ForegroundColor Yellow
}

function Start-ChatServer {
  # Starts the chat page web server (scripts\serve-chat.ps1): 127.0.0.1 only, or the home network when sharing.
  if (Test-Port $ChatPort) {
    if (Get-KitProcess 'chat-server') { Write-Host '  Chat page already running.'; return $true }
    Write-Host "  Port $ChatPort is used by another program; the chat page will open as a file instead." -ForegroundColor Yellow
    return $false
  }
  $ps = Join-Path $PSHOME 'powershell.exe'
  if (-not (Test-Path -LiteralPath $ps)) { $ps = (Get-Process -Id $PID).Path }
  $srv = Join-Path $PSScriptRoot 'serve-chat.ps1'
  $bind = 'local'; if ($ShareOnWifi) { $bind = 'any' }
  $p = Start-Process -FilePath $ps -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + $srv + '"'),'-Bind',$bind) -WindowStyle Hidden -PassThru
  Set-Content -LiteralPath (Get-PidFile 'chat-server') -Value $p.Id
  for ($i = 0; $i -lt 30 -and -not (Test-Port $ChatPort); $i++) { Start-Sleep -Milliseconds 300 }
  return (Test-Port $ChatPort)
}

function Set-ShareOnWifi([bool]$On, [switch]$Apply) {
  # Saves SHARE_ON_WIFI in kit-settings.ini; with -Apply, restarts the library and chat page if the kit is running.
  if ($On) { Set-KitSetting 'SHARE_ON_WIFI' '1' } else { Set-KitSetting 'SHARE_ON_WIFI' '0' }
  $script:ShareOnWifi = $On
  if (-not $Apply) { return }
  $running = (Get-KitProcess 'kiwix') -or (Get-KitProcess 'chat-server')
  if (-not $running) { Write-Host '  The kit is not running; this applies the next time you start it.'; return }
  Write-Host '  Restarting the library and chat page...'
  Write-ChatConfig
  Start-KitKiwix | Out-Null
  Stop-KitProcess 'chat-server'
  for ($i = 0; $i -lt 20 -and (Test-Port $ChatPort); $i++) { Start-Sleep -Milliseconds 250 }
  Start-ChatServer | Out-Null
}

function Show-ShareStatus {
  if ($ShareOnWifi) {
    $u = Get-ShareUrls
    Write-Host '  Share on Wi-Fi: ON' -ForegroundColor Green
    if ($u) { Write-Host "    Phones and tablets on the same Wi-Fi open:  $($u.Chat)" -ForegroundColor Green; Write-Host '    (the chat page also shows a QR code to scan)' }
    else { Write-Host '    No home network found right now (is Wi-Fi or Ethernet connected?).' -ForegroundColor Yellow }
    Write-Host '    If a phone cannot connect: when Windows asks, allow "Windows PowerShell" and "kiwix-serve" on Private networks,'
    Write-Host '    and make sure your home Wi-Fi is set to "Private" (Settings > Network & internet > your network).'
    Write-WifiWarning
  } else {
    Write-Host '  Share on Wi-Fi: off (only this computer can use the kit)'
  }
}

# ---------- Extra Libraries (catalog\extra-libraries.txt) ----------
function Get-ExtraCatalog {
  $list = @()
  if (-not (Test-Path -LiteralPath $ExtraCatalogFile)) { return $list }
  foreach ($line in Get-Content -LiteralPath $ExtraCatalogFile) {
    $t = $line.Trim(); if (-not $t -or $t.StartsWith('#')) { continue }
    $f = $t.Split('|'); if ($f.Count -lt 6) { continue }
    $list += [pscustomobject]@{ Id=$f[0].Trim(); Dir=$f[1].Trim(); Prefix=$f[2].Trim(); GB=[double]::Parse($f[3].Trim(), [Globalization.CultureInfo]::InvariantCulture); Group=$f[4].Trim(); About=$f[5].Trim() }
  }
  return $list
}

function Get-ExtraInstalled($Entry) {
  # Returns the verified file name for this collection (any edition), or $null.
  if (-not (Test-Path -LiteralPath $VerifiedDir)) { return $null }
  $re = '^' + [regex]::Escape($Entry.Prefix) + '_\d{4}-\d{2}\.zim$'
  $m = Get-ChildItem -LiteralPath $VerifiedDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $re -and (Test-Path -LiteralPath (Join-Path $Library $_.Name)) } | Select-Object -First 1
  if ($m) { return $m.Name }
  return $null
}

function Format-Size([double]$GB) { if ($GB -lt 1) { return ('{0:N0} MB' -f ($GB * 1000)) }; return ('{0:N1} GB' -f $GB) }

function Resolve-ExtraIds([string]$Text, $Catalog) {
  # "1,3" / "se-diy,wiktionary" / "all" / "" -> matching catalog entries (numbers follow the list order).
  $out = @()
  if (-not $Text) { return $out }
  foreach ($tok in ($Text -split '[,\s]+')) {
    $t = $tok.Trim().ToLower(); if (-not $t) { continue }
    if ($t -eq 'all') { return @($Catalog | Where-Object { $_.Id -ne 'gutenberg-all' }) }
    $n = 0
    if ([int]::TryParse($t, [ref]$n)) { if ($n -ge 1 -and $n -le $Catalog.Count) { $out += $Catalog[$n - 1] } else { Write-Host "  (No number $t in the list - skipped)" -ForegroundColor Yellow } }
    else { $e = $Catalog | Where-Object { $_.Id -eq $t } | Select-Object -First 1; if ($e) { $out += $e } else { Write-Host "  (Unknown library '$t' - skipped)" -ForegroundColor Yellow } }
  }
  $seen = @{}; $uniq = @()
  foreach ($e in $out) { if (-not $seen.ContainsKey($e.Id)) { $seen[$e.Id] = 1; $uniq += $e } }
  return $uniq
}

function Show-ExtraCatalog($Catalog) {
  $i = 0
  foreach ($e in $Catalog) {
    $i++
    $mark = '   '; if (Get-ExtraInstalled $e) { $mark = '[x]' }
    Write-Host ('  {0,2}) {1} {2,-22} {3,9}  {4}' -f $i, $mark, $e.Id, (Format-Size $e.GB), $e.About)
  }
  Write-Host '  [x] = already added. "all" means everything except gutenberg-all (206 GB).'
}

function Install-ExtraLibrary($Entry) {
  # Download (fastest mirror, resume) + SHA-256 check + VERIFIED marker. Returns $true when ready.
  $have = Get-ExtraInstalled $Entry
  if ($have) { Write-Host "  Already added: $($Entry.About) ($have)" -ForegroundColor Green; return $true }
  $z = Resolve-LatestZim ([pscustomobject]@{ Id=$Entry.Id; Dir=$Entry.Dir; Prefix=$Entry.Prefix; About=$Entry.About })
  $size = Get-RemoteSize $z.Url
  $already = [int64]0
  if (Test-Path -LiteralPath (Join-Path $Library "$($z.File).part")) { $already = (Get-Item -LiteralPath (Join-Path $Library "$($z.File).part")).Length }
  $free = Get-FreeBytes $Library
  Write-Host ("  - {0}: {1} ({2})" -f $Entry.About, $z.File, (Format-GB $size))
  if ($size -gt 0 -and $free -lt ($size - $already + [int64]2e9)) {
    Write-Host ("    Not enough free space: needs {0}, only {1} free on this drive. Skipped." -f (Format-GB ($size - $already)), (Format-GB $free)) -ForegroundColor Red
    return $false
  }
  return (Get-Zim -Z $z)
}

# ---------- Check for updates (only when asked; needs internet; never downloads or changes anything) ----------
function Compare-KitVersion([string]$A, [string]$B) {
  # -1 if A < B, 0 if equal, 1 if A > B. Accepts "v1.2.3" and "1.2.3-beta" (a pre-release sorts before the release).
  function Split-V([string]$v) {
    $v = $v.Trim().TrimStart('v','V'); $pre = ''
    $i = $v.IndexOf('-'); if ($i -ge 0) { $pre = $v.Substring($i + 1); $v = $v.Substring(0, $i) }
    $n = @(0,0,0); $p = $v.Split('.')
    for ($k = 0; $k -lt 3 -and $k -lt $p.Count; $k++) { $x = 0; [void][int]::TryParse(($p[$k] -replace '[^0-9]',''), [ref]$x); $n[$k] = $x }
    return @{ N = $n; Pre = $pre }
  }
  $va = Split-V $A; $vb = Split-V $B
  for ($k = 0; $k -lt 3; $k++) { if ($va.N[$k] -lt $vb.N[$k]) { return -1 }; if ($va.N[$k] -gt $vb.N[$k]) { return 1 } }
  if ($va.Pre -eq $vb.Pre) { return 0 }
  if (-not $va.Pre) { return 1 }; if (-not $vb.Pre) { return -1 }
  $c = [string]::CompareOrdinal($va.Pre, $vb.Pre)
  if ($c -lt 0) { return -1 }; if ($c -gt 0) { return 1 }; return 0
}

function Invoke-UpdateCheck {
  $api = $ReleasesApi; if ($env:OFFLINE_AI_RELEASES_API) { $api = $env:OFFLINE_AI_RELEASES_API }
  Write-Host "  This kit: version $KitVersion. Asking GitHub for the newest version..."
  $curl = Get-CurlExe
  $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $out = & $curl -sS -L --fail --connect-timeout 8 --max-time 20 -H 'Accept: application/vnd.github+json' -H 'User-Agent: offline-ai-kit' $api 2>$null
  $code = $LASTEXITCODE; $ErrorActionPreference = $eap
  if ($code -ne 0 -or -not $out) {
    Write-Host "  You appear to be offline (or GitHub could not be reached) - that's fine, the kit doesn't need internet to run." -ForegroundColor Yellow
    Write-Host 'UPDATE CHECK: OFFLINE'
    return 'offline'
  }
  try { $rel = ($out -join "`n") | ConvertFrom-Json } catch { Write-Host '  GitHub sent an answer the kit could not read. Try again later.' -ForegroundColor Yellow; Write-Host 'UPDATE CHECK: ERROR'; return 'error' }
  $latest = "$($rel.tag_name)".TrimStart('v','V')
  if ((Compare-KitVersion $KitVersion $latest) -ge 0) {
    Write-Host "  You're on the latest version, v$KitVersion." -ForegroundColor Green
    Write-Host "UPDATE CHECK: UP TO DATE (latest v$latest)"
    return 'current'
  }
  $zip = ($rel.assets | Where-Object { $_.name -like 'Offline-AI-Kit-*.zip' } | Select-Object -First 1).browser_download_url
  if (-not $zip) { $zip = $rel.zipball_url }
  Write-Host "  A newer version is available: v$latest (you have v$KitVersion)." -ForegroundColor Yellow
  Write-Host "  What's new:   $($rel.html_url)"
  Write-Host "  Download:     $zip"
  Write-Host '  Nothing was downloaded or changed. To update: download the ZIP, unzip it, and copy your'
  Write-Host '  "library", "ollama-models" and "runtime" folders (and kit-settings.ini) into the new folder.'
  Write-Host "UPDATE CHECK: UPDATE AVAILABLE v$latest"
  return 'update'
}
