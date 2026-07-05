# ============================================================
# PocketPilot Auto-Installer
# ============================================================
# This script:
#   1. Self-elevates to Administrator
#   2. Installs Python + pip if missing
#   3. Installs all Python dependencies
#   4. Creates Windows Firewall rule for port 8000
#   5. Installs as scheduled task (starts on boot)
#   6. Starts the server now
#
# USAGE: Just double-click this file!
# ============================================================

# Self-elevate to Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating to Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# We are now running as Admin
$scriptPath = Split-Path -Parent $PSCommandPath
$serverScript = Join-Path $scriptPath "pocketpilot_server.py"
$taskName = "PocketPilotServer"
$logFile = Join-Path $scriptPath "install.log"

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
    "$timestamp $Message" | Out-File -FilePath $logFile -Append
}

Clear-Host
Write-Log "========================================" -Color Cyan
Write-Log "  PocketPilot Auto-Installer" -Color Cyan
Write-Log "========================================" -Color Cyan
Write-Log "" ""

# Step 1: Check Python
Write-Log "[1/6] Checking Python..." -Color Green
$pythonInstalled = $false
try {
    $pyVersion = python --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "  Found: $pyVersion" -Color Gray
        $pythonInstalled = $true
    }
} catch {}

$pipInstalled = $false
if ($pythonInstalled) {
    try {
        $pipVer = pip --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "  Found: $pipVer" -Color Gray
            $pipInstalled = $true
        }
    } catch {}
}

if (-not $pythonInstalled) {
    Write-Log "  Python not found! Downloading Python 3.12..." -Color Yellow
    $pythonUrl = "https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe"
    $pythonInstaller = "$env:TEMP\python-installer.exe"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $pythonUrl -OutFile $pythonInstaller -UseBasicParsing
        Write-Log "  Installing Python (this may take a minute)..." -Color Yellow
        
        # Silent install: add to PATH, install pip, no shortcuts
        Start-Process -Wait -FilePath $pythonInstaller -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0"
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Log "  Python installed successfully!" -Color Green
        $pythonInstalled = $true
    } catch {
        Write-Log "  ERROR: Failed to install Python: $_" -Color Red
        Write-Log "  Please download Python from https://python.org and run this script again." -Color Red
        pause
        exit 1
    }
}

# Step 2: Install pip if needed
if ($pythonInstalled -and -not $pipInstalled) {
    Write-Log "  Installing pip..." -Color Yellow
    python -m ensurepip --upgrade 2>&1 | Out-Null
}

# Step 3: Install Python dependencies
Write-Log "[2/6] Installing Python dependencies..." -Color Green
try {
    pip install -r (Join-Path $scriptPath "requirements.txt") 2>&1 | Out-Null
    Write-Log "  Dependencies installed!" -Color Green
} catch {
    Write-Log "  Installing with --trusted-host..." -Color Yellow
    pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org -r (Join-Path $scriptPath "requirements.txt") 2>&1 | Out-Null
    Write-Log "  Dependencies installed!" -Color Green
}

# Step 4: Firewall rule
Write-Log "[3/6] Configuring Windows Firewall..." -Color Green
try {
    $ruleName = "PocketPilot Server (TCP 8000)"
    # Remove existing rule if present
    netsh advfirewall firewall delete rule name="$ruleName" 2>$null | Out-Null
    # Add new rule
    netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=8000 profile=any 2>&1 | Out-Null
    Write-Log "  Firewall rule added for port 8000!" -Color Green
} catch {
    Write-Log "  Warning: Could not add firewall rule: $_" -Color Yellow
}

# Step 5: Create scheduled task (with network wait)
Write-Log "[4/6] Creating auto-start scheduled task..." -Color Green
try {
    # Remove existing task
    schtasks /delete /tn $taskName /f 2>$null | Out-Null
    
    # Create task that waits for network then starts server
    $action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c cd /d `"$scriptPath`" && timeout /t 10 /nobreak >nul && python pocketpilot_server.py"
    $triggers = @(
        (New-ScheduledTaskTrigger -AtStartup -RandomDelay "00:00:30"),
        (New-ScheduledTaskTrigger -AtLogon -RandomDelay "00:00:10")
    )
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Settings $settings -Principal $principal -Force | Out-Null
    Write-Log "  Scheduled task '$taskName' created!" -Color Green
} catch {
    Write-Log "  Warning: Could not create scheduled task: $_" -Color Yellow
}

# Step 6: Start server now
Write-Log "[5/6] Starting PocketPilot server now..." -Color Green
try {
    # Stop any existing instance
    Get-Process -Name "python" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*pocketpilot*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # Start server in background window
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "python.exe"
    $startInfo.Arguments = "`"$serverScript`""
    $startInfo.WorkingDirectory = "$scriptPath"
    $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
    $startInfo.UseShellExecute = $true
    [System.Diagnostics.Process]::Start($startInfo) | Out-Null
    
    Write-Log "  Server starting..." -Color Green
    
    # Wait for server to be ready
    Start-Sleep -Seconds 3
    
    # Fetch server details
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:8000/" -UseBasicParsing -TimeoutSec 5
        $data = $response.Content | ConvertFrom-Json
        $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -ne "Loopback" -and $_.PrefixOrigin -ne "WellKnown" } | Select-Object -First 1).IPAddress
        
        Write-Log "" ""
        Write-Log "========================================" -Color Cyan
        Write-Log "  INSTALLATION COMPLETE!" -Color Cyan
        Write-Log "========================================" -Color Cyan
        Write-Log "" ""
        Write-Log "  Server is running!" -Color Green
        Write-Log "  IP:      $ip" -Color White
        Write-Log "  Port:    8000" -Color White
        Write-Log "" ""
        Write-Log "  Open the PocketPilot app on your phone" -Color White
        Write-Log "  and enter:" -Color White
        Write-Log "    IP:     $ip" -Color Cyan
        Write-Log "    Port:   8000" -Color Cyan
        Write-Log "" ""
    } catch {
        Write-Log "  Server started but couldn't fetch details yet." -Color Yellow
        Write-Log "  Wait a moment, then check the server window." -Color Yellow
    }
} catch {
    Write-Log "  Warning: Could not start server automatically: $_" -Color Yellow
}

# Step 7: Create desktop shortcut
Write-Log "[6/6] Creating desktop shortcut..." -Color Green
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktopPath "PocketPilot Server Info.lnk"
    
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -Command `"`$r = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/' -UseBasicParsing; `$d = `$r.Content | ConvertFrom-Json; Write-Host 'Server is running!' -ForegroundColor Green; Write-Host 'IP: ' -NoNewline -ForegroundColor Yellow; `$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { `$_.InterfaceAlias -ne 'Loopback' -and `$_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress; Write-Host `$ip -ForegroundColor Cyan; Write-Host 'Port: 8000' -ForegroundColor Cyan; Read-Host '`nPress Enter to exit'`""
    $shortcut.Description = "Show PocketPilot connection details"
    $shortcut.Save()
    Write-Log "  Desktop shortcut created!" -Color Green
} catch {
    # Non-critical, ignore
}

Write-Log "" ""
Write-Log "The server will now start automatically every time" -Color Cyan
Write-Log "you boot your laptop and connect to WiFi." -Color Cyan
Write-Log "" ""
Write-Log "To see IP anytime, double-click:" -Color Gray
Write-Log "  Desktop -> 'PocketPilot Server Info' shortcut" -Color Gray
Write-Log "" ""
Write-Log "Press any key to exit..." -Color Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")