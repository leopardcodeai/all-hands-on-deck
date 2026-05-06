#!/usr/bin/env python3
"""
Happy Path E2E Test — Multi-Device Accessibility-Driven
========================================================
Boots 3 iOS simulators and runs the full Happy Path:
  Host   — starts a crew photo session
  Viewer — joins the session
  Safari — opens the webapp join URL

Uses screen_mapper.py + navigator.py from ios-simulator-skill.
Requires: idb, xcrun, ios-simulator-skill installed.
"""

import subprocess
import sys
import time
import os
import json
from pathlib import Path

SKILL_DIR = Path.home() / ".agents" / "skills" / "ios-simulator-skill" / "scripts"
LOCAL_IP = "192.168.178.132"
APP_BUNDLE = "app.captainleopard.allhands"

SIM_HOST = "0C90FAC7-A5D9-431D-BC97-9CF7E824FA55"     # iPhone 17 Pro Max
SIM_VIEWER = "31FADEAB-A732-4EB2-ACFF-7CA8A83B50F9"    # iPhone 17 Pro Viewer
SIM_SAFARI = "1AB3C43B-4BDE-4B1B-8802-66E8E7AE4EEB"    # iPhone 17
SESSION_ID = "FLOWTEST"

OUTDIR = Path("/tmp/happy_path_e2e_results")
PASSED = 0
FAILED = 0


def run(cmd, check=True):
    """Run a shell command, return output."""
    if isinstance(cmd, str):
        cmd = cmd.split()
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{result.stderr[:200]}")
    return result.stdout.strip()


def navigate(udid, find_text=None, tap=False, enter_text=None, find_type=None):
    """Use navigator.py for semantic UI interaction."""
    args = ["python3", str(SKILL_DIR / "navigator.py"), "--udid", udid]
    if find_text:
        args += ["--find-text", find_text]
    if find_type:
        args += ["--find-type", find_type]
    if enter_text:
        args += ["--enter-text", enter_text]
    if tap:
        args.append("--tap")
    result = run(args, check=False)
    return result


def screen_map(udid):
    """Return screen elements via screen_mapper.py."""
    args = ["python3", str(SKILL_DIR / "screen_mapper.py"), "--udid", udid]
    return run(args, check=False)


def screenshot(udid, path):
    """Take a simulator screenshot."""
    run(f"xcrun simctl io {udid} screenshot {path}")


def is_host_session(udid):
    """Check if the screen shows host session elements."""
    output = screen_map(udid)
    return "Hide QR code" in output and "Start 10s" in output


def is_viewer_session(udid):
    """Check if the screen shows viewer session elements."""
    output = screen_map(udid)
    return "Crew" in output and "Ready" in output


def is_join_screen(udid):
    """Check if the screen shows the join session view."""
    output = screen_map(udid)
    return "Scan QR Code" in output or "ABCDEF1234" in output


def test_step(name, fn):
    """Run a test step, print result."""
    global PASSED, FAILED
    print(f"\n  [{name}]", end=" ", flush=True)
    try:
        fn()
        print("✅")
        PASSED += 1
    except Exception as e:
        print(f"❌ {e}")
        FAILED += 1


def main():
    global PASSED, FAILED
    OUTDIR.mkdir(exist_ok=True)

    print("=" * 60)
    print("Happy Path E2E — 3-Device Accessibility Test")
    print("=" * 60)

    # ── Setup ──────────────────────────────────────────────────
    print("\n► SETUP")

    def setup_simulators():
        # Boot all 3
        for sim in [SIM_HOST, SIM_VIEWER, SIM_SAFARI]:
            run(f"xcrun simctl boot {sim}", check=False)
        time.sleep(8)
        # Launch host + viewer apps
        for sim in [SIM_HOST, SIM_VIEWER]:
            run(f"xcrun simctl launch {sim} {APP_BUNDLE} -useMockTransport YES", check=False)
        time.sleep(6)

    test_step("Boot 3 simulators + launch apps", setup_simulators)

    # ── Stage 1: Host starts session ───────────────────────────
    print("\n► STAGE 1: Host starts crew photo session")

    def host_start():
        navigate(SIM_HOST, find_text="Start Crew Photo", tap=True)
        time.sleep(1)
        # Fallback clicks for robustness
        for _ in range(3):
            subprocess.run(["cliclick", "c:515,470"], capture_output=True)
            time.sleep(1)
        time.sleep(3)
        assert is_host_session(SIM_HOST), "Host not in session view"
        screenshot(SIM_HOST, OUTDIR / "01_host_session.png")

    test_step("Navigate Host → Session View", host_start)

    # ── Stage 2: Viewer joins session ─────────────────────────
    print("\n► STAGE 2: Viewer joins session")

    def viewer_join():
        navigate(SIM_VIEWER, find_text="Join Session", tap=True)
        time.sleep(2)
        assert is_join_screen(SIM_VIEWER), "Viewer not on join screen"
        navigate(SIM_VIEWER, find_type="TextField", enter_text=SESSION_ID)
        time.sleep(1)
        navigate(SIM_VIEWER, find_text="Connect", tap=True)
        time.sleep(4)
        assert is_viewer_session(SIM_VIEWER), "Viewer not in session view"
        screenshot(SIM_VIEWER, OUTDIR / "02_viewer_session.png")

    test_step("Viewer Join → Session View", viewer_join)

    # ── Stage 3: Safari opens webapp ──────────────────────────
    print("\n► STAGE 3: Safari opens webapp")

    def safari_webapp():
        join_url = f"http://{LOCAL_IP}:5173/join/{SESSION_ID}"
        run(f"xcrun simctl openurl {SIM_SAFARI} {join_url}")
        time.sleep(4)
        screenshot(SIM_SAFARI, OUTDIR / "03_safari_webapp.png")

    test_step("Safari → Webapp Join URL", safari_webapp)

    # ── Results ────────────────────────────────────────────────
    print("\n" + "=" * 60)
    print(f"RESULTS: {PASSED} passed, {FAILED} failed")
    print(f"Screenshots: {OUTDIR}")
    print("=" * 60)

    return 0 if FAILED == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
