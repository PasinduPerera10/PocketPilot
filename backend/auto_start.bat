@echo off
REM ============================================================
REM PocketPilot Auto-Start Script (Windows)
REM ============================================================
REM This script waits for network connectivity, then starts
REM the PocketPilot server automatically.
REM
REM To install: Run as Administrator via install_autostart.ps1
REM Or add to Startup folder manually:
REM   Copy this script to: shell:startup
REM ============================================================

title PocketPilot Auto-Start
cd /d "%~dp0"

echo [PocketPilot] Waiting for network connectivity...

:CHECK_NETWORK
REM Try to reach a reliable host
ping -n 1 8.8.8.8 >nul 2>&1
if %errorlevel% neq 0 (
    REM Try another approach - check if any network adapter is active
    timeout /t 5 /nobreak >nul
    goto CHECK_NETWORK
)

echo [PocketPilot] Network detected. Starting server...
echo [PocketPilot] Log: %~dp0server.log

REM Kill any existing PocketPilot process
taskkill /f /im python.exe 2>nul | findstr /i "pocketpilot" >nul 2>&1

REM Start the server in a hidden window
start /MIN "" cmd /c "python pocketpilot_server.py >> %~dp0server.log 2>&1"

echo [PocketPilot] Server started successfully.
echo [PocketPilot] IP is in %~dp0server.log
echo [PocketPilot] Or visit http://127.0.0.1:8000/ in a browser
