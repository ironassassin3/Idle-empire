"""Deterministic release gate for the player-visible prestige cadence.

Runs the real pygame economy/state path through the balanced human strategy.
Targets come from PRESTIGE_PACING_NOTES.md. This is intentionally a focused,
fast check; the broader strategy sweep remains sim_prestige_strategies.py.
"""
from __future__ import annotations

import random
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sim_prestige_strategies import STRATEGIES, fmt_t, gap, run_strategy


P1_WINDOW = (40 * 60, 65 * 60)
P2_GAP_WINDOW = (25 * 60, 45 * 60)


def _inside(value: float, window: tuple[float, float]) -> bool:
    return window[0] <= value <= window[1]


def main() -> int:
    random.seed(int(os.environ.get("IDLE_SIM_SEED", "1337")))
    balanced = next(s for s in STRATEGIES if s.name == "balanced")
    result = run_strategy(balanced, minutes=130, active_frac=0.33, prestige_target=2)
    if len(result.prestige_events) < 2:
        print("PRESTIGE_CADENCE FAIL — balanced play did not reach two prestiges")
        return 1

    p1 = gap(result.prestige_events, 0)
    p2_gap = gap(result.prestige_events, 1)
    print(
        "PRESTIGE_CADENCE balanced "
        f"P1={fmt_t(p1)} target=40–65m "
        f"P1→P2={fmt_t(p2_gap)} target=25–45m"
    )
    first = result.prestige_events[0]
    print(
        f"P1 outcome: +{first.influence_gain} Influence, "
        f"total={first.total_influence}, IPS={first.ips_before:.3g}, "
        f"P2 earnings gate={first.next_gate:.3g}"
    )
    if len(result.requirement_met_at) >= 2:
        p1_at = result.prestige_events[0].time
        p2_requirements = result.requirement_met_at[1]
        breakdown = ", ".join(
            f"{key}={fmt_t(when - p1_at)}"
            for key, when in sorted(p2_requirements.items(), key=lambda item: item[1])
        )
        print("P2 requirement timing after P1: " + breakdown)
    failures: list[str] = []
    if not _inside(p1, P1_WINDOW):
        failures.append("first prestige is outside its engagement window")
    if not _inside(p2_gap, P2_GAP_WINDOW):
        failures.append("second prestige cadence collapses or walls")
    if failures:
        for failure in failures:
            print("FAIL " + failure)
        return 1
    print("PRESTIGE_CADENCE PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
