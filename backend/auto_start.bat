@echo off
REM ============================================================
REM PocketPilot Auto-Start Script (Windows)
REM ============================================================
REM This script waits for network connectivity, then starts
REM the PocketPilot server automatically.
REM
REM To install: Run as Administrator:
REM   schtasks /create /tn "PocketPilot" /tr "%~dp0auto_start.bat" /sc onstart /delay 0000:30 /ru SYSTEM /f
REM
REM Or add to Startup folder:
REM   Copy this script to: shell:startup
REM ============================================================

title PocketPilot Auto-Start
cd /d "%~dp0"

echo [PocketPilot] Waiting for network connectivity...

:CHECK_NETWORK
ping -n 1 8.8.8.8 >nul 2>&1
if %errorlevel% neq 0 (
    timeout /t 5 /nobreak >nul
    goto CHECK_NETWORK
)

echo [PocketPilot] Network detected. Starting server...
echo [PocketPilot] Log: %~dp0server.log

REM Start the server in a minimized window
start /MIN "" cmd /c "python pocketpilot_server.py >> %~dp0server.log 2>&1"

echo [PocketPilot] Server started successfully.
echo [PocketPilot] IP and token are in the terminal window.