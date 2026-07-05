#!/bin/bash
# ============================================================
# PocketPilot Auto-Start Installer (Linux/macOS)
# ============================================================
# This script installs PocketPilot as a systemd service (Linux)
# or launchd plist (macOS) that starts when the laptop boots
# and network is available.
#
# Usage:
#   chmod +x install_autostart.sh
#   sudo ./install_autostart.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/pocketpilot_server.py"

echo "========================================"
echo "  PocketPilot Auto-Start Installer"
echo "========================================"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python3 not found! Install with: sudo apt install python3 python3-pip"
    exit 1
fi
echo "[OK] Python3 found: $(python3 --version)"

# Install dependencies
echo "[...] Checking dependencies..."
python3 -c "import fastapi, uvicorn" 2>/dev/null || {
    echo "[...] Installing dependencies..."
    pip3 install -r "$SCRIPT_DIR/requirements.txt"
}
echo "[OK] Dependencies OK"

# Detect OS
if [[ "$(uname)" == "Darwin" ]]; then
    # ===== macOS (launchd) =====
    PLIST_PATH="$HOME/Library/LaunchAgents/com.pocketpilot.server.plist"
    
    echo "[...] Creating launchd plist..."
    
    cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pocketpilot.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/python3</string>
        <string>${SERVER_SCRIPT}</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${SCRIPT_DIR}/server.log</string>
    <key>StandardErrorPath</key>
    <string>${SCRIPT_DIR}/server.log</string>
    <key>WatchPaths</key>
    <array>
        <string>/etc/resolv.conf</string>
    </array>
</dict>
</plist>
EOF
    
    chmod 644 "$PLIST_PATH"
    launchctl load "$PLIST_PATH"
    
    echo "[OK] launchd service installed!"
    echo "  Plist: $PLIST_PATH"
    echo "  Log:   $SCRIPT_DIR/server.log"
    
elif [[ "$(uname)" == "Linux" ]]; then
    # ===== Linux (systemd) =====
    SERVICE_PATH="/etc/systemd/system/pocketpilot.service"
    
    echo "[...] Creating systemd service..."
    
    sudo bash -c "cat > $SERVICE_PATH" << EOF
[Unit]
Description=PocketPilot Remote Laptop Control Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$(which python3) $SERVER_SCRIPT
Restart=on-failure
RestartSec=10
StandardOutput=append:${SCRIPT_DIR}/server.log
StandardError=append:${SCRIPT_DIR}/server.log

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable pocketpilot.service
    sudo systemctl start pocketpilot.service
    
    echo "[OK] systemd service installed!"
    echo "  Service: $SERVICE_PATH"
    echo "  Log:     $SCRIPT_DIR/server.log"
    echo ""
    echo "Commands:"
    echo "  sudo systemctl status pocketpilot   - Check status"
    echo "  sudo systemctl stop pocketpilot     - Stop server"
    echo "  sudo journalctl -u pocketpilot -f   - View live logs"
else
    echo "ERROR: Unsupported OS: $(uname)"
    exit 1
fi

echo ""
echo "========================================"
echo "  Installation Complete!"
echo "========================================"
echo ""
echo "The PocketPilot server will now start automatically:"
echo "  - On every system boot"
echo "  - After network is available"
echo "  - Will restart if it crashes"
echo ""
echo "To see the server IP:"
echo "  - Check the log file: $SCRIPT_DIR/server.log"
echo "  - Or visit http://127.0.0.1:8000/ in a browser"
echo ""