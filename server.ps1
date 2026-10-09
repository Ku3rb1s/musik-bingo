# Mini-Webserver fuer Musik-Bingo: liefert die Dateien dieses Ordners unter http://127.0.0.1:8888/ aus.
$port = 8888
$root = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') + '\'
$types = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript'; '.css'='text/css'; '.png'='image/png'; '.svg'='image/svg+xml'; '.ico'='image/x-icon'; '.json'='application/json' }

$listener = [System.Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
try { $listener.Start() } catch {
    Write-Host "Port $port ist belegt - laeuft Musik-Bingo schon? Oeffne http://127.0.0.1:$port/" -ForegroundColor Yellow
    Start-Process "http://127.0.0.1:$port/"; Read-Host 'Enter zum Beenden'; exit
}
Write-Host "Musik-Bingo laeuft auf http://127.0.0.1:$port/  (Fenster schliessen zum Beenden)" -ForegroundColor Green
if (-not $env:MB_NO_BROWSER) { Start-Process "http://127.0.0.1:$port/" }

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $reader = New-Object IO.StreamReader($stream)
        $requestLine = $reader.ReadLine()
        while (($h = $reader.ReadLine()) -ne $null -and $h -ne '') {}
        $path = '/'
        if ($requestLine -match '^\w+ (\S+)') { $path = $matches[1] }
        $path = [Uri]::UnescapeDataString(($path -split '\?')[0])
        if ($path -eq '/') { $path = '/index.html' }
        $file = [IO.Path]::GetFullPath((Join-Path $root $path.TrimStart('/')))
        if ($file.StartsWith($root) -and (Test-Path $file -PathType Leaf)) {
            $body = [IO.File]::ReadAllBytes($file); $status = '200 OK'
            $type = $types[[IO.Path]::GetExtension($file).ToLower()]; if (-not $type) { $type = 'application/octet-stream' }
        } else {
            $body = [Text.Encoding]::UTF8.GetBytes('Nicht gefunden'); $status = '404 Not Found'; $type = 'text/plain'
        }
        $head = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-cache`r`nConnection: close`r`n`r`n")
        $stream.Write($head, 0, $head.Length); $stream.Write($body, 0, $body.Length)
    } catch {} finally { $client.Close() }
}
