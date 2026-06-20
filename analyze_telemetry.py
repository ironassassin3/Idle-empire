#!/usr/bin/env python3
"""Analyze exported Godot telemetry JSONL — prestige cadence + P14 UI funnel.

Reads one or more JSONL files (local export, probe output, or user://telemetry.jsonl copy)
and prints:
  - Prestige cycle statistics (§4.4 balance question)
  - P14 UI event coverage, FTUE step drop-off, overlay dismiss timing, tab paths

Usage:
    python analyze_telemetry.py path/to/telemetry.jsonl
    python analyze_telemetry.py telemetry_probe.jsonl analytics.jsonl
"""

from __future__ import annotations

import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from statistics import mean, median

P14_UI_EVENTS = (
    "ui_session_start",
    "ui_tab_open",
    "ui_overlay_shown",
    "ui_overlay_dismiss_ms",
    "ui_buy_mult_changed",
    "ui_badge_click",
    "ui_badge_impression",
    "ui_prestige_tree_open",
    "ui_config_open",
    "ui_first_building_buy_ms",
    "ui_tutorial_step",
)


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
    events.sort(key=lambda e: float(e.get("t", e.get("ts", 0))))
    return events


def event_name(ev: dict) -> str:
    return str(ev.get("ev") or ev.get("event") or "")


def session_id(ev: dict) -> str:
    return str(ev.get("s") or ev.get("session") or "unknown")


def prestige_cadence(events: list[dict]) -> dict:
    by_session: dict[str, list[dict]] = defaultdict(list)
    for ev in events:
        if event_name(ev) != "prestige":
            continue
        by_session[session_id(ev)].append(ev)

    cycle_secs: list[float] = []
    prestige_counts: list[int] = []
    for pres in by_session.values():
        pres.sort(key=lambda e: float(e.get("t", e.get("ts", 0))))
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


def fmt_ms(ms: float) -> str:
    if ms >= 60_000:
        return f"{ms / 60_000:.1f}m"
    if ms >= 1000:
        return f"{ms / 1000:.1f}s"
    return f"{ms:.0f}ms"


def p14_funnel(events: list[dict]) -> dict:
    ui_counts: Counter[str] = Counter()
    tutorial_reached: Counter[int] = Counter()
    tutorial_sessions: dict[str, set[int]] = defaultdict(set)
    overlay_dismiss: dict[str, list[float]] = defaultdict(list)
    tab_paths: dict[str, list[str]] = defaultdict(list)
    first_buy_ms: list[float] = []

    for ev in events:
        name = event_name(ev)
        if name in P14_UI_EVENTS:
            ui_counts[name] += 1
        sid = session_id(ev)
        if name in ("ui_tutorial_step", "ftue_step"):
            step = int(ev.get("step", -1))
            if step >= 0:
                tutorial_reached[step] += 1
                tutorial_sessions[sid].add(step)
        if name == "ui_overlay_dismiss_ms":
            kind = str(ev.get("kind", "unknown"))
            overlay_dismiss[kind].append(float(ev.get("ms", 0)))
        if name == "ui_tab_open":
            tab_paths[sid].append(str(ev.get("tab", "?")))
        if name == "ui_first_building_buy_ms":
            first_buy_ms.append(float(ev.get("ms", 0)))

    max_step = max(tutorial_reached.keys(), default=-1)
    drop_off: list[tuple[int, int, str]] = []
    for step in range(max_step + 1):
        reached = tutorial_reached.get(step, 0)
        next_reached = tutorial_reached.get(step + 1, 0) if step < max_step else 0
        if step < max_step and reached > 0:
            pct = 100.0 * next_reached / reached
            drop_off.append((step, reached, f"{pct:.0f}% -> step {step + 1}"))
        elif reached > 0:
            drop_off.append((step, reached, "terminal"))

    overlay_stats: dict[str, dict] = {}
    for kind, values in overlay_dismiss.items():
        if not values:
            continue
        overlay_stats[kind] = {
            "n": len(values),
            "median_ms": median(values),
            "mean_ms": mean(values),
        }

    path_samples: list[str] = []
    for sid, tabs in tab_paths.items():
        if len(tabs) >= 2:
            path_samples.append(" -> ".join(tabs[:8]))
        if len(path_samples) >= 5:
            break

    return {
        "ui_counts": dict(ui_counts),
        "ui_kinds_seen": len(ui_counts),
        "tutorial_drop_off": drop_off,
        "overlay_dismiss": overlay_stats,
        "tab_path_samples": path_samples,
        "first_buy_ms_median": median(first_buy_ms) if first_buy_ms else None,
        "sessions_with_tabs": len(tab_paths),
    }


def print_prestige_report(events: list[dict], stats: dict) -> None:
    cycles = stats["cycle_secs"]
    print("=== Telemetry prestige cadence ===")
    print(f"Events loaded:        {len(events)}")
    print(f"Sessions w/ prestige: {stats['sessions_with_prestige']}")
    print(f"Total prestiges:      {stats['total_prestiges']}")
    if not cycles:
        print("No cycle_secs on prestige events — run Godot build with telemetry enabled.")
        return
    print(f"Cycles sampled:       {len(cycles)}")
    print(f"Median cycle:         {fmt_secs(median(cycles))}")
    print(f"Mean cycle:           {fmt_secs(mean(cycles))}")
    print(f"Min / Max:            {fmt_secs(min(cycles))} / {fmt_secs(max(cycles))}")
    if stats["prestige_counts"]:
        print(f"Latest prestige # median: {int(median(stats['prestige_counts']))}")


def print_p14_report(funnel: dict) -> None:
    print()
    print("=== P14 UI funnel ===")
    print(f"UI event kinds seen:  {funnel['ui_kinds_seen']} / {len(P14_UI_EVENTS)}")
    missing = [e for e in P14_UI_EVENTS if e not in funnel["ui_counts"]]
    if missing:
        print(f"Missing (no rows):    {', '.join(missing)}")
    for name in P14_UI_EVENTS:
        if name in funnel["ui_counts"]:
            print(f"  {name}: {funnel['ui_counts'][name]}")

    print()
    print("FTUE tutorial step -> drop-off")
    if not funnel["tutorial_drop_off"]:
        print("  (no ui_tutorial_step / ftue_step events)")
    else:
        print(f"  {'Step':<6} {'Reached':<8} Drop-off")
        for step, reached, note in funnel["tutorial_drop_off"]:
            print(f"  {step:<6} {reached:<8} {note}")

    print()
    print("Overlay dismiss (median ms by kind)")
    if not funnel["overlay_dismiss"]:
        print("  (no ui_overlay_dismiss_ms events)")
    else:
        for kind, st in sorted(funnel["overlay_dismiss"].items()):
            flag = " (>8s)" if st["median_ms"] > 8000 else ""
            print(
                f"  {kind}: n={st['n']} median={fmt_ms(st['median_ms'])}"
                f" mean={fmt_ms(st['mean_ms'])}{flag}"
            )

    print()
    print("Tab path samples (first sessions with >=2 tab opens)")
    if not funnel["tab_path_samples"]:
        print("  (no ui_tab_open sequences)")
    else:
        for path in funnel["tab_path_samples"]:
            print(f"  {path}")

    if funnel["first_buy_ms_median"] is not None:
        print()
        print(f"First building buy (median): {fmt_ms(funnel['first_buy_ms_median'])}")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 1
    paths = [Path(p) for p in argv[1:]]
    events = load_events(paths)
    if not events:
        print("No events loaded.")
        return 1

    print_prestige_report(events, prestige_cadence(events))
    print_p14_report(p14_funnel(events))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
