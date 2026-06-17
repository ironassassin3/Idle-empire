"""Phase 123 — employee roster screenshot capture."""
import copy
import os
import time as _time

os.environ.setdefault("SDL_VIDEODRIVER", "windib")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
import pygame
pygame.init()

import config
import src.theme as theme
import src.ui as ui

screen = pygame.display.set_mode((config.SCREEN_WIDTH, config.SCREEN_HEIGHT))
ui.reinit_layout(config.SCREEN_WIDTH, config.SCREEN_HEIGHT)

from src.state_base import StateManager
from src.states import PlayingState
from src.save_load import load_game, apply_save_data
import src.managers as mgr_mod

OUT_DIR = os.path.join(os.path.dirname(__file__), "phase123_screenshots")
os.makedirs(OUT_DIR, exist_ok=True)


def _state(sm, **kw):
    raw = load_game() or {}
    data = copy.deepcopy(raw)
    data['save_timestamp'] = _time.time()
    for k, v in kw.items():
        data[k] = v
    ps = PlayingState(sm)
    apply_save_data(ps, data)
    ps._show_offline_overlay = False
    ps._show_daily_overlay = False
    ps._milestone_timer = 0.0
    ps._milestone_queue.clear()
    ps._toasts.clear()
    ps._fonts = theme.make_fonts(config.SCREEN_HEIGHT)
    ps._tab = 'managers'
    ps._mgr_late_collapsed = kw.get('_mgr_late_collapsed', True)
    return ps


def _hire(ps, name):
    for m in ps.managers:
        if m.name == name:
            m.hired = True


def _shot(ps, name):
    screen.fill(theme.NOIR_INK)
    ps.draw(screen)
    path = os.path.join(OUT_DIR, name)
    pygame.image.save(screen, path)
    print(f"  saved: {path}")


print("Phase 123 roster captures")

# Early — mostly locked, one available
sm1 = StateManager()
ps1 = _state(sm1, balance=30_000, lifetime_earnings=28_000, prestige_tokens=0)
ps1.heat = 42.0
_shot(ps1, "01_early_roster.png")

# Mid — active crew + available hire
sm2 = StateManager()
ps2 = _state(sm2, balance=120_000, lifetime_earnings=250_000, prestige_tokens=6)
ps2.heat = 38.0
_hire(ps2, "Lucky Sal")
_hire(ps2, "The Mechanic")
_hire(ps2, "The Collector")
_shot(ps2, "02_mid_active_roster.png")

# Late — exec collapsed
sm3 = StateManager()
ps3 = _state(sm3, balance=5_000_000, lifetime_earnings=40_000_000, prestige_tokens=28,
             _mgr_late_collapsed=True)
ps3.heat = 55.0
for n in ("Lucky Sal", "The Mechanic", "The Accountant", "The Promoter", "Clean Carl"):
    _hire(ps3, n)
_shot(ps3, "03_late_exec_collapsed.png")

# Late — exec expanded
sm4 = StateManager()
ps4 = _state(sm4, balance=5_000_000, lifetime_earnings=40_000_000, prestige_tokens=28,
             _mgr_late_collapsed=False)
ps4.heat = 55.0
for n in ("Lucky Sal", "The Mechanic", "The Accountant", "The Promoter"):
    _hire(ps4, n)
_shot(ps4, "04_late_exec_expanded.png")

print("Done.")
