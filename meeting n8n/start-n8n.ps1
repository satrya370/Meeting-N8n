# n8n Startup Script
# Jalankan dari PowerShell: .\start-n8n.ps1

$PidFile = "$PSScriptRoot\n8n.pid"

# --- Hentikan proses n8n yang masih berjalan ---
if (Test-Path $PidFile) {
    $oldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
    if ($oldPid) {
        Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
        Write-Host "Proses lama (PID $oldPid) dihentikan." -ForegroundColor Yellow
    }
    Remove-Item $PidFile -Force
}

# Juga matikan node.exe yang menjalankan n8n (jaga-jaga)
Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -like '*n8n*' } |
    ForEach-Object {
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "Killed stray n8n process PID $($_.ProcessId)" -ForegroundColor Yellow
    }

Start-Sleep -Seconds 1

# --- Environment variables ---
$env:N8N_HOST     = "chowtime-angling-threefold.ngrok-free.dev"
$env:N8N_PROTOCOL = "https"
$env:WEBHOOK_URL  = "https://chowtime-angling-threefold.ngrok-free.dev"
$env:NODE_FUNCTION_ALLOW_BUILTIN  = '*'
$env:NODE_FUNCTION_ALLOW_EXTERNAL = '*'
$env:N8N_PAYLOAD_SIZE_MAX         = '600'   # raw/JSON body limit (MB), default 16
$env:N8N_FORMDATA_FILE_SIZE_MAX   = '600'   # FORM file upload limit (MB), default 200 <- this was the real blocker
$env:N8N_DEFAULT_BINARY_DATA_MODE = 'filesystem'
$env:GENERIC_TIMEZONE             = 'Asia/Jakarta'  # WIB UTC+7 — tanpa ini n8n default ke America/New_York

# --- Pastikan folder binaryData ada ---
$binaryDataDir = "$env:USERPROFILE\.n8n\binaryData"
if (-not (Test-Path $binaryDataDir)) {
    New-Item -ItemType Directory -Path $binaryDataDir -Force | Out-Null
    Write-Host "Dibuat: $binaryDataDir" -ForegroundColor Cyan
}

# --- Jalankan ngrok tunnel ---
$ngrokPath = "$PSScriptRoot\cloudflare\ngrok.exe"
if (Test-Path $ngrokPath) {
    Start-Process -FilePath $ngrokPath `
        -ArgumentList 'http', '--domain=chowtime-angling-threefold.ngrok-free.dev', '5678' `
        -WindowStyle Hidden
    Write-Host "ngrok tunnel dimulai." -ForegroundColor Cyan
} else {
    Write-Host "ngrok.exe tidak ditemukan di $ngrokPath" -ForegroundColor Yellow
}

# --- Jalankan n8n ---
$process = Start-Process `
    -FilePath    'C:\Program Files\nodejs\node.exe' `
    -ArgumentList 'D:\npm-global\node_modules\n8n\bin\n8n', 'start' `
    -WindowStyle Hidden `
    -PassThru

$process.Id | Set-Content $PidFile

Write-Host ""
Write-Host "n8n berjalan!" -ForegroundColor Green
Write-Host "  PID  : $($process.Id)  (tersimpan di n8n.pid)" -ForegroundColor White
Write-Host "  URL  : http://localhost:5678" -ForegroundColor White
Write-Host "  Publik: https://$env:N8N_HOST" -ForegroundColor Cyan
Write-Host ""
Write-Host "Env vars aktif:" -ForegroundColor DarkGray
Write-Host "  NODE_FUNCTION_ALLOW_BUILTIN  = $env:NODE_FUNCTION_ALLOW_BUILTIN" -ForegroundColor DarkGray
Write-Host "  NODE_FUNCTION_ALLOW_EXTERNAL = $env:NODE_FUNCTION_ALLOW_EXTERNAL" -ForegroundColor DarkGray
Write-Host "  N8N_PAYLOAD_SIZE_MAX         = $env:N8N_PAYLOAD_SIZE_MAX" -ForegroundColor DarkGray
Write-Host "  N8N_FORMDATA_FILE_SIZE_MAX   = $env:N8N_FORMDATA_FILE_SIZE_MAX" -ForegroundColor DarkGray
Write-Host "  N8N_DEFAULT_BINARY_DATA_MODE = $env:N8N_DEFAULT_BINARY_DATA_MODE" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Untuk menghentikan: .\stop-n8n.ps1" -ForegroundColor DarkGray
