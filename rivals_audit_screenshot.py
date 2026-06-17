"""Headless screenshot harness for Rivals audit."""
import os
os.environ["SDL_VIDEODRIVER"] = "dummy"
os.environ["SDL_AUDIODRIVER"] = "dummy"

import pygame
pygame.init()

import src.rivals as rivals_mod
import src.territory as terr_mod


def make_mock_state():
    class State:
        pass
    state = State()
    state.rivals = rivals_mod.make_rivals()
    state.territories = terr_mod.make_territories()
    state.prestige_tokens = 0
    state.influence = 0
    state.balance = 500_000.0
    state.heat = 15.0
    state._time = 0.0
    state._rival_outcome = None
    state._rival_outcome_timer = 0.0
    state.income_per_second = 100.0
    return state


fonts = {}
for size_name, pt in [("xs", 13), ("sm", 17), ("md", 21)]:
    fonts[size_name] = pygame.font.SysFont("consolas", pt)

resolutions = [(480, 480), (900, 720), (1280, 800), (1920, 1080)]

for w, h in resolutions:
    screen = pygame.Surface((w, h))
    screen.fill((10, 10, 20))
    # Simulate the panel_rect that states.py uses for the Rivals tab
    panel_x = int(w * 0.22)
    panel_y = 30
    panel_w = w - panel_x - 4
    panel_h = h - panel_y - 4
    panel_rect = pygame.Rect(panel_x, panel_y, panel_w, panel_h)
    state = make_mock_state()
    rivals_mod.draw_panel(screen, state, fonts, panel_rect)
    cards_avail = panel_h - 130 - 22  # minus log and header
    cards_fit = cards_avail // (182 + 8)
    fname = f"graphify-out/rivals_{w}x{h}.png"
    pygame.image.save(screen, fname)
    print(f"Saved {fname}  panel={panel_rect}  cards_avail_h={cards_avail}  cards_fit={cards_fit}")

pygame.quit()
