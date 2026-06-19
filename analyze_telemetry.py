#!/usr/bin/env python3
"""Analyze exported Godot telemetry JSONL — prestige cadence report (§4.4).

Reads one or more JSONL files (local export or user://telemetry.jsonl copy)
and prints time-to-prestige statistics to help close the 8× prestige-cadence
balance question.

Usage:
    python analyze_telemetry.py path/to/telemetry.jsonl
    python analyze_telemetry.py analytics.jsonl godot_export.jsonl
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path
from statistics import mean, median


def load_events(paths: list[Path]) -> list[dict]:
    events: list[dict] = []
    for path in paths:
        if not path.is_file():
            print(f"skip missing: {path}", file=sys.stderr)
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    events.sort(key=lambda e: float(e.get("t", 0)))
    return events


def prestige_cadence(events: list[dict]) -> dict:
    by_session: dict[str, list[dict]] = defaultdict(list)
    for ev in events:
        if ev.get("ev") != "prestige":
            continue
        sid = str(ev.get("s", "unknown"))
        by_session[sid].append(ev)

    cycle_secs: list[float] = []
    prestige_counts: list[int] = []
    for _sid, pres in by_session.items():
        pres.sort(key=lambda e: float(e.get("t", 0)))
        for i, ev in enumerate(pres):
            prestige_counts.append(int(ev.get("n", ev.get("prestige_count", i + 1))))
            cs = ev.get("cycle_secs")
            if cs is not None:
                cycle_secs.append(float(cs))

    return {
        "sessions_with_prestige": len(by_session),
        "total_prestiges": sum(len(v) for v in by_session.values()),
        "cycle_secs": cycle_secs,
        "prestige_counts": prestige_counts,
    }


def fmt_secs(secs: float) -> str:
    if secs >= 3600:
        return f"{secs / 3600:.2f}h"
    if secs >= 60:
        return f"{secs / 60:.1f}m"
    return f"{secs:.0f}s"


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 1
    paths = [Path(p) for p in argv[1:]]
    events = load_events(paths)
    if not events:
        print("No events loaded.")
        return 1

    stats = prestige_cadence(events)
    cycles = stats["cycle_secs"]
    print("=== Telemetry prestige cadence ===")
    print(f"Events loaded:     {len(events)}")
    print(f"Sessions w/ prestige:{stats['sessions_with_prestige']}")
    print(f"Total prestiges:   {stats['total_prestiges']}")
    if not cycles:
        print("No cycle_secs on prestige events — run Godot build with telemetry enabled.")
        return 0
    print(f"Cycles sampled:    {len(cycles)}")
    print(f"Median cycle:      {fmt_secs(median(cycles))}")
    print(f"Mean cycle:        {fmt_secs(mean(cycles))}")
    print(f"Min / Max:         {fmt_secs(min(cycles))} / {fmt_secs(max(cycles))}")
    if stats["prestige_counts"]:
        print(f"Latest prestige # median: {int(median(stats['prestige_counts']))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
