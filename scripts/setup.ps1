# One-time setup for the Offline AI Kit (needs internet). Safe to run again:
# finished downloads are skipped, half-finished ones resume.
#   EASY-INSTALL.bat  -> setup.ps1 -Easy   (no questions; picks everything from the hardware)
#   SETUP.bat         -> setup.ps1         (menus)
#   Power users: see ADVANCED.md for every option below and kit-settings.ini.
param(
  [switch]$Easy,
  [string]$HardwareProfile = '',  # lite | standard | full
  [string]$Tier = '',             # 1/essentials | 2/recommended
  [string]$Models = '',           # lite | core | full, or a comma list like "qwen3.5:9b,llama3.2:3b"
  [string]$Zims = '',             # comma list of library ids (see ADVANCED.md), overrides -Tier
  [string]$InstallPath = '',
  [switch]$SkipWikipedia,
  [switch]$WithWikipedia,
  [switch]$UseSystemOllama,
  [switch]$NoStart,
  [switch]$Test,
  [switch]$DetectOnly,            # just show the hardware check and chosen profile, then exit                  # quick test install (see ADVANCED.md "Test mode")
  [switch]$Yes
)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Offline AI - setup'
if ($Easy) { $Yes = $true }

function Ask([string]$Question, [string]$Default) {
  if ($Yes) { return $Default }
  $a = Read-Host "$Question [$Default]"
  if ([string]::IsNullOrWhiteSpace($a)) { return $Default }
  return $a.Trim()
}

Write-Host '=================================================='
if ($Easy) { Write-Host '  Offline AI Kit - EASY INSTALL (no questions)' } else { Write-Host '  Offline AI Kit - setup' }
Write-Host '  Downloads everything once, so it all works later with NO internet.'
Write-Host '=================================================='
Write-Host ''
if (-not $script:IsWin) { Write-Host 'Note: this kit is built for Windows. Continuing anyway.' -ForegroundColor Yellow }
$null = Get-CurlExe

# Settings file values act as defaults for anything not given on the command line.
if (-not $Tier)   { $Tier   = Get-Setting 'LIBRARY_TIER' '' }
if (-not $Models) { $Models = Get-Setting 'MODELS' '' }
if (-not $Zims)   { $Zims   = Get-Setting 'ZIMS' '' }
if ($UseSystemOllama) { Set-KitSetting 'USE_SYSTEM_OLLAMA' 'yes'; $script:UseSystemOllama = $true; if (-not $KitSettings.ContainsKey('OLLAMA_PORT')) { $script:OllamaPort = 11434 } }

# ---------- 1. Install folder ----------
$target = $Kit
if ($InstallPath) { $target = $InstallPath }
elseif (-not $Easy) {
  Write-Host "The kit will live in this folder (any drive is fine, e.g. an external SSD):"
  Write-Host "  $Kit"
  $target = Ask 'Press Enter to keep it, or type a different folder' $Kit
}
$target = [System.IO.Path]::GetFullPath($target.Trim().Trim('"'))
if ($target.TrimEnd('\','/') -ne $Kit.TrimEnd('\','/')) {
  Write-Host "Copying the kit files to $target ..."
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  foreach ($item in @('scripts','www','mac','SETUP.bat','EASY-INSTALL.bat','START-OFFLINE-AI.bat','STOP-OFFLINE-AI.bat','STATUS.bat','SETUP-MAC.command','EASY-INSTALL-MAC.command','START-OFFLINE-AI-MAC.command','STOP-OFFLINE-AI-MAC.command','STATUS-MAC.command','README.md','START-HERE.txt','ADVANCED.md','README-OUTAGE.txt','kit-settings.example.ini','kit-settings.ini','LICENSE')) {
    $src = Join-Path $Kit $item
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $target -Recurse -Force }
  }
  Write-Host 'Continuing setup in the new folder...'
  $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $target 'scripts\setup.ps1'))
  foreach ($pair in @(@('-HardwareProfile',$HardwareProfile),@('-Tier',$Tier),@('-Models',$Models),@('-Zims',$Zims))) { if ($pair[1]) { $argList += @($pair[0], $pair[1]) } }
  foreach ($sw in @(@('-Test',$Test),@('-Easy',$Easy),@('-SkipWikipedia',$SkipWikipedia),@('-WithWikipedia',$WithWikipedia),@('-UseSystemOllama',$UseSystemOllama),@('-NoStart',$NoStart),@('-Yes',$Yes))) { if ($sw[1]) { $argList += $sw[0] } }
  & (Get-Process -Id $PID).Path @argList
  exit $LASTEXITCODE
}
Ensure-Dirs
$LogFile = Join-Path $LogDir ('setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
try { Start-Transcript -LiteralPath $LogFile -Append | Out-Null; $global:KitTranscript = $true; Write-Host "(A copy of everything shown here is saved in $LogFile)" } catch {}
if ($Test -or $env:OFFLINE_AI_TEST -match '^(?i)(1|yes|true)$') { Set-KitSetting 'TEST_MODE' 'yes'; Enable-TestMode }
if ($TestMode) { Write-Host 'TEST MODE: tiny library, one small model, 13 MB Wikipedia stand-in. Delete kit-settings.ini (or set TEST_MODE=no) to leave test mode.' -ForegroundColor Yellow }
try { Get-ChildItem -LiteralPath $Kit -Recurse -Include *.ps1,*.bat,*.html -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue } catch {}

# ---------- 2. Hardware check ----------
$hw = Get-Hardware
$gpuText = 'no NVIDIA graphics card found'
if ($hw.Gpu) { $gpuText = $hw.Gpu; if ($hw.VramGB -gt 0) { $gpuText += " ($($hw.VramGB) GB)" } }
Write-Host ("This computer: {0} GB memory, {1}, {2} GB free on this drive." -f $hw.RamGB, $gpuText, $hw.FreeGB)
$hwProfile = Get-HardwareProfile $hw
if ($HardwareProfile) { $hwProfile = $HardwareProfile.ToLower() }
if (-not $Profiles.Contains($hwProfile)) { $hwProfile = 'standard' }
Write-Host ("Best fit for this computer: {0}" -f $Profiles[$hwProfile].Label)
if ($DetectOnly) {
  $pk = Select-ProfileForDisk $hwProfile $hw.FreeGB
  if ($pk) { Write-Host ("PROFILE: {0}  (Easy install would use: {1}, Wikipedia: {2})" -f $hwProfile, $pk.Profile, $pk.Wikipedia) } else { Write-Host "PROFILE: $hwProfile  (Easy install: not enough disk space)" }
  try { Stop-Transcript | Out-Null } catch {}
  exit 0
}
$wantWiki = -not $SkipWikipedia

if ($TestMode) {
  $tierName = 'test'; $modelList = @()
} elseif ($Easy) {
  $pick = Select-ProfileForDisk $hwProfile $hw.FreeGB
  if ($SkipWikipedia -and $pick) { $pick.Wikipedia = $false }
  if (-not $pick) {
    $lite = Get-ProfileNeedGB 'lite'
    Write-Host ''
    Write-Host ("There is not enough free space on this drive. The smallest version needs about {0:N0} GB" -f $lite) -ForegroundColor Red
    Write-Host ("and this drive has {0} GB free. Please delete some files (or plug in a bigger drive" -f $hw.FreeGB) -ForegroundColor Red
    Write-Host 'and copy this folder onto it), then double-click EASY-INSTALL again.' -ForegroundColor Red
    exit 1
  }
  if ($pick.Profile -ne $hwProfile) {
    Write-Host ("To fit the free space, installing the {0} version instead." -f $Profiles[$pick.Profile].Label) -ForegroundColor Yellow
  }
  $hwProfile = $pick.Profile
  $wantWiki = $pick.Wikipedia
  if (-not $wantWiki -and -not $SkipWikipedia) {
    Write-Host 'Full Wikipedia (127 GB) will NOT be downloaded because there is not enough free space.' -ForegroundColor Yellow
    Write-Host 'Everything else works. You can add Wikipedia later: free up about 140 GB and run SETUP.bat.' -ForegroundColor Yellow
  }
  $tierName = $Profiles[$hwProfile].Tier
  $modelList = Get-ModelsForSet $Profiles[$hwProfile].Models
} else {
  $defTier = '2'; if ($Profiles[$hwProfile].Tier -eq 'essentials') { $defTier = '1' }
  Write-Host ''
  Write-Host 'Which library do you want? (Full English Wikipedia ~127 GB is included and downloads'
  Write-Host 'in the background the first time you start the kit.)'
  Write-Host '  1) Essentials   - survival, first aid, water, food, knots, WikiMed   (~4 GB)'
  Write-Host '  2) Recommended  - Essentials + Wikipedia Medicine, Wikivoyage,'
  Write-Host '                    iFixit repair guides, Gardening Q&A               (~11 GB)'
  if (-not $Tier -and -not $Zims) { $Tier = Ask 'Type 1 or 2' $defTier }
  $tierName = 'recommended'; if ($Tier -eq '1' -or $Tier -eq 'essentials') { $tierName = 'essentials' }

  $defModels = @{ lite='0'; standard='1'; full='2' }[$hwProfile]
  Write-Host ''
  Write-Host 'Which AI models?'
  Write-Host '  0) Lite  - llama3.2:3b, medgemma:4b                                    (~5 GB)'
  Write-Host '  1) Core  - Lite + qwen3.5:9b, phi4-mini                                (~15 GB)'
  Write-Host '  2) All   - Core + gemma3:4b, gemma3:12b, qwen3:14b (best use of the GPU) (~35 GB)'
  if (-not $Models) { $Models = Ask 'Type 0, 1 or 2' $defModels }
  if ($Models.Contains(':') -or $Models.Contains(',')) {
    $modelList = @()
    foreach ($n in ($Models -split ',')) { $n = $n.Trim(); if ($n) { $c = $ModelCatalog | Where-Object { $_.Name -eq $n } | Select-Object -First 1; if (-not $c) { $c = @{ Name=$n; GB=0; Hint='custom' } }; $modelList += $c } }
  } else {
    $set = 'full'
    if ($Models -eq '0' -or $Models -eq 'lite') { $set = 'lite' } elseif ($Models -eq '1' -or $Models -eq 'core') { $set = 'core' }
    $modelList = Get-ModelsForSet $set
  }
  if (-not $SkipWikipedia -and -not $WithWikipedia -and ($hwProfile -eq 'lite' -or $hw.FreeGB -lt ($WikipediaGB + 60))) {
    $defW = 'Y'; if ($hw.FreeGB -lt ($WikipediaGB + 40)) { $defW = 'N' }
    $a = Ask 'Also download full English Wikipedia later (127 GB)? (Y/N)' $defW
    $wantWiki = ($a -match '^[Yy]')
  }
}

if ($TestMode) {
  $tierName = 'test'; $Zims = 'knots,water'
  $modelList = @($ModelCatalog | Where-Object { $_.Name -eq 'llama3.2:3b' })
  $wantWiki = -not $SkipWikipedia
}
$zimEntries = @($ZimCatalog | Where-Object { $_.Tier -eq 'essentials' -or ($tierName -eq 'recommended' -and $_.Tier -eq 'recommended') })
if ($Zims) { $ids = @($Zims -split ',' | ForEach-Object { $_.Trim().ToLower() }); $zimEntries = @($ZimCatalog | Where-Object { $ids -contains $_.Id -and $_.Tier -ne 'always' }) }
if ($wantWiki) { Set-KitSetting 'SKIP_WIKIPEDIA' 'no' } else { Set-KitSetting 'SKIP_WIKIPEDIA' 'yes' }

$estGB = $ProgramsGB
if ($tierName -eq 'essentials') { $estGB += 3.8 } elseif ($tierName -eq 'test') { $estGB += 0.1 } else { $estGB += 11.2 }
foreach ($m in $modelList) { $estGB += $m.GB }
$free = Get-FreeBytes $Kit
Write-Host ''
Write-Host ('Installing: library "{0}", models: {1}' -f $tierName, (($modelList | ForEach-Object { $_.Name }) -join ', '))
if ($wantWiki) { Write-Host ("Setup needs about {0:N0} GB now; full Wikipedia later needs about {1} more." -f $estGB, (Format-GB ($WikipediaGB * 1e9))) }
else { Write-Host ("Setup needs about {0:N0} GB. Full Wikipedia is switched off." -f $estGB) }
Write-Host ("Free space on this drive: {0}" -f (Format-GB $free))
if ($free -lt ($estGB * 1e9)) { Write-Host 'Not enough free space for setup. Free up space or choose another drive.' -ForegroundColor Red; exit 1 }
if ($wantWiki -and -not $TestMode -and $free -lt (($estGB + 140) * 1e9)) { Write-Host 'WARNING: there will not be enough room for full Wikipedia (~127 GB) on this drive.' -ForegroundColor Yellow }

@{ profile=$hwProfile; tier=$tierName; models=(($modelList | ForEach-Object { $_.Name }) -join ','); wikipedia=$wantWiki; created=(Get-Date -Format 'yyyy-MM-dd') } | ConvertTo-Json | Set-Content -LiteralPath $ConfigFile -Encoding UTF8

# ---------- 3. Kiwix (library server) ----------
Write-Host ''
Write-Host '[1/4] Library program (kiwix-tools)...'
if (Get-KiwixServeExe) { Write-Host '  Already installed.' -ForegroundColor Green }
else {
  $relUrl = "$KiwixBase/release/kiwix-tools/"
  $html = Invoke-CurlText $relUrl
  $vers = [regex]::Matches($html, 'href="(kiwix-tools_win-x86_64-(\d+)\.(\d+)\.(\d+)(?:-(\d+))?\.zip)"') | ForEach-Object {
    $b = 0; if ($_.Groups[5].Success) { $b = [int]$_.Groups[5].Value }
    [pscustomobject]@{ File=$_.Groups[1].Value; Key=('{0:D4}{1:D4}{2:D4}{3:D4}' -f [int]$_.Groups[2].Value,[int]$_.Groups[3].Value,[int]$_.Groups[4].Value,$b) } }
  $k = $vers | Sort-Object Key | Select-Object -Last 1
  if (-not $k) { throw 'Could not find kiwix-tools for Windows on download.kiwix.org' }
  Write-Host "  Downloading $($k.File)"
  $zip = Join-Path $Runtime $k.File
  Save-ResumableFile -Url ($relUrl + $k.File) -OutFile $zip -Label "Downloading $($k.File)" -MaxTries 20
  $md5 = (Invoke-CurlText ($relUrl + $k.File + '.md5')).Split(' ')[0].Trim().ToLower()
  if ((Get-FileHash -LiteralPath $zip -Algorithm MD5).Hash.ToLower() -ne $md5) { Remove-Item -LiteralPath $zip -Force; throw 'kiwix-tools download was damaged (checksum mismatch). Run setup again.' }
  Expand-Archive -LiteralPath $zip -DestinationPath $KiwixDir -Force
  Remove-Item -LiteralPath $zip -Force
  Write-Host '  Installed.' -ForegroundColor Green
}

# ---------- 4. Ollama (AI model server, portable) ----------
Write-Host '[2/4] AI program (Ollama, portable - about 1.6 GB, includes NVIDIA GPU support)...'
if ($UseSystemOllama) { Write-Host "  Using your own Ollama on port $OllamaPort (USE_SYSTEM_OLLAMA) - not downloading one." }
elseif (Get-OllamaExe) { Write-Host '  Already installed.' -ForegroundColor Green }
else {
  $asset = 'ollama-windows-amd64.zip'
  $base  = 'https://github.com/ollama/ollama/releases/latest/download/'
  $zip = Join-Path $Runtime $asset
  Save-ResumableFile -Url ($base + $asset) -OutFile $zip -Label "Downloading Ollama ($asset)" -MaxTries 20
  $sums = Invoke-CurlText ($base + 'sha256sum.txt')
  $expected = ''
  foreach ($line in $sums -split "`n") { if ($line.Trim() -match ('^([0-9a-f]{64})\s+\S*?' + [regex]::Escape($asset) + '\s*$')) { $expected = $Matches[1] } }
  if (-not $expected) { throw 'Could not read the Ollama checksum list.' }
  if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower() -ne $expected) { Remove-Item -LiteralPath $zip -Force; throw 'Ollama download was damaged (checksum mismatch). Run setup again.' }
  Write-Host '  Unpacking...'
  Expand-Archive -LiteralPath $zip -DestinationPath $OllamaDir -Force
  Remove-Item -LiteralPath $zip -Force
  Write-Host '  Installed.' -ForegroundColor Green
}

# ---------- 5. Library files ----------
Write-Host "[3/4] Library collections ($tierName)..."
$failed = @()
foreach ($e in $zimEntries) {
  try {
    $z = Resolve-LatestZim $e
    Write-Host "  - $($e.About): $($z.File)"
    if (-not (Get-Zim -Z $z)) { $failed += $z.File }
  } catch { Write-Host "    Problem: $($_.Exception.Message)" -ForegroundColor Yellow; $failed += $e.Prefix }
}

# ---------- 6. Models ----------
Write-Host '[4/4] AI models...'
if (-not (Start-KitOllama)) { throw 'The kit AI server would not start; see logs\ollama.log' }
$ollama = Get-OllamaExe
if ($UseSystemOllama) { $c = Get-Command ollama.exe -ErrorAction SilentlyContinue; if (-not $c) { $c = Get-Command ollama -ErrorAction SilentlyContinue }; if (-not $c) { throw 'USE_SYSTEM_OLLAMA is on but the ollama command was not found.' }; $ollama = $c.Source }
$savedHost = $env:OLLAMA_HOST
$env:OLLAMA_HOST = "127.0.0.1:$OllamaPort"
try {
  foreach ($m in $modelList) {
    $n = $m.Name; $tag = 'latest'
    if ($n.Contains(':')) { $tag = $n.Split(':')[1]; $n = $n.Split(':')[0] }
    $nul = '/dev/null'; if ($script:IsWin) { $nul = 'NUL' }
    $code = & (Get-CurlExe) -s -o $nul -w '%{http_code}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' "https://registry.ollama.ai/v2/library/$n/manifests/$tag"
    if ($code -ne '200') { Write-Host "  Skipping $($m.Name): not found in the Ollama library right now (HTTP $code)." -ForegroundColor Yellow; $failed += $m.Name; continue }
    Write-Host "  - $($m.Name) (~$($m.GB) GB) - $($m.Hint)"
    $ok = $false
    for ($t = 1; $t -le 5 -and -not $ok; $t++) {
      # Windows PowerShell turns a program's progress output on stderr into a fatal error when the
      # output is redirected to a file, so relax that here and keep the log free of spinner codes.
      $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
      if ([Console]::IsOutputRedirected) {
        & $ollama pull $m.Name 2>&1 | ForEach-Object { "$_" -replace "\x1b\[[0-9;?]*[A-Za-z]", '' } |
          Where-Object { $_ -match '\S' -and $_ -notmatch 'pulling manifest|\d+%' } | ForEach-Object { Write-Host "    $($_.Trim())" }
      } else { & $ollama pull $m.Name }
      $pullCode = $LASTEXITCODE
      $ErrorActionPreference = $eap
      if ($pullCode -eq 0) { $ok = $true } else { Write-Host '    Retrying in 20 seconds...' -ForegroundColor Yellow; Start-Sleep -Seconds 20 }
    }
    if (-not $ok) { $failed += $m.Name; continue }
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $reply = & $ollama run $m.Name 'Reply with just the word OK.' 2>$null
    $ErrorActionPreference = $eap
    Write-Host ("    Test answer: " + (($reply -join ' ').Trim() -replace '\s+',' ')) -ForegroundColor DarkGray
  }
} finally { $env:OLLAMA_HOST = $savedHost }

# ---------- Done ----------
Write-Host ''
if ($failed.Count -gt 0) {
  Write-Host 'Setup finished with some problems (run SETUP.bat again to retry just these):' -ForegroundColor Yellow
  $failed | ForEach-Object { Write-Host "   - $_" }
} else {
  Write-Host 'Setup finished. Everything downloaded and checked.' -ForegroundColor Green
}
Write-Host ''
if ($Easy) { New-DesktopShortcut }
if ($failed.Count -gt 0) { Write-Host 'RESULT: SETUP FINISHED WITH PROBLEMS' } else { Write-Host 'RESULT: SETUP OK' }
Write-Host 'NEXT: double-click START-OFFLINE-AI.bat (or the "Offline AI" shortcut on the Desktop).'
if ($wantWiki -and $TestMode) { Write-Host 'The first start also downloads a small Wikipedia test file in the background (test mode).' }
elseif ($wantWiki) {
  Write-Host 'The first start also begins downloading FULL English Wikipedia (~127 GB) in the'
  Write-Host 'background. Leave the PC on and online until it finishes (could be many hours).'
}
if ($NoStart) { try { Stop-Transcript | Out-Null } catch {}; exit 0 }
$go = 'Y'
if (-not $Easy) { $go = Ask 'Start the kit now? (Y/N)' 'Y' }
if ($go -match '^[Yy]') { Write-Host ''; Write-Host 'Starting the kit...'; & (Join-Path $PSScriptRoot 'start.ps1') }
try { Stop-Transcript | Out-Null } catch {}
