# Setup Cloudflare Tunnel sebagai Windows Service
# Jalankan sebagai Administrator setelah cloudflared.exe tersedia di PATH atau folder ini.
# Langkah 1-3 butuh browser, sisanya otomatis.

param(
    [string]$TunnelName = "meeting-notes",
    [string]$LocalPort  = "5678"
)

$CloudflaredPath = "cloudflared"
if (-not (Get-Command $CloudflaredPath -ErrorAction SilentlyContinue)) {
    $LocalExe = Join-Path $PSScriptRoot "cloudflared.exe"
    if (Test-Path $LocalExe) { $CloudflaredPath = $LocalExe }
    else {
        Write-Host "cloudflared.exe tidak ditemukan." -ForegroundColor Red
        Write-Host "Download dari: https://github.com/cloudflare/cloudflared/releases/latest"
        Write-Host "Letakkan di folder ini atau tambahkan ke PATH."
        exit 1
    }
}

Write-Host "=== Setup Cloudflare Tunnel ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "LANGKAH 1: Login ke Cloudflare (akan membuka browser)" -ForegroundColor Yellow
Write-Host "Tekan Enter untuk lanjut..."
Read-Host

& $CloudflaredPath tunnel login

Write-Host ""
Write-Host "LANGKAH 2: Buat tunnel '$TunnelName'" -ForegroundColor Yellow
& $CloudflaredPath tunnel create $TunnelName

# Temukan tunnel ID dari output
$TunnelId = (& $CloudflaredPath tunnel list --output json | ConvertFrom-Json | Where-Object { $_.name -eq $TunnelName }).id

if (-not $TunnelId) {
    Write-Host "Gagal mendapatkan tunnel ID. Cek: cloudflared tunnel list" -ForegroundColor Red
    exit 1
}

Write-Host "Tunnel ID: $TunnelId" -ForegroundColor Green

# Buat config file
$ConfigDir  = "$env:USERPROFILE\.cloudflared"
$ConfigFile = Join-Path $ConfigDir "config.yml"
$CredsFile  = Join-Path $ConfigDir "$TunnelId.json"

$ConfigContent = @"
tunnel: $TunnelId
credentials-file: $($CredsFile -replace '\\','/')

ingress:
  - service: http://localhost:$LocalPort
"@

Write-Host ""
Write-Host "LANGKAH 3: Menulis config ke $ConfigFile" -ForegroundColor Yellow
$ConfigContent | Set-Content $ConfigFile -Encoding UTF8
Write-Host "Config ditulis." -ForegroundColor Green

Write-Host ""
Write-Host "LANGKAH 4: Install sebagai Windows Service (auto-start saat boot)" -ForegroundColor Yellow
& $CloudflaredPath service install

Write-Host ""
Write-Host "=== SELESAI ===" -ForegroundColor Green
Write-Host ""
Write-Host "Tunnel domain kamu (Cloudflare-generated):" -ForegroundColor White
Write-Host "  https://$TunnelId.cfargotunnel.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "Atau set custom hostname (opsional, butuh domain di Cloudflare):"
Write-Host "  cloudflared tunnel route dns $TunnelName your-subdomain.your-domain.com"
Write-Host ""
Write-Host "Tambahkan ke start-n8n.ps1:"
Write-Host "  `$env:N8N_HOST = '$TunnelId.cfargotunnel.com'"
Write-Host "  `$env:N8N_PROTOCOL = 'https'"
Write-Host "  `$env:WEBHOOK_URL = 'https://$TunnelId.cfargotunnel.com'"
Write-Host ""
Write-Host "Untuk cek status: cloudflared tunnel info $TunnelName"
Write-Host "Untuk start/stop service: Start-Service cloudflared / Stop-Service cloudflared"
