# Drive tools. Separate from Uninstall. Deletes chosen library or model files,
# the whole kit folder, or asks prepare-disk to erase the kit partition.
# Erase does not accept -Yes.
param(
  [string]$Action = '',
  [string]$Files = '',
  [string]$Scope = 'partition',
  [string]$Phrase = '',
  [string]$EraseWord = '',
  [switch]$Yes,
  [switch]$IUnderstandThisDeletesData,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

function Fail-Drive([string]$Message) {
  Write-Output $Message
  Write-Output 'Nothing was deleted.'
  exit 1
}

if ($Action -eq 'erase' -and $Yes) { Fail-Drive '--yes is not accepted for erase.' }
if ($Action -ne 'erase' -and $Yes -and -not $IUnderstandThisDeletesData) {
  Fail-Drive '--yes needs --i-understand-this-deletes-data.'
}
if (-not $Action) {
  Write-Output 'Drive tools. Nothing is selected.'
  Write-Output 'Pressing Return does nothing.'
  $pick = Read-Host 'Type 1, 2, or 3'
  if ($pick -eq '1') { $Action = 'library' }
  elseif ($pick -eq '2') { $Action = 'kit' }
  elseif ($pick -eq '3') { $Action = 'erase' }
  else { Write-Output 'Nothing selected. Nothing was deleted.'; exit 0 }
}
Write-Output 'Nothing has been deleted yet.'
Write-Output 'This permanently deletes files from the drive. It cannot be undone. The drive will need internet to download this again.'
if ($DryRun) { Write-Output 'RESULT: DRIVE TOOLS DRY RUN'; exit 0 }
if ($Action -eq 'library') {
  $names = @($Files.Split(',') | Where-Object { $_ })
  $want = 'DELETE {0} FILES' -f $names.Count
  if (-not $Yes -and $Phrase -ne $want) { Write-Output 'Cancelled. Nothing was deleted.'; exit 0 }
  $probeDir = Join-Path $Checksums 'PROBE'
  foreach ($name in $names) {
    $leaf = Split-Path -Leaf $name
    $path = Join-Path $Library $leaf
    if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $ModelsDir $leaf }
    if (-not (Test-Path -LiteralPath $path)) { Fail-Drive "Not on this drive: $name" }
    $full = [System.IO.Path]::GetFullPath($path)
    $libRoot = [System.IO.Path]::GetFullPath($Library)
    $modelRoot = [System.IO.Path]::GetFullPath($ModelsDir)
    if (-not $libRoot.EndsWith('\')) { $libRoot = $libRoot + '\' }
    if (-not $modelRoot.EndsWith('\')) { $modelRoot = $modelRoot + '\' }
    $underLib = $full.StartsWith($libRoot, [System.StringComparison]::OrdinalIgnoreCase)
    $underModel = $full.StartsWith($modelRoot, [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $underLib -and -not $underModel) { Fail-Drive "Refused (outside the library): $name" }
    [System.IO.File]::Delete($full)
    $verified = Join-Path $VerifiedDir $leaf
    if (Test-Path -LiteralPath $verified) { [System.IO.File]::Delete($verified) }
    $probeFile = Join-Path $probeDir $leaf
    if (Test-Path -LiteralPath $probeFile) { [System.IO.File]::Delete($probeFile) }
    Write-Output "Deleted $leaf"
  }
  $xml = Join-Path $Library 'library.xml'
  if (Test-Path -LiteralPath $xml) {
    $keep = New-Object System.Collections.Generic.List[string]
    foreach ($line in [System.IO.File]::ReadAllLines($xml)) {
      $drop = $false
      foreach ($name in $names) {
        $leaf = Split-Path -Leaf $name
        if ($leaf -and $line.Contains($leaf)) { $drop = $true }
      }
      if (-not $drop) { [void]$keep.Add($line) }
    }
    [System.IO.File]::WriteAllLines($xml, $keep.ToArray())
  }
  try { Write-DriveManifest | Out-Null } catch {}
  Write-Output 'RESULT: DRIVE TOOLS OK'
  exit 0
}
if ($Action -eq 'kit') {
  if (-not $Yes -and $Phrase -ne 'REMOVE KIT FROM DRIVE') { Write-Output 'Cancelled. Nothing was deleted.'; exit 0 }
  [System.IO.Directory]::Delete($Kit, $true)
  Write-Output 'RESULT: DRIVE TOOLS OK'
  exit 0
}
if ($Action -eq 'erase') {
  $label = 'OFFLINEAI'
  if ($env:OFFLINE_AI_KIT_LABEL) { $label = $env:OFFLINE_AI_KIT_LABEL }
  if ($Phrase -ne $label -or $EraseWord -ne 'ERASE') { Write-Output 'Cancelled. Nothing was deleted.'; exit 0 }
  $others = $env:OFFLINE_AI_DISK_PARTITIONS
  if ($Scope -eq 'disk' -and $others) {
    Fail-Drive "This disk also has: $others. Erase the kit partition only."
  }
  $disk = $env:OFFLINE_AI_DISK_ID
  $part = $env:OFFLINE_AI_PARTITION_ID
  if (-not $disk) { Fail-Drive 'Could not see which disk this kit is on.' }
  if ($Scope -eq 'partition' -and -not $part) { Fail-Drive 'Could not see which partition this kit is on.' }
  if ($env:OFFLINE_AI_PREPARE_OUT) {
    $json = '{"confirmed":true,"mode":"' + $Scope + '","disk":"' + $disk + '","partitionId":"' + $part + '"}'
    Set-Content -LiteralPath $env:OFFLINE_AI_PREPARE_OUT -Value $json -Encoding ASCII
  }
  Write-Output 'RESULT: DRIVE TOOLS OK'
  exit 0
}
Fail-Drive 'Pick an action.'
