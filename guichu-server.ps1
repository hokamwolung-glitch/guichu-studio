param([switch]$NoBrowser, [int]$Port = 18123)
$ErrorActionPreference = 'Stop'
$taskHtmlPath = Join-Path $PSScriptRoot 'index.html'
if (-not (Test-Path -LiteralPath $taskHtmlPath)) { throw '请将启动文件与index.html 放在同一个文件夹。' }
$taskBytes = [System.IO.File]::ReadAllBytes($taskHtmlPath)
$taskListener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
try { $taskListener.Start() } catch { Write-Host '启动失败：端口被占用。请关闭之前启动的鬼畜工坊，或选择其他端口。'; exit 1 }
$taskUrl = "http://127.0.0.1:$Port/"
Write-Host "鬼畜工坊已启动：$taskUrl"
Write-Host '保持这个窗口开启。关闭窗口或按 Ctrl+C 可以停止服务。'
if (-not $NoBrowser) { Start-Process $taskUrl }
try {
    while ($true) {
        $taskClient = $taskListener.AcceptTcpClient()
        try {
            $taskClient.ReceiveTimeout = 2000
            $taskClient.SendTimeout = 5000
            $taskStream = $taskClient.GetStream()
            $taskReader = [System.IO.StreamReader]::new($taskStream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
            $taskFirstLine = $taskReader.ReadLine()
            if (-not $taskFirstLine) { continue }
            do { $taskHeaderLine = $taskReader.ReadLine() } while ($taskHeaderLine)
            $taskRequestParts = $taskFirstLine.Split(' ')
            $taskAllowed = $taskRequestParts[0] -eq 'GET' -and ($taskRequestParts[1] -eq '/' -or $taskRequestParts[1] -eq '/index.html')
            if ($taskAllowed) {
                $taskBody = $taskBytes
                $taskResponseLine = 'HTTP/1.1 200 OK'
                $taskContentType = 'text/html; charset=utf-8'
            } else {
                $taskBody = [System.Text.Encoding]::UTF8.GetBytes('Not found')
                $taskResponseLine = 'HTTP/1.1 404 Not Found'
                $taskContentType = 'text/plain; charset=utf-8'
            }
            $taskResponse = "$taskResponseLine`r`nContent-Type: $taskContentType`r`nContent-Length: $($taskBody.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
            $taskResponseBytes = [System.Text.Encoding]::ASCII.GetBytes($taskResponse)
            $taskStream.Write($taskResponseBytes, 0, $taskResponseBytes.Length)
            $taskStream.Write($taskBody, 0, $taskBody.Length)
            $taskStream.Flush()
        } catch { } finally { $taskClient.Dispose() }
    }
} finally { $taskListener.Stop() }
