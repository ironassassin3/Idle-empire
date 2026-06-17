"""Phase 124 — city-first layout screenshot capture."""
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

OUT_DIR = os.path.join(os.path.dirname(__file__), "phase124_screenshots")
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
    ps._tab = kw.get('_tab', 'buildings')
    return ps


def _set_buildings(ps, counts):
    for b, n in zip(ps.buildings, counts):
        b.owned = n


def _shot(ps, name):
    screen.fill(theme.NOIR_INK)
    ps.draw(screen)
    path = os.path.join(OUT_DIR, name)
    pygame.image.save(screen, path)
    print(f"  saved: {path}")


print("Phase 124 city-first captures")
print(f"  scene rect: {ui._SCENE_RECT}  ({ui._SCENE_RECT.height / config.SCREEN_HEIGHT * 100:.1f}% height)")

# Early — sparse skyline, low heat
sm1 = StateManager()
ps1 = _state(sm1, balance=500, lifetime_earnings=400, prestige_tokens=0)
_set_buildings(ps1, [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
ps1.heat = 12.0
_shot(ps1, "01_early_city.png")

# Mid — growing district, moderate heat
sm2 = StateManager()
ps2 = _state(sm2, balance=85_000, lifetime_earnings=120_000, prestige_tokens=4)
_set_buildings(ps2, [8, 6, 4, 2, 1, 0, 0, 0, 0, 0, 0])
ps2.heat = 48.0
_shot(ps2, "02_mid_growth.png")

# Late — full skyline, high heat (smoke + police flash)
sm3 = StateManager()
ps3 = _state(sm3, balance=2_500_000, lifetime_earnings=18_000_000, prestige_tokens=22)
_set_buildings(ps3, [40, 35, 28, 22, 18, 12, 8, 6, 4, 2, 1])
ps3.heat = 72.0
_shot(ps3, "03_late_skyline_heat.png")

# Prestige locked — verify bottom stack fits
sm4 = StateManager()
ps4 = _state(sm4, balance=15_000, lifetime_earnings=8_000, prestige_tokens=0)
_set_buildings(ps4, [3, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
ps4.heat = 28.0
_shot(ps4, "04_prestige_locked_stack.png")

print("Done.")
