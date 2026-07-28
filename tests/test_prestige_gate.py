"""Next prestige gate is max(prev x GROWTH, IPS-scaled floor); ignores overshoot."""
import os
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
import pygame
pygame.init()
pygame.display.set_mode((320, 240))

import src.prestige as prestige
import src.prestige_tree as prestige_tree
from src.state_base import StateManager
from src.states import PlayingState


def _fresh_state():
    sm = StateManager()
    ps = PlayingState(sm)
    ps.on_enter()
    return ps


def test_next_gate_ignores_overshoot():
    ps = _fresh_state()
    # Second-cycle prestige (count>=1). Satisfy scaled rebuild gates:
    #   need = FIRST * (1 + 0.5 * prestige_count) → 1.5x at count=1
    ps._prestige_count = 1
    d_need = prestige.post_building_required(1, prestige.POST_PRESTIGE_DEALERS)
    r_need = prestige.post_building_required(1, prestige.POST_PRESTIGE_RACKETS)
    c_need = prestige.post_building_required(1, prestige.POST_PRESTIGE_CHOPS)
    ps.buildings[0].owned = d_need
    ps.buildings[1].owned = r_need
    ps.buildings[2].owned = c_need
    ps.prestige_branch = prestige_tree.KINGPIN
    ps.perks_purchased = ['kp_cashflow']
    ps._next_prestige_earnings = 100_000_000.0     # the gate just crossed
    ps._prestige_route_earnings = 900_000_000.0    # a 9x overshoot
    ps.lifetime_earnings = 2_000_000_000.0         # plenty for influence calc
    assert prestige.can_prestige(ps), "setup must satisfy the gate"

    ips_before = float(ps.income_per_second)
    prestige.PrestigeManager.execute(ps)

    expected = prestige.next_earnings_gate(
        100_000_000.0, ips_before, ps.prestige_tokens
    )
    punished = 900_000_000.0 * prestige.PRESTIGE_EARNINGS_GROWTH
    assert ps._next_prestige_earnings == expected, (
        f"gate should be {expected:.0f}, got {ps._next_prestige_earnings:.0f}")
    assert ps._next_prestige_earnings != punished


def test_post_building_scales():
    assert prestige.post_building_required(1, 25) == 38  # 1.5x
    assert prestige.post_building_required(2, 25) == 50  # 2.0x
