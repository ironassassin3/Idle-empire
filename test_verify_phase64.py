"""Phase 64 verification — render the new faction symbols and UI symbols, save PNG."""
import os
os.environ["SDL_AUDIODRIVER"] = "dummy"
import pygame
pygame.init()

screen = pygame.display.set_mode((900, 560))
screen.fill((20, 22, 35))

import src.theme as theme
fonts = theme.make_fonts(720)
f_xs = fonts['xs']
f_sm = fonts['sm']
f_md = fonts['md']
f_lg = fonts['lg']

GOLD  = (255, 210, 80)
RED   = (255, 80, 80)
GREEN = (80, 220, 120)
WHITE = (235, 235, 245)
MUTED = (130, 135, 160)
BG    = (20, 22, 35)

# Header
screen.blit(f_sm.render("PHASE 64 -- Verification: New Symbol Rendering", True, GOLD), (10, 6))

y = 38

# ─── FACTION CARDS ────────────────────────────────────────────────────────────
screen.blit(f_xs.render("RIVAL FACTION SYMBOLS:", True, (180, 180, 180)), (10, y)); y += 22

factions = [
    ("♦", "Crimson Kings",  (200, 80, 80),   "unchanged"),
    ("◊", "Silver Hand",    (80, 140, 210),   "was ❖"),
    ("#", "Iron Union",     (155, 118, 48),   "was ⚙"),
    ("@", "The Network",    (155, 55, 175),   "was ◎"),
    ("~", "Blackwater Mob", (28, 105, 135),   "was ⚓"),
    ("●", "Unknown Rival",  (130, 130, 160),  "default was ◆"),
]

for sym, name, col, note in factions:
    card_r = pygame.Rect(10, y, 420, 34)
    pygame.draw.rect(screen, (30, 33, 48), card_r, border_radius=6)
    pygame.draw.rect(screen, (*col, 100), card_r, border_radius=6, width=1)
    sym_sm = f_sm.render(sym, True, col)
    sym_xs = f_xs.render(sym, True, col)
    name_s = f_sm.render(f"{sym} {name}", True, WHITE)
    note_s = f_xs.render(note, True, MUTED)
    screen.blit(sym_sm, (card_r.x + 8, card_r.y + 5))
    screen.blit(name_s, (card_r.x + 28, card_r.y + 6))
    screen.blit(note_s, (card_r.x + 330, card_r.y + 10))
    y += 40

y += 10

# ─── UI SYMBOLS ───────────────────────────────────────────────────────────────
screen.blit(f_xs.render("UI SYMBOLS:", True, (180, 180, 180)), (10, y)); y += 22

ui_syms = [
    (f_md, "*",             GOLD,             "Achievement star (was ★ md)"),
    (f_sm, "* PRESTIGE",    (220, 180, 255),  "Prestige button (was ✦ PRESTIGE)"),
    (f_xs, "* PRESTIGE  —  LOCKED", (180, 130, 220), "Prestige locked (was ✦)"),
    (f_lg, "* PRESTIGE?",   GOLD,             "Prestige confirm (was ✦)"),
    (f_xs, "#",             MUTED,            "Settings gear (was ⚙)"),
    (f_xs, "v  goal complete", GREEN,         "Check mark (was ✓)"),
    (f_xs, "○  goal pending",  MUTED,         "Locked circle (unchanged)"),
    (f_sm, "v",             GREEN,            "Upgrades purchased check (was ✓)"),
    (f_xs, "v AUTOMATED",   GREEN,            "Manager automated (was ✓)"),
    (f_xs, "v  Influence (Prestige Tokens)", (100, 190, 110), "Prestige keep list (was ✓)"),
    (f_xs, "x  Cash & balance", (200, 110, 90), "Prestige reset list (was ✗)"),
    (f_sm, "*",             GOLD,             "Streak star (was ★)"),
    (f_sm, "* Hustle — boosts your tap value", (180, 190, 255), "Manager specialty (was ★)"),
    (f_xs, "* special ability text", (120, 190, 255), "Building special (was ★)"),
]

for f, text, col, label in ui_syms:
    s = f.render(text[:40], True, col)
    lbl = f_xs.render(label, True, MUTED)
    screen.blit(s, (10, y))
    screen.blit(lbl, (470, y + 3))
    y += f.get_height() + 4
    if y > 540:
        break

pygame.display.flip()
pygame.image.save(screen, "verify_phase64.png")
print("Saved verify_phase64.png")
pygame.quit()
