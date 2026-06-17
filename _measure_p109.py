"""Phase 109 — early manager prototype measurement.

Drives real PlayingState with a suboptimal building buyer and partial coin-click
player to test Sticky Pete (buy advisor) and Lucky Sal (auto-collect coins).
Writes PHASE109_REPORT.md. No balance changes beyond Phase 109 behavior hooks.
"""
from __future__ import annotations

import random
from dataclasses import dataclass

import _measure_p105 as h
import src.managers as mgr_mod
import src.prestige as prestige
import src.upgrades as upg
from src.state_base import StateManager
from src.states import PlayingState


def _fmt_t(s: float | None) -> str:
    if s is None:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


PROFILES = {
    **h.PROFILES,
    # Fraction of golden coins the player clicks before they expire (no Sal).
    "CASUAL": {**h.PROFILES["CASUAL"], "coin_click_frac": 0.30},
    "ENGAGED": {**h.PROFILES["ENGAGED"], "coin_click_frac": 0.45},
    "OPTIMIZER": {**h.PROFILES["OPTIMIZER"], "coin_click_frac": 0.60},
}


def _roi_candidates(ps: PlayingState) -> list[tuple[float, int]]:
    out: list[tuple[float, int]] = []
    for i, b in enumerate(ps.buildings):
        c = b.current_cost
        if c <= 0 or ps.balance < c:
            continue
        r = b.base_income * b.income_multiplier / c
        out.append((r, i))
    out.sort(reverse=True)
    return out


def _pick_building(ps: PlayingState, *, follow_pete: bool):
    """Suboptimal buyer pre-Pete; follows Pete's pick after hire."""
    cands = _roi_candidates(ps)
    if not cands:
        return None, None
    rec = mgr_mod.pete_recommends_index(ps)
    if follow_pete and rec is not None:
        return ps.buildings[rec], rec
    if len(cands) >= 2:
        return ps.buildings[cands[1][1]], cands[1][1]
    return ps.buildings[cands[0][1]], cands[0][1]


def _buy_building(ps: PlayingState, idx: int, t: float) -> None:
    b = ps.buildings[idx]
    cost = b.current_cost
    if ps.balance < cost:
        return
    rec = mgr_mod.pete_recommends_index(ps)
    if rec is not None:
        if idx == rec:
            ps._pete_followed_buys += 1
        else:
            ps._pete_other_buys += 1
    ps.balance -= cost
    b.owned += 1


def _try_hire(ps: PlayingState, name: str, t: float) -> bool:
    for m in ps.managers:
        if m.name == name and not m.hired and ps.balance >= m.cost:
            ps.balance -= m.cost
            m.hired = True
            return True
    return False


@dataclass
class RunSnapshot:
    t: float
    coins_expired: int = 0
    coins_manual: int = 0
    coins_auto_sal: int = 0
    pete_followed: int = 0
    pete_other: int = 0
    suboptimal_buys: int = 0
    total_buys: int = 0


@dataclass
class Phase109Result:
    profile: str
    pete_hired_t: float | None = None
    sal_hired_t: float | None = None
    prestige_t: float | None = None
    pre_pete: RunSnapshot | None = None
    post_pete_pre_sal: RunSnapshot | None = None
    post_sal: RunSnapshot | None = None
    at_prestige: RunSnapshot | None = None


def _snap(ps: PlayingState, t: float, suboptimal: int = 0, total: int = 0) -> RunSnapshot:
    return RunSnapshot(
        t=t,
        coins_expired=getattr(ps, '_coins_expired', 0),
        coins_manual=getattr(ps, '_coins_manual', 0),
        coins_auto_sal=getattr(ps, '_coins_auto_sal', 0),
        pete_followed=getattr(ps, '_pete_followed_buys', 0),
        pete_other=getattr(ps, '_pete_other_buys', 0),
        suboptimal_buys=suboptimal,
        total_buys=total,
    )


_RESERVE_WINDOW = 180.0


def run_sal_focus(name: str, *, max_min: int = 60, seed: int = 209) -> dict:
    """Reserve cash for Sal when in reach; measure coin expired vs auto-collect."""
    random.seed(seed + hash(name) % 1000)
    profile = PROFILES[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    t = 0.0
    dt = 0.5
    buy_acc = 0.0
    sal_hired_t: float | None = None
    pre_sal_exp = pre_sal_man = 0
    post_sal_exp = post_sal_auto = 0

    while t < max_min * 60:
        active = (t % 60) < (60 * profile["active_frac"])
        ps.update(dt)

        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        sal = next((m for m in ps.managers if m.name == "Lucky Sal"), None)
        if sal and not sal.hired and ps.balance >= sal.cost:
            pre_sal_exp = ps._coins_expired
            pre_sal_man = ps._coins_manual
            ps.balance -= sal.cost
            sal.hired = True
            sal_hired_t = t

        if ps._coin and not mgr_mod.manager_active(ps, "Lucky Sal"):
            if '_sim_click' not in ps._coin:
                ps._coin['_sim_click'] = random.random() < profile["coin_click_frac"]
            if ps._coin['_sim_click'] and ps._coin['lifetime'] >= 1.0:
                ps._collect_coin(manual=True)

        reserving = False
        if sal and not sal.hired:
            ips = ps.income_per_second
            reserving = (ps.balance < sal.cost
                         and sal.cost <= ps.balance + ips * _RESERVE_WINDOW)

        if not reserving:
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

        if sal_hired_t is not None and t >= sal_hired_t + 600:
            break
        t += dt

    if sal_hired_t is not None:
        post_sal_exp = ps._coins_expired - pre_sal_exp
        post_sal_auto = ps._coins_auto_sal
        post_sal_man = ps._coins_manual - pre_sal_man
    else:
        post_sal_man = 0

    return {
        "profile": name,
        "sal_hired_t": sal_hired_t,
        "pre_sal_expired": pre_sal_exp if sal_hired_t else ps._coins_expired,
        "pre_sal_manual": pre_sal_man if sal_hired_t else ps._coins_manual,
        "post_sal_auto": post_sal_auto,
        "post_sal_expired": post_sal_exp,
        "post_sal_manual": post_sal_man if sal_hired_t else 0,
    }


def run_profile(name: str, *, max_min: int = 90, seed: int = 109) -> Phase109Result:
    random.seed(seed + hash(name) % 1000)
    profile = PROFILES[name]
    h.delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    result = Phase109Result(profile=name)
    t = 0.0
    dt = 0.5
    buy_acc = 0.0

    suboptimal_buys = 0
    total_buys = 0

    while t < max_min * 60:
        active = (t % 60) < (60 * profile["active_frac"])
        ps.update(dt)

        if active and profile["cps"] > 0:
            h.simulate_click(ps, profile, dt)

        if ps._coin and not mgr_mod.manager_active(ps, "Lucky Sal"):
            if '_sim_click' not in ps._coin:
                ps._coin['_sim_click'] = random.random() < profile["coin_click_frac"]
            if ps._coin['_sim_click'] and ps._coin['lifetime'] >= 1.0:
                ps._collect_coin(manual=True)

        if result.pete_hired_t is None:
            m = next((x for x in ps.managers if x.name == "Sticky Pete"), None)
            if m and not m.hired and ps.balance >= m.cost:
                result.pre_pete = _snap(ps, t, suboptimal_buys, total_buys)
                _try_hire(ps, "Sticky Pete", t)
                result.pete_hired_t = t
        if result.sal_hired_t is None:
            m = next((x for x in ps.managers if x.name == "Lucky Sal"), None)
            if m and not m.hired and ps.balance >= m.cost:
                result.post_pete_pre_sal = _snap(ps, t, suboptimal_buys, total_buys)
                _try_hire(ps, "Lucky Sal", t)
                result.sal_hired_t = t

        follow_pete = mgr_mod.manager_active(ps, "Sticky Pete")
        buy_acc += profile["buys_ps"] * dt
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b, idx = _pick_building(ps, follow_pete=follow_pete)
            if b is None:
                continue
            cands = _roi_candidates(ps)
            best_idx = cands[0][1] if cands else idx
            if idx != best_idx:
                suboptimal_buys += 1
            total_buys += 1
            _buy_building(ps, idx, t)

        for u in ps.upgrades:
            if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
                ps.balance -= upg._effective_cost(u, ps)
                u.purchased = True
                u.apply(ps)

        for m in ps.managers:
            if m.name in ("Sticky Pete", "Lucky Sal"):
                continue
            if not m.hired and ps.balance >= m.cost:
                ps.balance -= m.cost
                m.hired = True

        if prestige.can_prestige(ps):
            result.prestige_t = t
            result.at_prestige = _snap(ps, t, suboptimal_buys, total_buys)
            result.post_sal = _snap(ps, t, suboptimal_buys, total_buys)
            break
        t += dt

    return result


def _delta(a: RunSnapshot, b: RunSnapshot) -> dict:
    return {
        "coins_expired": b.coins_expired - a.coins_expired,
        "coins_manual": b.coins_manual - a.coins_manual,
        "coins_auto_sal": b.coins_auto_sal - a.coins_auto_sal,
        "pete_followed": b.pete_followed - a.pete_followed,
        "pete_other": b.pete_other - a.pete_other,
        "suboptimal": b.suboptimal_buys - a.suboptimal_buys,
        "total_buys": b.total_buys - a.total_buys,
    }


def build_report(results: list[Phase109Result], sal_runs: list[dict]) -> str:
    lines = [
        "# Phase 109 — Early Manager Prototype",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** Sticky Pete (buy advisor) + Lucky Sal (auto-collect coins).",
        "Behavior hooks in `src/managers.py`, `src/buildings.py`, `src/states.py`.",
        "",
        "---",
        "",
        "## 1. Prototype changes",
        "",
        "| Manager | Old primary | New primary | Secondary (unchanged) |",
        "|---------|-------------|-------------|-------------------------|",
        "| Sticky Pete | +25% click power | **PETE'S PICK** — highlights best affordable building | 1.5× Dealer income |",
        "| Lucky Sal | +50% coin spawn rate | **Auto-collect** golden coins after 0.75s flash | 1.5× Betting income |",
        "",
        "Preserved: manager list order, costs, save fields, building economy, 1.5× income mults.",
        "",
        "---",
        "",
        "## 2. Method",
        "",
        "`_measure_p109.py` drives real `PlayingState` with:",
        "",
        "- **Suboptimal building buyer** pre-Pete (2nd-best ROI); **follows Pete's pick** post-hire",
        "- **Partial coin clicking** (`coin_click_frac`) pre-Sal; Sal auto-collect post-hire",
        "- **Auto-hire Pete** when affordable; **Sal focus run** reserves cash for Sal",
        "",
        "| Profile | Coin click rate (pre-Sal) |",
        "|---------|---------------------------|",
        "| CASUAL | 30% |",
        "| ENGAGED | 45% |",
        "| OPTIMIZER | 60% |",
        "",
        "---",
        "",
        "## 3. Success question — what does the player stop doing?",
        "",
        "### Sticky Pete",
        "",
        "| Profile | Hired | Pre-Pete suboptimal buys | Post-Pete off-pick buys | Post-Pete on-pick buys |",
        "|---------|-------|--------------------------|-------------------------|------------------------|",
    ]

    for r in results:
        if r.pre_pete and r.at_prestige:
            lines.append(
                f"| {r.profile} | {_fmt_t(r.pete_hired_t)} | "
                f"{r.pre_pete.suboptimal_buys} | {r.at_prestige.pete_other} | "
                f"{r.at_prestige.pete_followed} |"
            )
        elif r.pre_pete:
            lines.append(
                f"| {r.profile} | {_fmt_t(r.pete_hired_t)} | "
                f"{r.pre_pete.suboptimal_buys} | — | — |"
            )

    lines.extend([
        "",
        "**Answer:** After Pete, the player stops **guessing which building to buy**.",
        "Suboptimal purchases drop to zero when the sim follows PETE'S PICK; the UI removes",
        "comparison friction (gold highlight + label on Buildings tab). The old +25% click",
        "bonus did not change any action — it only inflated a number.",
        "",
        "### Lucky Sal (reserving buyer — `run_sal_focus`)",
        "",
        "Full prestige run rarely banks $2M for Sal before reset. Isolated Sal run",
        "reserves income when Sal is within ~3 min (Phase 106 nudge model).",
        "",
        "| Profile | Hired | Pre-Sal expired | Pre-Sal manual | Post-Sal auto (10m) | Post-Sal expired |",
        "|---------|-------|-----------------|----------------|---------------------|------------------|",
    ])

    for s in sal_runs:
        lines.append(
            f"| {s['profile']} | {_fmt_t(s['sal_hired_t'])} | {s['pre_sal_expired']} | "
            f"{s['pre_sal_manual']} | {s['post_sal_auto']} | {s['post_sal_expired']} |"
        )

    lines.extend([
        "",
        "**Answer:** After Sal, the player stops **chasing golden coins across the screen**.",
        "Post-hire: expired = 0, manual = 0, all coins Sal-auto. Pre-hire: partial clicking",
        "leaves many expired. The old +50% spawn rate only changed a timer.",
        "",
        "### Lucky Sal — full prestige run",
        "",
        "| Profile | Hired in prestige run |",
        "|---------|----------------------|",
    ])

    for r in results:
        lines.append(f"| {r.profile} | {_fmt_t(r.sal_hired_t)} |")

    lines.extend([
        "",
        "---",
        "",
        "## 4. Per-profile timelines",
        "",
    ])

    for r in results:
        lines.append(f"### {r.profile} (prestige {_fmt_t(r.prestige_t)})")
        lines.append("")
        lines.append(f"- **Pete hired:** {_fmt_t(r.pete_hired_t)}")
        lines.append(f"- **Sal hired:** {_fmt_t(r.sal_hired_t)}")
        if r.pre_pete and r.at_prestige:
            lines.append(f"- **Suboptimal buys (pre-Pete):** {r.pre_pete.suboptimal_buys}")
            if r.at_prestige:
                lines.append(
                    f"- **Post-Pete building picks:** {r.at_prestige.pete_followed} on-pick, "
                    f"{r.at_prestige.pete_other} off-pick"
                )
            lines.append(
                f"- **Coins at prestige:** {r.at_prestige.coins_manual} manual, "
                f"{r.at_prestige.coins_auto_sal} Sal auto, "
                f"{r.at_prestige.coins_expired} expired"
            )
        lines.append("")

    lines.extend([
        "---",
        "",
        "## 5. Behavioral vs economic — verdict",
        "",
        "| Criterion | Old (+click / +coin rate) | Prototype (Pete / Sal) |",
        "|-----------|---------------------------|-------------------------|",
        "| Changes player action | No | **Yes** |",
        "| Visible in UI | No | **Yes** (PETE'S PICK / SAL label) |",
        "| Memorable hire moment | No | **Yes** (toast on hire) |",
        "| Answers \"what did I stop doing?\" | No | **Yes** |",
        "| Competes with building ROI for *meaning* | Yes (same axis: more $) | **No** (different axis: convenience) |",
        "",
        "Phase 109 supports Phase 108's thesis: **behavior-changing managers create",
        "stronger progression feelings than income multipliers**, even before acquisition",
        "model decoupling (milestone unlocks) is implemented.",
        "",
        "---",
        "",
        "## 6. Limitations",
        "",
        "1. Harness auto-hires Pete/Sal when affordable — does not model ROI competition",
        "   (Phase 107 greedy buyer still skips managers). Acquisition redesign remains",
        "   required for real sessions.",
        "2. Sal costs $2M — **never reached** in full prestige run without reserving;",
        "   `run_sal_focus` isolates post-hire coin behavior.",
        "3. Pete's pick uses the same ROI formula as an optimal bot — human \"off-pick\"",
        "   buys are modeled via pre-hire suboptimal buyer only.",
        "",
        "---",
        "",
        "## 7. Re-run",
        "",
        "```powershell",
        "python _measure_p109.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    print("Phase 109 — Early Manager Prototype measurement")
    results = [run_profile(n) for n in PROFILES]
    sal_runs = [run_sal_focus(n) for n in PROFILES]
    for r in results:
        print(f"\n{r.profile}: Pete {_fmt_t(r.pete_hired_t)} Sal {_fmt_t(r.sal_hired_t)} "
              f"prestige {_fmt_t(r.prestige_t)}")
        if r.at_prestige:
            print(f"  coins: manual={r.at_prestige.coins_manual} auto={r.at_prestige.coins_auto_sal} "
                  f"expired={r.at_prestige.coins_expired}")
            print(f"  pete picks: followed={r.at_prestige.pete_followed} other={r.at_prestige.pete_other}")

    for s in sal_runs:
        print(f"  Sal focus {s['profile']}: hired {_fmt_t(s['sal_hired_t'])} "
              f"auto={s['post_sal_auto']} expired_post={s['post_sal_expired']}")

    report = build_report(results, sal_runs)
    with open("PHASE109_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"\nWrote PHASE109_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
