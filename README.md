# PocketPilot — Remote Laptop Control

Control your laptop from your phone over local WiFi. Works fully offline — no internet required.

## Architecture

```
┌─────────────────────┐          WiFi Hotspot          ┌──────────────────────┐
│  Laptop (Server)    │ ◄─────── HTTP REST + WS ──────► │  Phone (Client)      │
│                     │                                 │                      │
│  Python + FastAPI   │    Phone creates hotspot;        │  Flutter App         │
│  pyautogui + psutil │    laptop connects to it         │                      │
│  Port 8000          │                                 │  7 screens:          │
│                     │                                 │  - Pairing           │
│  Endpoints:         │                                 │  - Dashboard         │
│  /status            │                                 │  - Trackpad (WS)     │
│  /power/*           │                                 │  - Keyboard          │
│  /volume/*          │                                 │  - Power Controls    │
│  /screenshot        │                                 │  - Screen Mirror     │
│  /mouse/*           │                                 │  - File Browser      │
│  /keyboard/*        │                                 │                      │
│  /media/*           │                                 │                      │
│  /app/open          │                                 │                      │
│  /files             │                                 │                      │
│  /ws/mouse          │                                 │                      │
└─────────────────────┘                                 └──────────────────────┘
```

## Features

- **System Status** — View battery %, CPU usage, RAM usage, and laptop IP in real-time
- **Power Controls** — Shutdown, Sleep, Lock with confirmation dialogs
- **Volume Control** — Set volume level, toggle mute
- **Media Controls** — Play/Pause, Next/Previous track
- **Live Trackpad** — Full-screen gesture area with low-latency WebSocket control
- **Keyboard Input** — Type text, send special keys (Enter, Esc, Arrows, F1-F12, etc.)
- **Screen Mirror** — View laptop screen with adjustable refresh rate
- **File Browser** — Navigate laptop filesystem, view files and directories
- **App Launcher** — Open applications by name

## Setup Instructions

### Prerequisites

- **Laptop**: Python 3.8+ installed
- **Phone**: Flutter-compatible device (Android/iOS) or install the APK
- **Both devices**: On the same WiFi network

---

### PART 1: Python Backend (Laptop)

1. **Clone or download** this repository to your laptop.

2. **Install dependencies**:

   ```bash
   cd backend
   pip install -r requirements.txt
   ```

   Or install manually:
   ```bash
   pip install fastapi uvicorn[standard] psutil Pillow pyautogui
   ```

   > **Windows users**: For better volume control, also run:
   > ```bash
   > pip install pycaw comtypes
   > ```

3. **Start the server**:

   **Option A — Double-click (easiest):**
   - **Windows**: Double-click `backend/start_server.bat`
   - **Linux/macOS**: Double-click `backend/start_server.sh` (or run `./start_server.sh` in terminal)

   **Option B — Manual terminal command:**
   ```bash
   python pocketpilot_server.py
   ```

   You'll see output like:
   ```
   ============================================================
     PocketPilot Server v2.0
   ============================================================
   Server running on: http://192.168.1.100:8000
   ```

   Keep this terminal open. Note the **IP address** — you'll need it.

---

### PART 2: Flutter App (Phone)

#### Option A: Build from source

1. Install [Flutter SDK](https://flutter.dev/docs/get-started/install) on your development machine.
2. Navigate to the app directory:
   ```bash
   cd pocketpilot_app
   ```
3. Get dependencies:
   ```bash
   flutter pub get
   ```
4. Build and install:
   ```bash
   flutter run          # For connected device
   # or
   flutter build apk    # For Android APK
   ```

#### Option B: Pre-built APK
If a pre-built APK is provided, install it directly on your Android phone.

---

### PART 3: Connect

1. **Create a WiFi hotspot** on your phone:
   - Android: Settings → Hotspot & tethering → WiFi hotspot → Enable
   - iOS: Settings → Personal Hotspot → Allow Others to Join

2. **Connect your laptop** to the phone's hotspot:
   - Windows: Click WiFi icon → Select your phone's hotspot → Connect
   - Mac: System Settings → Wi-Fi → Select hotspot → Connect
   - Linux: Network settings → Wi-Fi → Select hotspot → Connect

3. **Open the PocketPilot app** on your phone:
   - The app will start on the **Pairing Screen**
   - Enter the **laptop IP** (shown in terminal, e.g., `192.168.1.100`)
   - Port is `8000` by default
   - Tap **Connect**

4. The connection is saved locally. Next time you open the app, it will auto-connect.

---

## App Screens

| Screen | Purpose |
|--------|---------|
| **Pairing** | Enter IP and port to connect (with "Remember me" option) |
| **Dashboard** | View system stats (CPU, RAM, battery), quick actions, navigate to features |
| **Trackpad** | Full-screen swipe area for mouse control via WebSocket; tap to click, long-press to drag |
| **Keyboard** | Type text, special keys, arrows, F1-F12, media controls, open apps |
| **Power Controls** | Shutdown, Restart, Sleep, Lock with confirmation dialogs |
| **Screen Mirror** | View live laptop screen with adjustable refresh rate (0.5s - 5s) |
| **File Browser** | Navigate laptop filesystem, view files by type with color-coded icons |

---

## API Reference (Python Backend)

### System Status
- `GET /` — Server info
- `GET /status` — CPU%, RAM%, Battery%, IP, hostname

### Power
- `POST /power/shutdown`
- `POST /power/sleep`
- `POST /power/lock`

### Volume
- `POST /volume/set` — Body: `{"level": 50}`
- `POST /volume/mute`

### Input
- `GET /screenshot` — Returns JPEG image
- `POST /mouse/move` — Body: `{"dx": 10, "dy": 10}`
- `POST /mouse/click` — Body: `{"button": "left"}`
- `POST /keyboard/type` — Body: `{"text": "hello"}`
- `POST /keyboard/key` — Body: `{"key": "enter"}`

### Media
- `POST /media/play_pause`
- `POST /media/next`
- `POST /media/prev`

### Applications & Files
- `POST /app/open` — Body: `{"name": "chrome"}`
- `GET /files?path=C:\Users` — Directory listing

### WebSocket
- `WS /ws/mouse` — Send JSON messages: `{"type":"move","dx":10,"dy":10}`

---

## Platform Support

| Feature | Windows | macOS | Linux |
|---------|---------|-------|-------|
| Shutdown | ✅ | ✅ | ✅ |
| Sleep | ✅ | ✅ | ✅ |
| Lock | ✅ | ✅ | ✅ |
| Volume Set | ✅ (pycaw or fallback) | ✅ (osascript) | ✅ (amixer) |
| Mute | ✅ | ✅ | ✅ |
| Screenshot | ✅ (Pillow) | ✅ (Pillow) | ✅ (Pillow) |
| Mouse Move | ✅ (pyautogui) | ✅ (pyautogui) | ✅ (pyautogui) |
| Mouse Click | ✅ | ✅ | ✅ |
| Keyboard Type | ✅ | ✅ | ✅ |
| Media Controls | ✅ (virtual key codes) | ✅ (AppleScript) | ✅ (playerctl) |
| File Browser | ✅ | ✅ | ✅ |
| App Open | ✅ | ✅ | ✅ |
| CPU/RAM/Battery | ✅ (psutil) | ✅ (psutil) | ✅ (psutil) |

---

## Auto-Start (Server Starts Automatically on Boot)

The server can be configured to start automatically when your laptop boots up and connects to WiFi.

### Windows (Scheduled Task)

**One-click install:**
```powershell
# Right-click install_autostart.ps1 → "Run with PowerShell" (as Admin)
# OR run manually:
powershell -ExecutionPolicy Bypass -File backend\install_autostart.ps1
```

This creates a scheduled task that:
- Starts on system boot (with 10s delay for network)
- Auto-restarts if the server crashes (up to 3 times)
- Runs in background as SYSTEM user

**Manual alternative:**
1. Press `Win + R`, type `shell:startup`, press Enter
2. Create a shortcut to `backend\auto_start.bat` in the folder

**To uninstall:**
```powershell
schtasks /delete /tn PocketPilotServer /f
```

### Linux (systemd)

```bash
sudo chmod +x backend/install_autostart.sh
sudo ./backend/install_autostart.sh
```

Commands:
```bash
sudo systemctl status pocketpilot   # Check status
sudo systemctl stop pocketpilot     # Stop server
sudo journalctl -u pocketpilot -f   # View live logs
```

### macOS (launchd)

```bash
chmod +x backend/install_autostart.sh
sudo ./backend/install_autostart.sh
```

## Troubleshooting

**"No module named X" error**
```bash
pip install -r requirements.txt
```

**Can't connect from phone to laptop**
1. Check both devices are on the same WiFi network
2. Verify laptop IP is correct (run `ipconfig` on Windows, `ifconfig` on Mac/Linux)
3. Check Windows Firewall — allow Python on private networks
4. Try `ping <laptop-ip>` from another device to verify reachability

**Firewall issues (Windows)**
```powershell
# Allow Python through firewall
New-NetFirewallRule -DisplayName "PocketPilot" -Direction Inbound -Protocol TCP -LocalPort 8000 -Action Allow
```

**Port already in use**
Edit the `PORT` variable in `pocketpilot_server.py` or stop the other process using port 8000.

**Manual start not working**
- **Windows**: Run `start_server.bat` by double-clicking or from Command Prompt
- **Linux/macOS**: Run `chmod +x start_server.sh && ./start_server.sh`
- Or run directly: `python pocketpilot_server.py` from the `backend` folder

---

## Security Notes

- Communication is over HTTP (not HTTPS) — only use on trusted local networks
- The server binds to `0.0.0.0:8000`, accessible only to devices on the same network
- No authentication is required — consider this a trusted-local-network tool only

---

## License

MIT License — Use freely, modify, share.