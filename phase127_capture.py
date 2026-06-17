"""Phase 127 — noir theme pass screenshot capture."""
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
import main as menu_mod

OUT_DIR = os.path.join(os.path.dirname(__file__), "phase127_screenshots")
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


def _shot(surface, name):
    path = os.path.join(OUT_DIR, name)
    pygame.image.save(surface, path)
    print(f"  saved: {path}")


print("Phase 127 noir theme captures")

# Title screen
sm0 = StateManager()
menu = menu_mod.MenuState(sm0)
menu._fonts = theme.make_fonts(config.SCREEN_HEIGHT)
menu._time = 1.2
screen.fill(theme.NOIR_INK)
menu.draw(screen)
_shot(screen, "01_title_noir.png")

# Buildings — front-business cards
sm1 = StateManager()
ps1 = _state(sm1, balance=250_000, lifetime_earnings=180_000, prestige_tokens=6)
ps1.heat = 38.0
for i, n in enumerate([12, 8, 4, 2, 1, 0, 0, 0, 0, 0, 0]):
    ps1.buildings[i].owned = n
screen.fill(theme.NOIR_INK)
ps1.draw(screen)
_shot(screen, "02_buildings_dossier.png")

# Managers roster
sm2 = StateManager()
ps2 = _state(sm2, balance=500_000, lifetime_earnings=400_000, prestige_tokens=10,
             _tab='managers')
ps2.heat = 45.0
for n in ("Lucky Sal", "The Mechanic", "The Accountant"):
    for m in ps2.managers:
        if m.name == n:
            m.hired = True
screen.fill(theme.NOIR_INK)
ps2.draw(screen)
_shot(screen, "03_managers_roster.png")

# Late game city + atmosphere
sm3 = StateManager()
ps3 = _state(sm3, balance=3_000_000, lifetime_earnings=25_000_000, prestige_tokens=24)
ps3.heat = 68.0
for b in ps3.buildings:
    b.owned = max(b.owned, 15)
screen.fill(theme.NOIR_INK)
ps3.draw(screen)
_shot(screen, "04_late_empire_atmosphere.png")

print("Done.")
