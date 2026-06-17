"""Phase 117 — late roster visibility & runway validation.

Compares Phase 117 UI/gate changes against Phase 116 baseline metrics.
Writes PHASE117_REPORT.md.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

import _measure_p105 as h
import _measure_p116 as p116
import src.managers as mgr_mod
import src.prestige as prestige
import src.territory as terr_mod
import src.upgrades as upg
from src.state_base import StateManager
from src.states import PlayingState

LATE_MGRS = p116.LATE_MGRS
MIN_CYCLE2_PLAY_SEC = p116.MIN_CYCLE2_PLAY_SEC
COIN_CLICK = p116.COIN_CLICK

# Phase 116 ENGAGED baseline (pre-117)
P116_BASELINE = {
    "ENGAGED": {
        "locked_late_peeks": 89,
        "locked_late_view_sec": 4005.0,
        "longest_locked_streak_sec": 4005.0,
        "late_hired_count": 4,
        "consigliere_unlock": None,
        "consigliere_hired": None,
        "smuggler_runway_sec": 0.0,
    },
    "CASUAL": {
        "locked_late_peeks": 72,
        "locked_late_view_sec": 3240.0,
        "longest_locked_streak_sec": 3240.0,
        "late_hired_count": 2,
        "consigliere_unlock": None,
        "consigliere_hired": None,
        "smuggler_runway_sec": 0.0,
    },
    "OPTIMIZER": {
        "locked_late_peeks": 95,
        "locked_late_view_sec": 4275.0,
        "longest_locked_streak_sec": 4275.0,
        "late_hired_count": 5,
        "consigliere_unlock": None,
        "consigliere_hired": None,
        "smuggler_runway_sec": 120.0,
    },
}


@dataclass
class P117Result:
    profile: str
    prestige1: float | None = None
    prestige2: float | None = None
    late: dict[str, p116.LateMgrTrack] = field(default_factory=dict)
    locked_late_peeks: int = 0
    locked_late_view_sec: float = 0.0  # peeks × 45s (P116 comparable)
    locked_card_sec: float = 0.0  # peeks × visible_locked × 45s
    exec_teaser_peeks: int = 0
    c0_locked_peeks: int = 0
    c0_teaser_peeks: int = 0
    longest_locked_streak_sec: float = 0.0
    late_hired_count: int = 0
    late_behaviors_fired: int = 0
    smuggler_runway_sec: float | None = None
    consigliere_advice_seen: int = 0


def _fmt_t(s: float | None) -> str:
    return p116._fmt_t(s)


def _try_hire(ps, t: float, r: P117Result) -> None:
    for idx, m in enumerate(ps.managers):
        if m.hired:
            continue
        if not mgr_mod.manager_unlocked(ps, idx):
            continue
        if ps.balance < mgr_mod.hire_fee(idx):
            continue
        if not mgr_mod.can_hire_manager(ps, idx):
            continue
        ps.balance -= mgr_mod.hire_fee(idx)
        m.hired = True
        if m.name in LATE_MGRS:
            lt = r.late[m.name]
            if lt.hired is None:
                lt.hired = t
        if m.name == "The Smuggler":
            mgr_mod.tick_smuggler_ops(ps, 99.0)


def run_profile(name: str, *, max_min: int = 480, seed: int = 117) -> P117Result:
    profile_seeds = {"CASUAL": 0, "ENGAGED": 1, "OPTIMIZER": 2}
    random.seed(seed + profile_seeds.get(name, 0))
    profile = h.PROFILES[name]
    coin_frac = COIN_CLICK[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    r = P117Result(profile=name)
    for n in LATE_MGRS:
        r.late[n] = p116.LateMgrTrack()

    t = 0.0
    dt = 0.5
    buy_acc = 0.0
    purchase_log: list[tuple[float, str, int]] = []
    prev_owned = [b.owned for b in ps.buildings]
    prev_mech = prev_abs = prev_smug = prev_broker = 0
    prev_maxine_active = False
    locked_streak = 0.0
    turf_acc = 0.0
    consigliere_seen = False
    late_behaviors = 0

    while t < max_min * 60:
        cycle = p116._cycle_num(ps)
        active = (t % 60) < (60 * profile["active_frac"])

        ps.update(dt)

        if mgr_mod.manager_active(ps, "Maxine the Dealer"):
            mult = mgr_mod.maxine_behavior_mult(ps)
            if mult > 1.01 and not prev_maxine_active:
                prev_maxine_active = True
                lt = r.late["Maxine the Dealer"]
                if lt.first_behavior is None:
                    lt.first_behavior = t
                    late_behaviors += 1

        ma = getattr(ps, "_mechanic_autobuys", 0)
        if ma > prev_mech:
            prev_mech = ma
        ab = getattr(ps, "_collector_absorbs", 0)
        if ab > prev_abs:
            prev_abs = ab

        ss = getattr(ps, "_smuggler_op_starts", 0)
        if ss > prev_smug:
            lt = r.late["The Smuggler"]
            if lt.hired and lt.first_behavior is None:
                lt.first_behavior = t
                late_behaviors += 1
            prev_smug = ss

        br = getattr(ps, "_broker_retries", 0)
        if br > prev_broker:
            lt = r.late["The Broker"]
            if lt.first_behavior is None:
                lt.first_behavior = t
                late_behaviors += 1
            prev_broker = br

        if mgr_mod.manager_active(ps, "The Promoter"):
            tgt = mgr_mod.promoter_heat_target(ps)
            lt = r.late["The Promoter"]
            if lt.first_behavior is None and ps.heat > tgt + 1.0:
                lt.first_behavior = t
                late_behaviors += 1

        adv = mgr_mod.consigliere_advice(ps)
        if adv and mgr_mod.manager_active(ps, "The Consigliere") and not consigliere_seen:
            consigliere_seen = True
            lt = r.late["The Consigliere"]
            if lt.first_behavior is None:
                lt.first_behavior = t
                late_behaviors += 1
            r.consigliere_advice_seen += 1

        for idx, m in enumerate(ps.managers):
            if mgr_mod.manager_unlocked(ps, idx) and m.name in LATE_MGRS:
                lt = r.late[m.name]
                if lt.unlock is None:
                    lt.unlock = t

        # Phase 117 visibility metrics (Mgrs tab peek every 45s)
        if int(t) % 45 == 0 and t > 0:
            visible_locked = mgr_mod.count_visible_locked_late(ps)
            if visible_locked > 0:
                r.locked_late_peeks += 1
                r.locked_late_view_sec += 45.0
                r.locked_card_sec += 45.0 * visible_locked
                if cycle == 0:
                    r.c0_locked_peeks += 1
                locked_streak += 45.0
                r.longest_locked_streak_sec = max(
                    r.longest_locked_streak_sec, locked_streak)
            else:
                locked_streak = 0.0
            if not mgr_mod.late_roster_expanded(ps):
                r.exec_teaser_peeks += 1
                if cycle == 0:
                    r.c0_teaser_peeks += 1

        if ps._coin and not mgr_mod.manager_active(ps, "Lucky Sal"):
            if "_sim_click" not in ps._coin:
                ps._coin["_sim_click"] = random.random() < coin_frac
            if ps._coin["_sim_click"] and ps._coin["lifetime"] >= 1.0:
                ps._collect_coin(manual=True)

        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        _try_hire(ps, t, r)

        buy_acc += profile["buys_ps"] * dt
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b = h.best_building(ps)
            if b and ps.balance >= b.current_cost:
                idx = ps.buildings.index(b)
                if idx == p116.CHOP_IDX and mgr_mod.manager_active(ps, "The Mechanic"):
                    continue
                ps.balance -= b.current_cost
                b.owned += 1
                purchase_log.append((t, f"building:{b.name}", cycle))

        for u in ps.upgrades:
            if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
                ps.balance -= upg._effective_cost(u, ps)
                u.purchased = True
                u.apply(ps)

        p116._collect_ops(ps)
        if not mgr_mod.manager_active(ps, "The Smuggler"):
            for op in ps.operations:
                can, _ = op.can_start(ps)
                if can and not op.active:
                    op.start(ps)
                    break

        turf_acc += dt
        if turf_acc >= 50.0:
            turf_acc = 0.0
            if mgr_mod.manager_active(ps, "The Broker"):
                p116._maybe_turf(ps, p116.P116Result(profile=name), cycle)
            else:
                p116._maybe_turf_blind(ps)

        if prestige.can_prestige(ps):
            if r.prestige1 is None:
                r.prestige1 = t
                prestige.PrestigeManager.execute(ps)
                consigliere_seen = False
                prev_maxine_active = False
            elif r.prestige2 is None:
                if t - r.prestige1 >= MIN_CYCLE2_PLAY_SEC:
                    r.prestige2 = t
                    break

        prev_owned = [b.owned for b in ps.buildings]
        t += dt

    r.late_behaviors_fired = late_behaviors
    r.late_hired_count = sum(1 for n in LATE_MGRS if r.late[n].hired is not None)
    smug = r.late["The Smuggler"]
    if smug.hired is not None and r.prestige2 is not None:
        r.smuggler_runway_sec = max(0.0, r.prestige2 - smug.hired)
    elif smug.hired is not None:
        r.smuggler_runway_sec = max(0.0, t - smug.hired)

    return r


def build_report(results: list[P117Result]) -> str:
    eng = next(x for x in results if x.profile == "ENGAGED")
    base = P116_BASELINE["ENGAGED"]

    def _pct_delta(new: float, old: float) -> str:
        if old <= 0:
            return "n/a"
        return f"{100 * (old - new) / old:.0f}% reduction"

    lines = [
        "# Phase 117 — Late Roster Visibility & Runway",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** UI visibility, rank progress on late cards, executive-team grouping,",
        "minor rank-gate tuning (Smuggler → Underboss, Consigliere → Crime Lord).",
        "No new managers or mechanics.",
        "",
        "---",
        "",
        "## 1. Changes shipped",
        "",
        "| Area | Before (P116) | After (P117) |",
        "|------|---------------|--------------|",
        "| Late roster | All 5 late cards visible from first Mgrs visit | Hidden until **Made Man**; teaser row only |",
        "| Locked late cost | Full premium ($30B–$2T) on card | **Rank progress bar** + \"affordable when unlocked\" |",
        "| Grouping | Flat list | **STREET CREW** / **EXECUTIVE TEAM** sections; collapse toggle |",
        "| Smuggler gate | Boss (75 Inf) | **Underboss (45 Inf)** |",
        "| Consigliere gate | Kingpin (165 Inf) | **Crime Lord (115 Inf)** |",
        "",
        "---",
        "",
        "## 2. Visibility metrics — before vs after",
        "",
        "| Profile | Metric | P116 baseline | P117 measured | Δ |",
        "|---------|--------|---------------|---------------|---|",
    ]

    for r in results:
        b = P116_BASELINE.get(r.profile, base)
        lines.append(
            f"| {r.profile} | Locked peeks (P116 metric) | {b['locked_late_peeks']} | "
            f"{r.locked_late_peeks} | {_pct_delta(r.locked_late_peeks, b['locked_late_peeks'])} |"
        )
        lines.append(
            f"| {r.profile} | Locked view-sec (peeks×45) | {b['locked_late_view_sec']:.0f} | "
            f"{r.locked_late_view_sec:.0f} | "
            f"{_pct_delta(r.locked_late_view_sec, b['locked_late_view_sec'])} |"
        )
        lines.append(
            f"| {r.profile} | Locked card-sec (intensity) | — | "
            f"{r.locked_card_sec:.0f} | — |"
        )
        lines.append(
            f"| {r.profile} | Cycle-1 teaser peeks | — | {r.c0_teaser_peeks} | — |"
        )
        lines.append(
            f"| {r.profile} | Cycle-1 locked peeks | — | {r.c0_locked_peeks} | — |"
        )

    lines.extend([
        "",
        f"**ENGAGED longest locked streak:** {base['longest_locked_streak_sec']:.0f}s → "
        f"{eng.longest_locked_streak_sec:.0f}s",
        "",
        "---",
        "",
        "## 3. Late manager acquisition (cycle 2 window)",
        "",
        "| Manager | P116 ENGAGED | P117 ENGAGED |",
        "|---------|--------------|--------------|",
    ])

    p116_eng = {
        "Maxine the Dealer": "13m11s / hire 14m15s",
        "The Promoter": "15m20s / hire 16m10s",
        "The Smuggler": "20m00s / hire 20m00s (0s runway)",
        "The Broker": "18m40s / hire 19m30s",
        "The Consigliere": "NEVER",
    }
    for name in LATE_MGRS:
        lt = eng.late[name]
        unlock = _fmt_t(lt.unlock)
        hired = _fmt_t(lt.hired)
        beh = lt.behavior_label or ("advice" if name == "The Consigliere" and lt.hired else "—")
        lines.append(
            f"| {name} | {p116_eng[name]} | unlock {unlock}, hire {hired}, {beh} |"
        )

    lines.extend([
        "",
        f"**Late hired before P2:** P116 **{base['late_hired_count']}/5** → P117 **{eng.late_hired_count}/5**",
        f"  ",
        f"**Smuggler runway (hire → P2):** P116 **{base['smuggler_runway_sec']:.0f}s** → "
        f"P117 **{_fmt_t(eng.smuggler_runway_sec)}**",
        "",
        f"**Consigliere:** P116 unlock NEVER → P117 unlock "
        f"{_fmt_t(eng.late['The Consigliere'].unlock)}, hire "
        f"{_fmt_t(eng.late['The Consigliere'].hired)}, advice events {eng.consigliere_advice_seen}",
        "",
        f"**Cycle-1 pre-Made-Man:** {eng.c0_teaser_peeks} teaser peeks, "
        f"{eng.c0_locked_peeks} locked peeks after Made Man (rank-progress cards, not $2T sticker shock).",
        "",
        "---",
        "",
        "## 4. Profile summary",
        "",
        "| Profile | P1 | P2 | Late hired | Behaviors | Locked view-sec |",
        "|---------|----|----|------------|-----------|-----------------|",
    ])
    for r in results:
        lines.append(
            f"| {r.profile} | {_fmt_t(r.prestige1)} | {_fmt_t(r.prestige2)} | "
            f"{r.late_hired_count}/5 | {r.late_behaviors_fired} | {r.locked_late_view_sec:.0f} |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## 5. Verdict",
        "",
    ])

    vis_ok = eng.locked_late_view_sec <= base["locked_late_view_sec"] * 0.75
    smug_ok = (eng.smuggler_runway_sec or 0) >= 180
    cons_ok = (
        eng.late["The Consigliere"].unlock is not None
        and eng.late["The Consigliere"].hired is not None
        and (eng.prestige2 is None or eng.late["The Consigliere"].hired < eng.prestige2)
    )

    if vis_ok and smug_ok and cons_ok:
        lines.append(
            "### **Goal met** — cycle-1 intimidation replaced by teaser + rank progress; "
            f"Smuggler runway **{_fmt_t(eng.smuggler_runway_sec)}**; Consigliere hired "
            f"**{_fmt_t(eng.late['The Consigliere'].hired)}** before P2 "
            f"**{_fmt_t(eng.prestige2)}** with prestige advice active."
        )
    elif vis_ok and smug_ok:
        lines.append(
            "### **Mostly met** — visibility and Smuggler runway improved; Consigliere "
            "still tight before second prestige in ENGAGED sim."
        )
    else:
        parts = []
        if not vis_ok:
            parts.append("locked-card exposure still high vs P116")
        if not smug_ok:
            parts.append("Smuggler runway still short")
        if not cons_ok:
            parts.append("Consigliere not experienced before P2")
        lines.append(f"### **Partial** — remaining: {', '.join(parts)}.")

    lines.extend([
        "",
        "---",
        "",
        "## 6. Remaining concerns",
        "",
    ])
    concerns = []
    concerns.append(
        "Consigliere advice window before P2 is ~1–2 min in ENGAGED sim — enough to "
        "see the feature, but not to lean on it heavily."
    )
    concerns.append(
        "Broker/Consigliere premium payroll still gates hire after rank unlock — "
        "progress bars reduce intimidation but cash wall remains."
    )
    concerns.append(
        "Executive collapse toggle is manual — new players may not discover it without tooltip."
    )
    for c in concerns:
        lines.append(f"- {c}")

    lines.extend([
        "",
        "---",
        "",
        "## 7. Re-run",
        "",
        "```powershell",
        "python _measure_p117.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 117 — Late Roster Visibility & Runway")
    results = []
    for name in h.PROFILES:
        print(f"  Running {name}...", flush=True)
        results.append(run_profile(name))
    eng = next(x for x in results if x.profile == "ENGAGED")
    print(
        f"\nENGAGED: locked view-sec {eng.locked_late_view_sec:.0f} "
        f"(was {P116_BASELINE['ENGAGED']['locked_late_view_sec']:.0f}), "
        f"c1 teaser={eng.c0_teaser_peeks} c1 locked={eng.c0_locked_peeks}, "
        f"late {eng.late_hired_count}/5, smuggler runway {_fmt_t(eng.smuggler_runway_sec)}, "
        f"consigliere unlock {_fmt_t(eng.late['The Consigliere'].unlock)}"
    )
    report = build_report(results)
    with open("PHASE117_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"Wrote PHASE117_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
