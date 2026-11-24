# Offline check of this drive. No downloads.
param([switch]$Full, [switch]$Quick)
. (Join-Path $PSScriptRoot 'common.ps1')
$manifest = Join-Path $Kit 'DRIVE-MANIFEST.json'
if (-not (Test-Path -LiteralPath $manifest)) {
  Write-Output 'RESULT: DRIVE INCOMPLETE'
  Write-Output 'Missing DRIVE-MANIFEST.json'
  exit 1
}
$doc = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
$problems = @()
$i = 0
$n = @($doc.files).Count
foreach ($item in @($doc.files)) {
  $i++
  $full = Join-Path $Kit ($item.path -replace '/', '\')
  if (-not (Test-Path -LiteralPath $full)) { $problems += ('missing ' + $item.path); continue }
  $len = (Get-Item -LiteralPath $full).Length
  if ([int64]$item.size -ne $len) { $problems += ('size ' + $item.path); continue }
  if ($Full) {
    $sha = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLower()
    if ($sha -ne $item.sha256) { $problems += ('hash ' + $item.path) }
    if (($i % 20) -eq 0 -or $i -eq $n) { Write-Output ("Checked {0} of {1}" -f $i, $n) }
  }
}
if ($problems.Count) {
  Write-Output 'RESULT: DRIVE INCOMPLETE'
  $problems | ForEach-Object { Write-Output $_ }
  exit 1
}
Write-Output ("Verified: all {0} files match." -f $n)
Write-Output 'RESULT: DRIVE OK'
