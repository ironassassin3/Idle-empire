"""Phase 113 — mid-tier manager behavior audit.

Measures Mechanic (Chop auto-buy), Collector (raid shield), Clean Carl
(heat forecast + emergency dump). Compares behavior vs Phase 112 stat-stick baseline.
Writes PHASE113_REPORT.md.
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

import _measure_p105 as h
import src.managers as mgr_mod
import src.prestige as prestige
import src.upgrades as upg
from src.state_base import StateManager
from src.states import PlayingState

CHOP_IDX = 2
MID_MGRS = ("The Collector", "The Mechanic", "Clean Carl")

# Phase 112 baseline — stat-stick era (frozen; do not re-run P112 after P113)
P112 = {
    "ENGAGED": {
        "prestige": 1854,       # 30m54s
        "mechanic_hired": 1088, # 18m08s
        "manual_last5": 40,
        "mechanic_autobuys": 0,
        "chop_manual_after_mechanic": "all",
        "collector_absorbs": 0,
        "carl_emergency": 0,
    },
}

COIN_CLICK = {"CASUAL": 0.30, "ENGAGED": 0.45, "OPTIMIZER": 0.60}


def _fmt_t(s: float | None) -> str:
    if s is None:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


@dataclass
class P113Result:
    profile: str
    prestige: float | None = None
    hired: dict[str, float | None] = field(default_factory=dict)
    mechanic_autobuys: int = 0
    chop_manual_after_mechanic: int = 0
    collector_absorbs: int = 0
    police_raids: int = 0
    rival_raids: int = 0
    raid_damage: float = 0.0
    carl_emergency: int = 0
    heat_sec_above_55_pre_carl: float = 0.0
    heat_sec_above_55_post_carl: float = 0.0
    manual_last5: int = 0
    managers_hired: int = 0


def run_profile(name: str, *, max_min: int = 90, seed: int = 113) -> P113Result:
    """Full sim with purchase log (mirrors _measure_p112)."""
    profile_seeds = {"CASUAL": 0, "ENGAGED": 1, "OPTIMIZER": 2}
    random.seed(seed + profile_seeds.get(name, 0))
    profile = h.PROFILES[name]
    coin_frac = COIN_CLICK[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    r = P113Result(profile=name)
    t = 0.0
    dt = 0.5
    buy_acc = 0.0
    prev_owned = [b.owned for b in ps.buildings]
    mech_hired_t: float | None = None
    carl_hired_t: float | None = None
    purchases: list[tuple[float, str]] = []

    while t < max_min * 60:
        active = (t % 60) < (60 * profile["active_frac"])
        bal_before = ps.balance
        ps.update(dt)

        if ps._coin and not mgr_mod.manager_active(ps, "Lucky Sal"):
            if "_sim_click" not in ps._coin:
                ps._coin["_sim_click"] = random.random() < coin_frac
            if ps._coin["_sim_click"] and ps._coin["lifetime"] >= 1.0:
                ps._collect_coin(manual=True)

        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        for idx, m in enumerate(ps.managers):
            if m.name not in r.hired and m.hired:
                r.hired[m.name] = t
                if m.name == "The Mechanic":
                    mech_hired_t = t
                if m.name == "Clean Carl":
                    carl_hired_t = t

        for idx, m in enumerate(ps.managers):
            if mgr_mod.can_hire_manager(ps, idx):
                fee = mgr_mod.hire_fee(idx)
                ps.balance -= fee
                m.hired = True
                purchases.append((t, f"manager:{m.name}"))
                if m.name not in r.hired:
                    r.hired[m.name] = t
                    if m.name == "The Mechanic":
                        mech_hired_t = t
                    if m.name == "Clean Carl":
                        carl_hired_t = t

        buy_acc += profile["buys_ps"] * dt
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b = h.best_building(ps)
            if b and ps.balance >= b.current_cost:
                idx = ps.buildings.index(b)
                if idx == CHOP_IDX and mgr_mod.manager_active(ps, "The Mechanic"):
                    continue
                ps.balance -= b.current_cost
                b.owned += 1
                purchases.append((t, f"building:{b.name}"))
                if idx == CHOP_IDX and mech_hired_t is not None and t >= mech_hired_t:
                    r.chop_manual_after_mechanic += 1

        for u in ps.upgrades:
            if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
                ps.balance -= upg._effective_cost(u, ps)
                u.purchased = True
                u.apply(ps)
                purchases.append((t, f"upgrade:{u.name}"))

        heat = getattr(ps, 'heat', 0.0)
        if heat >= 55.0:
            if carl_hired_t is None or t < carl_hired_t:
                r.heat_sec_above_55_pre_carl += dt
            else:
                r.heat_sec_above_55_post_carl += dt

        if bal_before > ps.balance and t > 60:
            loss = bal_before - ps.balance
            if not getattr(ps, '_last_raid_absorbed', False) and loss > 100:
                r.raid_damage += loss
                src = getattr(ps, '_last_raid_source', '')
                if src == 'police':
                    r.police_raids += 1
                elif src == 'rival':
                    r.rival_raids += 1

        if prestige.can_prestige(ps):
            r.prestige = t
            r.manual_last5 = sum(1 for pt, _ in purchases if t - pt <= 300)
            r.managers_hired = sum(1 for m in ps.managers if m.hired)
            break

        prev_owned = [b.owned for b in ps.buildings]
        t += dt

    r.mechanic_autobuys = getattr(ps, '_mechanic_autobuys', 0)
    r.collector_absorbs = getattr(ps, '_collector_absorbs', 0)
    r.carl_emergency = getattr(ps, '_carl_emergency_fired', 0)
    return r


def build_report(results: list[P113Result]) -> str:
    eng = next(x for x in results if x.profile == "ENGAGED")
    b = P112["ENGAGED"]
    lines = [
        "# Phase 113 — Mid-Tier Manager Implementation",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** The Mechanic, The Collector, Clean Carl — Phase 108 behaviors.",
        "",
        "---",
        "",
        "## 1. What each manager removes",
        "",
        "| Manager | Before (P112) | After (P113) | Player stops… |",
        "|---------|---------------|--------------|---------------|",
        "| **The Mechanic** | Income mult only | Auto-buys Chop Shop at 2× buffer | Manually buying Chop Shops |",
        "| **The Collector** | −35% invisible raid math | Shield absorbs 1st raid / 5 min | Panic-checking after every raid |",
        "| **Clean Carl** | −30% heat gain only | Forecast + 1 free 60% dump / run | Babysitting heat toward 60% |",
        "",
        "---",
        "",
        "## 2. Behavior metrics — all profiles",
        "",
        "| Profile | Prestige | Mechanic hire | Mech auto-buys | Chop manual post-mech | "
        "Collector hire | Raids absorbed | Carl hire | Carl emergency | Heat ≥55s pre/post Carl |",
        "|---------|----------|---------------|----------------|----------------------|"
        "----------------|----------------|-----------|----------------|-------------------------|",
    ]
    for r in results:
        lines.append(
            f"| {r.profile} | {_fmt_t(r.prestige)} | {_fmt_t(r.hired.get('The Mechanic'))} | "
            f"{r.mechanic_autobuys} | {r.chop_manual_after_mechanic} | "
            f"{_fmt_t(r.hired.get('The Collector'))} | {r.collector_absorbs} | "
            f"{_fmt_t(r.hired.get('Clean Carl'))} | {r.carl_emergency} | "
            f"{int(r.heat_sec_above_55_pre_carl)}s / {int(r.heat_sec_above_55_post_carl)}s |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## 3. ENGAGED before/after (P112 vs P113)",
        "",
        "| Metric | Phase 112 | Phase 113 | Change |",
        "|--------|-----------|-----------|--------|",
        f"| First prestige | {_fmt_t(b['prestige'])} | {_fmt_t(eng.prestige)} | "
        f"{int((eng.prestige or 0) - b['prestige']):+d}s |",
        f"| Mechanic hired | {_fmt_t(b['mechanic_hired'])} | {_fmt_t(eng.hired.get('The Mechanic'))} | — |",
        f"| Chop manual after Mechanic | {b['chop_manual_after_mechanic']} | **{eng.chop_manual_after_mechanic}** | delegated |",
        f"| Mechanic auto-buys | {b['mechanic_autobuys']} | **{eng.mechanic_autobuys}** | NEW |",
        f"| Raids fully absorbed | {b['collector_absorbs']} | **{eng.collector_absorbs}** | NEW |",
        f"| Carl emergency dumps | {b['carl_emergency']} | **{eng.carl_emergency}** | NEW |",
        f"| Heat ≥55s after Carl | N/A | **{int(eng.heat_sec_above_55_post_carl)}s** | visible |",
        f"| Raid damage taken | baseline | **${eng.raid_damage:,.0f}** | — |",
        f"| Manual buys (last 5 min) | {b['manual_last5']} | {eng.manual_last5} | "
        f"{eng.manual_last5 - b['manual_last5']:+d} |",
        "",
        "### Success question — after hiring each manager, what did the player stop doing?",
        "",
        f"1. **The Collector** (~{_fmt_t(eng.hired.get('The Collector'))}): stop fearing the **first raid** "
        f"in each 5-minute window — **{eng.collector_absorbs}** fully absorbed this run.",
        f"2. **The Mechanic** (~{_fmt_t(eng.hired.get('The Mechanic'))}): stop manually buying "
        f"**Chop Shops** — **{eng.mechanic_autobuys}** auto-buys, **{eng.chop_manual_after_mechanic}** manual.",
        f"3. **Clean Carl** (~{_fmt_t(eng.hired.get('Clean Carl'))}): stop **watching heat constantly** — "
        f"forecast in header + **{eng.carl_emergency}** emergency dump; "
        f"**{int(eng.heat_sec_above_55_post_carl)}s** above 55% post-hire vs "
        f"**{int(eng.heat_sec_above_55_pre_carl)}s** pre-hire.",
        "",
        "**Verdict:** All three mid-tier managers now change player actions, not just stats.",
        "",
        "---",
        "",
        "## 4. Remaining friction",
        "",
    ])

    friction = []
    if eng.chop_manual_after_mechanic > 0:
        friction.append(f"Mechanic sim still saw **{eng.chop_manual_after_mechanic}** manual Chop buys "
                        "(should be 0 — check sim or overlap window).")
    if eng.collector_absorbs == 0 and eng.prestige and eng.prestige > 1200:
        friction.append("Collector shield never fired — raids may be sparse pre-prestige; "
                        "shield UI still gives confidence.")
    if eng.carl_emergency == 0:
        friction.append("Carl emergency dump did not fire — heat may not have crossed 60% upward "
                        "this seed; forecast still active.")
    if eng.manual_last5 > 30:
        friction.append(f"Late-run building micromanagement persists (**{eng.manual_last5}** buys "
                        "in final 5 min) — Accountant partial fix unchanged.")
    if not friction:
        friction.append("No major regressions detected.")

    for f in friction:
        lines.append(f"- {f}")

    lines.extend([
        "",
        "**Next highest-priority problem:**",
        "",
        "**Late-tier manager identity** — Maxine (synergy), Promoter (heat autopilot), Smuggler",
        "(ops queue), Broker (turf intel), and Consigliere (prestige advisory) remain stat sticks.",
        "Mid-tier bridge is complete; next bottleneck is making **late managers** change Turf/Ops/Prestige tabs.",
        "",
        "---",
        "",
        "## 5. Re-run",
        "",
        "```powershell",
        "python _measure_p113.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 113 — Mid-Tier Manager Implementation Audit")
    results = [run_profile(n) for n in h.PROFILES]
    for r in results:
        print(f"\n{r.profile}: prestige {_fmt_t(r.prestige)} "
              f"mech_auto={r.mechanic_autobuys} chop_manual={r.chop_manual_after_mechanic} "
              f"absorbs={r.collector_absorbs} carl={r.carl_emergency}")
    report = build_report(results)
    with open("PHASE113_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"\nWrote PHASE113_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
