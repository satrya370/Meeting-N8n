# n8n Stop Script
# Jalankan dari PowerShell: .\stop-n8n.ps1

$PidFile = "$PSScriptRoot\n8n.pid"

$stopped = $false

if (Test-Path $PidFile) {
    $savedPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($savedPid) {
        Stop-Process -Id $savedPid -Force -ErrorAction SilentlyContinue
        Write-Host "n8n (PID $savedPid) dihentikan." -ForegroundColor Yellow
        $stopped = $true
    }
    Remove-Item $PidFile -Force
}

# Tangkap sisa proses n8n yang mungkin terlewat
$remaining = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -like '*n8n*' }

foreach ($p in $remaining) {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Host "Killed stray n8n PID $($p.ProcessId)" -ForegroundColor Yellow
    $stopped = $true
}

if (-not $stopped) {
    Write-Host "Tidak ada proses n8n yang berjalan." -ForegroundColor DarkGray
}
