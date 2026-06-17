"""Phase 70 runtime validation screenshot capture v2."""
import os
import sys
import time as _time

os.environ.setdefault("SDL_VIDEODRIVER", "windib")
import pygame
pygame.init()

import config
screen = pygame.display.set_mode((config.SCREEN_WIDTH, config.SCREEN_HEIGHT))
pygame.display.set_caption("Phase 70 v2")

import src.ui as ui
ui.reinit_layout(config.SCREEN_WIDTH, config.SCREEN_HEIGHT)

from src.state_base import StateManager
from src.states import PlayingState
from src.save_load import load_game, apply_save_data
import src.prestige as prestige_mod
import src.theme as theme

OUT = "phase70_"


def _clean_state(sm, earnings, balance, tokens=14):
    import copy as _copy
    raw = load_game() or {}
    data = _copy.deepcopy(raw)
    data['save_timestamp']   = _time.time()
    data['last_login_date']  = _time.strftime('%Y-%m-%d')
    data['lifetime_earnings'] = float(earnings)
    data['balance']           = float(balance)
    data['prestige_tokens']   = int(tokens)
    data['influence']         = int(tokens)
    data['city_control_milestones'] = ['25pct', '50pct', '75pct', '100pct']
    shown = list(data.get('shown_milestones', []))
    for m in ['money_1000', 'money_10000', 'money_100000', 'money_1000000', 'money_20000000']:
        if m not in shown:
            shown.append(m)
    data['shown_milestones'] = shown
    ps = PlayingState(sm)
    apply_save_data(ps, data)
    ps._show_offline_overlay = False
    ps._show_daily_overlay   = False
    ps._milestone_timer      = 0.0
    ps._milestone_queue.clear()
    ps._toasts.clear()
    return ps


def tick(state, seconds, step=0.016):
    r = seconds
    while r > 0:
        dt = min(step, r)
        state.update(dt)
        r -= dt
    state._milestone_timer = 0.0
    state._milestone_queue.clear()


def shot(label):
    pygame.display.flip()
    path = f"{OUT}{label}.png"
    pygame.image.save(screen, path)
    print(f"  saved: {path}")


def draw(state):
    screen.fill((0, 0, 0))
    state.draw(screen)


# SCENE 1a — Prestige button LOCKED (87% earnings bar)
print("SCENE 1a — locked prestige button")
sm = StateManager()
ps = _clean_state(sm, earnings=17_500_000, balance=2_800_000, tokens=14)
tick(ps, 1.0)
draw(ps)
shot("01_approach")

# SCENE 1b — 80%/90% near-prestige notifications in stack
print("SCENE 1b — 80/90 notifications")
sm1b = StateManager()
ps1b = _clean_state(sm1b, earnings=18_500_000, balance=3_200_000, tokens=14)
ui.push_notification("Prestige approaching — 80% there!", theme.PRESTIGE_LABEL)
ui.push_notification("Almost ready to PRESTIGE! — 90%", theme.PRESTIGE_LABEL)
tick(ps1b, 0.5)
draw(ps1b)
shot("01b_notifications")

# SCENE 2 — Prestige button UNLOCKED
print("SCENE 2 — unlocked prestige button")
sm2 = StateManager()
ps2 = _clean_state(sm2, earnings=21_000_000, balance=5_500_000, tokens=14)
tick(ps2, 1.0)
draw(ps2)
shot("02_prestige_ready")

# SCENE 3a — Prestige tree, LOCKED strip visible
print("SCENE 3a — prestige tree locked")
from src.prestige_tree import PrestigeTreeState
sm3a = StateManager()
ps3a = _clean_state(sm3a, earnings=17_500_000, balance=2_800_000, tokens=14)
tick(ps3a, 0.5)
tree_locked = PrestigeTreeState(sm3a, ps3a)
sm3a.push(tree_locked)
screen.fill((0, 0, 0))
tree_locked.draw(screen)
shot("03_tree_locked")

# SCENE 3b — Prestige tree, PRESTIGE button lit
print("SCENE 3b — prestige tree available")
sm3b = StateManager()
ps3b = _clean_state(sm3b, earnings=21_000_000, balance=5_500_000, tokens=14)
tick(ps3b, 0.5)
tree_ready = PrestigeTreeState(sm3b, ps3b)
sm3b.push(tree_ready)
screen.fill((0, 0, 0))
tree_ready.draw(screen)
shot("03b_tree_ready")

# SCENE 4 — Confirmation dialog
print("SCENE 4 — confirmation dialog")
tree_ready._confirm = True
screen.fill((0, 0, 0))
tree_ready.draw(screen)
shot("04_confirm")

# SCENE 5 — Post-prestige milestone overlay
print("SCENE 5 — first prestige overlay")
tree_ready._do_prestige()
ps3b._show_offline_overlay = False
ps3b._show_daily_overlay   = False
tick(ps3b, 0.1)
draw(ps3b)
shot("05_first_prestige")

# SCENE 6 — Early rebuild, overlay dismissed
print("SCENE 6 — rebuild screen")
ps3b._milestone_timer = 0.0
ps3b._milestone_queue.clear()
tick(ps3b, 5.0)
draw(ps3b)
shot("06_rebuild")

pygame.quit()
print("Done.")
