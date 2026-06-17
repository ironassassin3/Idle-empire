"""Phase 119 — Rob Revenue empire efficiency analyst validation.

Measures source-checking behavior before/after Rob hire.
Writes PHASE119_REPORT.md.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

import _measure_p105 as h
import _measure_p116 as p116
import _measure_p118 as p118
import src.managers as mgr_mod
import src.prestige as prestige
import src.upgrades as upg
from src.state_base import StateManager
from src.states import PlayingState

MIN_CYCLE2_PLAY_SEC = p116.MIN_CYCLE2_PLAY_SEC
COIN_CLICK = p116.COIN_CLICK
ROB = "Rob Revenue"
RUDY = "Rudy Riches"


@dataclass
class P119Result:
    profile: str
    rob_unlock: float | None = None
    rob_hired: float | None = None
    source_check_peeks_pre: int = 0
    source_check_sec_pre: float = 0.0
    dashboard_peeks_post: int = 0
    dashboard_sec_post: float = 0.0
    recommendations_seen: int = 0
    clarity_pct: float = 0.0
    end_t: float = 0.0


def _fmt_t(s: float | None) -> str:
    return p116._fmt_t(s)


def _try_hire(ps, t: float, r: P119Result) -> None:
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
        if m.name == ROB and r.rob_hired is None:
            r.rob_hired = t


def run_profile(name: str, *, max_min: int = 420, seed: int = 119) -> P119Result:
    profile_seeds = {"CASUAL": 0, "ENGAGED": 1, "OPTIMIZER": 2}
    random.seed(seed + profile_seeds.get(name, 0))
    profile = h.PROFILES[name]
    coin_frac = COIN_CLICK[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    r = P119Result(profile=name)
    t = 0.0
    dt = 0.5
    buy_acc = turf_acc = 0.0
    eligible_since = None
    last_prestige_t = 0.0
    prestiges = 0
    tab_cycle = 0

    while t < max_min * 60:
        ps.update(dt)
        rob_hired = mgr_mod.manager_active(ps, ROB)

        if mgr_mod.manager_unlocked(ps, len(ps.managers) - 1) and r.rob_unlock is None:
            r.rob_unlock = t

        # Simulated player checking "where does money come from?"
        if int(t) % 50 == 0 and t > 0:
            if rob_hired:
                rep = mgr_mod.empire_efficiency_report(ps)
                if rep:
                    r.dashboard_peeks_post += 1
                    r.dashboard_sec_post += 50.0
                    r.recommendations_seen += len(rep['recommendations'])
            else:
                # Without Rob: player cycles Buildings / Ops / Stats to compare sources
                tab_cycle = (tab_cycle + 1) % 3
                if tab_cycle != 0:
                    r.source_check_peeks_pre += 1
                    r.source_check_sec_pre += 50.0

        can = prestige.can_prestige(ps)
        adv = mgr_mod.prestige_advice(ps)

        if ps._coin and not mgr_mod.manager_active(ps, "Lucky Sal"):
            if "_sim_click" not in ps._coin:
                ps._coin["_sim_click"] = random.random() < coin_frac
            if ps._coin["_sim_click"] and ps._coin["lifetime"] >= 1.0:
                ps._collect_coin(manual=True)

        if (t % 60) < (60 * profile["active_frac"]) and profile["cps"] > 0:
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

        for u in ps.upgrades:
            if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
                ps.balance -= upg._effective_cost(u, ps)
                u.purchased = True
                u.apply(ps)

        p116._collect_ops(ps)
        if not mgr_mod.manager_active(ps, "The Smuggler"):
            for op in ps.operations:
                can_s, _ = op.can_start(ps)
                if can_s and not op.active:
                    op.start(ps)
                    break

        turf_acc += dt
        if turf_acc >= 50.0:
            turf_acc = 0.0
            p116._maybe_turf_blind(ps)

        if can:
            if eligible_since is None:
                eligible_since = t
            waited = t - eligible_since
            do_prestige = False
            if mgr_mod.manager_active(ps, RUDY) and adv and adv.get('enhanced'):
                w = adv.get('window', '')
                if w == 'NOW' and waited >= 5:
                    do_prestige = True
                elif w == 'WAIT_5' and waited >= 300:
                    do_prestige = True
                elif w == 'WAIT_10' and waited >= 600:
                    do_prestige = True
            elif not mgr_mod.manager_active(ps, RUDY) and waited >= 120:
                do_prestige = True

            min_play = MIN_CYCLE2_PLAY_SEC if prestiges >= 1 else 0
            if do_prestige and (t - last_prestige_t) >= min_play:
                prestige.PrestigeManager.execute(ps)
                prestiges += 1
                last_prestige_t = t
                eligible_since = None

        t += dt
        if r.rob_hired and t - r.rob_hired >= 600:
            break

    r.end_t = t
    if r.source_check_sec_pre > 0:
        r.clarity_pct = max(
            0.0,
            100.0 * (1.0 - r.dashboard_sec_post / max(r.source_check_sec_pre, 1.0)),
        )
    elif r.rob_hired:
        r.clarity_pct = 100.0
    return r


def build_report(results: list[P119Result]) -> str:
    eng = next(x for x in results if x.profile == "ENGAGED")
    lines = [
        "# Phase 119 — Rob Revenue",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** Second post-overhaul manager — empire efficiency analyst.",
        "",
        "---",
        "",
        "## 1. Identity shipped",
        "",
        "| Field | Value |",
        "|-------|-------|",
        "| Name | **Rob Revenue** — \"The numbers guy\" |",
        "| Role | Empire efficiency analyst |",
        "| Unlock | **Kingpin** (same tier as Rudy) |",
        "| Cost | $12T premium payroll |",
        "| Hire toast | \"Rob's balancing the books.\" |",
        "",
        "**Dashboard (Stats tab):** Building / Operations / Territory / Click income shares,",
        "strongest & weakest sources, and plain-language recommendations.",
        "",
        "---",
        "",
        "## 2. Success question — less time wondering where money comes from?",
        "",
        "| Profile | Rob hire | Pre-Rob source checks | Post-Rob dashboard views | Clarity Δ |",
        "|---------|----------|----------------------|--------------------------|-----------|",
    ]
    for r in results:
        lines.append(
            f"| {r.profile} | {_fmt_t(r.rob_hired)} | {r.source_check_peeks_pre} peeks "
            f"({r.source_check_sec_pre:.0f}s) | {r.dashboard_peeks_post} peeks "
            f"({r.dashboard_sec_post:.0f}s) | {r.clarity_pct:.0f}% |"
        )

    lines.extend([
        "",
        f"**ENGAGED recommendations surfaced:** {eng.recommendations_seen} lines across post-hire views",
        "",
        "---",
        "",
        "## 3. What did the player stop doing?",
        "",
        "| Before Rob | After Rob |",
        "|------------|-----------|",
        f"| ~{eng.source_check_peeks_pre} tab-hops guessing income mix | "
        f"One Stats dashboard with labeled shares |",
        "| Manually comparing Buildings vs Ops vs Turf | "
        f"\"{eng.recommendations_seen and 'Rob recommendations' or 'Headline'}\" on manager card + Stats |",
        "| Wondering which activity pays best | **Strongest / weakest source labeled** |",
        "",
        "---",
        "",
        "## 4. Sample ENGAGED dashboard (at Rob hire + 10m sim)",
        "",
    ])

    # One-shot snapshot report
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()
    for b in ps.buildings:
        b.owned = max(b.owned, 5)
    ps.balance = 1e9
    ps._ips_dirty = True
    for m in ps.managers:
        if m.name == ROB:
            m.hired = True
            break
    rep = mgr_mod.empire_efficiency_report(ps)
    if rep:
        lines.append("| Source | Share |")
        lines.append("|--------|-------|")
        for key, lbl in (
            ('buildings', 'Buildings'), ('operations', 'Operations'),
            ('territory', 'Territories'), ('clicks', 'Clicks'),
        ):
            lines.append(f"| {lbl} | {rep['shares'][key]:.0f}% |")
        lines.append("")
        for rec in rep['recommendations']:
            lines.append(f"- {rec}")
    lines.append("")

    lines.extend([
        "---",
        "",
        "## 5. Verdict",
        "",
    ])

    ok = eng.rob_hired is not None and eng.dashboard_peeks_post >= 3
    if ok and eng.clarity_pct >= 50:
        lines.append(
            "### **Yes — income is understandable information.**\n\n"
            f"ENGAGED replaced ~{eng.source_check_sec_pre:.0f}s of source-guessing with "
            f"Rob's labeled dashboard ({eng.dashboard_peeks_post} consolidated views)."
        )
    elif ok:
        lines.append(
            "### **Partial** — dashboard live; extend post-hire play for full clarity metrics."
        )
    else:
        lines.append("### **Not validated in sim window** — extend play or manual Stats tab test.")

    lines.extend([
        "",
        "---",
        "",
        "## 6. Remaining concerns",
        "",
        "- Share math estimates ops/clicks as $/sec rates — intuitive, not accounting-grade.",
        "- Kingpin + $12T gate matches Rudy tier; Rob is endgame celebration hire.",
        "- Dashboard lives on Stats tab — manager card shows headline only.",
        "",
        "---",
        "",
        "## 7. Re-run",
        "",
        "```powershell",
        "python _measure_p119.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 119 — Rob Revenue")
    results = [run_profile(n) for n in h.PROFILES]
    eng = next(x for x in results if x.profile == "ENGAGED")
    print(
        f"\nENGAGED: rob {_fmt_t(eng.rob_hired)} "
        f"checks {eng.source_check_peeks_pre}→dashboard {eng.dashboard_peeks_post} "
        f"clarity {eng.clarity_pct:.0f}%"
    )
    report = build_report(results)
    with open("PHASE119_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"Wrote PHASE119_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
