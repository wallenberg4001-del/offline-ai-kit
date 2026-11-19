# Tiny local web server for the chat page (127.0.0.1 only, no Python needed).
# Serves files from the kit's www folder plus /status.json (Wikipedia download progress).
param([int]$Port = 0)
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Continue'
if ($Port -le 0) { $Port = $ChatPort }
$root = (Resolve-Path -LiteralPath $WwwDir).Path
$types = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.json'='application/json; charset=utf-8'; '.png'='image/png'; '.svg'='image/svg+xml'; '.ico'='image/x-icon'; '.txt'='text/plain; charset=utf-8' }

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Log 'chat-server.log' "listening on 127.0.0.1:$Port"

function Send-Response($stream, [int]$code, [string]$reason, [string]$ctype, [byte[]]$body) {
  $hdr = "HTTP/1.1 $code $reason`r`nContent-Type: $ctype`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $h = [System.Text.Encoding]::ASCII.GetBytes($hdr)
  $stream.Write($h, 0, $h.Length)
  if ($body.Length -gt 0) { $stream.Write($body, 0, $body.Length) }
  $stream.Flush()
}

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $client.ReceiveTimeout = 3000; $client.SendTimeout = 10000
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 4096, $true)
    $first = $reader.ReadLine()
    while ($true) { $l = $reader.ReadLine(); if ($null -eq $l -or $l -eq '') { break } }
    if (-not $first) { continue }
    $parts = $first.Split(' ')
    $path = [Uri]::UnescapeDataString(($parts[1] -split '\?')[0])
    if ($parts[0] -ne 'GET' -and $parts[0] -ne 'HEAD') { Send-Response $stream 405 'Method Not Allowed' 'text/plain' ([byte[]]@()); continue }
    if ($path -eq '/status.json') {
      $pf = Join-Path $LogDir 'wikipedia-progress.json'
      $json = '{"state":"unknown"}'
      $wv = Get-ChildItem -LiteralPath $VerifiedDir -Filter "$WikipediaPrefix*.zim" -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($wv) { $json = '{"state":"done","percent":100,"message":"Wikipedia ready"}' }
      elseif (Test-Path -LiteralPath $pf) { $json = (Get-Content -LiteralPath $pf -Raw) }
      Send-Response $stream 200 'OK' 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
      continue
    }
    if ($path -eq '/') { $path = '/chat.html' }
    $full = [System.IO.Path]::GetFullPath((Join-Path $root ($path.TrimStart('/'))))
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
      Send-Response $stream 404 'Not Found' 'text/plain' ([System.Text.Encoding]::ASCII.GetBytes('Not found'))
      continue
    }
    $ext = [System.IO.Path]::GetExtension($full).ToLower()
    $ct = $types[$ext]; if (-not $ct) { $ct = 'application/octet-stream' }
    $bytes = [System.IO.File]::ReadAllBytes($full)
    if ($parts[0] -eq 'HEAD') { $bytes = [byte[]]@() }
    Send-Response $stream 200 'OK' $ct $bytes
  } catch {
    Write-Log 'chat-server.log' ("request error: " + $_.Exception.Message)
  } finally {
    $client.Close()
  }
}
