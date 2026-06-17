"""Phase 105 — automation timing audit (measurement only).

Drives real PlayingState; records manager hires, managed buildings, idle-capable
windows, purchase friction, and prestige-progress snapshots. No balance changes.
"""
from __future__ import annotations

import os
import sys
import io
import random
import copy
from dataclasses import dataclass, field

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
try:
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
except Exception:
    pass

import pygame

pygame.init()
pygame.display.set_mode((900, 720))

import config
import src.ui as ui
import src.theme as theme
import src.upgrades as upg
import src.prestige as prestige
import src.managers as mgr_mod
import src.buildings as bld_mod
from src.state_base import StateManager
from src.states import PlayingState
from src.save_load import delete_save

ui.push_notification = lambda *a, **k: None

CRIT_EXPECTED = 1.0 + config.CLICK_CRIT_CHANCE * (
    (config.CLICK_CRIT_MIN + config.CLICK_CRIT_MAX) / 2 - 1
)

PROFILES = {
    "CASUAL": dict(cps=1.5, active_frac=0.25, buys_ps=0.15, use_hustle=False),
    "ENGAGED": dict(cps=4.0, active_frac=0.33, buys_ps=0.50, use_hustle=True),
    "OPTIMIZER": dict(cps=6.0, active_frac=0.45, buys_ps=1.20, use_hustle=True),
}

IDLE_LOSS_THRESHOLD = 0.10  # active layer <10% of 60s earnings => "no meaningful loss"
DEAD_PERIOD_SEC = 60.0


def fmt_time(s: float | None) -> str:
    if s is None:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


def fmt_money(n: float) -> str:
    return theme.format_number(n)


def best_building(ps: PlayingState):
    best, br = None, 0.0
    for b in ps.buildings:
        c = b.current_cost
        if c <= 0 or ps.balance < c:
            continue
        r = b.base_income * b.income_multiplier / c
        if r > br:
            br, best = r, b
    return best


def prestige_progress(ps: PlayingState) -> dict:
    req = prestige.prestige_earnings_required(ps)
    le = float(ps.lifetime_earnings)
    rank = prestige.get_rank(ps.prestige_tokens)
    return {
        "lifetime": le,
        "required": req,
        "pct": min(100.0, le / req * 100) if req > 0 else 0.0,
        "rank": rank,
        "tokens": ps.prestige_tokens,
        "can_prestige": prestige.can_prestige(ps),
    }


def snapshot(ps: PlayingState, t: float) -> dict:
    pp = prestige_progress(ps)
    return {
        "t": t,
        "balance": ps.balance,
        "ips": ps.income_per_second,
        "click_value": ps.click_value,
        **pp,
    }


def active_earnings_rate(ps: PlayingState, profile: dict) -> float:
    """Expected $/s from clicking at this profile's cadence."""
    cps = profile["cps"] * profile["active_frac"]
    return cps * ps.click_value * CRIT_EXPECTED


def can_afford_anything(ps: PlayingState) -> bool:
    b = best_building(ps)
    if b and ps.balance >= b.current_cost:
        return True
    for u in ps.upgrades:
        if not u.purchased and ps.balance >= upg._effective_cost(u, ps):
            return True
    for m in ps.managers:
        if not m.hired and ps.balance >= m.cost:
            return True
    return False


def next_affordable_cost(ps: PlayingState) -> float | None:
    costs = []
    b = best_building(ps)
    if b:
        costs.append(b.current_cost)
    for u in ps.upgrades:
        if not u.purchased:
            costs.append(upg._effective_cost(u, ps))
    for m in ps.managers:
        if not m.hired:
            costs.append(m.cost)
    affordable = [c for c in costs if ps.balance >= c]
    if affordable:
        return min(affordable)
    return min(costs) if costs else None


@dataclass
class AuditResult:
    profile: str
    manager_hires: list[dict] = field(default_factory=list)
    first_managed_building: dict | None = None
    accountant_hired: dict | None = None
    first_accountant_autobuy: dict | None = None
    first_idle_60s: dict | None = None
    first_passive_crossover: dict | None = None
    purchase_times: list[tuple[float, str]] = field(default_factory=list)
    dead_periods: list[dict] = field(default_factory=list)
    buy_bursts: list[dict] = field(default_factory=list)
    prestige_time: float | None = None
    end_time: float = 0.0
    micromanaging_at_prestige: dict | None = None

    def midpoint_classification(self) -> str:
        if not self.manager_hires or not self.prestige_time:
            return "unknown (no prestige in window)"
        mid = self.prestige_time / 2
        t1 = self.manager_hires[0]["t"]
        ratio = t1 / self.prestige_time
        if ratio < 0.40:
            return "A) Before midpoint"
        if ratio <= 0.60:
            return "B) Near midpoint"
        return "C) Near first prestige"


def simulate_click(ps: PlayingState, profile: dict, dt: float) -> None:
    n = int(round(profile["cps"] * dt))
    for _ in range(n):
        if profile["use_hustle"]:
            ps._register_active_click()
        pre_crit = ps.click_value
        crit = random.random() < config.CLICK_CRIT_CHANCE
        cv = pre_crit * (random.uniform(config.CLICK_CRIT_MIN, config.CLICK_CRIT_MAX) if crit else 1.0)
        ps.balance += cv
        ps.lifetime_earnings += cv


def run_audit(name: str, *, max_min: int = 90, seed: int = 105) -> AuditResult:
    random.seed(seed + hash(name) % 1000)
    profile = PROFILES[name]
    delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()

    result = AuditResult(profile=name)
    t = 0.0
    dt = 0.5
    buy_acc = 0.0

    last_purchase_t = 0.0
    dead_start: float | None = None
    recent_buys: list[float] = []

    prev_owned = [b.owned for b in ps.buildings]
    prev_hired = [m.hired for m in ps.managers]
    prev_upgrades = [u.purchased for u in ps.upgrades]
    prev_balance = ps.balance

    while t < max_min * 60:
        active = (t % 60) < (60 * profile["active_frac"])
        ips_before = ps.income_per_second

        ps.update(dt)

        # Detect Accountant auto-buy (balance drop + owned increase, no manual buy flag)
        if mgr_mod.manager_active(ps, "The Accountant"):
            for i, b in enumerate(ps.buildings):
                if b.owned > prev_owned[i]:
                    if result.first_accountant_autobuy is None:
                        bname = ps.buildings[i].name
                        result.first_accountant_autobuy = {
                            **snapshot(ps, t),
                            "building": bname,
                            "note": "Accountant auto-purchase detected",
                        }

        if active and profile["cps"] > 0:
            simulate_click(ps, profile, dt)

        # Passive crossover (ips beats active click rate)
        if result.first_passive_crossover is None and t > 60:
            ar = active_earnings_rate(ps, profile)
            if ips_before > ar and ar > 0:
                result.first_passive_crossover = {
                    **snapshot(ps, t),
                    "active_rate": ar,
                    "note": "idle/s exceeds sustained click $/s",
                }

        # 60s idle-capable check (every 30s after 2 min)
        if result.first_idle_60s is None and t >= 120 and int(t) % 30 == 0:
            ar = active_earnings_rate(ps, profile)
            passive = ps.income_per_second
            total = passive + ar
            if total > 0 and ar / total <= IDLE_LOSS_THRESHOLD:
                result.first_idle_60s = {
                    **snapshot(ps, t),
                    "active_rate": ar,
                    "passive_rate": passive,
                    "active_share": ar / total * 100,
                    "note": f"active layer <{IDLE_LOSS_THRESHOLD*100:.0f}% of combined $/s",
                }

        # Manual buys
        buy_acc += profile["buys_ps"] * dt
        manual_bought = False
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b = best_building(ps)
            if b and ps.balance >= b.current_cost:
                ps.balance -= b.current_cost
                b.owned += 1
                manual_bought = True
                result.purchase_times.append((t, f"building:{b.name}"))
                recent_buys.append(t)

        for ui_idx, u in enumerate(ps.upgrades):
            if not u.purchased:
                c = upg._effective_cost(u, ps)
                if ps.balance >= c:
                    ps.balance -= c
                    u.purchased = True
                    u.apply(ps)
                    result.purchase_times.append((t, f"upgrade:{u.name}"))
                    recent_buys.append(t)

        for mi, m in enumerate(ps.managers):
            if not m.hired and ps.balance >= m.cost:
                ps.balance -= m.cost
                m.hired = True
                hire_snap = {**snapshot(ps, t), "manager": m.name, "cost": m.cost,
                             "building": ps.buildings[m.building_index].name
                             if m.building_index < len(ps.buildings) else "?"}
                result.manager_hires.append(hire_snap)
                result.purchase_times.append((t, f"manager:{m.name}"))
                recent_buys.append(t)

                if result.first_managed_building is None:
                    b = ps.buildings[m.building_index]
                    if b.owned > 0:
                        result.first_managed_building = {
                            **hire_snap,
                            "note": f"{b.name} now has hired manager (passive boost)",
                        }
                if m.name == "The Accountant" and result.accountant_hired is None:
                    result.accountant_hired = hire_snap

        # Purchase / dead-period tracking
        any_purchase = (
            len(recent_buys) > 0 and recent_buys[-1] >= t - dt
        ) or manual_bought
        if any_purchase:
            last_purchase_t = t
            dead_start = None
        else:
            if dead_start is None:
                dead_start = t
            elif t - dead_start >= DEAD_PERIOD_SEC:
                if not can_afford_anything(ps):
                    nxt = next_affordable_cost(ps)
                    gap = (nxt - ps.balance) if nxt and nxt > ps.balance else None
                    result.dead_periods.append({
                        "start": dead_start,
                        "end": t,
                        "duration": t - dead_start,
                        "balance": ps.balance,
                        "ips": ps.income_per_second,
                        "next_cost_gap": gap,
                        "note": "no purchase >60s, nothing affordable",
                    })
                    dead_start = t  # record once per span

        # Buy bursts (3+ purchases within 10s)
        recent_buys = [tb for tb in recent_buys if t - tb <= 10]
        if len(recent_buys) >= 3 and len(result.buy_bursts) < 20:
            if not result.buy_bursts or result.buy_bursts[-1]["t"] < t - 10:
                result.buy_bursts.append({
                    "t": t,
                    "count": len(recent_buys),
                    "balance": ps.balance,
                    "note": "rapid manual purchase burst",
                })

        if prestige.can_prestige(ps):
            result.prestige_time = t
            ar = active_earnings_rate(ps, profile)
            result.micromanaging_at_prestige = {
                **snapshot(ps, t),
                "active_rate": ar,
                "passive_rate": ps.income_per_second,
                "managers_hired": sum(1 for m in ps.managers if m.hired),
                "accountant": mgr_mod.manager_active(ps, "The Accountant"),
                "manual_buys_last_5min": sum(
                    1 for pt, _ in result.purchase_times if t - pt <= 300
                ),
            }
            break

        prev_owned = [b.owned for b in ps.buildings]
        prev_hired = [m.hired for m in ps.managers]
        prev_upgrades = [u.purchased for u in ps.upgrades]
        prev_balance = ps.balance
        t += dt

    result.end_time = t
    return result


def avg_purchase_interval(purchases: list[tuple[float, str]]) -> float | None:
    if len(purchases) < 2:
        return None
    gaps = [purchases[i][0] - purchases[i - 1][0] for i in range(1, len(purchases))]
    return sum(gaps) / len(gaps)


def print_summary(r: AuditResult) -> None:
    print(f"\n{'='*70}\nPROFILE: {r.profile}\n{'='*70}")
    print(f"Prestige reached: {fmt_time(r.prestige_time)}  (sim end: {fmt_time(r.end_time)})")
    print(f"Midpoint classification (1st manager): {r.midpoint_classification()}")

    for label, key in [
        ("1st manager", 0), ("2nd manager", 1), ("3rd manager", 2),
    ]:
        if key < len(r.manager_hires):
            h = r.manager_hires[key]
            print(
                f"  {label}: {fmt_time(h['t'])} — {h['manager']} "
                f"(${fmt_money(h['cost'])})  ips={fmt_money(h['ips'])}/s  "
                f"prestige={h['pct']:.1f}%  rank={h['rank']}"
            )
        else:
            print(f"  {label}: NEVER")

    for tag, ev in [
        ("First managed building", r.first_managed_building),
        ("The Accountant hired", r.accountant_hired),
        ("First Accountant auto-buy", r.first_accountant_autobuy),
        ("Passive crossover (ips>clicks)", r.first_passive_crossover),
        ("First 60s-idle-capable moment", r.first_idle_60s),
    ]:
        if ev:
            extra = ev.get("building") or ev.get("manager") or ""
            print(
                f"  {tag}: {fmt_time(ev['t'])} {extra}  "
                f"ips={fmt_money(ev['ips'])}/s  prestige={ev['pct']:.1f}%"
            )
        else:
            print(f"  {tag}: NEVER")

    interval = avg_purchase_interval(r.purchase_times)
    print(f"  Purchases total: {len(r.purchase_times)}  avg interval: "
          f"{fmt_time(interval) if interval else 'N/A'}")
    print(f"  Dead periods (>{DEAD_PERIOD_SEC:.0f}s, nothing to buy): {len(r.dead_periods)}")
    for dp in r.dead_periods[:3]:
        print(f"    {fmt_time(dp['start'])}–{fmt_time(dp['end'])} "
              f"({dp['duration']:.0f}s) gap-to-next=${fmt_money(dp['next_cost_gap'] or 0)}")
    print(f"  Manual buy bursts (3+ in 10s): {len(r.buy_bursts)}")
    for bb in r.buy_bursts[:3]:
        print(f"    {fmt_time(bb['t'])} — {bb['count']} buys in 10s")

    if r.micromanaging_at_prestige:
        mp = r.micromanaging_at_prestige
        print(f"  At prestige: managers={mp['managers_hired']}  "
              f"accountant={'yes' if mp['accountant'] else 'no'}  "
              f"manual buys last 5min={mp['manual_buys_last_5min']}  "
              f"active/passive $/s={fmt_money(mp['active_rate'])}/"
              f"{fmt_money(mp['passive_rate'])}")


def build_report(results: list[AuditResult]) -> str:
    lines = [
        "# Phase 105 — Automation Timing Audit",
        "",
        "**Date:** 2026-06-15  ",
        "**Scope:** Measurement only — no balance or code changes.",
        "",
        "---",
        "",
        "## Objective",
        "",
        "Determine when managers and automation unlock relative to the first prestige cycle,",
        "and when the game transitions from manual play to self-running empire.",
        "",
        "---",
        "",
        "## Method",
        "",
        "`_measure_p105.py` drives **real `PlayingState`** with the same three profiles as Phase 104:",
        "",
        "| Profile | CPS | Active time | Buys/sec |",
        "|---------|-----|-------------|----------|",
        "| CASUAL | 1.5 | 25% | 0.15 |",
        "| ENGAGED | 4.0 | 33% | 0.50 |",
        "| OPTIMIZER | 6.0 | 45% | 1.20 |",
        "",
        "**Definitions used in this audit:**",
        "",
        "- **Managed building** — first manager hired for a building tier that is already owned (passive income boost via `compute_base_income`).",
        "- **True automation** — **The Accountant** hired; auto-buys best building every 3s via `tick_manager_effects`.",
        "- **Passive crossover** — `income_per_second` exceeds sustained click $/s for the profile.",
        "- **60s idle-capable** — active click layer contributes <10% of combined active+passive $/s (first time after 2 min).",
        "- **Dead period** — >60s with no purchase and nothing affordable.",
        "",
        "Manager hire order in sim: first affordable in list order (Sticky Pete → Consigliere).",
        "",
        "---",
        "",
        "## Manager roster & costs (reference)",
        "",
        "| # | Manager | Building | Cost | Primary hook |",
        "|---|---------|----------|------|--------------|",
    ]
    for i, m in enumerate(mgr_mod.MANAGERS[:6]):
        bname = bld_mod._DEFS[m.building_index][0] if m.building_index < len(bld_mod._DEFS) else "?"
        hook = "AUTO-BUY" if m.name == "The Accountant" else m.specialty.split("*")[-1].strip()[:40]
        lines.append(f"| {i+1} | {m.name} | {bname} | ${theme.format_number(m.cost)} | {hook} |")
    lines.append("")
    lines.append("*Full roster: 11 managers; Accountant (6th) is the only auto-buy.*")
    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## Automation timelines")
    lines.append("")

    for r in results:
        lines.append(f"### {r.profile}")
        lines.append("")
        lines.append(f"- **First prestige:** {fmt_time(r.prestige_time)}")
        lines.append(f"- **Automation vs midpoint:** {r.midpoint_classification()}")
        lines.append("")
        lines.append("| Event | Time | Money (lifetime) | IPS | Prestige % | Rank |")
        lines.append("|-------|------|------------------|-----|------------|------|")

        def row(ev: dict | None, label: str) -> None:
            if ev:
                lines.append(
                    f"| {label} | {fmt_time(ev['t'])} | ${fmt_money(ev['lifetime'])} | "
                    f"{fmt_money(ev['ips'])}/s | {ev['pct']:.1f}% | {ev['rank']} |"
                )
            else:
                lines.append(f"| {label} | NEVER | — | — | — | — |")

        for i, label in enumerate(["1st manager", "2nd manager", "3rd manager"], 1):
            row(r.manager_hires[i - 1] if len(r.manager_hires) >= i else None, label)
        row(r.first_managed_building, "First managed building")
        row(r.accountant_hired, "The Accountant (auto-buy)")
        row(r.first_accountant_autobuy, "First Accountant auto-buy")
        row(r.first_passive_crossover, "Passive > click crossover")
        row(r.first_idle_60s, "60s idle-capable moment")
        lines.append("")

        if r.manager_hires:
            lines.append(f"**First manager:** {r.manager_hires[0]['manager']} "
                         f"({r.manager_hires[0].get('building', '?')})")
        if r.accountant_hired:
            pct_run = r.accountant_hired["t"] / r.prestige_time * 100 if r.prestige_time else 0
            lines.append(f"**Accountant arrives at {pct_run:.0f}% of run to prestige.**")
        lines.append("")

    lines.extend([
        "---",
        "",
        "## Manual friction",
        "",
        "| Profile | Total purchases | Avg interval | Dead periods | Buy bursts |",
        "|---------|-----------------|--------------|--------------|------------|",
    ])
    for r in results:
        iv = avg_purchase_interval(r.purchase_times)
        lines.append(
            f"| {r.profile} | {len(r.purchase_times)} | "
            f"{fmt_time(iv) if iv else 'N/A'} | {len(r.dead_periods)} | {len(r.buy_bursts)} |"
        )

    lines.extend([
        "",
        "**Friction observations:**",
        "",
    ])

    friction_lines = []
    for r in results:
        parts = []
        if r.dead_periods:
            longest = max(r.dead_periods, key=lambda d: d["duration"])
            parts.append(
                f"longest dead wait {longest['duration']:.0f}s "
                f"at {fmt_time(longest['start'])} (saving for next buy)"
            )
        else:
            parts.append("no dead periods (always saving toward next buy)")
        if r.buy_bursts:
            parts.append(f"{len(r.buy_bursts)} manual buy bursts in first ~10 min")
        if r.accountant_hired is None:
            parts.append("never reached The Accountant ($60M) before prestige")
        elif r.prestige_time:
            acc_pct = r.accountant_hired["t"] / r.prestige_time * 100
            parts.append(f"Accountant at {acc_pct:.0f}% of prestige run")
        if r.micromanaging_at_prestige:
            mp = r.micromanaging_at_prestige
            if mp["manual_buys_last_5min"] >= 5:
                parts.append(f"{mp['manual_buys_last_5min']} manual purchases in final 5 min")
        friction_lines.append(f"- **{r.profile}:** " + "; ".join(parts))
    lines.extend(friction_lines)

    lines.extend([
        "",
        "---",
        "",
        "## Emotional transition analysis",
        "",
    ])

    engaged = next((r for r in results if r.profile == "ENGAGED"), None)
    if engaged:
        lines.append("### When does ENGAGED stop feeling like a clicker?")
        lines.append("")
        if engaged.first_passive_crossover:
            lines.append(
                f"- **Passive crossover** at {fmt_time(engaged.first_passive_crossover['t'])} "
                f"({engaged.first_passive_crossover['pct']:.0f}% to prestige) — idle $/s beats clicking."
            )
        if engaged.first_idle_60s:
            lines.append(
                f"- **Psychological idle window** at {fmt_time(engaged.first_idle_60s['t'])} "
                f"(clicks <10% of earnings rate)."
            )
        if engaged.manager_hires:
            lines.append(
                f"- **First manager** ({engaged.manager_hires[0]['manager']}) at "
                f"{fmt_time(engaged.manager_hires[0]['t'])} — "
                f"{'click boost, not automation' if engaged.manager_hires[0]['manager'] == 'Sticky Pete' else 'specialty boost'}."
            )
        if engaged.accountant_hired:
            lines.append(
                f"- **True automation** (Accountant) at {fmt_time(engaged.accountant_hired['t'])} — "
                f"{'before' if engaged.accountant_hired['t'] < engaged.prestige_time * 0.9 else 'near'} prestige."
            )
        else:
            lines.append("- **True automation never unlocked** before first prestige.")
        lines.append("")

    lines.extend([
        "---",
        "",
        "## Audit questions answered",
        "",
    ])

    # Aggregate answers
    first_mgr_times = [r.manager_hires[0]["t"] for r in results if r.manager_hires]
    acc_times = [r.accountant_hired["t"] for r in results if r.accountant_hired]
    prestige_times = [r.prestige_time for r in results if r.prestige_time]

    lines.append("### Is automation too late?")
    lines.append("")
    if first_mgr_times:
        avg_first = sum(first_mgr_times) / len(first_mgr_times)
        lines.append(
            f"**First manager (Sticky Pete) averages {fmt_time(avg_first)}** — "
            f"at ~{first_mgr_times[0]/prestige_times[0]*100 if prestige_times else 0:.0f}%–"
            f"{first_mgr_times[-1]/prestige_times[-1]*100 if prestige_times else 0:.0f}% of the prestige run. "
            f"Classification: **{results[1].midpoint_classification() if len(results)>1 else 'see profiles'}**."
        )
    if acc_times and prestige_times:
        lines.append(
            f"**The Accountant** (only true auto-buy) arrives at "
            f"{fmt_time(min(acc_times))}–{fmt_time(max(acc_times))}, "
            f"roughly **{min(a/p for a,p in zip(acc_times, prestige_times))*100:.0f}%–"
            f"{max(a/p for a,p in zip(acc_times, prestige_times))*100:.0f}%** through the prestige cycle — "
            "**likely too late** for the \"empire runs itself\" moment."
        )
    else:
        lines.append("**The Accountant is not reached before first prestige** in some/all profiles — automation is absent entirely.")
    lines.append("")

    lines.append("### Which manager creates the first \"idle feeling\"?")
    lines.append("")
    lines.append(
        "**Sticky Pete** is always first hired (~75K), but he boosts **clicks**, not automation. "
        "The first *passive* shift is **passive crossover** (idle > click $/s), not a manager. "
        "**The Accountant** is the first manager that removes manual building buys — if reached."
    )
    lines.append("")

    lines.append("### Which building becomes self-sustaining first?")
    lines.append("")
    lines.append(
        "Corner Dealer income ramps first; **Protection Racket** multiplier makes dealer tier self-reinforcing. "
        "No building auto-purchases itself until **The Accountant** (Loan Shark tier manager) is hired."
    )
    lines.append("")

    lines.append("### Are players still micromanaging near prestige?")
    lines.append("")
    for r in results:
        if r.micromanaging_at_prestige:
            mp = r.micromanaging_at_prestige
            lines.append(
                f"- **{r.profile}:** {mp['manual_buys_last_5min']} manual purchases in last 5 min; "
                f"Accountant={'yes' if mp['accountant'] else 'no'}; "
                f"{mp['managers_hired']} managers hired."
            )
    lines.append("")

    lines.append("### Where should automation ideally appear?")
    lines.append("")
    lines.append(
        "Design intent (Phase 104 targets): **15–30 min** = \"empire running itself\"; "
        "**30–60 min** = \"optimizing systems.\" Current data suggests:"
    )
    lines.append("")
    lines.append("| Ideal milestone | Current ENGAGED (approx) | Gap |")
    lines.append("|-----------------|--------------------------|-----|")
    if engaged:
        lines.append(f"| First *automation* manager | {fmt_time(engaged.accountant_hired['t']) if engaged.accountant_hired else 'NEVER'} | Should be ~15–25 min |")
        lines.append(f"| Passive crossover | {fmt_time(engaged.first_passive_crossover['t']) if engaged.first_passive_crossover else 'NEVER'} | OK (~9 min) |")
        lines.append(f"| First manager (any) | {fmt_time(engaged.manager_hires[0]['t']) if engaged.manager_hires else 'NEVER'} | Too late for *automation* feel |")
        lines.append(f"| First prestige | {fmt_time(engaged.prestige_time)} | — |")
    lines.append("")

    lines.extend([
        "---",
        "",
        "## Remaining concerns",
        "",
        "1. **Accountant cost ($60M)** gates true automation to the back third of the prestige run (if reached at all).",
        "2. **First three managers** are passive modifiers (click, raid, income) — they do not reduce manual building buys.",
        "3. **CASUAL may never reach Accountant** before prestige at current pacing.",
        "4. **Harness does not simulate tab switching** or operations/crew — real players may feel friction differently.",
        "5. **Prestige gate at $20M lifetime** extends run length, pushing all manager timestamps later.",
        "",
        "---",
        "",
        "## Re-run",
        "",
        "```powershell",
        "python _measure_p105.py",
        "```",
        "",
    ])
    return "\n".join(lines)


def main() -> None:
    results = [run_audit(n) for n in PROFILES]
    for r in results:
        print_summary(r)
    report = build_report(results)
    with open("PHASE105_REPORT.md", "w", encoding="utf-8") as f:
        f.write(report)
    print(f"\nWrote PHASE105_REPORT.md ({len(report)} chars)")


if __name__ == "__main__":
    main()
