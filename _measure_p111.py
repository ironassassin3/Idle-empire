"""Phase 111 — manager access measurement (post milestone + payroll fees).

Greedy buyer hires unlocked managers when payroll is affordable (no reserving).
Compares hire/unlock times against Phase 107/109 baselines. Writes PHASE111_REPORT.md.
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

FOCUS = ("Sticky Pete", "Lucky Sal", "The Mechanic", "The Accountant")

# Phase 107 greedy baseline (pre-Phase 111)
BASELINE_HIRE = {
    "ENGAGED": {
        "Sticky Pete": 38 * 60 + 33,
        "Lucky Sal": None,
        "The Mechanic": None,
        "The Accountant": None,
    },
}

# Phase 109 forced-hire baseline (not natural)
P109_FORCED = {
    "ENGAGED": {"Sticky Pete": 32 * 60 + 58, "Lucky Sal": None},
}


def _fmt_t(s: float | None) -> str:
    if s is None:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


def _in_window(t: float | None, lo: float, hi: float) -> str:
    if t is None:
        return "MISS"
    m = t / 60
    if lo <= m <= hi:
        return "OK"
    return f"{'early' if m < lo else 'late'} ({_fmt_t(t)})"


@dataclass
class RunResult:
    profile: str
    unlock: dict[str, float | None] = field(default_factory=dict)
    hired: dict[str, float | None] = field(default_factory=dict)
    prestige_t: float | None = None
    coins_expired: int = 0
    coins_auto_sal: int = 0
    pete_followed: int = 0
    hires_all: list[str] = field(default_factory=list)


def _try_hire_all(ps: PlayingState) -> list[str]:
    hired_now = []
    for idx, m in enumerate(ps.managers):
        if mgr_mod.can_hire_manager(ps, idx):
            ps.balance -= mgr_mod.hire_fee(idx)
            m.hired = True
            hired_now.append(m.name)
    return hired_now


def run_profile(name: str, *, max_min: int = 90, seed: int = 111) -> RunResult:
    random.seed(seed + hash(name) % 1000)
    profile = h.PROFILES[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    result = RunResult(profile=name)
    t = 0.0
    dt = 0.5
    buy_acc = 0.0

    while t < max_min * 60:
        active = (t % 60) < (60 * profile["active_frac"])
        ps.update(dt)

        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        for idx, m in enumerate(ps.managers):
            if m.name in FOCUS and result.unlock.get(m.name) is None:
                if mgr_mod.manager_unlocked(ps, idx):
                    result.unlock[m.name] = t

        # Hire before building buys — payroll is cheap vs next building
        for mname in _try_hire_all(ps):
            if result.hired.get(mname) is None:
                result.hired[mname] = t
            result.hires_all.append(mname)

        buy_acc += profile["buys_ps"] * dt
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b = h.best_building(ps)
            if b and ps.balance >= b.current_cost:
                ps.balance -= b.current_cost
                b.owned += 1

        for u in ps.upgrades:
            if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
                ps.balance -= upg._effective_cost(u, ps)
                u.purchased = True
                u.apply(ps)

        if prestige.can_prestige(ps):
            result.prestige_t = t
            break
        t += dt

    result.coins_expired = getattr(ps, '_coins_expired', 0)
    result.coins_auto_sal = getattr(ps, '_coins_auto_sal', 0)
    result.pete_followed = getattr(ps, '_pete_followed_buys', 0)
    return result


def build_report(results: list[RunResult]) -> str:
    engaged = next(r for r in results if r.profile == "ENGAGED")
    lines = [
        "# Phase 111 — Manager Access Implementation",
        "",
        "**Date:** 2026-06-15  ",
        "**Change:** Phase 110 acquisition model — milestone unlocks + payroll fees",
        "(early tier), rank gates + premium costs (late tier). No new save fields.",
        "",
        "---",
        "",
        "## 1. Implementation summary",
        "",
        "| Tier | Managers | Unlock | Cost |",
        "|------|----------|--------|------|",
        "| Early (0–5) | Pete → Accountant | Computed milestones | $3K–$65K payroll |",
        "| Late (6–10) | Maxine → Consigliere | Rank gate | Premium cash (unchanged) |",
        "",
        "| Manager | Unlock | Payroll |",
        "|---------|--------|---------|",
        "| Sticky Pete | $25K lifetime | $3K |",
        "| The Collector | 3 Rackets | $10K |",
        "| The Mechanic | 2 Chop Shops | $8K |",
        "| Lucky Sal | $25K lifetime OR 1 Betting Ring | $4K |",
        "| Clean Carl | Heat 40% or 80 heat generated | $50K |",
        "| The Accountant | $200K lifetime OR 4 building types | $65K |",
        "",
        "**Late rank gates:** Capo · Underboss · Boss · Crime Lord · Kingpin.",
        "",
        "Phase 106 cash nudges removed; unlock milestones via `tick_unlock_milestones`.",
        "Phase 109 behavior hooks preserved.",
        "",
        "---",
        "",
        "## 2. Before / after — hire times (greedy buyer, no reserving)",
        "",
        "| Manager | Phase 107 (old cash) | Phase 111 unlock | Phase 111 hired |",
        "|---------|---------------------|------------------|-----------------|",
    ]

    for mname in FOCUS:
        old = BASELINE_HIRE.get("ENGAGED", {}).get(mname)
        old_s = _fmt_t(old) if old else "NEVER"
        lines.append(
            f"| {mname} | {old_s} | {_fmt_t(engaged.unlock.get(mname))} | "
            f"{_fmt_t(engaged.hired.get(mname))} |"
        )

    lines.extend([
        "",
        "### All profiles — Phase 111 hires",
        "",
        "| Profile | Pete | Sal | Mechanic | Accountant | Prestige |",
        "|---------|------|-----|----------|------------|----------|",
    ])
    for r in results:
        lines.append(
            f"| {r.profile} | {_fmt_t(r.hired.get('Sticky Pete'))} | "
            f"{_fmt_t(r.hired.get('Lucky Sal'))} | "
            f"{_fmt_t(r.hired.get('The Mechanic'))} | "
            f"{_fmt_t(r.hired.get('The Accountant'))} | "
            f"{_fmt_t(r.prestige_t)} |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## 3. ENGAGED success criteria (target windows)",
        "",
        "| Manager | Target | Unlock | Hired | Verdict |",
        "|---------|--------|--------|-------|---------|",
    ])
    targets = {
        "Sticky Pete": (10, 20),
        "Lucky Sal": (10, 20),
        "The Mechanic": (17, 25),
        "The Accountant": (20, 35),
    }
    for mname, (lo, hi) in targets.items():
        lines.append(
            f"| {mname} | {lo}–{hi} min | {_fmt_t(engaged.unlock.get(mname))} | "
            f"{_fmt_t(engaged.hired.get(mname))} | "
            f"{_in_window(engaged.hired.get(mname), lo, hi)} |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## 4. Manual actions removed (ENGAGED, full run)",
        "",
        f"- **Golden coins expired:** {engaged.coins_expired} (Sal auto-collect after hire)",
        f"- **Sal auto-collects:** {engaged.coins_auto_sal}",
        f"- **Pete on-pick buys** (if Pete hired): {engaged.pete_followed}",
        "",
        "**What players stop doing:** guessing building ROI (Pete), chasing coins (Sal),",
        "banking $40K–$2M for managers (payroll fees fit between building buys).",
        "",
        "---",
        "",
        "## 5. Full hire order (ENGAGED)",
        "",
        f"{' → '.join(engaged.hires_all) if engaged.hires_all else '*(none)*'}",
        "",
        "---",
        "",
        "## 6. Remaining concerns",
        "",
    ])

    concerns = []
    for mname, (lo, hi) in targets.items():
        ht = engaged.hired.get(mname)
        if ht is None or ht / 60 < lo - 2 or ht / 60 > hi + 3:
            concerns.append(f"{mname} hire {_fmt_t(ht)} outside {lo}–{hi}m target.")
    if not concerns:
        concerns.append(
            "ENGAGED targets met under greedy sim without reserving or Phase 106 nudges."
        )
    concerns.append(
        "Greedy sim auto-hires when payroll affordable — real players must open "
        "Managers tab once; unlock milestones prompt this."
    )
    concerns.append(
        "Late managers (6–10) still require Capo+ rank and premium cash — "
        "unchanged by design for post-prestige runs."
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
        "python _measure_p111.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 111 — Manager Access measurement")
    results = [run_profile(n) for n in h.PROFILES]
    for r in results:
        print(f"\n{r.profile} prestige {_fmt_t(r.prestige_t)}")
        for m in FOCUS:
            print(f"  {m}: unlock {_fmt_t(r.unlock.get(m))} hire {_fmt_t(r.hired.get(m))}")
    report = build_report(results)
    with open("PHASE111_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"\nWrote PHASE111_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
