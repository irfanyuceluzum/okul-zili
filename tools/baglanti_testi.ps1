# Okul Zili - ag baglanti testi
#
# Telefonun zil bilgisayarina okul aginda ulasip ulasamadigini dener.
# Zil bilgisayarinda YONETICI olarak calistirin:
#   powershell -ExecutionPolicy Bypass -File baglanti_testi.ps1
# Sonra telefonun tarayicisinda ekranda yazan adresi acin.
# Ctrl+C ile kapatinca gecici guvenlik duvari kurali da silinir.

$port = 8642
$ruleName = 'Okul Zili Baglanti Testi'

$ips = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object IPAddress, InterfaceAlias

if (-not $ips) {
    Write-Host 'Bu bilgisayar hicbir aga bagli degil.' -ForegroundColor Red
    exit 1
}

New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP `
    -LocalPort $port -Action Allow -Profile Any | Out-Null

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://+:$port/")

try {
    $listener.Start()
    Write-Host ''
    Write-Host 'Test sunucusu calisiyor. Telefonun tarayicisinda su adreslerden birini acin:' -ForegroundColor Green
    foreach ($ip in $ips) {
        Write-Host ('  http://{0}:{1}    ({2})' -f $ip.IPAddress, $port, $ip.InterfaceAlias)
    }
    Write-Host ''
    Write-Host 'Durdurmak icin Ctrl+C.'

    while ($listener.IsListening) {
        # Bekleme yarim saniyelik parcalara bolunur; boylece Ctrl+C calisir.
        $task = $listener.GetContextAsync()
        while (-not $task.AsyncWaitHandle.WaitOne(500)) { }
        $ctx = $task.GetAwaiter().GetResult()

        Write-Host ('{0:HH:mm:ss}  Baglanti geldi: {1}' -f (Get-Date), $ctx.Request.RemoteEndPoint) -ForegroundColor Cyan

        $html = "<!doctype html><html lang='tr'><head><meta charset='utf-8'>" +
            "<meta name='viewport' content='width=device-width, initial-scale=1'>" +
            "<title>Okul Zili</title></head>" +
            "<body style='font-family:sans-serif;padding:24px;background:#E2F3E9;color:#1D6A41'>" +
            "<h1>Ba&#287;lant&#305; ba&#351;ar&#305;l&#305;</h1>" +
            "<p>Telefon zil bilgisayar&#305;na ula&#351;abiliyor: <b>$env:COMPUTERNAME</b></p>" +
            "</body></html>"
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)
        $ctx.Response.ContentType = 'text/html; charset=utf-8'
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $ctx.Response.Close()
    }
}
finally {
    $listener.Stop()
    Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    Write-Host 'Test bitti, gecici guvenlik duvari kurali silindi.'
}
