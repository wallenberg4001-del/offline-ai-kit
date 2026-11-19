# One-time setup for the Offline AI Kit (needs internet). Safe to run again:
# finished downloads are skipped, half-finished ones resume.
param([string]$Tier = '', [string]$Models = '', [switch]$Yes)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Offline AI - setup'

function Ask([string]$Question, [string]$Default) {
  if ($Yes) { return $Default }
  $a = Read-Host "$Question [$Default]"
  if ([string]::IsNullOrWhiteSpace($a)) { return $Default }
  return $a.Trim()
}

Write-Host '=================================================='
Write-Host '  Offline AI Kit - setup'
Write-Host '  Downloads everything once, so it all works later with NO internet.'
Write-Host '=================================================='
Write-Host ''
if (-not $script:IsWin) { Write-Host 'Note: this kit is built for Windows. Continuing anyway.' -ForegroundColor Yellow }
$null = Get-CurlExe

# ---------- 1. Install folder ----------
Write-Host "The kit will live in this folder (any drive is fine, e.g. an external SSD):"
Write-Host "  $Kit"
$target = Ask 'Press Enter to keep it, or type a different folder' $Kit
$target = [System.IO.Path]::GetFullPath($target)
if ($target.TrimEnd('\','/') -ne $Kit.TrimEnd('\','/')) {
  Write-Host "Copying the kit files to $target ..."
  New-Item -ItemType Directory -Force -Path $target | Out-Null
  foreach ($item in @('scripts','www','mac','SETUP.bat','START-OFFLINE-AI.bat','STOP-OFFLINE-AI.bat','STATUS.bat','SETUP-MAC.command','START-OFFLINE-AI-MAC.command','STOP-OFFLINE-AI-MAC.command','STATUS-MAC.command','README.md','README-OUTAGE.txt','LICENSE')) {
    $src = Join-Path $Kit $item
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination $target -Recurse -Force }
  }
  Write-Host 'Continuing setup in the new folder...'
  $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $target 'scripts\setup.ps1'))
  if ($Tier) { $argList += @('-Tier',$Tier) }
  if ($Models) { $argList += @('-Models',$Models) }
  if ($Yes) { $argList += '-Yes' }
  & (Get-Process -Id $PID).Path @argList
  exit $LASTEXITCODE
}
Ensure-Dirs
try { Get-ChildItem -LiteralPath $Kit -Recurse -Include *.ps1,*.bat,*.html -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue } catch {}

# ---------- 2. Choices ----------
Write-Host ''
Write-Host 'Which library do you want? (Full English Wikipedia ~127 GB is ALWAYS included;'
Write-Host 'it downloads in the background the first time you start the kit.)'
Write-Host '  1) Essentials   - survival, first aid, water, food, knots, WikiMed   (~4 GB)'
Write-Host '  2) Recommended  - Essentials + Wikipedia Medicine, Wikivoyage,'
Write-Host '                    iFixit repair guides, Gardening Q&A               (~11 GB)'
if (-not $Tier) { $Tier = Ask 'Type 1 or 2' '2' }
$tierName = 'recommended'; if ($Tier -eq '1' -or $Tier -eq 'essentials') { $tierName = 'essentials' }

Write-Host ''
Write-Host 'Which AI models?'
Write-Host '  1) Core  - qwen3.5:9b, llama3.2:3b, phi4-mini, medgemma:4b              (~15 GB)'
Write-Host '  2) All   - Core + gemma3:4b, gemma3:12b, qwen3:14b (best use of the GPU) (~35 GB)'
if (-not $Models) { $Models = Ask 'Type 1 or 2' '2' }
$modelSet = 'full'; if ($Models -eq '1' -or $Models -eq 'core') { $modelSet = 'core' }

$zimEntries = @($ZimCatalog | Where-Object { $_.Tier -eq 'essentials' -or ($tierName -eq 'recommended' -and $_.Tier -eq 'recommended') })
$modelList  = @($ModelCatalog | Where-Object { $_.Set -eq 'core' -or $modelSet -eq 'full' })

$estGB = 3.5   # programs
if ($tierName -eq 'essentials') { $estGB += 4 } else { $estGB += 11 }
foreach ($m in $modelList) { $estGB += $m.GB }
$free = Get-FreeBytes $Kit
Write-Host ''
Write-Host ("Setup now needs about {0:N0} GB. Wikipedia later needs about 127 GB more (total ~{1:N0} GB)." -f $estGB, ($estGB + 127))
Write-Host ("Free space on this drive: {0}" -f (Format-GB $free))
if ($free -lt ($estGB * 1e9)) { Write-Host 'Not enough free space for setup. Free up space or choose another drive.' -ForegroundColor Red; exit 1 }
if ($free -lt (($estGB + 140) * 1e9)) { Write-Host 'WARNING: there will not be enough room for full Wikipedia (~127 GB) on this drive.' -ForegroundColor Yellow }

@{ tier=$tierName; models=$modelSet; created=(Get-Date -Format 'yyyy-MM-dd') } | ConvertTo-Json | Set-Content -LiteralPath $ConfigFile -Encoding UTF8

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
if (Get-OllamaExe) { Write-Host '  Already installed.' -ForegroundColor Green }
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
      & $ollama pull $m.Name
      if ($LASTEXITCODE -eq 0) { $ok = $true } else { Write-Host '    Retrying in 20 seconds...' -ForegroundColor Yellow; Start-Sleep -Seconds 20 }
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
Write-Host 'NEXT: double-click START-OFFLINE-AI.bat.'
Write-Host 'The first start also begins downloading FULL English Wikipedia (~127 GB) in the'
Write-Host 'background. Leave the PC on and online until it finishes (could be many hours).'
$go = Ask 'Start the kit now? (Y/N)' 'Y'
if ($go -match '^[Yy]') { & (Join-Path $PSScriptRoot 'start.ps1') }
