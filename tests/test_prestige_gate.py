"""The next prestige gate is previous_gate x GROWTH, independent of overshoot."""
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
    # Second-cycle prestige (count>=1). Satisfy the real rebuild gates so the
    # test exercises the gate FORMULA, not the requirement machinery:
    #   - rebuilt dealers/rackets/chops (POST_PRESTIGE_* counts)
    #   - a committed branch with >=1 purchased perk
    ps._prestige_count = 1
    ps.buildings[0].owned = 18   # dealers  (POST_PRESTIGE_DEALERS)
    ps.buildings[1].owned = 7    # rackets  (POST_PRESTIGE_RACKETS)
    ps.buildings[2].owned = 3    # chops    (POST_PRESTIGE_CHOPS)
    ps.prestige_branch = prestige_tree.KINGPIN
    ps.perks_purchased = ['kp_cashflow']
    ps._next_prestige_earnings = 100_000_000.0     # the gate just crossed
    ps._prestige_route_earnings = 900_000_000.0    # a 9x overshoot
    ps.lifetime_earnings = 2_000_000_000.0         # plenty for influence calc
    assert prestige.can_prestige(ps), "setup must satisfy the gate"

    prestige.PrestigeManager.execute(ps)

    growth = prestige.PRESTIGE_EARNINGS_GROWTH
    expected = 100_000_000.0 * growth              # previous_gate x GROWTH
    punished = 900_000_000.0 * growth              # the old route x GROWTH bug
    assert ps._next_prestige_earnings == expected, (
        f"gate should be {expected:.0f} (prev x {growth}), "
        f"got {ps._next_prestige_earnings:.0f}")
    assert ps._next_prestige_earnings != punished
