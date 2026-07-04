#!/usr/bin/env python3
"""
PocketPilot Server
=================
Remote laptop control server using FastAPI.
Runs on laptop, controlled from phone over local WiFi.

Usage:
    pip install -r requirements.txt
    python server.py

The server will print a pairing token and the laptop's local IP.
Use the PocketPilot Flutter app to connect.
"""

import asyncio
import json
import os
import platform
import random
import shutil
import socket
import string
import subprocess
import sys
import time
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, Query, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel

# ==================== CONFIGURATION ====================

HOST = "0.0.0.0"
PORT = 8000
TOKEN_LENGTH = 8

# ==================== PLATFORM DETECTION ====================

IS_WINDOWS = platform.system() == "Windows"
IS_MAC = platform.system() == "Darwin"
IS_LINUX = platform.system() == "Linux"

# ==================== PAIRING TOKEN ====================

def generate_token(length: int = TOKEN_LENGTH) -> str:
    """Generate a random alphanumeric pairing token."""
    chars = string.ascii_uppercase + string.digits
    return ''.join(random.choices(chars, k=length))

PAIRING_TOKEN = generate_token()

# ==================== FASTAPI APP ====================

app = FastAPI(title="PocketPilot Server", version="2.0.0")

# CORS - allow any origin for local network access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================== AUTH DEPENDENCY ====================

async def verify_token(authorization: str = Header(None)):
    """Dependency to verify the Bearer token."""
    if authorization is None:
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    
    parts = authorization.split()
    if len(parts) != 2 or parts[0].lower() != "bearer":
        raise HTTPException(status_code=401, detail="Invalid Authorization format. Use: Bearer <token>")
    
    if parts[1] != PAIRING_TOKEN:
        raise HTTPException(status_code=403, detail="Invalid pairing token")
    
    return True

# ==================== REQUEST MODELS ====================

class VolumeRequest(BaseModel):
    level: int  # 0-100

class MouseMoveRequest(BaseModel):
    dx: int
    dy: int

class MouseClickRequest(BaseModel):
    button: str = "left"  # left, right, middle

class KeyboardTypeRequest(BaseModel):
    text: str

class KeyboardKeyRequest(BaseModel):
    key: str  # enter, escape, tab, up, down, left, right, backspace, delete, space, etc.

class AppOpenRequest(BaseModel):
    name: str

# ==================== SYSTEM COMMANDS ====================

def get_local_ip() -> str:
    """Get the local IP address on the active network."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def get_status() -> dict:
    """Get system status: battery, CPU, RAM, IP."""
    status = {
        "status": "ok",
        "hostname": socket.gethostname(),
        "platform": platform.system(),
        "platform_version": platform.version(),
        "ip": get_local_ip(),
        "cpu_percent": None,
        "memory_percent": None,
        "battery_percent": None,
        "battery_charging": None,
    }
    
    try:
        import psutil
        # CPU
        status["cpu_percent"] = psutil.cpu_percent(interval=0.5)
        # Memory
        status["memory_percent"] = psutil.virtual_memory().percent
        # Battery
        battery = psutil.sensors_battery()
        if battery:
            status["battery_percent"] = battery.percent
            status["battery_charging"] = battery.power_plugged
    except ImportError:
        pass
    
    return status

# ==================== POWER COMMANDS ====================

def power_shutdown():
    """Shutdown the computer."""
    try:
        if IS_WINDOWS:
            subprocess.run(["shutdown", "/s", "/t", "3"], check=True)
        elif IS_MAC:
            subprocess.run(["sudo", "shutdown", "-h", "now"], check=True)
        elif IS_LINUX:
            subprocess.run(["systemctl", "poweroff"], check=True)
        return {"status": "ok", "message": "Shutdown initiated"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def power_restart():
    """Restart the computer."""
    try:
        if IS_WINDOWS:
            subprocess.run(["shutdown", "/r", "/t", "3"], check=True)
        elif IS_MAC:
            subprocess.run(["sudo", "shutdown", "-r", "now"], check=True)
        elif IS_LINUX:
            subprocess.run(["systemctl", "reboot"], check=True)
        return {"status": "ok", "message": "Restart initiated"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def power_sleep():
    """Put the computer to sleep."""
    try:
        if IS_WINDOWS:
            import ctypes
            ctypes.windll.powrprof.SetSuspendState(0, 1, 0)
        elif IS_MAC:
            subprocess.run(["pmset", "sleepnow"], check=True)
        elif IS_LINUX:
            subprocess.run(["systemctl", "suspend"], check=True)
        return {"status": "ok", "message": "Sleep initiated"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def power_lock():
    """Lock the computer."""
    try:
        if IS_WINDOWS:
            import ctypes
            ctypes.windll.user32.LockWorkStation()
        elif IS_MAC:
            subprocess.run(["/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession", "-suspend"], check=True)
        elif IS_LINUX:
            subprocess.run(["gnome-screensaver-command", "-l"], check=True)
        return {"status": "ok", "message": "Locked"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==================== VOLUME COMMANDS ====================

def volume_get() -> int:
    """Get current system volume level (0-100)."""
    try:
        if IS_WINDOWS:
            try:
                from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
                from ctypes import cast, POINTER
                from comtypes import CLSCTX_ALL
                devices = AudioUtilities.GetSpeakers()
                interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
                volume = cast(interface, POINTER(IAudioEndpointVolume))
                return int(volume.GetMasterVolumeLevelScalar() * 100)
            except ImportError:
                return None
        elif IS_MAC:
            result = subprocess.run(["osascript", "-e", "output volume of (get volume settings)"], capture_output=True, text=True)
            return int(result.stdout.strip())
        elif IS_LINUX:
            result = subprocess.run(["amixer", "get", "Master"], capture_output=True, text=True)
            import re
            match = re.search(r'(\d+)%', result.stdout)
            if match:
                return int(match.group(1))
    except Exception:
        pass
    return None

def volume_set(level: int):
    """Set system volume level (0-100)."""
    try:
        level = max(0, min(100, level))
        if IS_WINDOWS:
            try:
                from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
                from ctypes import cast, POINTER
                from comtypes import CLSCTX_ALL
                devices = AudioUtilities.GetSpeakers()
                interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
                volume = cast(interface, POINTER(IAudioEndpointVolume))
                volume.SetMasterVolumeLevelScalar(level / 100.0, None)
            except ImportError:
                # Fallback: use PowerShell
                ps_script = f'''
                $obj = New-Object -ComObject WScript.Shell;
                for($i=0; $i -le 100; $i+=2) {{ $obj.SendKeys([char]175) }};
                for($i=0; $i -lt {100 - level}; $i+=2) {{ $obj.SendKeys([char]174) }};
                '''
                subprocess.run(["powershell", "-Command", ps_script], check=True, capture_output=True)
        elif IS_MAC:
            subprocess.run(["osascript", "-e", f"set volume output volume {level}"], check=True)
        elif IS_LINUX:
            subprocess.run(["amixer", "set", "Master", f"{level}%"], check=True)
        return {"status": "ok", "message": f"Volume set to {level}%"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def volume_mute():
    """Toggle mute."""
    try:
        if IS_WINDOWS:
            try:
                from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
                from ctypes import cast, POINTER
                from comtypes import CLSCTX_ALL
                devices = AudioUtilities.GetSpeakers()
                interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
                volume = cast(interface, POINTER(IAudioEndpointVolume))
                volume.SetMute(not volume.GetMute(), None)
            except ImportError:
                subprocess.run(["powershell", "-Command", "(New-Object -ComObject WScript.Shell).SendKeys([char]173)"], check=True, capture_output=True)
        elif IS_MAC:
            subprocess.run(["osascript", "-e", "set volume with output muted"], check=True)
        elif IS_LINUX:
            subprocess.run(["amixer", "set", "Master", "toggle"], check=True)
        return {"status": "ok", "message": "Mute toggled"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==================== SCREENSHOT ====================

def take_screenshot() -> Optional[bytes]:
    """Take a screenshot and return JPEG bytes."""
    try:
        from PIL import ImageGrab
        import io
        screenshot = ImageGrab.grab()
        img_byte_arr = io.BytesIO()
        screenshot.save(img_byte_arr, format='JPEG', quality=70)
        return img_byte_arr.getvalue()
    except Exception as e:
        print(f"[ERROR] Screenshot failed: {e}")
        return None

# ==================== MOUSE COMMANDS ====================

def mouse_move(dx: int, dy: int):
    """Move mouse by relative offset."""
    try:
        import pyautogui
        pyautogui.moveRel(dx, dy, duration=0.0)
        return {"status": "ok", "message": f"Mouse moved by ({dx}, {dy})"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def mouse_click(button: str = "left"):
    """Click mouse button."""
    try:
        import pyautogui
        btn_map = {"left": "left", "right": "right", "middle": "middle"}
        pyautogui.click(button=btn_map.get(button, "left"))
        return {"status": "ok", "message": f"Mouse {button} click"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==================== KEYBOARD COMMANDS ====================

def keyboard_type(text: str):
    """Type text."""
    try:
        import pyautogui
        pyautogui.typewrite(text, interval=0.01)
        return {"status": "ok", "message": f"Typed {len(text)} characters"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def keyboard_key(key: str):
    """Press a special key."""
    try:
        import pyautogui
        key_map = {
            "enter": "enter", "return": "enter",
            "escape": "esc", "esc": "esc",
            "tab": "tab",
            "up": "up", "down": "down", "left": "left", "right": "right",
            "backspace": "backspace", "delete": "delete",
            "space": "space",
            "home": "home", "end": "end",
            "pageup": "pageup", "pagedown": "pagedown",
            "f1": "f1", "f2": "f2", "f3": "f3", "f4": "f4",
            "f5": "f5", "f6": "f6", "f7": "f7", "f8": "f8",
            "f9": "f9", "f10": "f10", "f11": "f11", "f12": "f12",
        }
        mapped = key_map.get(key.lower(), key)
        pyautogui.press(mapped)
        return {"status": "ok", "message": f"Key pressed: {key}"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==================== MEDIA COMMANDS ====================

def media_play_pause():
    """Toggle play/pause."""
    try:
        if IS_WINDOWS:
            import ctypes
            ctypes.windll.user32.keybd_event(0xB3, 0, 0, 0)  # VK_MEDIA_PLAY_PAUSE
            time.sleep(0.05)
            ctypes.windll.user32.keybd_event(0xB3, 0, 2, 0)  # KEYEVENTF_KEYUP
        elif IS_MAC:
            subprocess.run(["osascript", "-e", 'tell application "System Events" to key code 16'], check=True)
        elif IS_LINUX:
            subprocess.run(["playerctl", "play-pause"], check=True)
        return {"status": "ok", "message": "Play/Pause toggled"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def media_next():
    """Next track."""
    try:
        if IS_WINDOWS:
            import ctypes
            ctypes.windll.user32.keybd_event(0xB0, 0, 0, 0)  # VK_MEDIA_NEXT_TRACK
            time.sleep(0.05)
            ctypes.windll.user32.keybd_event(0xB0, 0, 2, 0)
        elif IS_MAC:
            subprocess.run(["osascript", "-e", 'tell application "System Events" to key code 17'], check=True)
        elif IS_LINUX:
            subprocess.run(["playerctl", "next"], check=True)
        return {"status": "ok", "message": "Next track"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

def media_prev():
    """Previous track."""
    try:
        if IS_WINDOWS:
            import ctypes
            ctypes.windll.user32.keybd_event(0xB1, 0, 0, 0)  # VK_MEDIA_PREV_TRACK
            time.sleep(0.05)
            ctypes.windll.user32.keybd_event(0xB1, 0, 2, 0)
        elif IS_MAC:
            subprocess.run(["osascript", "-e", 'tell application "System Events" to key code 18'], check=True)
        elif IS_LINUX:
            subprocess.run(["playerctl", "previous"], check=True)
        return {"status": "ok", "message": "Previous track"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==================== APP COMMANDS ====================

def app_open(name: str):
    """Open an application by name."""
    try:
        if IS_WINDOWS:
            subprocess.Popen(["start", name], shell=True)
        elif IS_MAC:
            subprocess.Popen(["open", "-a", name])
        elif IS_LINUX:
            subprocess.Popen([name])
        return {"status": "ok", "message": f"Opening: {name}"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==================== FILE BROWSER ====================

def list_files(path: str = ".") -> dict:
    """List files and directories at the given path."""
    try:
        # Resolve the path
        p = Path(path).expanduser().resolve()
        
        if not p.exists():
            return {"status": "error", "message": f"Path does not exist: {path}"}
        
        if not p.is_dir():
            return {"status": "error", "message": f"Not a directory: {path}"}
        
        entries = []
        for entry in sorted(p.iterdir()):
            try:
                stat = entry.stat()
                entries.append({
                    "name": entry.name,
                    "path": str(entry),
                    "is_dir": entry.is_dir(),
                    "size": stat.st_size if entry.is_file() else 0,
                    "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                })
            except (PermissionError, OSError):
                entries.append({
                    "name": entry.name,
                    "path": str(entry),
                    "is_dir": entry.is_dir(),
                    "size": 0,
                    "modified": None,
                })
        
        return {
            "status": "ok",
            "path": str(p),
            "parent": str(p.parent) if str(p) != str(p.parent) else None,
            "entries": entries,
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ==================== REST ENDPOINTS ====================

@app.get("/")
async def root():
    return {
        "status": "ok",
        "server": "PocketPilot",
        "version": "2.0.0",
        "token": PAIRING_TOKEN,
    }

@app.get("/status")
async def status(_: bool = Depends(verify_token)):
    return get_status()

@app.post("/power/shutdown")
async def shutdown(_: bool = Depends(verify_token)):
    return power_shutdown()

@app.post("/power/sleep")
async def sleep(_: bool = Depends(verify_token)):
    return power_sleep()

@app.post("/power/restart")
async def restart(_: bool = Depends(verify_token)):
    return power_restart()

@app.post("/power/lock")
async def lock(_: bool = Depends(verify_token)):
    return power_lock()

@app.get("/volume")
async def volume_get_endpoint(_: bool = Depends(verify_token)):
    level = volume_get()
    return {"status": "ok", "volume": level}

@app.post("/volume/set")
async def volume_set_endpoint(req: VolumeRequest, _: bool = Depends(verify_token)):
    return volume_set(req.level)

@app.post("/volume/mute")
async def mute(_: bool = Depends(verify_token)):
    return volume_mute()

@app.get("/screenshot")
async def screenshot(_: bool = Depends(verify_token)):
    img_bytes = take_screenshot()
    if img_bytes:
        return Response(content=img_bytes, media_type="image/jpeg")
    return {"status": "error", "message": "Screenshot failed"}

@app.post("/mouse/move")
async def mouse_move_endpoint(req: MouseMoveRequest, _: bool = Depends(verify_token)):
    return mouse_move(req.dx, req.dy)

@app.post("/mouse/click")
async def mouse_click_endpoint(req: MouseClickRequest, _: bool = Depends(verify_token)):
    return mouse_click(req.button)

@app.post("/keyboard/type")
async def keyboard_type_endpoint(req: KeyboardTypeRequest, _: bool = Depends(verify_token)):
    return keyboard_type(req.text)

@app.post("/keyboard/key")
async def keyboard_key_endpoint(req: KeyboardKeyRequest, _: bool = Depends(verify_token)):
    return keyboard_key(req.key)

@app.post("/media/play_pause")
async def media_play_pause_endpoint(_: bool = Depends(verify_token)):
    return media_play_pause()

@app.post("/media/next")
async def media_next_endpoint(_: bool = Depends(verify_token)):
    return media_next()

@app.post("/media/prev")
async def media_prev_endpoint(_: bool = Depends(verify_token)):
    return media_prev()

@app.post("/app/open")
async def app_open_endpoint(req: AppOpenRequest, _: bool = Depends(verify_token)):
    return app_open(req.name)

@app.get("/files")
async def files(path: str = Query(".", description="Directory path to list"), _: bool = Depends(verify_token)):
    return list_files(path)

# ==================== WEBSOCKET: LIVE TRACKPAD ====================

@app.websocket("/ws/mouse")
async def websocket_mouse(websocket: WebSocket):
    """WebSocket for low-latency live trackpad control."""
    await websocket.accept()
    
    # Authenticate via first message
    authenticated = False
    try:
        # Expect first message to be the token
        data = await asyncio.wait_for(websocket.receive_text(), timeout=5.0)
        if data == PAIRING_TOKEN:
            authenticated = True
            await websocket.send_text(json.dumps({"type": "auth", "status": "ok"}))
        else:
            await websocket.send_text(json.dumps({"type": "auth", "status": "error", "message": "Invalid token"}))
            await websocket.close()
            return
    except asyncio.TimeoutError:
        await websocket.close()
        return
    
    if not authenticated:
        await websocket.close()
        return
    
    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
                msg_type = msg.get("type", "")
                
                if msg_type == "move":
                    dx = msg.get("dx", 0)
                    dy = msg.get("dy", 0)
                    mouse_move(dx, dy)
                elif msg_type == "click":
                    button = msg.get("button", "left")
                    mouse_click(button)
                elif msg_type == "scroll":
                    clicks = msg.get("clicks", 1)
                    try:
                        import pyautogui
                        pyautogui.scroll(clicks)
                    except Exception:
                        pass
                elif msg_type == "drag":
                    dx = msg.get("dx", 0)
                    dy = msg.get("dy", 0)
                    try:
                        import pyautogui
                        pyautogui.dragRel(dx, dy, duration=0.0)
                    except Exception:
                        pass
                elif msg_type == "ping":
                    await websocket.send_text(json.dumps({"type": "pong"}))
            except json.JSONDecodeError:
                pass
    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"[WS] Error: {e}")

# ==================== STARTUP ====================

def print_banner():
    """Print the startup banner with connection info."""
    ip = get_local_ip()
    banner = f"""
{'='*60}
  POCKETPILOT - Remote Laptop Control Server
{'='*60}
  Version 2.0.0
{'='*60}

  Server running on: http://{ip}:{PORT}
  Pairing Token:    {PAIRING_TOKEN}

  To connect:
  1. Make sure your phone is on the same WiFi network
  2. Open the PocketPilot app on your phone
  3. Enter IP: {ip}  and Token: {PAIRING_TOKEN}

  Endpoints:
    GET  /status          - System status (CPU, RAM, battery, IP)
    POST /power/shutdown  - Shutdown computer
    POST /power/sleep     - Sleep computer
    POST /power/lock      - Lock computer
    POST /volume/set      - Set volume (0-100)
    POST /volume/mute     - Toggle mute
    GET  /screenshot      - Take screenshot (JPEG)
    POST /mouse/move      - Move mouse (dx, dy)
    POST /mouse/click     - Click mouse (button)
    POST /keyboard/type   - Type text
    POST /keyboard/key    - Press special key
    POST /media/play_pause - Play/Pause media
    POST /media/next      - Next track
    POST /media/prev      - Previous track
    POST /app/open        - Open application
    GET  /files?path=     - Browse files
    WS   /ws/mouse        - Live trackpad (WebSocket)

  Press Ctrl+C to stop the server.
{'='*60}
"""
    print(banner)

def main():
    print_banner()
    
    # Run the server
    uvicorn.run(
        app,
        host=HOST,
        port=PORT,
        log_level="info",
        access_log=True,
    )

if __name__ == "__main__":
    main()