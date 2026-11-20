# One-time setup for the Offline AI Kit (needs internet). Safe to run again:
# finished downloads are skipped, half-finished ones resume.
#   EASY-INSTALL (Windows).bat  -> setup.ps1 -Easy   (no questions; picks everything from the hardware)
#   SETUP.bat         -> setup.ps1         (Setup Wizard: choose your features step by step)
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
  [switch]$DetectOnly,            # just show the hardware check and chosen profile, then exit
  [switch]$Yes,
  [switch]$ShareWifi,              # turn on Share on Wi-Fi (phones/tablets on the home network)
  [string]$ExtraLibraries = '',    # comma list of Extra Library ids or numbers (catalog\extra-libraries.txt), or 'all'
  [string]$Maps = '',              # comma list of map ids or numbers (catalog\maps.txt), or 'all'. Easy Install ignores this unless you pass it.
  [switch]$Universal              # also download programs for Windows, Mac and Linux (one shared library)
)
. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'programs.ps1')
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Offline AI - setup'
if ($Easy) { $Yes = $true }

function Ask([string]$Question, [string]$Default) {
  if ($Yes) { return $Default }
  if ([Console]::IsInputRedirected) {
    # Scripted answers (one per line on standard input); end of input = the suggested answer.
    $a = [Console]::In.ReadLine()
    Write-Host "$Question [$Default] $a"
  } else { $a = Read-Host "$Question [$Default]" }
  if ([string]::IsNullOrWhiteSpace($a)) { return $Default }
  return $a.Trim()
}

function Start-SetupLog {
  $LogFile = Join-Path $LogDir ('setup-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
  try { Start-Transcript -LiteralPath $LogFile -Append | Out-Null; $global:KitTranscript = $true; Write-Host "(A copy of everything shown here is saved in $LogFile)" } catch {}
}

function Unblock-KitFiles {
  try { Get-ChildItem -LiteralPath $Kit -Recurse -Include *.ps1,*.bat,*.html -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue } catch {}
}

Write-Host '=================================================='
if ($Easy) { Write-Host '  Offline AI Kit - EASY INSTALL (no questions)' } else { Write-Host '  Offline AI Kit - setup' }
Write-Host '  Downloads everything once, so it all works later with NO internet.'
Write-Host '=================================================='
Write-Host ''
if (-not $script:IsWin) { Write-Host 'Note: this kit is built for Windows. Continuing anyway.' -ForegroundColor Yellow }

# -DetectOnly is read-only: hardware check and chosen profile, then stop.
# No folder prompt, no directories, no log, and no kit-settings.ini.
if ($DetectOnly) {
  $hw = Get-Hardware
  $gpuText = 'no NVIDIA graphics card found'
  if ($hw.Gpu) { $gpuText = $hw.Gpu; if ($hw.VramGB -gt 0) { $gpuText += " ($($hw.VramGB) GB)" } }
  Write-Host ("This computer: {0} GB memory, {1}, {2} GB free on this drive." -f $hw.RamGB, $gpuText, $hw.FreeGB)
  $hwProfile = Get-HardwareProfile $hw
  if ($HardwareProfile) { $hwProfile = $HardwareProfile.ToLower() }
  if (-not $Profiles.Contains($hwProfile)) { $hwProfile = 'standard' }
  Write-Host ("Best fit for this computer: {0}" -f $Profiles[$hwProfile].Label)
  $pk = Select-ProfileForDisk $hwProfile $hw.FreeGB
  if ($pk) { Write-Host ("PROFILE: {0}  (Easy install would use: {1}, Wikipedia: {2})" -f $hwProfile, $pk.Profile, $pk.Wikipedia) } else { Write-Host "PROFILE: $hwProfile  (Easy install: not enough disk space)" }
  exit 0
}

$null = Get-CurlExe

# Settings file values act as defaults for anything not given on the command line.
if (-not $Tier)   { $Tier   = Get-Setting 'LIBRARY_TIER' '' }
if (-not $Models) { $Models = Get-Setting 'MODELS' '' }
if (-not $Zims)   { $Zims   = Get-Setting 'ZIMS' '' }
# Remember this choice in memory now. kit-settings.ini is written only after Proceed
# (Easy Install does not ask, and writes the file when the download starts).
$persistSystemOllama = $false
if ($UseSystemOllama) {
  $persistSystemOllama = $true
  $script:UseSystemOllama = $true
  if (-not $KitSettings.ContainsKey('OLLAMA_PORT')) { $script:OllamaPort = 11434 }
}

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
  foreach ($item in @('scripts','www','mac','linux','catalog','VERSION','SETUP.bat','EASY-INSTALL (Windows).bat','START-OFFLINE-AI.bat','STOP-OFFLINE-AI.bat','STATUS.bat','SETUP-MAC.command','EASY-INSTALL (Mac).command','START-OFFLINE-AI-MAC.command','STOP-OFFLINE-AI-MAC.command','STATUS-MAC.command','SETUP-LINUX.sh','EASY-INSTALL (Linux).sh','START-OFFLINE-AI-LINUX.sh','STOP-OFFLINE-AI-LINUX.sh','STATUS-LINUX.sh','README.md','START-HERE.txt','ADVANCED.md','README-OUTAGE.txt','kit-settings.example.ini','kit-settings.ini','LICENSE')) {
    $src = Join-Path $Kit $item
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $target -Recurse -Force }
  }
  Write-Host 'Continuing setup in the new folder...'
  $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $target 'scripts\setup.ps1'))
  foreach ($pair in @(@('-HardwareProfile',$HardwareProfile),@('-Tier',$Tier),@('-Models',$Models),@('-Zims',$Zims),@('-ExtraLibraries',$ExtraLibraries),@('-Maps',$Maps))) { if ($pair[1]) { $argList += @($pair[0], $pair[1]) } }
  foreach ($sw in @(@('-Test',$Test),@('-Easy',$Easy),@('-SkipWikipedia',$SkipWikipedia),@('-WithWikipedia',$WithWikipedia),@('-UseSystemOllama',$UseSystemOllama),@('-NoStart',$NoStart),@('-Yes',$Yes),@('-ShareWifi',$ShareWifi),@('-Universal',$Universal))) { if ($sw[1]) { $argList += $sw[0] } }
  & (Get-Process -Id $PID).Path @argList
  exit $LASTEXITCODE
}
# Directories, the setup log and kit-settings.ini wait until the user says Proceed.
# Easy Install does not ask, so it prepares the folder now.
$persistTest = $false
if ($Test -or $env:OFFLINE_AI_TEST -match '^(?i)(1|yes|true)$') {
  $persistTest = $true
  if (-not $script:TestMode) { Enable-TestMode }
}
if ($Easy) { Ensure-Dirs; Unblock-KitFiles; Start-SetupLog }
if ($TestMode) { Write-Host 'TEST MODE: tiny library, one small model, 13 MB Wikipedia stand-in. Delete kit-settings.ini (or set TEST_MODE=no) to leave test mode.' -ForegroundColor Yellow }

# ---------- 2. Hardware check ----------
$hw = Get-Hardware
$gpuText = 'no NVIDIA graphics card found'
if ($hw.Gpu) { $gpuText = $hw.Gpu; if ($hw.VramGB -gt 0) { $gpuText += " ($($hw.VramGB) GB)" } }
Write-Host ("This computer: {0} GB memory, {1}, {2} GB free on this drive." -f $hw.RamGB, $gpuText, $hw.FreeGB)
$hwProfile = Get-HardwareProfile $hw
if ($HardwareProfile) { $hwProfile = $HardwareProfile.ToLower() }
if (-not $Profiles.Contains($hwProfile)) { $hwProfile = 'standard' }
Write-Host ("Best fit for this computer: {0}" -f $Profiles[$hwProfile].Label)
$wantWiki = -not $SkipWikipedia
$extraCat = @(Get-ExtraCatalog)
$extraSel = @()
if ($ExtraLibraries) { $extraSel = @(Resolve-ExtraIds $ExtraLibraries $extraCat) }
$mapCat = @(Get-MapCatalog)
$mapSel = @()
if ($Maps) { $mapSel = @(Resolve-MapIds $Maps $mapCat) }
$shareChoice = ([bool]$ShareWifi -or [bool]$ShareOnWifi)   # Easy keeps the current setting (off on a new kit)

function Step([int]$n, [string]$title) {
  Write-Host ''
  Write-Host ("--- Step {0} of {1}: {2} " -f $n, $WizardSteps, $title).PadRight(64, '-') -ForegroundColor Cyan
}
$WizardSteps = 8   # maps are step 6; which computers is step 7; the summary is step 8. Easy Install never asks.
$universal = [bool]$Universal

if ($Easy) {
  $pick = Select-ProfileForDisk $hwProfile $hw.FreeGB
  if ($SkipWikipedia -and $pick) { $pick.Wikipedia = $false }
  if (-not $pick -and -not $TestMode) {
    $lite = Get-ProfileNeedGB 'lite'
    Write-Host ''
    Write-Host ("There is not enough free space on this drive. The smallest version needs about {0:N0} GB" -f $lite) -ForegroundColor Red
    Write-Host ("and this drive has {0} GB free. Please delete some files (or plug in a bigger drive" -f $hw.FreeGB) -ForegroundColor Red
    Write-Host 'and copy this folder onto it), then double-click EASY-INSTALL (Windows) again.' -ForegroundColor Red
    exit 1
  }
  if ($pick) {
    if ($pick.Profile -ne $hwProfile) {
      Write-Host ("To fit the free space, installing the {0} version instead." -f $Profiles[$pick.Profile].Label) -ForegroundColor Yellow
    }
    $hwProfile = $pick.Profile
    $wantWiki = $pick.Wikipedia
    if (-not $wantWiki -and -not $SkipWikipedia -and -not $TestMode) {
      Write-Host 'Full Wikipedia (127 GB) will NOT be downloaded because there is not enough free space.' -ForegroundColor Yellow
      Write-Host 'Everything else works. You can add Wikipedia later: free up about 140 GB and run SETUP.bat.' -ForegroundColor Yellow
    }
  }
  $tierName = $Profiles[$hwProfile].Tier
  $modelList = Get-ModelsForSet $Profiles[$hwProfile].Models
} else {
  Write-Host ''
  Write-Host '=================== SETUP WIZARD ===================' -ForegroundColor Cyan
  Write-Host 'Choose what to install. Press Enter to take the suggested answer [in brackets].'
  Write-Host 'Nothing is downloaded until you say yes on the summary screen at the end.'

  # Step 1: AI model size
  Step 1 'AI model size'
  Write-Host ("This computer: {0} GB memory, {1}." -f $hw.RamGB, $gpuText)
  $defModels = @{ lite='0'; standard='1'; full='2' }[$hwProfile]
  Write-Host '  0) Lite  - llama3.2:3b, medgemma:4b                                    (~5 GB)  any computer'
  Write-Host '  1) Core  - Lite + qwen3.5:9b, phi4-mini                                (~15 GB) NVIDIA graphics card'
  Write-Host '  2) All   - Core + gemma3:4b, gemma3:12b, qwen3:14b (best use of the GPU) (~35 GB) 12 GB+ graphics card'
  Write-Host "  Recommended for this computer: $defModels"
  if ($TestMode) { Write-Host '  (TEST MODE: the test installs only llama3.2:3b, whatever you pick here.)' -ForegroundColor Yellow }
  if (-not $Models) { $Models = Ask 'Type 0, 1 or 2' $defModels }
  if ($Models.Contains(':') -or $Models.Contains(',')) {
    $modelList = @()
    foreach ($n in ($Models -split ',')) { $n = $n.Trim(); if ($n) { $c = $ModelCatalog | Where-Object { $_.Name -eq $n } | Select-Object -First 1; if (-not $c) { $c = @{ Name=$n; GB=0; Hint='custom' } }; $modelList += $c } }
  } else {
    $set = 'full'
    if ($Models -eq '0' -or $Models -eq 'lite') { $set = 'lite' } elseif ($Models -eq '1' -or $Models -eq 'core') { $set = 'core' }
    $modelList = Get-ModelsForSet $set
  }

  # Step 2: core library
  Step 2 'Core library (always included)'
  $defTier = '2'; if ($Profiles[$hwProfile].Tier -eq 'essentials') { $defTier = '1' }
  Write-Host '  1) Essentials   - survival, first aid, water, food, knots, WikiMed   (~4 GB)'
  Write-Host '  2) Recommended  - Essentials + Wikipedia Medicine, Wikivoyage,'
  Write-Host '                    iFixit repair guides, Gardening Q&A               (~11 GB)'
  if (-not $Tier -and -not $Zims) { $Tier = Ask 'Type 1 or 2' $defTier }
  $tierName = 'recommended'; if ($Tier -eq '1' -or $Tier -eq 'essentials') { $tierName = 'essentials' }

  # Step 3: full English Wikipedia
  Step 3 'Full English Wikipedia'
  Write-Host ('  All of English Wikipedia with pictures, about {0}. It downloads in the background the' -f (Format-GB ($WikipediaGB * 1e9)))
  Write-Host '  first time you start the kit (everything else works meanwhile) and resumes if interrupted.'
  if (-not $SkipWikipedia -and -not $WithWikipedia) {
    $defW = 'Y'; if (-not $TestMode -and $hw.FreeGB -lt ($WikipediaGB + 40)) { $defW = 'N'; Write-Host ("  This drive has only {0} GB free, so the suggestion is No." -f $hw.FreeGB) -ForegroundColor Yellow }
    $a = Ask 'Download full English Wikipedia? (Y/N)' $defW
    $wantWiki = ($a -match '^[Yy]')
  } else { Write-Host ("  Chosen on the command line: {0}" -f $(if ($wantWiki) { 'Yes' } else { 'No' })) }

  # Step 4: extra libraries
  Step 4 'Extra Libraries (optional)'
  Show-ExtraCatalog $extraCat
  if (-not $ExtraLibraries) {
    $ans = Ask 'Type numbers or names (e.g. 1,3), "all", or press Enter for none' ''
    $extraSel = @(Resolve-ExtraIds $ans $extraCat)
  }
  if ($extraSel.Count) { Write-Host ('  Chosen: ' + (($extraSel | ForEach-Object { $_.Id }) -join ', ')) } else { Write-Host '  None (you can add them any time from STATUS.bat).' }

  # Step 5: share on Wi-Fi
  Step 5 'Share on home Wi-Fi (phones and tablets)'
  Write-Host '  Lets phones and tablets on the same Wi-Fi use the chat and library. Trusted home Wi-Fi only.'
  if (-not $ShareWifi) {
    $defS = 'N'; if ($ShareOnWifi) { $defS = 'Y' }
    $a = Ask 'Turn on Share on Wi-Fi? (Y/N)' $defS
    $shareChoice = ($a -match '^[Yy]')
  } else { Write-Host '  Chosen on the command line: ON' }
  if ($shareChoice) { Write-WifiWarning }

  # Step 6: optional offline maps. Easy Install never reaches this (maps stay off unless -Maps was passed).
  Step 6 'Offline maps (optional)'
  Write-Host '  Clean offline maps in the browser, stored in this kit (OpenStreetMap data packed by Kiwix).'
  Write-Host '  Vancouver Island, British Columbia, Alberta and Saskatchewan are inside the one Canada map'
  Write-Host '  (about 10 GB). Kiwix publishes Canada as one file, so picking any of those, or Canada,'
  Write-Host '  downloads that file once.'
  Write-Host '  Other regions are separate, larger files.'
  Show-MapCatalog $mapCat
  if (-not $Maps) {
    $ans = Ask 'Type numbers or names (e.g. 1,4), "all", or press Enter for none' ''
    $mapSel = @(Resolve-MapIds $ans $mapCat)
  }
  if ($mapSel.Count) {
    $dl = @(Get-MapDownloadSet $mapSel)
    Write-Host ('  Chosen: ' + (($mapSel | ForEach-Object { $_.Id }) -join ', ') + '  (' + $dl.Count + ' file(s), about ' + (Format-Size (Get-MapDownloadGB $mapSel)) + ')')
  } else { Write-Host '  None (you can add them any time from STATUS.bat).' }

  # Step 7: this computer, or programs for every computer on one drive.
  Step 7 'Which computers'
  $extraNow = Get-UniversalExtraGB
  Write-Host '  1) This computer only'
  Write-Host '  2) All computers (universal drive)'
  Write-Host '     Programs for Windows, Mac (Apple chip and Intel) and Linux (64-bit PC and ARM).'
  Write-Host '     One shared copy of the models, Wikipedia, extra libraries and maps.'
  Write-Host ("     Extra download for the other computers: about {0:N1} GB." -f $extraNow)
  if ($Universal) { Write-Host '  Chosen on the command line: All computers (universal drive)'; $universal = $true }
  else {
    $defU = '1'; if ((Get-Setting 'UNIVERSAL' 'no') -match '^(?i)(yes|true|1|2)$') { $defU = '2' }
    $a = Ask 'Type 1 or 2' $defU
    $universal = ($a -eq '2' -or $a -match '^(?i)(all|universal)')
  }
}

if ($TestMode) {
  $tierName = 'test'; $Zims = 'knots,water,wpmed'
  $modelList = @($ModelCatalog | Where-Object { $_.Name -eq 'llama3.2:3b' })
}
$zimEntries = @($ZimCatalog | Where-Object { $_.Tier -eq 'essentials' -or ($tierName -eq 'recommended' -and $_.Tier -eq 'recommended') })
if ($Zims) { $ids = @($Zims -split ',' | ForEach-Object { $_.Trim().ToLower() }); $zimEntries = @($ZimCatalog | Where-Object { $ids -contains $_.Id -and $_.Tier -ne 'always' }) }

$estGB = $ProgramsGB
if ($tierName -eq 'essentials') { $estGB += 3.8 } elseif ($tierName -eq 'test') { $estGB += 0.2 } else { $estGB += 11.2 }
foreach ($m in $modelList) { $estGB += $m.GB }
$extraGB = 0.0; foreach ($e in $extraSel) { if (-not (Get-ExtraInstalled $e)) { $extraGB += $e.GB } }
$mapGB = Get-MapDownloadGB $mapSel
$estGB += $extraGB + $mapGB
$extraProg = 0.0
if ($universal) { $extraProg = Get-UniversalExtraGB; $estGB += $extraProg }
$free = Get-FreeBytes $Kit

# Summary (Step 8 in the wizard)
if (-not $Easy) { Step $WizardSteps 'Summary' } else { Write-Host '' }
Write-Host ("  AI models:        {0}" -f (($modelList | ForEach-Object { $_.Name }) -join ', '))
Write-Host ("  Core library:     {0}" -f $tierName)
Write-Host ("  Full Wikipedia:   {0}" -f $(if ($wantWiki) { 'Yes - about ' + (Format-GB ($WikipediaGB * 1e9)) + ', downloads in the background on first start' } else { 'No' }))
Write-Host ("  Extra libraries:  {0}" -f $(if ($extraSel.Count) { (($extraSel | ForEach-Object { $_.Id }) -join ', ') + ' (' + (Format-Size $extraGB) + ')' } else { 'none' }))
Write-Host ("  Offline maps:     {0}" -f $(if ($mapSel.Count) { (($mapSel | ForEach-Object { $_.Id }) -join ', ') + ' (' + (Format-Size $mapGB) + ', shared files counted once)' } else { 'none' }))
Write-Host ("  Share on Wi-Fi:   {0}" -f $(if ($shareChoice) { 'ON (trusted home Wi-Fi only)' } else { 'off' }))
Write-Host ("  Computers:        {0}" -f $(if ($universal) { 'All computers (universal drive)' } else { 'This computer only' }))
if ($universal) { Write-Host ("  Extra programs:   about {0:N1} GB (other computers). Library, models and maps stay one shared copy." -f $extraProg) }
$totalGB = $estGB; if ($wantWiki) { $totalGB += $WikipediaGB }
Write-Host ("  Download now:     about {0:N1} GB   (with Wikipedia later: about {1:N1} GB in total)" -f $estGB, $totalGB)
Write-Host ("  Free space:       {0} on this drive" -f (Format-GB $free))
if ($free -lt ($estGB * 1e9)) { Write-Host 'Not enough free space for these choices. Free up space, pick fewer extras or a smaller model size, or choose another drive.' -ForegroundColor Red; exit 1 }
if ($wantWiki -and -not $TestMode -and $free -lt (($estGB + 140) * 1e9)) { Write-Host 'WARNING: there will not be enough room for full Wikipedia (~127 GB) on this drive.' -ForegroundColor Yellow }
if (-not $Easy) {
  $go = Ask 'Proceed? (Y/N)' 'Y'
  if ($go -notmatch '^[Yy]') { Write-Host 'OK - nothing was downloaded or changed. Run SETUP.bat again any time.'; Write-Host 'RESULT: SETUP CANCELLED'; exit 0 }
  Ensure-Dirs
  Unblock-KitFiles
  Start-SetupLog
}

# Save the choices so START / STOP / STATUS follow them.
if ($persistTest) { Set-KitSetting 'TEST_MODE' 'yes' }
if ($persistSystemOllama) { Set-KitSetting 'USE_SYSTEM_OLLAMA' 'yes' }
if ($wantWiki) { Set-KitSetting 'SKIP_WIKIPEDIA' 'no' } else { Set-KitSetting 'SKIP_WIKIPEDIA' 'yes' }
Set-ShareOnWifi $shareChoice
if ($extraSel.Count) { Set-KitSetting 'EXTRA_LIBRARIES' (($extraSel | ForEach-Object { $_.Id }) -join ',') }
if (-not $Easy -or $Maps) { Set-KitSetting 'MAPS' (($mapSel | ForEach-Object { $_.Id }) -join ',') }
if (-not $Easy -or $universal) { if ($universal) { Set-KitSetting 'UNIVERSAL' 'yes' } else { Set-KitSetting 'UNIVERSAL' 'no' } }

@{ profile=$hwProfile; tier=$tierName; models=(($modelList | ForEach-Object { $_.Name }) -join ','); wikipedia=$wantWiki; created=(Get-Date -Format 'yyyy-MM-dd') } | ConvertTo-Json | Set-Content -LiteralPath $ConfigFile -Encoding UTF8

# ---------- 3. Kiwix (library server) ----------
Write-Host ''
Start-StayAwake
$needBig = $false
if ($wantWiki -and -not $TestMode) { $needBig = $true }
foreach ($e in @($extraSel + $mapSel)) { if ($e.GB -ge 4) { $needBig = $true } }
if ($needBig -and (Test-Fat32Volume $Kit)) {
  Write-Host 'This drive is FAT32, which cannot store a file larger than 4 GB.' -ForegroundColor Red
  Write-Host 'Wikipedia, the larger libraries, and offline maps need exFAT, NTFS, or APFS.' -ForegroundColor Red
  Write-Host 'Copy this folder onto an exFAT, NTFS, or APFS drive, then run setup again.' -ForegroundColor Red
  exit 1
}
if ($universal -and $TestMode) { Write-Host 'TEST MODE: not downloading programs for other computers.' -ForegroundColor Yellow }
if ($universal -and -not $TestMode) { Install-UniversalPrograms }
else { Install-WindowsPrograms }

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

if ($extraSel.Count) {
  Write-Host 'Extra Libraries...'
  foreach ($e in $extraSel) {
    try { if (-not (Install-ExtraLibrary $e)) { $failed += $e.Id } } catch { Write-Host "    Problem: $($_.Exception.Message)" -ForegroundColor Yellow; $failed += $e.Id }
  }
}
if ($mapSel.Count) {
  Write-Host 'Offline maps...'
  foreach ($e in @(Get-MapDownloadSet $mapSel)) {
    try { if (-not (Install-Map $e)) { $failed += $e.Id } } catch { Write-Host "    Problem: $($_.Exception.Message)" -ForegroundColor Yellow; $failed += $e.Id }
  }
}
Write-MapsIndex

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
        $null | & $ollama pull $m.Name 2>&1 | ForEach-Object { "$_" -replace "\x1b\[[0-9;?]*[A-Za-z]", '' } |
          Where-Object { $_ -match '\S' -and $_ -notmatch 'pulling manifest|\d+%' } | ForEach-Object { Write-Host "    $($_.Trim())" }
      } else { $null | & $ollama pull $m.Name }
      $pullCode = $LASTEXITCODE
      $ErrorActionPreference = $eap
      if ($pullCode -eq 0) { $ok = $true } else { Write-Host '    Retrying in 20 seconds...' -ForegroundColor Yellow; Start-Sleep -Seconds 20 }
    }
    if (-not $ok) { $failed += $m.Name; continue }
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $reply = $null | & $ollama run $m.Name 'Reply with just the word OK.' 2>$null
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
