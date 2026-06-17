"""Render only the rival cards using the actual rivals.draw_panel function."""
import os
os.environ["SDL_AUDIODRIVER"] = "dummy"
import pygame
pygame.init()

import src.theme as theme
import config
import src.rivals as rivals_mod
import src.ui as ui

W, H = config.SCREEN_WIDTH, config.SCREEN_HEIGHT
screen = pygame.display.set_mode((W, H))
screen.fill(theme.BG_DARK)

fonts = theme.make_fonts(H)
ui.reinit_layout(W, H)

# Minimal state — only what rivals.draw_panel touches
class MinState:
    rivals = rivals_mod.make_rivals()
    heat   = 22.0
    _time  = 0.0
    _rival_outcome = None
    _rival_outcome_timer = 0.0
    prestige_tokens = 0

state = MinState()

# Give first rival "at_war" status to show that rendering path too
state.rivals[0].at_war = True
state.rivals[1].turf   = 5
state.rivals[1].wealth = 50_000_000
state.rivals[2].status = 'Weakened'
# Leave the last one with default values

# Draw background panel
panel_rect = pygame.Rect(0, 0, W, H)
pygame.draw.rect(screen, theme.BG_PANEL, panel_rect)

# Header
title = fonts['md'].render("PHASE 64 — Rival Cards (symbol rendering)", True, theme.TEXT_GOLD)
screen.blit(title, (10, 6))

# Draw rival cards in a column
card_panel = pygame.Rect(10, 40, W - 20, H - 50)
rivals_mod.draw_panel(screen, state, fonts, card_panel)

pygame.display.flip()
pygame.image.save(screen, "rivals_cards.png")
print("Saved rivals_cards.png")
pygame.quit()
