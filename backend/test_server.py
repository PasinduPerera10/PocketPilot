#!/usr/bin/env python3
"""
PocketPilot Server Test Script
==============================
Tests all endpoints of the PocketPilot server.

Usage:
    1. Start the server in one terminal:
       python pocketpilot_server.py

    2. In another terminal, run this test:
       python test_server.py

    Or run server in background and test:
       start /B python pocketpilot_server.py
       timeout /T 3
       python test_server.py
"""

import json
import sys
import urllib.request
import urllib.error

# ==================== CONFIG ====================

SERVER_URL = "http://127.0.0.1:8000"

def make_headers():
    """Return standard headers."""
    return {
        "Content-Type": "application/json",
    }

def test_get(endpoint, expected_status="ok"):
    """Test a GET endpoint."""
    url = f"{SERVER_URL}{endpoint}"
    try:
        req = urllib.request.Request(url, headers=make_headers())
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read()
            content_type = resp.headers.get("Content-Type", "")

            if "image" in content_type:
                print(f"  [PASS] GET {endpoint} -> {resp.status} ({len(body)} bytes, {content_type})")
                return True
            else:
                data = json.loads(body.decode())
                status = data.get("status")
                if status == expected_status:
                    print(f"  [PASS] GET {endpoint} -> {json.dumps(data, indent=2)}")
                    return True
                else:
                    print(f"  [FAIL] GET {endpoint} -> unexpected status: {data}")
                    return False
    except urllib.error.HTTPError as e:
        print(f"  [FAIL] GET {endpoint} -> HTTP {e.code}: {e.read().decode()}")
        return False
    except Exception as e:
        print(f"  [FAIL] GET {endpoint} -> {e}")
        return False

def test_post(endpoint, body=None, expected_status="ok"):
    """Test a POST endpoint."""
    url = f"{SERVER_URL}{endpoint}"
    data = json.dumps(body).encode() if body else None
    try:
        req = urllib.request.Request(url, data=data, headers=make_headers(), method="POST")
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json.loads(resp.read().decode())
            status = result.get("status")
            if status == expected_status:
                print(f"  [PASS] POST {endpoint} -> {json.dumps(result)}")
                return True
            else:
                print(f"  [FAIL] POST {endpoint} -> unexpected status: {result}")
                return False
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"  [FAIL] POST {endpoint} -> HTTP {e.code}: {body}")
        return False
    except Exception as e:
        print(f"  [FAIL] POST {endpoint} -> {e}")
        return False

def test_server_connect():
    """Test basic server connectivity."""
    print("\n--- Connecting to Server ---")
    try:
        req = urllib.request.Request(f"{SERVER_URL}/", headers=make_headers())
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())
            print(f"  [PASS] Server version: {data.get('version')}")
            return True
    except Exception as e:
        print(f"[FAIL] Could not connect to server: {e}")
        print("Make sure the server is running:")
        print("  cd backend")
        print("  python pocketpilot_server.py")
        return False

def run_tests():
    """Run all tests."""
    print("=" * 60)
    print("  PocketPilot Server Test Suite")
    print("=" * 60)

    # Step 1: Connect to server
    if not test_server_connect():
        return False

    # Step 2: Test endpoints
    print("\n--- Testing Endpoints ---")

    all_pass = True

    # Root
    all_pass &= test_get("/")

    # Status
    all_pass &= test_get("/status")

    # Power (these are safe - they just return confirmation)
    all_pass &= test_post("/power/lock")

    # Volume
    all_pass &= test_post("/volume/set", {"level": 50})
    all_pass &= test_post("/volume/mute")

    # Screenshot
    all_pass &= test_get("/screenshot")

    # Mouse
    all_pass &= test_post("/mouse/move", {"dx": 10, "dy": 10})
    all_pass &= test_post("/mouse/click", {"button": "left"})

    # Keyboard
    all_pass &= test_post("/keyboard/type", {"text": "Hello from test!"})
    all_pass &= test_post("/keyboard/key", {"key": "enter"})

    # Media
    all_pass &= test_post("/media/play_pause")
    all_pass &= test_post("/media/next")
    all_pass &= test_post("/media/prev")

    # App
    all_pass &= test_post("/app/open", {"name": "notepad"})

    # Files
    all_pass &= test_get("/files?path=.")

    # ==================== RESULTS ====================
    print("\n" + "=" * 60)
    if all_pass:
        print("  ALL TESTS PASSED!")
    else:
        print("  SOME TESTS FAILED - check output above")
    print("=" * 60)

    return all_pass

if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)