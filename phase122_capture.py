"""Phase 122 — command center header screenshot capture."""
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
import src.managers as mgr_mod
import src.operations as ops_mod

screen = pygame.display.set_mode((config.SCREEN_WIDTH, config.SCREEN_HEIGHT))
pygame.display.set_caption("Idle Empire")
ui.reinit_layout(config.SCREEN_WIDTH, config.SCREEN_HEIGHT)

from src.state_base import StateManager
from src.states import PlayingState
from src.save_load import load_game, apply_save_data

OUT_DIR = os.path.join(os.path.dirname(__file__), "phase122_screenshots")
os.makedirs(OUT_DIR, exist_ok=True)


def _base_state(sm, **kw):
    raw = load_game() or {}
    data = copy.deepcopy(raw)
    data['save_timestamp'] = _time.time()
    data['last_login_date'] = _time.strftime('%Y-%m-%d')
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
    return ps


def _hire(state, name: str) -> None:
    for m in state.managers:
        if m.name == name:
            m.hired = True
            return


def _shot(state, name: str) -> str:
    screen.fill(theme.NOIR_INK)
    state.draw(screen)
    path = os.path.join(OUT_DIR, name)
    pygame.image.save(screen, path)
    print(f"  saved: {path}")
    return path


def _crop_header(state, name: str) -> str:
    """Header-only crop for report comparison."""
    full = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT))
    state.draw(full)
    crop = full.subsurface(pygame.Rect(0, 0, config.SCREEN_WIDTH, ui.HEADER_H)).copy()
    path = os.path.join(OUT_DIR, name)
    pygame.image.save(crop, path)
    print(f"  saved: {path}")
    return path


print("Phase 122 header captures")

# Early — fresh economy, one goal visible
sm1 = StateManager()
ps1 = _base_state(sm1, balance=4200, lifetime_earnings=3800, prestige_tokens=0)
ps1.heat = 18.0
_shot(ps1, "01_early_full.png")
_crop_header(ps1, "01_early_header.png")

# Mid — automation crew hired, moderate heat
sm2 = StateManager()
ps2 = _base_state(sm2, balance=850_000, lifetime_earnings=2_400_000, prestige_tokens=8)
ps2.heat = 44.0
for n in ("Lucky Sal", "The Mechanic", "The Accountant", "The Collector"):
    _hire(ps2, n)
_shot(ps2, "02_mid_automation_full.png")
_crop_header(ps2, "02_mid_automation_header.png")

# Late — exec automation + op timer + high heat
sm3 = StateManager()
ps3 = _base_state(sm3, balance=12_000_000, lifetime_earnings=45_000_000, prestige_tokens=28)
ps3.heat = 67.0
for n in ("Lucky Sal", "The Mechanic", "The Accountant", "The Promoter",
          "The Smuggler", "The Collector", "Clean Carl"):
    _hire(ps3, n)
if ps3.operations:
    op = ps3.operations[0]
    op.active = True
    op.collected = False
    op.start_time = _time.time() - op.duration * 0.55
    op.reward = 500_000
_shot(ps3, "03_late_ops_heat_full.png")
_crop_header(ps3, "03_late_ops_heat_header.png")

print("Done.")
