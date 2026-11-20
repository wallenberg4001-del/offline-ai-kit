# Tiny web server for the chat page (no Python, no admin rights needed).
#   -Bind local : 127.0.0.1 only (default)          -Bind any : the home network too (Share on Wi-Fi)
# Serves the kit's www folder, /status.json (Wikipedia download progress) and /ollama/api/... :
# a small proxy to the kit's AI server, which itself only ever listens on 127.0.0.1.
# Only chat/listing endpoints are passed through (no pulling, deleting or creating models).
# It also passes the library's pages through read-only (/library, /content/..., /search, /catalog/...),
# so with Share on Wi-Fi only this one program is reachable; Kiwix and the AI server stay on 127.0.0.1.
# Uses TcpListener (not HttpListener, which needs admin rights for anything but localhost)
# and a pool of worker threads, so a long streaming answer never blocks other requests or phones.
param([int]$Port = 0, [string]$Bind = '')
. (Join-Path $PSScriptRoot 'common.ps1')
$ErrorActionPreference = 'Continue'
if ($Port -le 0) { $Port = $ChatPort }
if (-not $Bind) { if ($ShareOnWifi) { $Bind = 'any' } else { $Bind = 'local' } }
$addr = [System.Net.IPAddress]::Loopback
if ($Bind -eq 'any') { $addr = [System.Net.IPAddress]::Any }

$ctx = @{
  Root        = (Resolve-Path -LiteralPath $WwwDir).Path
  LogFile     = (Join-Path $LogDir 'chat-server.log')
  Progress    = (Join-Path $LogDir 'wikipedia-progress.json')
  VerifiedDir = $VerifiedDir
  WikiPrefix  = $WikipediaPrefix
  SkipWiki    = [bool]$SkipWikipedia
  OllamaPort  = $OllamaPort
  LibraryPort = $LibraryPort
  Types       = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.json'='application/json; charset=utf-8'; '.png'='image/png'; '.svg'='image/svg+xml'; '.ico'='image/x-icon'; '.txt'='text/plain; charset=utf-8' }
}

$handler = {
  param($client, $C)
  function Log([string]$t) { try { Add-Content -LiteralPath $C.LogFile -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ' + $t) } catch {} }
  function Send($s, [int]$code, [string]$reason, [string]$ctype, [byte[]]$body, [bool]$head) {
    $hdr = "HTTP/1.1 $code $reason`r`nContent-Type: $ctype`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n"
    $h = [System.Text.Encoding]::ASCII.GetBytes($hdr)
    $s.Write($h, 0, $h.Length)
    if ($body.Length -gt 0 -and -not $head) { $s.Write($body, 0, $body.Length) }
    $s.Flush()
  }
  function ReadHead($s) {
    # Reads bytes up to the blank line that ends the HTTP headers (max 32 KB). Never reads past it.
    $ms = New-Object System.IO.MemoryStream; $st = 0
    while ($ms.Length -lt 32768) {
      $b = $s.ReadByte(); if ($b -lt 0) { return $null }
      $ms.WriteByte([byte]$b)
      if ($b -eq 13) { if ($st -eq 0 -or $st -eq 2) { $st++ } else { $st = 1 } }
      elseif ($b -eq 10 -and ($st -eq 1 -or $st -eq 3)) { $st++; if ($st -eq 4) { return [System.Text.Encoding]::ASCII.GetString($ms.ToArray()) } }
      else { $st = 0 }
    }
    return $null
  }
  $up = $null
  try {
    $client.ReceiveTimeout = 15000; $client.SendTimeout = 60000; $client.NoDelay = $true
    $s = $client.GetStream()
    $head = ReadHead $s
    if (-not $head) { return }
    $lines = $head -split "`r`n"
    $parts = $lines[0].Split(' ')
    if ($parts.Count -lt 2) { return }
    $method = $parts[0].ToUpper(); $target = $parts[1]
    $len = 0; $range = ''
    foreach ($l in $lines) {
      if ($l -match '^(?i)content-length:\s*(\d+)') { $len = [int]$Matches[1] }
      if ($l -match '^(?i)range:\s*(bytes=[0-9,\- ]+)$') { $range = $Matches[1] }
    }
    $path = [Uri]::UnescapeDataString(($target -split '\?')[0])
    $none = [byte[]]@()

    if ($path.StartsWith('/ollama/')) {
      # ---- proxy to the private AI server ----
      $api = $path.Substring(7)
      $allowed = @{ 'GET /api/tags'=1; 'GET /api/version'=1; 'GET /api/ps'=1; 'POST /api/chat'=1; 'POST /api/generate'=1; 'POST /api/show'=1; 'POST /api/embed'=1; 'POST /api/embeddings'=1 }
      if ($method -eq 'OPTIONS') { Send $s 204 'No Content' 'text/plain' $none $false; return }
      if (-not $allowed.ContainsKey("$method $api")) { Send $s 403 'Forbidden' 'text/plain' ([System.Text.Encoding]::ASCII.GetBytes('Not allowed through the chat page')) $false; return }
      if ($len -gt 16MB) { Send $s 413 'Payload Too Large' 'text/plain' $none $false; return }
      $body = New-Object byte[] $len
      $got = 0
      while ($got -lt $len) { $n = $s.Read($body, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
      try { $up = New-Object System.Net.Sockets.TcpClient('127.0.0.1', [int]$C.OllamaPort) }
      catch { Send $s 502 'Bad Gateway' 'application/json' ([System.Text.Encoding]::ASCII.GetBytes('{"error":"The AI server is not running"}')) $false; return }
      $up.ReceiveTimeout = 900000; $up.NoDelay = $true
      $us = $up.GetStream()
      $q = ''; $qi = $target.IndexOf('?'); if ($qi -ge 0) { $q = $target.Substring($qi) }
      $req = "$method $api$q HTTP/1.1`r`nHost: 127.0.0.1:$($C.OllamaPort)`r`nContent-Type: application/json`r`nContent-Length: $got`r`nConnection: close`r`n`r`n"
      $rb = [System.Text.Encoding]::ASCII.GetBytes($req)
      $us.Write($rb, 0, $rb.Length); if ($got -gt 0) { $us.Write($body, 0, $got) }; $us.Flush()
      # Pass the answer back byte for byte as it arrives (keeps NDJSON streaming and chunked encoding intact).
      $buf = New-Object byte[] 16384
      while ($true) { $n = $us.Read($buf, 0, $buf.Length); if ($n -le 0) { break }; $s.Write($buf, 0, $n); $s.Flush() }
      return
    }

    if ($target -match '^/(library|content|skin|search|suggest|catalog|random|raw|viewer|viewer_settings\.js|nojs|catch)([/?]|$)') {
      # ---- read-only proxy to the library (Kiwix) ----
      if ($method -ne 'GET' -and $method -ne 'HEAD') { Send $s 405 'Method Not Allowed' 'text/plain' $none $false; return }
      $t = $target -replace '^/library/?(?=\?|$)', '/'
      try { $up = New-Object System.Net.Sockets.TcpClient('127.0.0.1', [int]$C.LibraryPort) }
      catch { Send $s 502 'Bad Gateway' 'text/plain; charset=utf-8' ([System.Text.Encoding]::ASCII.GetBytes('The library is not running')) $false; return }
      $up.ReceiveTimeout = 120000
      $us = $up.GetStream()
      $req = "$method $t HTTP/1.1`r`nHost: 127.0.0.1:$($C.LibraryPort)`r`n"
      if ($range) { $req += "Range: $range`r`n" }
      $req += "Connection: close`r`n`r`n"
      $rb = [System.Text.Encoding]::ASCII.GetBytes($req)
      $us.Write($rb, 0, $rb.Length); $us.Flush()
      $buf = New-Object byte[] 65536
      while ($true) { $n = $us.Read($buf, 0, $buf.Length); if ($n -le 0) { break }; $s.Write($buf, 0, $n) }
      $s.Flush()
      return
    }

    if ($method -ne 'GET' -and $method -ne 'HEAD') { Send $s 405 'Method Not Allowed' 'text/plain' $none $false; return }
    $isHead = ($method -eq 'HEAD')
    if ($path -eq '/status.json') {
      $json = '{"state":"unknown"}'
      $wv = Get-ChildItem -LiteralPath $C.VerifiedDir -Filter "$($C.WikiPrefix)*.zim" -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($wv) { $json = '{"state":"done","percent":100,"message":"Wikipedia ready"}' }
      elseif ($C.SkipWiki) { $json = '{"state":"off"}' }
      elseif (Test-Path -LiteralPath $C.Progress) { $json = (Get-Content -LiteralPath $C.Progress -Raw) }
      Send $s 200 'OK' 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json)) $isHead
      return
    }
    if ($path -eq '/') { $path = '/chat.html' }
    $full = [System.IO.Path]::GetFullPath((Join-Path $C.Root ($path.TrimStart('/'))))
    if (-not $full.StartsWith($C.Root + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
      Send $s 404 'Not Found' 'text/plain' ([System.Text.Encoding]::ASCII.GetBytes('Not found')) $false
      return
    }
    $ext = [System.IO.Path]::GetExtension($full).ToLower()
    $ct = $C.Types[$ext]; if (-not $ct) { $ct = 'application/octet-stream' }
    Send $s 200 'OK' $ct ([System.IO.File]::ReadAllBytes($full)) $isHead
  } catch {
    Log ('request error: ' + $_.Exception.Message)
  } finally {
    if ($up) { try { $up.Close() } catch {} }
    try { $client.Close() } catch {}
  }
}.ToString()

try {
  $listener = New-Object System.Net.Sockets.TcpListener($addr, $Port)
  $listener.Start()
} catch {
  Write-Log 'chat-server.log' "could not listen on ${addr}:$Port - $($_.Exception.Message)"
  exit 1
}
Write-Log 'chat-server.log' "listening on ${addr}:$Port (bind=$Bind)"
$pool = [runspacefactory]::CreateRunspacePool(1, 24)
$pool.Open()
$jobs = New-Object System.Collections.ArrayList
while ($true) {
  $client = $listener.AcceptTcpClient()
  $ps = [powershell]::Create()
  $ps.RunspacePool = $pool
  [void]$ps.AddScript($handler).AddArgument($client).AddArgument($ctx)
  [void]$jobs.Add(@($ps, $ps.BeginInvoke()))
  for ($i = $jobs.Count - 1; $i -ge 0; $i--) {
    if ($jobs[$i][1].IsCompleted) { try { [void]$jobs[$i][0].EndInvoke($jobs[$i][1]) } catch {}; $jobs[$i][0].Dispose(); $jobs.RemoveAt($i) }
  }
}
