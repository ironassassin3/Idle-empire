"""Pygame ↔ Godot income parity check (ROADMAP P5 exit criteria).

Loads identical save fixtures into both engines, compares income_per_second
and passive earnings over a fixed tick count.

Usage:
    python sim_income_parity.py
    python sim_income_parity.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
"""
from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")

import pygame

pygame.init()
pygame.display.set_mode((900, 720))

from src.save_load import apply_save_data, _migrate
from src.state_base import StateManager
from src.states import PlayingState

ROOT = Path(__file__).resolve().parent
GODOT_PROJECT = ROOT / "godot"
PROBE = "res://scripts/tools/income_parity_probe.gd"
TICKS = 600
SAMPLE_EVERY = 60
TOLERANCE_REL = 0.01  # 1% — ROADMAP "within tolerance"


def _building_counts(*counts: int) -> list[int]:
    out = list(counts)
    while len(out) < 11:
        out.append(0)
    return out[:11]


FIXTURES: dict[str, dict] = {
    "fresh_dealer": {
        "balance": 0.0,
        "lifetime_earnings": 0.0,
        "prestige_tokens": 0,
        "prestige_count": 0,
        "influence": 0,
        "heat": 0.0,
        "buildings": _building_counts(1),
        "managers": [False] * 13,
        "upgrades": [False] * 25,
    },
    "mid_spread": {
        "_unlock_territories": 3,
        "balance": 5_000_000.0,
        "lifetime_earnings": 500_000_000.0,
        "prestige_tokens": 40,
        "prestige_count": 1,
        "next_prestige_earnings": 4_000_000_000.0,
        "influence": 800,
        "heat": 55.0,
        "buildings": _building_counts(40, 20, 12, 8, 6, 5, 4, 3, 2, 2, 1),
        "managers": [True] * 13,
        "upgrades": [False] * 25,
        "crew": {
            "protection": 20,
            "collection": 40,
            "smuggling": 10,
            "territory": 10,
            "heat": 5,
        },
    },
    "mid_red_dragon": {
        "_unlock_territories": 3,
        "balance": 5_000_000.0,
        "lifetime_earnings": 500_000_000.0,
        "prestige_tokens": 40,
        "prestige_count": 1,
        "next_prestige_earnings": 4_000_000_000.0,
        "influence": 800,
        "heat": 55.0,
        "buildings": _building_counts(40, 20, 12, 8, 6, 5, 4, 3, 2, 2, 1),
        "managers": [True] * 13,
        "upgrades": [False] * 25,
        "crew": {
            "protection": 20,
            "collection": 40,
            "smuggling": 10,
            "territory": 10,
            "heat": 5,
        },
        "dragon_patron": "red",
        "dragon_xp": 100,
        "dragon_red_elim_count": 2,
    },
    # High rank: prestige_tokens=420 reaches National Influence, so cumulative
    # rank perks give +10% income (Crime Lord 0.05 + National Influence 0.05).
    # Exercises rank_income_bonus on both engines (parity debt closed P-debt).
    "late_national": {
        "_unlock_territories": 3,
        "balance": 5_000_000.0,
        "lifetime_earnings": 50_000_000_000.0,
        "prestige_tokens": 420,
        "prestige_count": 5,
        "next_prestige_earnings": 400_000_000_000.0,
        "influence": 4000,
        "heat": 30.0,
        "buildings": _building_counts(60, 40, 30, 20, 15, 12, 10, 8, 6, 4, 3),
        "managers": [True] * 13,
        "upgrades": [False] * 25,
        "crew": {
            "protection": 30,
            "collection": 60,
            "smuggling": 20,
            "territory": 20,
            "heat": 10,
        },
    },
}


def _make_pygame_state(fixture: dict) -> PlayingState:
    data = _migrate(dict(fixture))
    data.pop("_label", None)
    unlock_n = int(data.pop("_unlock_territories", 0))
    # Avoid offline/daily return bonuses — parity compares passive income only.
    data["save_timestamp"] = time.time()
    data["last_login_date"] = time.strftime("%Y-%m-%d")
    sm = StateManager()
    ps = PlayingState(sm)
    apply_save_data(ps, data)
    if unlock_n > 0:
        owned = 0
        for t in ps.territories:
            if owned >= unlock_n:
                break
            t.unlocked = True
            t.owner = "player"
            owned += 1
    ps._ips_dirty = True
    return ps


def _tick_passive_pygame(ps: PlayingState, ticks: int, dt: float = 1.0) -> dict:
    ips0 = float(ps.income_per_second)
    total = 0.0
    samples = [ips0]
    for i in range(ticks):
        ips = float(ps.income_per_second)
        if i > 0 and i % SAMPLE_EVERY == 0:
            samples.append(ips)
        total += ips * dt
        ps.balance += ips * dt
        ps.lifetime_earnings += ips * dt
        ps._play_time += dt
    return {
        "ips0": ips0,
        "total_passive": total,
        "samples": samples,
        "balance": ps.balance,
        "lifetime_earnings": ps.lifetime_earnings,
    }


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


def _run_godot(godot_bin: str, fixture: dict, ticks: int) -> dict:
    payload = dict(fixture)
    payload.pop("_label", None)
    unlock_n = int(payload.pop("_unlock_territories", 0))
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False, encoding="utf-8"
    ) as f:
        json.dump(payload, f)
        path = f.name
    try:
        cmd = [
            godot_bin,
            "--path",
            str(GODOT_PROJECT),
            "--headless",
            "-s",
            PROBE,
            "--",
            "--fixture",
            path,
            "--ticks",
            str(ticks),
        ]
        if unlock_n > 0:
            cmd.extend(["--unlock-territories", str(unlock_n)])
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=str(ROOT),
        )
        if proc.returncode != 0:
            raise RuntimeError(
                "Godot probe failed (exit %s)\n%s\n%s"
                % (proc.returncode, proc.stdout, proc.stderr)
            )
        for line in reversed(proc.stdout.splitlines()):
            line = line.strip()
            if line.startswith("{") and line.endswith("}"):
                return json.loads(line)
        raise RuntimeError("No JSON output from Godot probe:\n" + proc.stdout + proc.stderr)
    finally:
        os.unlink(path)


def _close(a: float, b: float) -> bool:
    if not (math.isfinite(a) and math.isfinite(b)):
        return False
    if abs(b) < 1e-9:
        return abs(a - b) < 1e-6
    return abs(a - b) / abs(b) <= TOLERANCE_REL or abs(a - b) <= 0.01


def _compare(name: str, py: dict, gd: dict) -> list[str]:
    fails: list[str] = []
    for key in ("ips0", "total_passive", "balance", "lifetime_earnings"):
        pv, gv = float(py[key]), float(gd[key])
        if not _close(pv, gv):
            rel = abs(pv - gv) / max(abs(gv), 1e-9) * 100.0
            fails.append(
                f"{name} {key}: pygame={pv:.6g} godot={gv:.6g} diff={rel:.3f}%"
            )
    ps, gs = py["samples"], gd["samples"]
    n = min(len(ps), len(gs))
    for i in range(n):
        if not _close(float(ps[i]), float(gs[i])):
            fails.append(
                f"{name} sample[{i}]: pygame={ps[i]:.6g} godot={gs[i]:.6g}"
            )
    return fails


def main() -> int:
    parser = argparse.ArgumentParser(description="Pygame vs Godot income parity")
    parser.add_argument("--godot", help="Path to Godot executable")
    parser.add_argument("--ticks", type=int, default=TICKS)
    args = parser.parse_args()
    godot_bin = _find_godot(args.godot)

    print("ROADMAP P5 — income parity (pygame lab vs Godot port)")
    print(f"Godot: {godot_bin}")
    print(f"Ticks: {args.ticks}  tolerance: {TOLERANCE_REL * 100:.1f}%")
    print("=" * 72)

    all_fails: list[str] = []
    for name, base in FIXTURES.items():
        fixture = dict(base)
        fixture["_label"] = name
        py_state = _make_pygame_state(fixture)
        py_out = _tick_passive_pygame(py_state, args.ticks)
        gd_out = _run_godot(godot_bin, fixture, args.ticks)
        fails = _compare(name, py_out, gd_out)
        status = "PASS" if not fails else "FAIL"
        print(f"\n[{status}] {name}")
        print(f"  ips0: pygame {py_out['ips0']:.6g}  godot {gd_out['ips0']:.6g}")
        print(
            f"  passive {args.ticks}s: pygame {py_out['total_passive']:.6g}  "
            f"godot {gd_out['total_passive']:.6g}"
        )
        for f in fails:
            print(f"  ! {f}")
        all_fails.extend(fails)

    print("\n" + "=" * 72)
    if all_fails:
        print(f"FAIL — {len(all_fails)} mismatch(es)")
        return 1
    print(f"PASS — all {len(FIXTURES)} fixtures within tolerance")
    return 0


if __name__ == "__main__":
    sys.exit(main())
