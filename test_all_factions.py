"""Render all 5 faction name + symbol combinations as they appear in the rival card."""
import os
os.environ["SDL_AUDIODRIVER"] = "dummy"
import pygame
pygame.init()

import src.theme as theme
import src.rivals as rivals_mod

W, H = 600, 480
screen = pygame.display.set_mode((W, H))
screen.fill(theme.BG_DARK)
fonts = __import__('src.theme', fromlist=['make_fonts']).make_fonts(720)
f_sm = fonts['sm']
f_xs = fonts['xs']
f_md = fonts['md']

GOLD  = (255, 210, 80)
WHITE = (235, 235, 245)

rivals = rivals_mod.make_rivals()

# Title
screen.blit(f_md.render("PHASE 64 — All Faction Symbols", True, GOLD), (10, 8))
screen.blit(f_xs.render("as rendered by fonts['sm'] in rival card Row 1", True, theme.TEXT_MUTED), (10, 38))

y = 68
for r in rivals:
    symbol   = getattr(r, 'symbol', '')
    name     = r.name
    color    = r.color

    # Faction card bg strip
    card = pygame.Rect(10, y, W - 20, 56)
    bg = pygame.Surface((card.width, card.height), pygame.SRCALPHA)
    pygame.draw.rect(bg, (*color, 25), bg.get_rect(), border_radius=8)
    pygame.draw.rect(bg, (*color, 80), bg.get_rect(), border_radius=8, width=1)
    screen.blit(bg, card.topleft)
    pygame.draw.rect(screen, color, pygame.Rect(card.x, card.y + 6, 3, card.height - 12))

    # Exact same render as rivals.py line 939
    display_name = f"{symbol} {name}" if symbol else name
    ns = f_sm.render(display_name, True, WHITE)
    screen.blit(ns, (card.x + 14, y + 8))

    # Show the symbol alone in a separate large render for clarity
    sym_big = f_md.render(symbol, True, color)
    screen.blit(sym_big, (card.x + 14, y + 28))

    # Trait + symbol codepoint
    info = f_xs.render(f"trait: {r.trait}  |  symbol: U+{ord(symbol):04X} = '{symbol}'", True, theme.TEXT_MUTED)
    screen.blit(info, (card.x + 60, y + 32))

    y += 72

# Check mark and other UI replacements at the bottom
y += 8
screen.blit(f_xs.render("UI symbols:", True, theme.TEXT_MUTED), (10, y)); y += 18
ui_tests = [
    ("* PRESTIGE",          fonts['sm'], (220, 180, 255), "prestige button"),
    ("* PRESTIGE  — LOCKED",fonts['xs'], (180, 130, 220), "locked"),
    ("* PRESTIGE?",         fonts['lg'], GOLD,            "confirm"),
    ("v  mission complete", fonts['xs'], theme.GREEN,     "check (territory)"),
    ("○  mission pending",  fonts['xs'], theme.TEXT_MUTED,"locked circle"),
    ("#  settings",         fonts['xs'], theme.TEXT_MUTED,"gear/config tab"),
]
for text, f, col, label in ui_tests:
    if y > H - 20:
        break
    s = f.render(text[:38], True, col)
    lbl = f_xs.render(label, True, (80, 90, 110))
    screen.blit(s, (10, y))
    screen.blit(lbl, (380, y + 2))
    y += f.get_height() + 3

pygame.display.flip()
pygame.image.save(screen, "all_factions.png")
print("Saved all_factions.png")
pygame.quit()
