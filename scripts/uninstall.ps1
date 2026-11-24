# Removes the Offline AI Kit from this computer only.
# The drive is not changed. Library files, models, and programs stay.
#   -Yes      uninstall without the question
#   -DryRun   list the computer items, then stop
#   -Root DIR check DIR instead of this folder. Only allowed with -DryRun.
param(
  [switch]$Yes,
  [switch]$DryRun,
  [string]$Root = ''
)
$ErrorActionPreference = 'Stop'

function Write-Refuse([string]$Message) {
  Write-Output "Refused: $Message"
  exit 1
}

if ($Root -and -not $DryRun) { Write-Refuse 'Checking another folder needs -DryRun. Nothing was deleted.' }

$target = $Root
if (-not $target) {
  $here = $PSScriptRoot
  if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
  $target = Split-Path -Parent $here
}
try { $target = [System.IO.Path]::GetFullPath($target) } catch { Write-Refuse 'That folder is not a kit folder. Nothing was deleted.' }
$target = $target.TrimEnd('\')
$root = ''
try { $root = [System.IO.Path]::GetPathRoot($target).TrimEnd('\') } catch { $root = '' }
if (-not $target -or ($root -and $target -eq $root)) {
  Write-Refuse 'This copy is the whole drive, not a folder on it. The uninstaller will not erase a whole drive. Nothing was deleted.'
}
$home = ''
if ($env:USERPROFILE) { $home = [System.IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') }
if ($home -and $target -eq $home) { Write-Refuse 'That folder is your home folder. Nothing was deleted.' }
$version = Join-Path $target 'VERSION'
$scripts = Join-Path $target 'scripts'
$mac = Join-Path $target 'mac'
if (-not (Test-Path -LiteralPath $version) -or ((-not (Test-Path -LiteralPath $scripts)) -and (-not (Test-Path -LiteralPath $mac)))) {
  Write-Refuse 'This folder does not look like the Offline AI Kit. Nothing was deleted.'
}

Write-Output 'Remove the Offline AI Kit from this computer?'
Write-Output "  $target"
Write-Output ''
Write-Output 'Your drive, library, Wikipedia and AI models are not touched.'
Write-Output 'This removes the Desktop shortcut if it starts this copy,'
Write-Output 'and the small cache this kit put on this computer.'
Write-Output ''
Write-Output 'The drive was not changed. Plug it into any computer and run START to use it again.'

function Test-SameOrUnder([string]$Path, [string]$Root) {
  if (-not $Path -or -not $Root) { return $false }
  $p = $Path.TrimEnd('\', '/')
  $r = $Root.TrimEnd('\', '/')
  if ($p.Equals($r, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
  return $p.StartsWith($r + '\', [System.StringComparison]::OrdinalIgnoreCase)
}
function Test-TextHasPath([string]$Text, [string]$Root) {
  if (-not $Text -or -not $Root) { return $false }
  $r = $Root.TrimEnd('\')
  $i = 0
  while ($true) {
    $j = $Text.IndexOf($r, $i, [System.StringComparison]::OrdinalIgnoreCase)
    if ($j -lt 0) { return $false }
    $after = $j + $r.Length
    if ($after -ge $Text.Length) { return $true }
    $c = $Text[$after]
    if ($c -eq '\' -or $c -eq '/' -or $c -eq '"' -or $c -eq "'" -or [char]::IsWhiteSpace($c)) { return $true }
    $i = $j + 1
  }
}

if ($DryRun) { Write-Output 'RESULT: UNINSTALL DRY RUN'; exit 0 }
if (-not $Yes) {
  $answer = Read-Host 'Type YES to continue'
  if ($answer -ne 'YES') { Write-Output 'Nothing was deleted.'; exit 0 }
}

$env:OFFLINE_AI_KIT = $target
. (Join-Path $PSScriptRoot 'common.ps1')
# common.ps1 sets $Kit from its own folder. Point the guard at the folder we checked.
$script:Kit = $target
$global:Kit = $target

foreach ($n in @('kiwix','ollama','chat-server','add-libraries','add-maps','wikipedia-download')) {
  try { Stop-KitProcess $n } catch {}
}
$desk = ''
try { $desk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Offline AI.lnk' } catch { $desk = '' }
if ($desk -and (Test-Path -LiteralPath $desk)) {
  $text = ''
  try { $text = Get-Content -LiteralPath $desk -Raw -ErrorAction SilentlyContinue } catch {}
  if (Test-TextHasPath $text $target) {
    if (Remove-KitComputerItem $desk) { Write-Output "Removed shortcut: $desk" }
  }
}
$receipt = ''
try { $receipt = Get-ComputerReceiptPath } catch { $receipt = '' }
if ($receipt -and (Test-Path -LiteralPath $receipt)) {
  foreach ($line in Get-Content -LiteralPath $receipt) {
    $bits = $line.Split('|')
    if ($bits.Count -lt 2) { continue }
    $item = $bits[1].Trim()
    if (-not $item) { continue }
    if (Remove-KitComputerItem $item) { Write-Output "Removed $($bits[0].Trim()): $item" }
  }
  if (Remove-KitComputerItem $receipt) { Write-Output "Removed receipt: $receipt" }
}
try {
  Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'Offline AI*' } | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output ("Removed scheduled task: " + $_.TaskName)
  }
} catch {}
try {
  $prop = Get-ItemProperty -Path 'HKCU:\Environment' -Name Path -ErrorAction SilentlyContinue
  if ($prop -and $prop.Path -and $prop.Path.ToLower().Contains($target.ToLower())) {
    $kept = @($prop.Path.Split(';') | Where-Object { $_ -and -not (Test-SameOrUnder $_ $target) })
    Set-ItemProperty -Path 'HKCU:\Environment' -Name Path -Value ($kept -join ';')
    Write-Output 'Removed kit folders from HKCU Environment\Path.'
  }
} catch {}
try {
  if (Test-Path 'HKCU:\Software\OfflineAIKit') {
    Remove-Item -Path 'HKCU:\Software\OfflineAIKit' -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output 'Removed HKCU Software\OfflineAIKit.'
  }
} catch {}
$localKit = Join-Path $env:LOCALAPPDATA 'OfflineAIKit'
if (Test-Path -LiteralPath $localKit) {
  if (Remove-KitComputerItem $localKit) { Write-Output "Removed state: $localKit" }
}
try {
  $rules = Get-NetFirewallApplicationFilter -ErrorAction Stop | Where-Object { $_.Program -and $_.Program.ToLower().StartsWith($target.ToLower()) }
  if ($rules) {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($admin) {
      $rules | ForEach-Object { Remove-NetFirewallRule -AssociatedNetFirewallApplicationFilter $_ -ErrorAction SilentlyContinue }
    } else {
      Write-Output 'Windows Firewall rules for this kit are still here. Remove them from Windows Security, Firewall, Allow an app, or run this uninstaller as Administrator.'
    }
  }
} catch {}
$logDir = Join-Path $target 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Add-Content -LiteralPath (Join-Path $logDir 'uninstall-windows.log') -Value ((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') + ' computer-only uninstall') -Encoding ASCII
Get-ChildItem -LiteralPath $logDir -Filter '*.windows.pid' -ErrorAction SilentlyContinue | ForEach-Object { [System.IO.File]::Delete($_.FullName) }
Write-Output 'The drive was not changed. Plug it into any computer and run START to use it again.'
Write-Output 'RESULT: UNINSTALL OK'
