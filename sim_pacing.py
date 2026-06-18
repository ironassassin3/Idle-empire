"""
P9 — Faithful pacing sim (ROADMAP retention).

sim_playthrough.py is the *experience* tracer but it cheats: it negotiates a
territory every 0.5s tick, mass-capturing rival districts at UI-impossible speed.
That floods territory goals -> Influence -> fast rank-ups -> an unrealistic ~8min
first prestige, hiding the Phase 103 "Influence-snowball lockout".

This sim drives the REAL PlayingState but constrains the player to human cadence:
  * actions only during active windows (default 20s/min = 33% engaged)
  * territory / rival actions gated by a cooldown (default one per 4s), one
    district per attempt (no per-tick sweep)
  * clicks at a fixed rate, buys best-value at a human buy rate

It then measures the Phase 103 pacing metrics so a fix can be proven against
before/after numbers. No balance is changed here — measurement only.
"""
from __future__ import annotations
import os, sys, io, argparse
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
    return f"{int(s // 60)}m{int(s % 60):02d}s" if s < 1e8 else "NEVER"


class HumanPlayer:
    """Drives PlayingState via real methods at human-realistic cadence."""

    def __init__(self, ps, clicks_per_sec=2.0, buy_interval=1.5, action_cd=4.0, do_territory=True):
        self.ps = ps
        self.cps = clicks_per_sec
        self.buy_interval = buy_interval
        self.action_cd = action_cd
        self.do_territory = do_territory
        self._click_acc = 0.0
        self._buy_t = 0.0
        self._action_t = 0.0

    def act(self, dt: float, active: bool) -> None:
        ps = self.ps
        if not active:
            return
        # Clicks (real click_value path).
        self._click_acc += self.cps * dt
        while self._click_acc >= 1.0:
            cv = ps.click_value
            ps.balance += cv
            ps.lifetime_earnings += cv
            ps._prestige_route_earnings = float(getattr(ps, '_prestige_route_earnings', 0.0)) + cv
            ps._click_count += 1
            self._click_acc -= 1.0
        # Buy best-value building at a human buy rate.
        self._buy_t += dt
        if self._buy_t >= self.buy_interval:
            self._buy_t = 0.0
            b = self._best_building()
            if b and ps.balance >= b.current_cost:
                ps.balance -= b.current_cost
                b.owned += 1
        # Upgrades / managers — bought promptly when affordable (realistic).
        for u in ps.upgrades:
            if not u.purchased:
                cost = upg._effective_cost(u, ps)
                if ps.balance >= cost:
                    ps.balance -= cost
                    u.purchased = True
                    u.apply(ps)
        for m in ps.managers:
            if not m.hired and ps.balance >= m.cost:
                ps.balance -= m.cost
                m.hired = True
        ps.crew.collection = sum(b.owned for b in ps.buildings)
        # One territory action per cooldown (not a per-tick sweep).
        if self.do_territory:
            self._action_t += dt
            if self._action_t >= self.action_cd:
                self._action_t = 0.0
                self._try_one_territory()

    def _try_one_territory(self) -> None:
        ps = self.ps
        for idx, terr in enumerate(ps.territories):
            if terr.unlocked:
                continue
            if ps.prestige_tokens < terr.unlock_cost:
                continue
            terr_mod.perform_action(ps, idx, 'negotiate')
            return

    def _best_building(self):
        best, br = None, 0.0
        for b in self.ps.buildings:
            c = b.current_cost
            if c <= 0 or self.ps.balance < c:
                continue
            r = (b.base_income * b.income_multiplier) / c
            if r > br:
                br, best = r, b
        return best


def run(minutes: float, active_frac: float, cps: float, do_territory: bool = True) -> dict:
    delete_save()
    sm = StateManager()
    ps = PlayingState(sm)
    ps.on_enter()
    player = HumanPlayer(ps, clicks_per_sec=cps, do_territory=do_territory)

    t, dt = 0.0, 0.5
    active_secs = max(1, int(60 * active_frac))
    marks: dict[str, float] = {}
    inf_at: dict[int, int] = {}
    crossover: float = 1e9
    first_prestige: float = 1e9

    def mark(k):
        if k not in marks:
            marks[k] = t

    while t < minutes * 60:
        active = (t % 60) < active_secs
        ps.update(dt)
        player.act(dt, active)

        if any(u.purchased for u in ps.upgrades): mark('first_upgrade')
        if ps.prestige_tokens >= 1: mark('first_influence')
        if any(m.hired for m in ps.managers): mark('first_manager')
        if any(tt.unlocked and tt.unlock_cost > 0 for tt in ps.territories):
            mark('first_paid_district')
        # Click income/s (during active) vs passive IPS — crossover.
        click_rate = cps * ps.click_value
        if crossover > 1e8 and ps.income_per_second > click_rate and t > 5:
            crossover = t
        if first_prestige > 1e8 and prestige.can_prestige(ps):
            first_prestige = t

        for milestone_min in (5, 10, 15, 20, 30):
            sec = milestone_min * 60
            if sec - dt <= t < sec + dt:
                inf_at[milestone_min] = ps.prestige_tokens

        t += dt

    return {
        'marks': marks, 'inf_at': inf_at, 'crossover': crossover,
        'first_prestige': first_prestige, 'final_inf': ps.prestige_tokens,
        'final_ips': ps.income_per_second, 'final_buildings': sum(b.owned for b in ps.buildings),
    }


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--minutes", type=float, default=30.0)
    p.add_argument("--active", type=float, default=0.33, help="fraction of each minute actively played")
    p.add_argument("--cps", type=float, default=2.0, help="clicks/sec while active")
    p.add_argument("--no-territory", action="store_true", help="model a player who ignores territory early")
    args = p.parse_args()

    r = run(args.minutes, args.active, args.cps, do_territory=not args.no_territory)
    print("=" * 64)
    arch = "buildings-only" if args.no_territory else "territory-engaging"
    print(f"PACING [{arch}] — {args.minutes:.0f}min, {args.active*100:.0f}% active, {args.cps:.0f} click/s")
    print("=" * 64)
    print("Milestones:")
    for k, label in [('first_upgrade', 'first upgrade'), ('first_influence', 'first Influence'),
                     ('first_manager', 'first manager'), ('first_paid_district', 'first PAID district')]:
        print(f"  {label:22s}: {fmt_t(r['marks'].get(k, 1e9))}")
    print(f"  {'click->idle crossover':22s}: {fmt_t(r['crossover'])}")
    print(f"  {'first prestige':22s}: {fmt_t(r['first_prestige'])}")
    print("Influence (prestige_tokens) over time:")
    for m in (5, 10, 15, 20, 30):
        if m in r['inf_at']:
            print(f"  @ {m:2d}min: {r['inf_at'][m]} Influence")
    print(f"Final @ {args.minutes:.0f}min: {r['final_inf']} Influence, "
          f"{r['final_buildings']} buildings, IPS={r['final_ips']:.3g}")
    delete_save()
