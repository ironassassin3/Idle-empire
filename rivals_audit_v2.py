"""Headless screenshot harness — uses game's real make_fonts() per resolution."""
import os
os.environ["SDL_VIDEODRIVER"] = "dummy"
os.environ["SDL_AUDIODRIVER"] = "dummy"

import pygame
pygame.init()

import src.rivals as rivals_mod
import src.territory as terr_mod
import src.theme as theme


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


resolutions = [(480, 480), (900, 720), (1280, 800), (1920, 1080)]

for w, h in resolutions:
    fonts = theme.make_fonts(h)   # real scaling formula
    xs_h  = fonts['xs'].get_height()
    sm_h  = fonts['sm'].get_height()

    screen = pygame.Surface((w, h))
    screen.fill((10, 10, 20))
    panel_x = int(w * 0.22)
    panel_y = 30
    panel_w = w - panel_x - 4
    panel_h = h - panel_y - 4
    panel_rect = pygame.Rect(panel_x, panel_y, panel_w, panel_h)
    state = make_mock_state()
    rivals_mod.draw_panel(screen, state, fonts, panel_rect)

    # Draw a red horizontal line at the button zone top (card_top + 148)
    # to show where buttons should be across every visible card
    row_y = panel_rect.y + 22
    for i in range(5):
        card_top = row_y + i * (182 + 8)
        btn_line = card_top + 148
        if btn_line < panel_rect.bottom - 130:
            pygame.draw.line(screen, (255, 0, 0), (panel_rect.x, btn_line),
                             (panel_rect.right, btn_line), 1)
        # Green line at expected content bottom
        cy = card_top + 10
        rows_h = [(sm_h, 2), (xs_h, 2), (xs_h, 4), (xs_h, 6), (xs_h, 6), (xs_h, 6)]
        for rh, rg in rows_h:
            cy += rh + rg
        if cy < panel_rect.bottom - 130:
            pygame.draw.line(screen, (0, 255, 0), (panel_rect.x, cy),
                             (panel_rect.right, cy), 1)

    cards_avail = panel_h - 130 - 22
    cards_fit = cards_avail // (182 + 8)
    btn_top = 148
    top_pad = 10
    cy_final = top_pad
    for rh, rg in [(sm_h, 2), (xs_h, 2), (xs_h, 4), (xs_h, 6), (xs_h, 6), (xs_h, 6)]:
        cy_final += rh + rg
    gap = btn_top - cy_final

    fname = f"graphify-out/rivals_real_{w}x{h}.png"
    pygame.image.save(screen, fname)
    print(f"{w}x{h}  xs_px={xs_h} sm_px={sm_h}  cards_fit={cards_fit}  "
          f"content_bottom={cy_final}  btn_top={btn_top}  gap={gap:+d}  "
          f"{'OVERLAP' if gap < 0 else ('WARNING' if gap < 10 else 'SAFE')}")

pygame.quit()
