# Erases one USB disk or one partition and formats it as exFAT named OFFLINEAI.
# modelsGB, when the whole disk is erased, also makes an NTFS volume named AI-DRIVE
# for a Windows PC to store LLM models. OFFLINEAI gets the rest of the disk.
# Reads one JSON object on stdin, or from -RequestFile.
# -List prints external disks as JSON and does not erase anything.
# Refuses the startup disk (IsSystem or IsBoot) and any disk that is not USB.
param(
  [switch]$List,
  [string]$RequestFile = ''
)
$ErrorActionPreference = 'Stop'

function Escape-JsonText([string]$s) {
  if ($null -eq $s) { return '' }
  return $s.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", ' ')
}
function Write-Refuse([string]$Message) {
  Write-Output "Refused: $Message"
  exit 1
}
function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($id)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-DiskListJson {
  $items = @()
  try { $disks = @(Get-Disk) } catch { return '[]' }
  foreach ($disk in $disks) {
    if ($disk.BusType -ne 'USB') { continue }
    if ($disk.IsSystem -or $disk.IsBoot) { continue }
    $parts = @()
    $partitions = @()
    try { $partitions = @(Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue) } catch { $partitions = @() }
    foreach ($part in $partitions) {
      $gpt = [string]$part.GptType
      if ($part.Type -eq 'System' -or $part.Type -eq 'Reserved') { continue }
      if ($gpt -match '(?i)c12a7328-f81f-11d2-ba4b-00a0c93ec93b|e3c9e316-0e5b-4db5-817d-f92df00215ae') { continue }
      $name = ''
      $fmt = ''
      $mount = ''
      try {
        $vol = Get-Volume -Partition $part -ErrorAction SilentlyContinue
        if ($vol) {
          $name = [string]$vol.FileSystemLabel
          $fmt = [string]$vol.FileSystem
          if ($vol.DriveLetter) { $mount = "$($vol.DriveLetter):\" }
        }
      } catch {}
      if (-not $name) { $name = "Partition $($part.PartitionNumber)" }
      $size = 0
      if ($part.Size) { $size = [math]::Round(([double]$part.Size / 1000000000), 1) }
      $sizeText = $size.ToString([System.Globalization.CultureInfo]::InvariantCulture)
      $id = "$($disk.Number):$($part.PartitionNumber)"
      $parts += ('{"id":"' + (Escape-JsonText $id) + '","name":"' + (Escape-JsonText $name) + '","format":"' + (Escape-JsonText $fmt) + '","sizeGB":' + $sizeText + ',"mount":"' + (Escape-JsonText $mount) + '"}')
    }
    $diskSize = 0
    if ($disk.Size) { $diskSize = [math]::Round(([double]$disk.Size / 1000000000), 1) }
    $diskText = $diskSize.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    $items += ('{"id":"' + $disk.Number + '","sizeGB":' + $diskText + ',"internal":false,"startup":false,"partitions":[' + ($parts -join ',') + ']}')
  }
  return '[' + ($items -join ',') + ']'
}

if ($List) {
  Write-Output (Get-DiskListJson)
  exit 0
}

$raw = ''
if ($RequestFile) {
  if (-not (Test-Path -LiteralPath $RequestFile)) { Write-Refuse 'The request could not be read.' }
  $raw = [System.IO.File]::ReadAllText($RequestFile)
} else {
  $raw = [Console]::In.ReadToEnd()
}
if (-not $raw) { Write-Refuse 'The request could not be read.' }
try { $data = $raw | ConvertFrom-Json } catch { Write-Refuse 'The request could not be read.' }
$confirmed = $false
if ($data.confirmed -eq $true -or [string]$data.confirmed -eq 'true') { $confirmed = $true }
if (-not $confirmed) { Write-Refuse 'Tick the box before erasing.' }

$diskId = [string]$data.disk
if ($diskId -notmatch '^\d+$') { Write-Refuse 'Pick a disk.' }
$num = [int]$diskId
$mode = [string]$data.mode
if ($mode -ne 'partition' -and $mode -ne 'disk') { Write-Refuse 'Pick what to erase.' }

$disk = $null
try { $disk = Get-Disk -Number $num } catch { Write-Refuse 'That disk is not on this computer.' }
if ($disk.IsSystem -or $disk.IsBoot) { Write-Refuse 'That disk is the startup disk. It cannot be erased.' }
if ($disk.BusType -ne 'USB') { Write-Refuse 'That disk is not a USB disk. The startup disk cannot be erased.' }

$pageSize = 0.0
if ($data.diskSizeGB) { $pageSize = [double]$data.diskSizeGB }
if ($pageSize -le 0) { Write-Refuse 'The disk size was not confirmed.' }
$actual = [double]$disk.Size / 1000000000
$diff = [math]::Abs($actual - $pageSize) / $pageSize
if ($diff -gt 0.05) { Write-Refuse 'That disk is a different size from the one on the page. Look again. The startup disk was not touched.' }

$sizeGB = 0.0
if ($data.sizeGB) { $sizeGB = [double]$data.sizeGB }
$modelsGB = 0.0
if ($data.modelsGB) { $modelsGB = [double]$data.modelsGB }
if ($mode -eq 'partition' -and $modelsGB -gt 0) { Write-Refuse 'The Windows drive is only made when the whole disk is erased. Nothing was erased.' }
if ($modelsGB -gt 0 -and $modelsGB -lt 200) { Write-Refuse 'The Windows drive needs at least 200 GB. Nothing was erased.' }
if ($modelsGB -gt 0) {
  $kitGB = $sizeGB
  if ($kitGB -le 0) { $kitGB = $actual - $modelsGB }
  if ($kitGB -lt 199) { Write-Refuse 'The Windows drive does not leave 200 GB for the kit. Nothing was erased.' }
  if ($sizeGB -gt 0 -and ($sizeGB + $modelsGB) -gt ($actual + 1)) { Write-Refuse 'Those sizes do not fit on this disk. Nothing was erased.' }
}
if (-not (Test-Admin)) { Write-Refuse 'Preparing a disk needs an Administrator window. The startup disk was not touched.' }

function Get-Letter([int]$DiskNumber, [int]$PartitionNumber) {
  $part = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber
  if ($part.DriveLetter) { return [string]$part.DriveLetter }
  Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber -AssignDriveLetter | Out-Null
  $part = Get-Partition -DiskNumber $DiskNumber -PartitionNumber $PartitionNumber
  if ($part.DriveLetter) { return [string]$part.DriveLetter }
  return ''
}

if ($mode -eq 'partition') {
  $partId = [string]$data.partitionId
  if ($partId -notmatch '^(\d+):(\d+)$') { Write-Refuse 'That partition is not on this disk.' }
  if ([int]$Matches[1] -ne $num) { Write-Refuse 'That partition is not on this disk.' }
  $partNum = [int]$Matches[2]
  $part = $null
  try { $part = Get-Partition -DiskNumber $num -PartitionNumber $partNum } catch { Write-Refuse 'That partition is not on this disk.' }
  $gpt = [string]$part.GptType
  if ($part.Type -eq 'System' -or $part.Type -eq 'Reserved' -or $gpt -match '(?i)c12a7328-f81f-11d2-ba4b-00a0c93ec93b|e3c9e316-0e5b-4db5-817d-f92df00215ae') {
    Write-Refuse 'That partition is a system partition. The startup disk was not touched.'
  }
  Write-Output 'Erasing the chosen partition and formatting it as exFAT, named OFFLINEAI.'
  try {
    Format-Volume -Partition $part -FileSystem exFAT -NewFileSystemLabel 'OFFLINEAI' -Confirm:$false -Force | Out-Null
  } catch {
    Write-Output ('The erase did not finish. ' + $_.Exception.Message)
    exit 1
  }
  $letter = Get-Letter $num $partNum
  if (-not $letter) { Write-Output 'The volume was formatted, but it did not mount.'; exit 1 }
  Write-Output "PREPARED ${letter}:\"
  exit 0
}

if ($sizeGB -gt 0 -and $sizeGB -lt 200) { Write-Refuse 'That size does not fit on this disk.' }
if ($sizeGB -gt ($actual + 1)) { Write-Refuse 'That size does not fit on this disk.' }
if ($modelsGB -gt 0) {
  Write-Output "Erasing the whole disk. AI-DRIVE gets $modelsGB GB for a Windows PC to store LLM models. OFFLINEAI gets the rest for the kit."
} else {
  Write-Output 'Erasing the whole disk and formatting it as exFAT, named OFFLINEAI.'
}
try {
  Clear-Disk -Number $num -RemoveData -RemoveOEM -Confirm:$false
  $again = Get-Disk -Number $num
  if ($again.PartitionStyle -eq 'RAW' -or [string]$again.PartitionStyle -eq 'Unknown') {
    Initialize-Disk -Number $num -PartitionStyle GPT
  }
  if ($modelsGB -gt 0) {
    $modelsBytes = [uint64]($modelsGB * 1000000000)
    $modelsPart = New-Partition -DiskNumber $num -Size $modelsBytes -AssignDriveLetter
    Format-Volume -Partition $modelsPart -FileSystem NTFS -NewFileSystemLabel 'AI-DRIVE' -Confirm:$false -Force | Out-Null
    $created = New-Partition -DiskNumber $num -UseMaximumSize -AssignDriveLetter
  } elseif ($sizeGB -gt 0 -and ($actual - $sizeGB) -ge 1) {
    $bytes = [uint64]($sizeGB * 1000000000)
    $created = New-Partition -DiskNumber $num -Size $bytes -AssignDriveLetter
  } else {
    $created = New-Partition -DiskNumber $num -UseMaximumSize -AssignDriveLetter
  }
  Format-Volume -Partition $created -FileSystem exFAT -NewFileSystemLabel 'OFFLINEAI' -Confirm:$false -Force | Out-Null
} catch {
  Write-Output ('The erase did not finish. ' + $_.Exception.Message)
  exit 1
}
$letter = ''
if ($created.DriveLetter) { $letter = [string]$created.DriveLetter }
if (-not $letter) { $letter = Get-Letter $num $created.PartitionNumber }
if (-not $letter) { Write-Output 'The volume was formatted, but it did not mount.'; exit 1 }
Write-Output "PREPARED ${letter}:\"
exit 0
