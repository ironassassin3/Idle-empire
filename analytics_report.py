"""Analytics Report — offline reader for analytics.jsonl.

Run:  python analytics_report.py [--file analytics.jsonl] [--json]

Reads the local analytics log and prints funnel stats, session metrics,
and churn signals useful for soft-launch balance tuning.
"""
from __future__ import annotations
import argparse
import json
import math
import os
import sys
from collections import defaultdict
from pathlib import Path


def _load(path: str) -> list[dict]:
    lines = Path(path).read_text(encoding="utf-8").splitlines()
    records = []
    for ln in lines:
        ln = ln.strip()
        if not ln:
            continue
        try:
            records.append(json.loads(ln))
        except json.JSONDecodeError:
            pass
    return records


def _median(values: list[float]) -> float | None:
    if not values:
        return None
    s = sorted(values)
    n = len(s)
    if n % 2 == 1:
        return s[n // 2]
    return (s[n // 2 - 1] + s[n // 2]) / 2.0


def _pct(num: int, denom: int) -> str:
    if denom == 0:
        return "n/a"
    return f"{100 * num / denom:.1f}%"


def _fmt(n: float) -> str:
    for threshold, suffix in [(1e9, "B"), (1e6, "M"), (1e3, "K")]:
        if abs(n) >= threshold:
            return f"{n / threshold:.1f}{suffix}"
    return str(int(n))


def _fmt_time(secs: float) -> str:
    h = int(secs) // 3600
    m = (int(secs) % 3600) // 60
    s = int(secs) % 60
    if h:
        return f"{h}h {m}m"
    if m:
        return f"{m}m {s}s"
    return f"{s}s"


def analyse(records: list[dict]) -> dict:
    sessions: dict[str, dict] = {}
    prestige_times: list[float] = []
    session_lengths: list[float] = []
    return_gaps: list[float] = []    # time between sessions
    near_prestige_exits = 0
    total_exits = 0
    rank_counts: dict[str, int] = defaultdict(int)
    building_firsts = 0
    influence_firsts = 0
    push_events: list[dict] = []
    session_starts_ts: list[float] = []

    for rec in records:
        ev   = rec.get("event", "")
        sid  = rec.get("session", "")
        ts   = rec.get("ts", 0.0)
        props = rec.get("props", {})

        if ev == "session_start":
            sessions[sid] = {"start_ts": ts, "props": props}
            session_starts_ts.append(ts)

        elif ev == "session_end":
            dur = props.get("duration_s", 0.0)
            session_lengths.append(dur)
            total_exits += 1
            if props.get("near_prestige"):
                near_prestige_exits += 1

        elif ev == "prestige":
            t = props.get("time_to_prestige_s", 0.0)
            if t > 0:
                prestige_times.append(t)

        elif ev == "rank_up":
            rank_counts[props.get("rank", "?")] += 1

        elif ev == "first_building":
            building_firsts += 1

        elif ev == "first_influence":
            influence_firsts += 1

        elif ev == "push_notification":
            push_events.append(props)

    # Compute return gaps from consecutive session starts
    session_starts_ts.sort()
    for i in range(1, len(session_starts_ts)):
        gap = session_starts_ts[i] - session_starts_ts[i - 1]
        if 0 < gap < 86400 * 7:   # ignore gaps > 1 week (likely different players)
            return_gaps.append(gap)

    n_sessions = len(session_lengths)
    n_prestige = len(prestige_times)
    n_returning = sum(1 for s in sessions.values()
                      if s["props"].get("returning"))

    return {
        "sessions": {
            "total": n_sessions,
            "returning": n_returning,
            "return_rate": _pct(n_returning, n_sessions),
        },
        "session_length": {
            "median_s": _median(session_lengths),
            "p25_s": _median(session_lengths[:len(session_lengths)//2]) if session_lengths else None,
            "p75_s": _median(session_lengths[len(session_lengths)//2:]) if session_lengths else None,
        },
        "return_gap": {
            "median_s": _median(return_gaps),
            "n": len(return_gaps),
        },
        "prestige": {
            "total_events": n_prestige,
            "median_time_to_first_s": _median(prestige_times[:max(1, n_prestige//2)]),
            "median_time_s": _median(prestige_times),
        },
        "churn": {
            "near_prestige_exits": near_prestige_exits,
            "total_exits": total_exits,
            "near_prestige_churn_rate": _pct(near_prestige_exits, total_exits),
        },
        "funnel": {
            "first_building": building_firsts,
            "first_influence": influence_firsts,
            "prestige_conversions": n_prestige,
        },
        "rank_ups": dict(rank_counts),
        "push_events": len(push_events),
        "push_triggers": {p.get("payload", {}).get("trigger", "?")
                         for p in push_events if "payload" in p},
        "_raw_session_lengths": session_lengths,
        "_raw_prestige_times": prestige_times,
    }


def _flag(label: str, value, warn: bool = False) -> str:
    mark = " ⚠" if warn else ""
    return f"  {label:<40} {value}{mark}"


def print_report(data: dict) -> None:
    s  = data["sessions"]
    sl = data["session_length"]
    rg = data["return_gap"]
    pr = data["prestige"]
    ch = data["churn"]
    fu = data["funnel"]

    print("=" * 60)
    print("  IDLE EMPIRE — ANALYTICS REPORT")
    print("=" * 60)

    # Sessions
    print("\n── SESSIONS ─────────────────────────────")
    print(_flag("Total sessions:", s["total"]))
    print(_flag("Returning players:", f"{s['returning']} ({s['return_rate']})"))

    med = sl["median_s"]
    med_str = _fmt_time(med) if med is not None else "n/a"
    warn_short = med is not None and med < 120
    print(_flag("Median session length:", med_str, warn_short))
    if warn_short:
        print("    ^ Very short — consider tutorial pacing or first-wow timing.")

    # Return gap
    print("\n── RETURN ENGAGEMENT ────────────────────")
    gap = rg["median_s"]
    gap_str = _fmt_time(gap) if gap is not None else "n/a"
    print(_flag(f"Median return gap ({rg['n']} gaps):", gap_str))
    if gap is not None:
        if gap > 86400:
            print("    ^ >24h gap — push notifications would help here.")
        elif gap < 1800:
            print("    ^ <30m gap — players are actively engaged, great sign.")

    # Prestige funnel
    print("\n── PRESTIGE FUNNEL ──────────────────────")
    print(_flag("Total prestige events:", pr["total_events"]))
    med_p = pr["median_time_s"]
    med_p_str = _fmt_time(med_p) if med_p is not None else "n/a"
    warn_long = med_p is not None and med_p > 3600
    print(_flag("Median time-to-prestige:", med_p_str, warn_long))
    if med_p is not None and med_p > 3600:
        print("    ^ >60m to first prestige — risk of player giving up.")
    if med_p is not None and med_p < 900:
        print("    ^ <15m to prestige — may be too easy, escalate the gate.")

    # Churn signals
    print("\n── CHURN SIGNALS ────────────────────────")
    print(_flag("Near-prestige exits:", ch["near_prestige_exits"]))
    print(_flag("Total exits:", ch["total_exits"]))
    np_rate = ch["near_prestige_churn_rate"]
    warn_churn = "n/a" not in np_rate and float(np_rate.rstrip('%')) > 30
    print(_flag("Near-prestige churn rate:", np_rate, warn_churn))
    if warn_churn:
        print("    ^ >30% quit right before prestige — add a reminder nudge.")

    # Funnel breadth
    print("\n── FUNNEL ───────────────────────────────")
    print(_flag("Sessions reaching first building:", fu["first_building"]))
    print(_flag("Sessions earning first influence:", fu["first_influence"]))
    print(_flag("Sessions reaching prestige:", fu["prestige_conversions"]))

    # Rank distribution
    print("\n── RANK PROGRESSION ─────────────────────")
    if data["rank_ups"]:
        for rank, count in sorted(data["rank_ups"].items(), key=lambda x: -x[1]):
            print(f"  {rank:<30} {count} events")
    else:
        print("  No rank-up events recorded yet.")

    # Push hooks
    print("\n── PUSH NOTIFICATION HOOKS ──────────────")
    print(_flag("Total push events logged:", data["push_events"]))
    if data["push_triggers"]:
        for t in sorted(data["push_triggers"]):
            print(f"  trigger: {t}")

    print("\n" + "=" * 60)

    # Actionable recommendations
    recs = []
    if med is not None and med < 120:
        recs.append("Short sessions: shorten early tutorial or add a faster first-wow.")
    if med_p is not None and med_p > 3600:
        recs.append("Long prestige gate: lower FIRST_PRESTIGE_EARNINGS or add income boost.")
    if med_p is not None and med_p < 900:
        recs.append("Prestige too easy: raise FIRST_PRESTIGE_EARNINGS.")
    if "n/a" not in np_rate and float(np_rate.rstrip('%')) > 30:
        recs.append("High near-prestige churn: wire push_near_prestige to a real notification.")
    if gap is not None and gap > 86400:
        recs.append("Long return gaps: wire push_offline_idle to a real notification.")

    if recs:
        print("\n── RECOMMENDATIONS ──────────────────────")
        for r in recs:
            print(f"  • {r}")
        print()


def main() -> None:
    parser = argparse.ArgumentParser(description="Idle Empire analytics reader")
    parser.add_argument("--file", default="analytics.jsonl")
    parser.add_argument("--json", action="store_true", help="Output raw JSON instead of report")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        print(f"No analytics file found: {args.file}")
        print("Run the game first to generate analytics data.")
        sys.exit(1)

    records = _load(args.file)
    if not records:
        print("Analytics file is empty.")
        sys.exit(0)

    data = analyse(records)

    if args.json:
        out = {k: v for k, v in data.items() if not k.startswith("_")}
        # Make sets JSON-serialisable
        out["push_triggers"] = list(out.get("push_triggers", []))
        print(json.dumps(out, indent=2))
    else:
        print_report(data)


if __name__ == "__main__":
    main()
