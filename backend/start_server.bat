@echo off
REM ============================================================
REM PocketPilot - Manual Server Launcher (Windows)
REM ============================================================
REM Double-click this file to start the server manually.
REM The server window will stay open showing connection info.
REM ============================================================

title PocketPilot Server
cd /d "%~dp0"

echo.
echo ============================================================
echo   PocketPilot - Starting Server...
echo ============================================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found! Please install Python 3.8+
    echo.
    pause
    exit /b 1
)

echo [OK] Python found
echo.

REM Start the server
python pocketpilot_server.py

REM If server stops, pause so user can see the output
echo.
echo ============================================================
echo   Server stopped.
echo ============================================================
pause