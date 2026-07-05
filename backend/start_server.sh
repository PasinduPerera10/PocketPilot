#!/bin/bash
# ============================================================
# PocketPilot - Manual Server Launcher (Linux/macOS)
# ============================================================
# Run this script to start the server manually:
#   chmod +x start_server.sh
#   ./start_server.sh
#
# The server will print connection info and stay running.
# Press Ctrl+C to stop.
# ============================================================

echo ""
echo "============================================================"
echo "  PocketPilot - Starting Server..."
echo "============================================================"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    if command -v python &> /dev/null; then
        PYTHON=python
    else
        echo "[ERROR] Python not found! Please install Python 3.8+"
        exit 1
    fi
else
    PYTHON=python3
fi

echo "[OK] Using: $($PYTHON --version)"
echo ""

# Start the server
$PYTHON "$(dirname "$0")/pocketpilot_server.py"

# If server stops
echo ""
echo "============================================================"
echo "  Server stopped."
echo "============================================================"