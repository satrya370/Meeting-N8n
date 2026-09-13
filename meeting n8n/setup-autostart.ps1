# Setup Auto-Restart: n8n via Windows Task Scheduler
# Jalankan sekali sebagai Administrator: .\setup-autostart.ps1

$ScriptDir  = $PSScriptRoot
$StartScript = Join-Path $ScriptDir "start-n8n.ps1"

if (-not (Test-Path $StartScript)) {
    Write-Host "ERROR: start-n8n.ps1 tidak ditemukan di $ScriptDir" -ForegroundColor Red
    exit 1
}

Write-Host "Mendaftarkan n8n ke Windows Task Scheduler..." -ForegroundColor Cyan

$action = New-ScheduledTaskAction `
    -Execute    "powershell.exe" `
    -Argument   "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$StartScript`""

$trigger = New-ScheduledTaskTrigger -AtLogon

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit  (New-TimeSpan -Hours 0) `
    -RestartCount        3 `
    -RestartInterval     (New-TimeSpan -Minutes 2) `
    -StartWhenAvailable  $true

Register-ScheduledTask `
    -TaskName   "n8n-MeetingNotes-AutoStart" `
    -Action     $action `
    -Trigger    $trigger `
    -Settings   $settings `
    -RunLevel   Highest `
    -Force | Out-Null

Write-Host "Task Scheduler: OK" -ForegroundColor Green
Write-Host "  n8n akan otomatis start saat login."
Write-Host "  Restart otomatis 3x jika crash (interval 2 menit)."
Write-Host ""
Write-Host "Untuk uninstall: Unregister-ScheduledTask -TaskName 'n8n-MeetingNotes-AutoStart' -Confirm:`$false"
