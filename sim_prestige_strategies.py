"""
Prestige pacing + strategy comparison using real PlayingState logic.

Extends sim_pacing.py with:
  * auto-prestige when requirements met (tracks cadence, influence gain)
  * named player strategies (buildings vs turf vs clicks vs buy cadence)

Usage:
    python sim_prestige_strategies.py
    python sim_prestige_strategies.py --active 0.33 --minutes 90 --prestiges 3
"""
from __future__ import annotations
import os
import sys
import io
import argparse
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

import src.prestige as prestige
import src.territory as terr_mod
import src.upgrades as upg
from src.state_base import StateManager
from src.states import PlayingState
from src.save_load import delete_save


def fmt_t(s: float) -> str:
    if s >= 1e8:
        return "NEVER"
    return f"{int(s // 60)}m{int(s % 60):02d}s"


@dataclass
class Strategy:
    name: str
    cps: float = 2.0
    buy_interval: float = 1.5
    action_cd: float = 4.0
    do_territory: bool = True
    buy_cheapest: bool = False
    skip_upgrades: bool = False
    skip_managers: bool = False


@dataclass
class PrestigeEvent:
    time: float
    index: int
    influence_gain: int
    total_influence: int
    rank: str
    ips_before: float


@dataclass
class RunResult:
    strategy: str
    first_influence: float = 1e9
    first_prestige_ready: float = 1e9
    prestige_events: list[PrestigeEvent] = field(default_factory=list)
    inf_at: dict[int, int] = field(default_factory=dict)
    final_influence: int = 0
    final_ips: float = 0.0


class StrategyPlayer:
    """Human-realistic player with configurable priorities."""

    def __init__(self, ps: PlayingState, strat: Strategy):
        self.ps = ps
        self.strat = strat
        self._click_acc = 0.0
        self._buy_t = 0.0
        self._action_t = 0.0

    def act(self, dt: float, active: bool) -> None:
        if not active:
            return
        ps = self.ps
        s = self.strat

        self._click_acc += s.cps * dt
        while self._click_acc >= 1.0:
            cv = ps.click_value
            ps.balance += cv
            ps.lifetime_earnings += cv
            ps._prestige_route_earnings = float(
                getattr(ps, "_prestige_route_earnings", 0.0)
            ) + cv
            ps._click_count += 1
            self._click_acc -= 1.0

        self._buy_t += dt
        if self._buy_t >= s.buy_interval:
            self._buy_t = 0.0
            b = self._pick_building()
            if b and ps.balance >= b.current_cost:
                ps.balance -= b.current_cost
                b.owned += 1

        if not s.skip_upgrades:
            for u in ps.upgrades:
                if not u.purchased:
                    cost = upg._effective_cost(u, ps)
                    if ps.balance >= cost:
                        ps.balance -= cost
                        u.purchased = True
                        u.apply(ps)

        if not s.skip_managers:
            for m in ps.managers:
                if not m.hired and ps.balance >= m.cost:
                    ps.balance -= m.cost
                    m.hired = True

        ps.crew.collection = sum(b.owned for b in ps.buildings)

        if s.do_territory:
            self._action_t += dt
            if self._action_t >= s.action_cd:
                self._action_t = 0.0
                self._try_one_territory()

    def _pick_building(self):
        ps = self.ps
        if self.strat.buy_cheapest:
            best = None
            cheapest = 1e30
            for b in ps.buildings:
                c = b.current_cost
                if c > 0 and ps.balance >= c and c < cheapest:
                    cheapest, best = c, b
            return best
        best, br = None, 0.0
        for b in ps.buildings:
            c = b.current_cost
            if c <= 0 or ps.balance < c:
                continue
            r = (b.base_income * b.income_multiplier) / c
            if r > br:
                br, best = r, b
        return best

    def _try_one_territory(self) -> None:
        ps = self.ps
        for idx, terr in enumerate(ps.territories):
            if terr.unlocked:
                continue
            if ps.prestige_tokens < terr.unlock_cost:
                continue
            terr_mod.perform_action(ps, idx, "negotiate")
            return


STRATEGIES: list[Strategy] = [
    Strategy("balanced", cps=2.0, buy_interval=1.5, action_cd=4.0),
    Strategy("buildings_only", do_territory=False),
    Strategy("turf_rush", action_cd=2.0),
    Strategy("click_heavy", cps=5.0, buy_interval=2.5),
    Strategy("fast_buyer", cps=1.0, buy_interval=0.75),
    Strategy("cheapest_building", buy_cheapest=True),
    Strategy("no_upgrades", skip_upgrades=True),
    Strategy("no_managers", skip_managers=True),
    Strategy("pure_idle", cps=0.0, buy_interval=2.0, do_territory=False),
]


def run_strategy(
    strat: Strategy,
    minutes: float,
    active_frac: float,
    prestige_target: int,
    idle_active_frac: float | None = None,
) -> RunResult:
    delete_save()
    sm = StateManager()
    ps = PlayingState(sm)
    ps.on_enter()
    player = StrategyPlayer(ps, strat)

    t, dt = 0.0, 0.5
    active_secs = max(1, int(60 * active_frac))
    idle_secs = max(0, int(60 * (idle_active_frac if idle_active_frac is not None else active_frac)))
    if strat.name == "pure_idle":
        active_secs = max(1, int(60 * 0.10))

    result = RunResult(strategy=strat.name)
    done = 0

    while t < minutes * 60 and done < prestige_target:
        if strat.name == "pure_idle":
            active = (t % 60) < active_secs
        else:
            active = (t % 60) < active_secs

        ps.update(dt)
        player.act(dt, active)

        if result.first_influence > 1e8 and ps.prestige_tokens >= 1:
            result.first_influence = t

        if prestige.can_prestige(ps):
            if result.first_prestige_ready > 1e8:
                result.first_prestige_ready = t
            ips_before = ps.income_per_second
            gain = prestige.calc_influence_gain(ps.lifetime_earnings)
            prestige.PrestigeManager.execute(ps)
            done += 1
            result.prestige_events.append(
                PrestigeEvent(
                    time=t,
                    index=done,
                    influence_gain=gain,
                    total_influence=ps.prestige_tokens,
                    rank=prestige.get_rank(ps.prestige_tokens),
                    ips_before=ips_before,
                )
            )

        for milestone_min in (5, 10, 15, 20, 25, 30, 45, 60):
            sec = milestone_min * 60
            if sec - dt <= t < sec + dt:
                result.inf_at[milestone_min] = ps.prestige_tokens

        t += dt

    result.final_influence = ps.prestige_tokens
    result.final_ips = ps.income_per_second
    delete_save()
    return result


def gap(events: list[PrestigeEvent], i: int) -> float:
    if len(events) < i + 1:
        return 1e9
    if i == 0:
        return events[0].time
    return events[i].time - events[i - 1].time


def print_results(results: list[RunResult], minutes: float, active_frac: float) -> None:
    print("=" * 88)
    print(f"PRESTIGE STRATEGY COMPARISON — {minutes:.0f}min cap, {active_frac*100:.0f}% active window")
    print("=" * 88)
    hdr = (
        f"{'strategy':<18} {'1st ready':>10} {'P1':>10} {'P2':>10} {'P3':>10} "
        f"{'P1 inf':>7} {'P2 inf':>7} {'final inf':>10}"
    )
    print(hdr)
    print("-" * 88)
    for r in sorted(results, key=lambda x: x.first_prestige_ready):
        p = r.prestige_events
        p1 = fmt_t(p[0].time) if p else "NEVER"
        p2 = fmt_t(p[1].time) if len(p) > 1 else "—"
        p3 = fmt_t(p[2].time) if len(p) > 2 else "—"
        p1_inf = str(p[0].influence_gain) if p else "—"
        p2_inf = str(p[1].influence_gain) if len(p) > 1 else "—"
        print(
            f"{r.strategy:<18} {fmt_t(r.first_prestige_ready):>10} {p1:>10} {p2:>10} {p3:>10} "
            f"{p1_inf:>7} {p2_inf:>7} {r.final_influence:>10}"
        )

    print()
    print("Cadence gaps (time between prestiges):")
    for r in sorted(results, key=lambda x: gap(x.prestige_events, 1)):
        p = r.prestige_events
        if len(p) < 2:
            continue
        parts = [f"to P1: {fmt_t(gap(p, 0))}"]
        for i in range(1, len(p)):
            parts.append(f"P{i}→P{i + 1}: {fmt_t(gap(p, i))}")
        print(f"  {r.strategy:<18}  " + "  ".join(parts))

    print()
    print("Influence @ milestones (top 3 fastest to first prestige):")
    top = sorted(results, key=lambda x: x.first_prestige_ready)[:3]
    for r in top:
        parts = [f"@{m}m={r.inf_at[m]}" for m in sorted(r.inf_at) if m <= minutes]
        print(f"  {r.strategy}: {', '.join(parts)}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--minutes", type=float, default=90.0)
    p.add_argument("--active", type=float, default=0.33)
    p.add_argument("--prestiges", type=int, default=3)
    p.add_argument(
        "--strategies",
        nargs="*",
        default=[s.name for s in STRATEGIES],
        help="subset of strategy names",
    )
    args = p.parse_args()
    delete_save()  # avoid loading a polluted save from a prior sim in the same cwd

    by_name = {s.name: s for s in STRATEGIES}
    chosen = [by_name[n] for n in args.strategies if n in by_name]
    if not chosen:
        chosen = STRATEGIES

    results = [
        run_strategy(s, args.minutes, args.active, args.prestiges) for s in chosen
    ]
    print_results(results, args.minutes, args.active)
