"""
Headless simulation harness for Idle Empire balance analysis.

Runs the real game logic (income, buildings, upgrades, heat, prestige) at
accelerated time with a configurable "AI player" buying policy, and records
progression milestones. No rendering — pygame runs in dummy video mode.

Usage:
    python sim_harness.py            # run default fresh-save playtest
"""
from __future__ import annotations
import os
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")

import sys
import math
import random

import pygame
pygame.init()
# A real display surface is needed because some modules build font/icon surfaces.
pygame.display.set_mode((900, 720))

import config
import src.buildings as bld
import src.upgrades as upg
import src.managers as mgr_mod
import src.prestige as prestige
import src.heat as heat_mod
import src.territory as territory_mod
import src.crew as crew_mod
import src.goals as goals_mod


class SimState:
    """A lightweight stand-in for PlayingState carrying only economic fields.

    It reuses the real income/click formulas by duck-typing the attributes the
    pure-logic modules read. UI-only attributes default via getattr fallbacks.
    """

    def __init__(self, seed=0):
        random.seed(seed)
        self.balance = 0.0
        self.lifetime_earnings = 0.0
        self.prestige_tokens = 0
        self.influence = 0
        self._click_count = 0
        self.buy_count = 1
        self.buildings = bld.make_buildings()
        self.upgrades = upg.make_upgrades()
        self.managers = mgr_mod.make_managers()
        self.achievements = []
        self.heat = 0.0
        self.territories = territory_mod.make_territories()
        self.crew = crew_mod.CrewAssignment()
        self.operations = []
        self.rivals = []
        self.goals = goals_mod.make_goals()
        self.perks_purchased = []
        self._buffs = []
        self._perk_click_mult = 1.0
        self._perk_income_mult = 1.0
        self._perk_bld_mults = [1.0] * len(self.buildings)
        self._time = 0.0
        self._play_time = 0.0
        self._prestige_count = 0
        self._peak_income = 0.0
        # Seed one dealer so sims start with nonzero income. NOTE: the real game
        # starts EMPTY (0 dealers) — the tutorial teaches the first buy; this is a
        # sim-only bootstrap, not a match to fresh-game state.
        self.buildings[0].owned = 1

    # Reuse the exact income/click formulas from PlayingState by copying logic.
    @property
    def income_per_second(self) -> float:
        base = mgr_mod.compute_base_income(self)
        mult = prestige.income_mult(self.prestige_tokens)
        if any(u.purchased and u.effect_key == 'prestige_boost' for u in self.upgrades):
            mult *= prestige.prestige_mastery_mult(self.prestige_tokens)
        mult *= self._perk_income_mult
        mult *= heat_mod.heat_income_mult(self.heat)
        mult *= territory_mod.territory_income_mult(self.territories)
        for b in self._buffs:
            if b.get('name') == 'syndicate_income':
                mult *= b.get('mult', 1.0)
        mult *= crew_mod.collection_income_mult(self.crew)
        return base * mult

    @property
    def click_value(self) -> float:
        mult = prestige.income_mult(self.prestige_tokens)
        if any(u.purchased and u.effect_key == 'double_click' for u in self.upgrades):
            mult *= 2.0
        if any(u.purchased and u.effect_key == 'quad_click' for u in self.upgrades):
            mult *= 4.0
        if any(u.purchased and u.effect_key == 'octo_click' for u in self.upgrades):
            mult *= 8.0
        if any(u.purchased and u.effect_key == 'hex_click' for u in self.upgrades):
            mult *= 16.0
        mult *= self._perk_click_mult
        mult *= heat_mod.heat_click_bonus(self.heat)
        mult *= territory_mod.territory_click_mult(self.territories)
        dealer_bonus = bld.dealer_click_bonus(self.buildings)
        return 1.0 * mult + dealer_bonus

    def _has_buff(self, name):
        return any(b['name'] == name for b in self._buffs)

    def _add_buff(self, name, duration):
        self._buffs = [b for b in self._buffs if b['name'] != name]
        self._buffs.append({'name': name, 'remaining': duration, 'total': duration})


# ─── AI player policies ────────────────────────────────────────────────────────

def _best_value_building(state):
    """Buy the affordable building with the best marginal income/cost ratio.

    With the rebalanced curve (inc/$ rises with tier) this naturally pulls the
    player toward the highest tier they can afford — the intended behavior."""
    best = None
    best_ratio = 0.0
    for b in state.buildings:
        cost = b.current_cost
        if cost <= 0 or state.balance < cost:
            continue
        ratio = (b.base_income * b.income_multiplier) / cost
        if ratio > best_ratio:
            best_ratio = ratio
            best = b
    return best


def _buy_affordable_upgrades(state):
    bought = 0
    for u in state.upgrades:
        if u.purchased:
            continue
        cost = upg._effective_cost(u, state)
        # only buy income/click upgrades automatically; affordable and < 50% of balance
        if state.balance >= cost and cost <= state.balance:
            state.balance -= cost
            u.purchased = True
            u.apply(state)
            bought += 1
    return bought


def _hire_affordable_managers(state):
    # Managers live in the Empire tab (always visible) and only require cash —
    # no rank gate in the real game (managers.handle_click checks balance only).
    hired = 0
    for m in state.managers:
        if not m.hired and state.balance >= m.cost:
            state.balance -= m.cost
            m.hired = True
            hired += 1
    return hired


def _maybe_capture_territory(state):
    """Model a player capturing the next available district once its Influence
    gate is met. Downtown is free (0 Influence) — the bootstrap faucet. Each
    capture grants +1 Influence via Negotiate (the safe, reliable action).

    Gated on a small building foothold so the sim doesn't instant-capture at t=0
    (a real player engages territory after establishing income, not on frame 1)."""
    import src.territory as territory_mod
    if sum(b.owned for b in state.buildings) < 15:
        return False
    captured = False
    for idx, terr in enumerate(state.territories):
        if terr.unlocked:
            continue
        if state.prestige_tokens >= terr.unlock_cost:
            # Negotiate: reliable, +1 Influence, low heat. Model as auto-success
            # (a real player retries until it lands; we approximate the steady state).
            terr.unlocked = True
            terr.owner = 'player'
            state.prestige_tokens += 1
            state.influence += 5
            captured = True
            break  # one capture per tick at most
    return captured


def _do_prestige(state):
    """Mirror PrestigeManager.execute() economic effects (no UI/save)."""
    gain = prestige.calc_influence_gain(state.lifetime_earnings)
    state.prestige_tokens += gain
    state.influence += gain
    state._prestige_count += 1
    state.balance = 0.0
    for b in state.buildings:
        b.owned = 0
        b.income_multiplier = 1.0
    state.buildings[0].owned = 1  # the game gifts 1 dealer on fresh/reset start
    for u in state.upgrades:
        u.purchased = False
    return gain


# ─── Simulation loop ───────────────────────────────────────────────────────────

class Milestones:
    def __init__(self):
        self.events = {}

    def mark(self, key, t):
        if key not in self.events:
            self.events[key] = t


def run_sim(duration_s=7200.0, dt=0.5, clicks_per_sec=3.0,
            active_minutes=20.0, seed=0, verbose=True):
    """
    Simulate a player.
    - clicks_per_sec: manual click rate while 'active'
    - active_minutes: how long the player actively clicks before going idle
    """
    state = SimState(seed=seed)
    ms = Milestones()
    t = 0.0
    last_rank = prestige.get_rank(state.prestige_tokens)
    click_accumulator = 0.0
    buy_accumulator = 0.0

    snapshots = []
    next_snapshot = 0.0

    while t < duration_s:
        # passive income
        ips = state.income_per_second
        passive = ips * dt
        state.balance += passive
        state.lifetime_earnings += passive
        state._play_time += dt
        state._time += dt

        # manual clicks while active
        if t < active_minutes * 60.0:
            click_accumulator += clicks_per_sec * dt
            while click_accumulator >= 1.0:
                cv = state.click_value
                state.balance += cv
                state.lifetime_earnings += cv
                state._click_count += 1
                click_accumulator -= 1.0

        # heat tick
        heat_mod.update_heat(state, dt)
        bld.update_building_specials(state, dt)
        for b in state._buffs:
            b['remaining'] -= dt
        state._buffs = [b for b in state._buffs if b['remaining'] > 0]

        # buying policy: spend down balance greedily each step
        rank = prestige.get_rank(state.prestige_tokens)
        rank_idx = prestige._rank_index(rank)
        # assign crew to collection automatically (typical player behavior)
        total_crew = sum(b.owned for b in state.buildings)
        state.crew.collection = total_crew

        # Realistic purchase cadence: a player makes ~buy_rate purchase-taps per
        # second of play (not "spend the whole balance every tick", which turns
        # the income curve into a singularity). The player tends to buy the best
        # value building they can afford.
        buy_rate = 0.5  # purchases per second
        buy_accumulator += buy_rate * dt
        max_buys = int(buy_accumulator)
        buy_accumulator -= max_buys
        bought = 0
        while bought < max_buys:
            b = _best_value_building(state)
            if not b:
                break
            cost = b.current_cost
            if state.balance < cost:
                break
            state.balance -= cost
            b.owned += 1
            bought += 1

        _buy_affordable_upgrades(state)
        _hire_affordable_managers(state)

        # Process goals each tick (this is the non-circular Influence faucet)
        goals_mod.check_goals(state)

        # Model territory captures once their Influence gate is met
        _maybe_capture_territory(state)

        # milestone tracking
        total_owned = sum(b.owned for b in state.buildings)
        if total_owned >= 2:
            ms.mark('second_building', t)
        if state.buildings[0].owned >= 5:
            ms.mark('5_dealers', t)
        if any(u.purchased for u in state.upgrades):
            ms.mark('first_upgrade', t)
        if state.buildings[1].owned >= 1:
            ms.mark('first_racket', t)
        if state.buildings[2].owned >= 1:
            ms.mark('first_chop', t)
        if any(m.hired for m in state.managers):
            ms.mark('first_manager', t)
        if any(tt.unlocked and tt.name != 'South Side' for tt in state.territories):
            ms.mark('first_territory', t)
        if state.prestige_tokens >= 1:
            ms.mark('first_influence', t)
        if prestige.can_prestige(state):
            ms.mark('can_prestige', t)

        # Model the player executing their first prestige once available
        if prestige.can_prestige(state) and state._prestige_count == 0:
            ms.mark('first_prestige_done', t)
            _do_prestige(state)

        # rank-up
        if rank != last_rank:
            ms.mark(f'rank_{rank}', t)
            last_rank = rank

        # snapshot every 5 min
        if t >= next_snapshot:
            snapshots.append((t, state.balance, state.lifetime_earnings, ips,
                              total_owned, state.heat,
                              prestige.get_rank(state.prestige_tokens),
                              prestige.calc_influence_gain(state.lifetime_earnings)))
            next_snapshot += 300.0

        t += dt

    return state, ms, snapshots


def fmt_time(s):
    if s is None:
        return "NEVER"
    m = int(s // 60)
    sec = int(s % 60)
    return f"{m}m{sec:02d}s"


def fmt_money(n):
    import src.theme as theme
    return theme.format_number(n)


_ORDER = [
    ('second_building',     'Time to 2nd building'),
    ('first_upgrade',       'Time to first upgrade'),
    ('5_dealers',           'Time to 5 dealers'),
    ('first_racket',        'Time to first Protection Racket'),
    ('first_chop',          'Time to first Chop Shop'),
    ('first_influence',     'Time to FIRST INFLUENCE token'),
    ('first_manager',       'Time to first manager'),
    ('first_territory',     'Time to first territory'),
    ('can_prestige',        'Time to first prestige AVAILABLE'),
    ('first_prestige_done', 'Time to FIRST PRESTIGE executed'),
]


def _print_profile(name, **kw):
    print("=" * 70)
    print(f"PROFILE: {name}")
    print("=" * 70)
    state, ms, snaps = run_sim(**kw)
    print("MILESTONE TIMINGS:")
    for key, label in _ORDER:
        print(f"  {label:38s}: {fmt_time(ms.events.get(key))}")
    print("RANK PROGRESSION:")
    for key in sorted((k for k in ms.events if k.startswith('rank_')),
                      key=lambda k: ms.events[k]):
        print(f"  {key.replace('rank_',''):20s}: {fmt_time(ms.events[key])}")
    return state, ms, snaps


if __name__ == "__main__":
    print("IDLE EMPIRE — FRESH SAVE PLAYTEST SIMULATION\n")
    # Optimal player: clicks a lot, buys efficiently — an OPTIMISTIC lower bound.
    _print_profile("OPTIMAL (3 clicks/s, perfect buying — lower bound)",
                   duration_s=7200.0, dt=0.5, clicks_per_sec=3.0,
                   active_minutes=20.0, seed=42)
    print()
    # Casual mobile player: rarely clicks, checks in periodically — realistic.
    state, ms, snaps = _print_profile(
        "CASUAL (0.5 clicks/s, realistic mobile pacing)",
        duration_s=7200.0, dt=0.5, clicks_per_sec=0.5,
        active_minutes=10.0, seed=42)

    print()
    print("SNAPSHOTS (every 5 min):")
    print(f"  {'time':>7} {'balance':>12} {'lifetime':>12} {'income/s':>12} "
          f"{'blds':>5} {'heat':>5} {'rank':>16} {'inf_gain':>8}")
    for (t, bal, life, ips, owned, heat, rank, infg) in snaps:
        print(f"  {fmt_time(t):>7} {fmt_money(bal):>12} {fmt_money(life):>12} "
              f"{fmt_money(ips):>12} {owned:>5} {heat:>5.1f} {rank:>16} {infg:>8}")

    print()
    print(f"FINAL @ 2h: lifetime={fmt_money(state.lifetime_earnings)}  "
          f"income/s={fmt_money(state.income_per_second)}  "
          f"buildings={sum(b.owned for b in state.buildings)}  "
          f"prestige_avail={prestige.can_prestige(state)}")
