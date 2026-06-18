"""Godot headless soak + income parity (ROADMAP P5 exit verify).

Runs:
  1. game_screen load + 60s live sim tick (headless_soak.gd)
  2. pygame ↔ Godot income parity (sim_income_parity.py)

Usage:
    python sim_godot_soak.py
    python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
    python sim_godot_soak.py --seconds 60 --skip-income
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GODOT_PROJECT = ROOT / "godot"
SOAK = "res://scripts/tools/headless_soak.gd"
DEFAULT_SECONDS = 60


def _find_godot(explicit: str | None) -> str:
    if explicit and Path(explicit).is_file():
        return explicit
    for candidate in [
        os.environ.get("GODOT_BIN", ""),
        "E:/Downloads/Godot_v4.6.3-stable_win64.exe",
        "godot",
    ]:
        if candidate and (Path(candidate).is_file() or candidate == "godot"):
            return candidate
    raise FileNotFoundError("Godot executable not found; pass --godot PATH")


def _run_soak(godot_bin: str, seconds: float) -> dict:
    cmd = [
        godot_bin,
        "--path",
        str(GODOT_PROJECT),
        "--headless",
        "-s",
        SOAK,
        "--",
        "--seconds",
        str(seconds),
    ]
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=int(seconds) + 120,
        cwd=str(ROOT),
    )
    combined = proc.stdout + proc.stderr
    if "SCRIPT ERROR" in combined:
        raise RuntimeError("SCRIPT ERROR during soak:\n" + combined)
    if proc.returncode != 0:
        raise RuntimeError(
            "Soak failed (exit %s)\n%s" % (proc.returncode, combined)
        )
    for line in reversed(proc.stdout.splitlines()):
        line = line.strip()
        if line.startswith("{") and line.endswith("}"):
            soak = json.loads(line)
            if soak.get("audio_enabled", True):
                raise RuntimeError("Audio should be disabled in headless soak")
            return soak
    raise RuntimeError("No JSON from soak probe:\n" + combined)


def main() -> int:
    parser = argparse.ArgumentParser(description="P5 Godot headless verify")
    parser.add_argument("--godot", help="Path to Godot executable")
    parser.add_argument("--seconds", type=float, default=DEFAULT_SECONDS)
    parser.add_argument("--skip-income", action="store_true")
    args = parser.parse_args()
    godot_bin = _find_godot(args.godot)

    print("ROADMAP P5 — Godot headless verify")
    print(f"Godot: {godot_bin}")
    print("=" * 72)

    print(f"\n[1/2] Soak game_screen ({args.seconds:.0f}s sim tick)...")
    soak = _run_soak(godot_bin, args.seconds)
    print(
        "  PASS — elapsed=%.2fs play_time=%.2fs balance=%.6g"
        % (soak["elapsed"], soak["play_time"], soak["balance"])
    )

    if args.skip_income:
        print("\n[2/2] Income parity — skipped")
    else:
        print("\n[2/2] Income parity (pygame lab vs Godot)...")
        income_cmd = [
            sys.executable,
            str(ROOT / "sim_income_parity.py"),
            "--godot",
            godot_bin,
        ]
        proc = subprocess.run(income_cmd, cwd=str(ROOT))
        if proc.returncode != 0:
            print("  FAIL — income parity")
            return 1
        print("  PASS — income parity")

    print("\n" + "=" * 72)
    print("P5 VERIFY PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
