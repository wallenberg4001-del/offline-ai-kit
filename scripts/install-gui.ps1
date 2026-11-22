# Guided installer for Windows. Opens a browser on this computer only.
# The page explains every choice. Install runs setup.ps1 with those answers.
# Nothing is downloaded until the page says Install.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

function Escape-JsonText([string]$s) {
  if ($null -eq $s) { return '' }
  return $s.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", ' ')
}
function Quote-Cmd([string]$s) {
  return '"' + $s.Replace('"', '') + '"'
}
function Read-SharedText([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return '' }
  $fs = $null
  try {
    $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
    return $sr.ReadToEnd()
  } catch { return '' }
  finally { if ($fs) { $fs.Dispose() } }
}
function Send-Response($Res, [int]$Code, [string]$Type, [string]$Body) {
  if ($null -eq $Body) { $Body = '' }
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
  $Res.StatusCode = $Code
  $Res.ContentType = $Type
  $Res.ContentLength64 = $bytes.Length
  $Res.Headers['Cache-Control'] = 'no-store'
  $Res.OutputStream.Write($bytes, 0, $bytes.Length)
  $Res.Close()
}
function Send-File($Res, [string]$Path, [string]$Type) {
  if (-not (Test-Path -LiteralPath $Path)) { Send-Response $Res 404 'text/plain; charset=utf-8' "Missing file.`n"; return }
  $text = [System.IO.File]::ReadAllText($Path)
  Send-Response $Res 200 $Type $text
}
function Test-IdList($Value) {
  $items = @()
  if ($null -eq $Value) { return @() }
  if ($Value -is [System.Array]) { $items = @($Value) } else { $items = @($Value) }
  foreach ($id in $items) {
    if ($id -notmatch '^[a-z0-9-]+$') { throw 'A choice was not recognised.' }
  }
  return @($items)
}

if ($Kit -match '[&|<>^%]') {
  Write-Host 'This folder path has a character the installer cannot use (& | < > ^ %).' -ForegroundColor Red
  Write-Host 'Move the folder to a simpler path, such as C:\OfflineAI, and run it again.'
  exit 1
}

$hw = Get-Hardware
$gpuText = 'no NVIDIA graphics card found'
if ($hw.Gpu) {
  $gpuText = $hw.Gpu
  if ($hw.VramGB -gt 0) { $gpuText += " ($($hw.VramGB) GB)" }
}
$profile = Get-HardwareProfile $hw
if (-not $Profiles.Contains($profile)) { $profile = 'standard' }
$suggested = @{ lite = '0'; standard = '1'; full = '2' }[$profile]
if (-not $suggested) { $suggested = '1' }
$tier = '2'
if ($Profiles[$profile].Tier -eq 'essentials') { $tier = '1' }
$wiki = 'false'
if ($hw.FreeGB -ge 170) { $wiki = 'true' }
$extra = Get-UniversalExtraGB
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$ramText = $hw.RamGB.ToString($inv)
$freeText = $hw.FreeGB.ToString($inv)
$extraText = $extra.ToString($inv)
$computer = "Windows PC, $ramText GB memory, $gpuText, $freeText GB free on this drive"
$contextJson = '{"os":"windows","family":"windows","ramGB":' + $ramText + ',"freeGB":' + $freeText + ',"suggestedModels":"' + $suggested + '","suggestedTier":"' + $tier + '","suggestedWikipedia":' + $wiki + ',"universalExtraGB":' + $extraText + ',"programsGB":2.5,"aiAvailable":true,"intelModels":"","computer":"' + (Escape-JsonText $computer) + '","folder":"' + (Escape-JsonText $Kit) + '"}'

$script:InstallProc = $null
$script:LogFile = Join-Path $Kit 'logs\install-gui.log'

$listener = New-Object System.Net.HttpListener
$port = 0
foreach ($try in 8092, 8093, 8094, 8095) {
  $listener.Prefixes.Clear()
  $listener.Prefixes.Add("http://127.0.0.1:$try/")
  try { $listener.Start(); $port = $try; break } catch { $listener = New-Object System.Net.HttpListener }
}
if (-not $port) {
  Write-Host 'Could not open the guided installer (ports 8092-8095 are in use).' -ForegroundColor Red
  Write-Host 'Use SETUP.bat instead. It asks the same questions in a text window.'
  exit 1
}
$url = "http://127.0.0.1:$port/"
Write-Host "Guided installer is open in your web browser:"
Write-Host "  $url"
Write-Host 'Leave this window open. Closing it stops the installer.'
Write-Host 'Nothing is downloaded until you press Install on the last screen.'
Start-Process $url

while ($listener.IsListening) {
  $ctx = $null
  try { $ctx = $listener.GetContext() } catch { break }
  try {
    $req = $ctx.Request
    $res = $ctx.Response
    $path = $req.Url.AbsolutePath
    if ($req.HttpMethod -eq 'GET' -and ($path -eq '/' -or $path -eq '/install-wizard.html')) {
      Send-File $res (Join-Path $WwwDir 'install-wizard.html') 'text/html; charset=utf-8'
    } elseif ($req.HttpMethod -eq 'GET' -and $path -eq '/install-wizard.js') {
      Send-File $res (Join-Path $WwwDir 'install-wizard.js') 'text/javascript; charset=utf-8'
    } elseif ($req.HttpMethod -eq 'GET' -and $path -eq '/catalog/extra-libraries.txt') {
      Send-File $res (Join-Path $Kit 'catalog\extra-libraries.txt') 'text/plain; charset=utf-8'
    } elseif ($req.HttpMethod -eq 'GET' -and $path -eq '/catalog/maps.txt') {
      Send-File $res (Join-Path $Kit 'catalog\maps.txt') 'text/plain; charset=utf-8'
    } elseif ($req.HttpMethod -eq 'GET' -and $path -eq '/api/context') {
      Send-Response $res 200 'application/json; charset=utf-8' $contextJson
    } elseif ($req.HttpMethod -eq 'GET' -and $path -eq '/api/log') {
      $running = $false
      $exitCode = $null
      if ($script:InstallProc) {
        try { $script:InstallProc.Refresh() } catch {}
        if ($script:InstallProc.HasExited) { $exitCode = $script:InstallProc.ExitCode; $script:InstallProc = $null }
        else { $running = $true }
      }
      $text = Read-SharedText $script:LogFile
      if ($text.Length -gt 20000) { $text = $text.Substring($text.Length - 20000) }
      $text = Escape-JsonText $text
      $run = 'false'; if ($running) { $run = 'true' }
      $json = '{"running":' + $run + ',"text":"' + $text + '"'
      if ($null -ne $exitCode) { $json += ',"exit":' + $exitCode }
      $json += '}'
      Send-Response $res 200 'application/json; charset=utf-8' $json
    } elseif ($req.HttpMethod -eq 'POST' -and $path -eq '/api/install') {
      if ($script:InstallProc -and -not $script:InstallProc.HasExited) {
        Send-Response $res 409 'text/plain; charset=utf-8' "An install is already running.`n"
        continue
      }
      $reader = New-Object System.IO.StreamReader($req.InputStream, $req.ContentEncoding)
      $raw = $reader.ReadToEnd()
      $reader.Close()
      $data = $raw | ConvertFrom-Json
      $models = [string]$data.models
      $tierChoice = [string]$data.tier
      if ($models -and $models -notmatch '^(lite|8|16|24|32|0|1|2|core|full|[A-Za-z0-9_.:-]+(,[A-Za-z0-9_.:-]+)*)$') { throw 'Choose an AI size.' }
      if ($tierChoice -notmatch '^(1|2|essentials|recommended)$') { throw 'Choose a library.' }
      $extras = @(Test-IdList $data.extras)
      $maps = @(Test-IdList $data.maps)
      $share = $false
      if ($data.shareWifi -eq $true -or [string]$data.shareWifi -eq 'true') { $share = $true }
      $universal = $false
      if ($data.universal -eq $true -or [string]$data.universal -eq 'true') { $universal = $true }
      $wikiOn = $false
      if ($data.wikipedia -eq $true -or [string]$data.wikipedia -eq 'true') { $wikiOn = $true }
      New-Item -ItemType Directory -Force -Path (Join-Path $Kit 'logs') | Out-Null
      if (Test-Path -LiteralPath $script:LogFile) { Remove-Item -LiteralPath $script:LogFile -Force }
      $setup = Join-Path $PSScriptRoot 'setup.ps1'
      $bat = Join-Path $Kit 'logs\install-run.bat'
      $lines = @('@echo off', ('cd /d ' + (Quote-Cmd $Kit)), 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File ' + (Quote-Cmd $setup) + ' -Yes')
      if ($models) { $lines[-1] += ' -Models ' + $models }
      $lines[-1] += ' -Tier ' + $tierChoice
      if ($wikiOn) { $lines[-1] += ' -WithWikipedia' } else { $lines[-1] += ' -SkipWikipedia' }
      if ($extras.Count) { $lines[-1] += ' -ExtraLibraries ' + ($extras -join ',') }
      if ($maps.Count) { $lines[-1] += ' -Maps ' + ($maps -join ',') }
      if ($share) { $lines[-1] += ' -ShareWifi' } else { $lines[-1] += ' -NoShareWifi' }
      if ($universal) { $lines[-1] += ' -Universal' } else { $lines[-1] += ' -ThisComputer' }
      $lines[-1] += ' > ' + (Quote-Cmd $script:LogFile) + ' 2>&1'
      $lines += 'exit /b %ERRORLEVEL%'
      Set-Content -LiteralPath $bat -Value $lines -Encoding ASCII
      $script:InstallProc = Start-Process -FilePath $bat -WorkingDirectory $Kit -PassThru -WindowStyle Minimized
      Send-Response $res 200 'application/json; charset=utf-8' '{"ok":true}'
    } else {
      Send-Response $res 404 'text/plain; charset=utf-8' "Not found.`n"
    }
  } catch {
    try { Send-Response $ctx.Response 400 'text/plain; charset=utf-8' ($_.Exception.Message + "`n") } catch {}
  }
}
