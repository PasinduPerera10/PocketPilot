# ============================================================
# PocketPilot Auto-Start Installer (Windows)
# ============================================================
# Run this script as Administrator to install PocketPilot
# as a scheduled task that starts when the laptop connects
# to any network.
#
# Usage:
#   Right-click → "Run with PowerShell" (as Admin)
#   OR
#   powershell -ExecutionPolicy Bypass -File install_autostart.ps1
# ============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PocketPilot Auto-Start Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click the script and select 'Run as PowerShell'" -ForegroundColor Yellow
    pause
    exit 1
}

$scriptPath = Split-Path -Parent $PSCommandPath
$serverScript = Join-Path $scriptPath "pocketpilot_server.py"
$taskName = "PocketPilotServer"

Write-Host "[1/3] Checking Python installation..." -ForegroundColor Green
try {
    $pythonVersion = python --version
    Write-Host "  Found: $pythonVersion" -ForegroundColor Gray
} catch {
    Write-Host "  ERROR: Python not found! Please install Python 3.8+" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "[2/3] Checking dependencies..." -ForegroundColor Green
try {
    python -c "import fastapi, uvicorn" 2>$null
    Write-Host "  Dependencies OK" -ForegroundColor Gray
} catch {
    Write-Host "  Installing dependencies..." -ForegroundColor Yellow
    python -m pip install -r (Join-Path $scriptPath "requirements.txt") 2>&1 | Out-Null
    Write-Host "  Dependencies installed" -ForegroundColor Gray
}

Write-Host "[3/3] Creating scheduled task..." -ForegroundColor Green

# Remove existing task if present
schtasks /delete /tn $taskName /f 2>$null | Out-Null

# Create the task that triggers on network events
$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c cd /d `"$scriptPath`" && timeout /t 10 /nobreak >nul && python pocketpilot_server.py"
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay "00:01:00"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force
    Write-Host "  Scheduled task '$taskName' created successfully!" -ForegroundColor Green
} catch {
    Write-Host "  ERROR creating task: $_" -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installation Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "The PocketPilot server will now start automatically:" -ForegroundColor White
Write-Host "  - On every system startup" -ForegroundColor Gray
Write-Host "  - After network is available (10s delay)" -ForegroundColor Gray
Write-Host "  - Will restart if it crashes (up to 3 times)" -ForegroundColor Gray
Write-Host ""
Write-Host "To see the server IP and token:" -ForegroundColor Yellow
Write-Host "  - Check the server log file:" -ForegroundColor Gray
Write-Host "    $scriptPath\server.log" -ForegroundColor Gray
Write-Host "  - Or visit http://127.0.0.1:8000/ in a browser" -ForegroundColor Gray
Write-Host ""
Write-Host "To uninstall, run as Admin:" -ForegroundColor Yellow
Write-Host "  schtasks /delete /tn PocketPilotServer /f" -ForegroundColor Gray
Write-Host ""
pause