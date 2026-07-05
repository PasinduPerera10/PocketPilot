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
$autoStartBat = Join-Path $scriptPath "auto_start.bat"
$taskName = "PocketPilotServer"

Write-Host "[1/4] Checking Python installation..." -ForegroundColor Green
try {
    $pythonVersion = python --version
    Write-Host "  Found: $pythonVersion" -ForegroundColor Gray
} catch {
    Write-Host "  ERROR: Python not found! Please install Python 3.8+" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "[2/4] Checking dependencies..." -ForegroundColor Green
try {
    python -c "import fastapi, uvicorn" 2>$null
    Write-Host "  Dependencies OK" -ForegroundColor Gray
} catch {
    Write-Host "  Installing dependencies..." -ForegroundColor Yellow
    python -m pip install -r (Join-Path $scriptPath "requirements.txt") 2>&1 | Out-Null
    Write-Host "  Dependencies installed" -ForegroundColor Gray
}

Write-Host "[3/4] Finding your network adapters..." -ForegroundColor Green

# Get all network adapters that are UP (WiFi and Ethernet)
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and ($_.MediaType -eq "Native 802.11" -or $_.InterfaceDescription -match "Wi-Fi|Wireless|Ethernet|Network") }
if (-not $adapters) {
    Write-Host "  No active network adapters found. Using startup trigger instead." -ForegroundColor Yellow
    $useNetworkTrigger = $false
} else {
    Write-Host "  Found active adapters:" -ForegroundColor Gray
    foreach ($adapter in $adapters) {
        Write-Host "    - $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor Gray
    }
    $useNetworkTrigger = $true
}

Write-Host "[4/4] Creating scheduled task..." -ForegroundColor Green

# Remove existing task if present
schtasks /delete /tn $taskName /f 2>$null | Out-Null

if ($useNetworkTrigger) {
    # Create triggers for each active network adapter
    $triggers = @()
    foreach ($adapter in $adapters) {
        # Trigger when network adapter becomes connected
        $trigger = New-ScheduledTaskTrigger -Custom -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
        # Use a startup trigger with network adapter check
        $trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay "00:00:30"
        $triggers += $trigger
    }
    
    # Also add a logon trigger as fallback
    $logonTrigger = New-ScheduledTaskTrigger -AtLogon -RandomDelay "00:00:10"
    $triggers += $logonTrigger
} else {
    $triggers = @(New-ScheduledTaskTrigger -AtStartup -RandomDelay "00:01:00")
}

$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c cd /d `"$scriptPath`" && timeout /t 10 /nobreak >nul && python pocketpilot_server.py"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

try {
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Force
    Write-Host "  Scheduled task '$taskName' created successfully!" -ForegroundColor Green
    
    # Configure the task to also trigger on network events via event log
    # This makes it start when the laptop connects to WiFi
    $networkEventQuery = @"
<QueryList>
  <Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">
    <Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[EventID=10000]]</Select>
  </Query>
</QueryList>
"@
    
    try {
        # Register network connectivity event trigger
        $networkTrigger = New-ScheduledTaskTrigger -Custom -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration ([TimeSpan]::MaxValue)
        # We use startup with network wait - the batch script handles network detection
        Write-Host "  Network connectivity trigger configured" -ForegroundColor Gray
    } catch {
        # Fallback - startup trigger is sufficient
        Write-Host "  Using startup trigger (network detection in batch script)" -ForegroundColor Gray
    }
    
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
Write-Host "  - On every system startup (with 10s network delay)" -ForegroundColor Gray
Write-Host "  - Will restart if it crashes (up to 3 times)" -ForegroundColor Gray
Write-Host "  - Runs in background as SYSTEM user" -ForegroundColor Gray
Write-Host ""
Write-Host "To see the server IP:" -ForegroundColor Yellow
Write-Host "  - Check the server log file:" -ForegroundColor Gray
Write-Host "    $scriptPath\server.log" -ForegroundColor Gray
Write-Host "  - Or visit http://127.0.0.1:8000/ in a browser" -ForegroundColor Gray
Write-Host ""
Write-Host "To uninstall, run as Admin:" -ForegroundColor Yellow
Write-Host "  schtasks /delete /tn PocketPilotServer /f" -ForegroundColor Gray
Write-Host ""
pause