"""Phase 104 measurement harness — three player profiles, source breakdown.

Runs REAL PlayingState code paths. Debug output only; set config.DEBUG_MONEY_SOURCES
or pass debug=True to accumulate per-source totals.

Profiles:
  CASUAL    — occasional clicks, slow buying
  ENGAGED   — regular clicking + hustle, efficient buys
  OPTIMIZER — high click rate, near-perfect economy decisions
"""
from __future__ import annotations

import os
import sys
import io
import random
import copy

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
import src.money_debug as money_debug
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

MARKS = (600, 1200, 1800)  # 10, 20, 30 min


def fmt_time(s: float | None) -> str:
    if s is None:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


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


def pct_from_sources(totals: dict[str, float]) -> dict[str, float]:
    grand = sum(totals.values()) + 1e-9
    click = totals["money_from_clicks"] + totals["money_from_crit_clicks"] + totals["money_from_hustle"]
    idle = totals["money_from_buildings"]
    ops = totals["money_from_operations"]
    other = totals["money_from_other"] + totals["money_from_territories"]
    return {
        "click_pct": click / grand * 100,
        "idle_pct": idle / grand * 100,
        "ops_pct": ops / grand * 100,
        "other_pct": other / grand * 100,
        "total": grand,
    }


def simulate_click(ps: PlayingState, cv: float, *, pre_crit: float, crit: bool, hustle: bool) -> None:
    ps.balance += cv
    ps.lifetime_earnings += cv
    money_debug.credit_click(ps, cv, pre_crit=pre_crit, had_crit=crit, had_hustle=hustle)


def run_profile(name: str, *, max_min: int = 90, debug: bool = False,
                seed: int = 104) -> dict:
    random.seed(seed)
    p = PROFILES[name]
    prev_debug = config.DEBUG_MONEY_SOURCES
    config.DEBUG_MONEY_SOURCES = True  # sim always tracks sources

    delete_save()
    ps = PlayingState(StateManager())
    ps.on_enter()
    money_debug.reset(ps)

    t = 0.0
    dt = 0.5
    buy_acc = 0.0
    snaps: dict[int, dict] = {}
    crossover = None
    first_mgr = None
    first_prestige = None

    while t < max_min * 60:
        ps.update(dt)
        ips = ps.income_per_second
        active = (t % 60) < (60 * p["active_frac"])

        if active and p["cps"] > 0:
            n_clicks = int(round(p["cps"] * dt))
            for _ in range(n_clicks):
                if p["use_hustle"]:
                    ps._register_active_click()
                pre_crit = ps.click_value
                hustle = ps._has_buff("hustle")
                crit = random.random() < config.CLICK_CRIT_CHANCE
                if crit:
                    cv = pre_crit * random.uniform(config.CLICK_CRIT_MIN, config.CLICK_CRIT_MAX)
                else:
                    cv = pre_crit
                simulate_click(ps, cv, pre_crit=pre_crit, crit=crit, hustle=hustle)

            sustained = p["cps"] * ps.click_value * CRIT_EXPECTED
            if crossover is None and t > 300 and ips > sustained:
                crossover = t

        buy_acc += p["buys_ps"] * dt
        while buy_acc >= 1.0:
            buy_acc -= 1.0
            b = best_building(ps)
            if b and ps.balance >= b.current_cost:
                ps.balance -= b.current_cost
                b.owned += 1

        for u in ps.upgrades:
            if not u.purchased:
                c = upg._effective_cost(u, ps)
                if ps.balance >= c:
                    ps.balance -= c
                    u.purchased = True
                    u.apply(ps)

        for m in ps.managers:
            if not m.hired and ps.balance >= m.cost:
                ps.balance -= m.cost
                m.hired = True
                if first_mgr is None:
                    first_mgr = t

        for mark in MARKS:
            if mark not in snaps and t >= mark:
                snaps[mark] = {
                    "t": t,
                    "ips": ips,
                    "click_value": ps.click_value,
                    **pct_from_sources(money_debug.totals(ps)),
                }

        if first_prestige is None and prestige.can_prestige(ps):
            first_prestige = t
            break

        t += dt

    final = pct_from_sources(money_debug.totals(ps))
    config.DEBUG_MONEY_SOURCES = prev_debug
    return {
        "profile": name,
        "snaps": snaps,
        "crossover": crossover,
        "first_mgr": first_mgr,
        "first_prestige": first_prestige,
        "end_t": t,
        "final": final,
        "sources": money_debug.totals(ps),
    }


def print_report(results: list[dict], label: str = "") -> None:
    if label:
        print(f"\n{'=' * 72}\n{label}\n{'=' * 72}")
    for r in results:
        print(f"\n--- {r['profile']} ---")
        for mark in MARKS:
            if mark in r["snaps"]:
                s = r["snaps"][mark]
                print(
                    f"  {mark // 60:2d}min: click={s['click_pct']:5.1f}%  "
                    f"idle={s['idle_pct']:5.1f}%  ips={theme.format_number(s['ips']):>8}  "
                    f"cv={s['click_value']:.1f}"
                )
        f = r["final"]
        print(
            f"  prestige@{fmt_time(r['first_prestige'])}  "
            f"crossover={fmt_time(r['crossover'])}  mgr={fmt_time(r['first_mgr'])}"
        )
        print(
            f"  FINAL: click={f['click_pct']:5.1f}%  idle={f['idle_pct']:5.1f}%  "
            f"ops={f['ops_pct']:4.1f}%  other={f['other_pct']:4.1f}%  "
            f"total=${f['total']:,.0f}"
        )


def score_results(results: list[dict]) -> float:
    """Lower is better — distance from Phase 104 targets."""
    s = 0.0
    by_name = {r["profile"]: r for r in results}
    engaged = by_name.get("ENGAGED", {})
    casual = by_name.get("CASUAL", {})
    optimizer = by_name.get("OPTIMIZER", {})
    for mark, target in ((600, 38.0), (1200, 27.0), (1800, 22.0)):
        if mark in engaged.get("snaps", {}):
            s += abs(engaged["snaps"][mark]["click_pct"] - target) * 1.5
    if 600 in optimizer.get("snaps", {}):
        s += max(0, optimizer["snaps"][600]["click_pct"] - 55) * 2
    for r in results:
        fp = r["final"]["click_pct"]
        idle = r["final"]["idle_pct"]
        if fp < 15:
            s += (15 - fp) * 3
        elif fp > 30:
            s += (fp - 30) * 3
        if idle > 75:
            s += (idle - 75) * 1.5
        if idle < 50:
            s += (50 - idle) * 1.0
        pt = r.get("first_prestige")
        if pt and pt > 50 * 60:
            s += (pt - 50 * 60) / 30
        if pt is None and r["profile"] == "CASUAL":
            s += 40
    if 1200 in casual.get("snaps", {}):
        s += max(0, 25 - casual["snaps"][1200]["click_pct"])
    return s


def main() -> None:
    label = "Phase 104 baseline"
    if len(sys.argv) > 1 and sys.argv[1] == "--debug":
        config.DEBUG_MONEY_SOURCES = True
        label += " (debug sources on)"
    results = [run_profile(n) for n in PROFILES]
    print_report(results, label)
    if config.DEBUG_MONEY_SOURCES and results:
        print("\n" + money_debug.format_report(
            type("S", (), {"_money_sources": results[0]["sources"]})()
        ))


if __name__ == "__main__":
    main()
