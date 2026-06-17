"""Phase 64 — render all faction/UI symbols to PNG for visual inspection."""
import os
os.environ["SDL_AUDIODRIVER"] = "dummy"

import pygame

pygame.init()
screen = pygame.display.set_mode((800, 500))
pygame.display.set_caption("Glyph Test")

import src.theme as theme
fonts = theme.make_fonts(720)
f_xs = fonts['xs']
f_sm = fonts['sm']
f_md = fonts['md']

BG = (20, 22, 35)
WHITE = (235, 235, 245)
GOLD  = (255, 210, 80)
RED   = (255, 80, 80)
GREEN = (80, 220, 120)

ROWS = [
    # (char, label, font_key, color, category)
    # --- Faction symbols ---
    ("♦",  "Crimson Kings",   'sm', (200, 80, 80),   "Faction"),
    ("❖",  "Silver Hand",     'sm', (200, 200, 200), "Faction"),
    ("⚙",  "Iron Union",      'sm', (150, 150, 220), "Faction"),
    ("◎",  "Network",         'sm', (80, 220, 180),  "Faction"),
    ("⚓",  "Blackwater",      'sm', (80, 140, 200),  "Faction"),
    # --- Dragon HUD / goals ---
    ("▶",  "Dragon goal  ",   'xs', GOLD,             "HUD"),
    ("►",  "Alt arrow ►  ",   'xs', GOLD,             "HUD"),
    # --- Other UI ---
    ("★",  "Ach/manager   ",  'md', GOLD,             "UI"),
    ("✦",  "Prestige       ", 'sm', (220, 180, 255),  "UI"),
    ("✓",  "Check/done    ",  'xs', GREEN,            "UI"),
    ("○",  "Locked item   ",  'xs', (130,135,160),    "UI"),
    ("▲",  "Income / scroll", 'xs', (80, 220, 120),   "UI"),
    ("▼",  "Scroll down   ",  'xs', (130,135,160),    "UI"),
    ("→",  "Arrow labels  ",  'xs', (130,135,160),    "UI"),
    # --- Reference chars ---
    ("?",       "ASCII ? (ref)",   'sm', RED, "REF"),
    ("A",       "ASCII A (ref)",   'sm', RED, "REF"),
]

screen.fill(BG)

# Draw header
hdr = f_md.render("PHASE 64 -- Glyph Render Test", True, GOLD)
screen.blit(hdr, (20, 10))

# Two-column layout
col_w = 390
y = 50
col = 0

results = []

for i, (char, label, fk, color, cat) in enumerate(ROWS):
    x = 20 + col * col_w
    if y > 450:
        col += 1
        y = 50
        x = 20 + col * col_w

    f = fonts[fk]

    # Render the symbol
    sym_surf = f.render(char, True, color)
    # Render the symbol at xs too
    sym_xs   = f_xs.render(char, True, color)

    # Label
    lbl_surf = f_xs.render(f"{cat}: {label}", True, (130, 135, 160))

    # Detect tofu: check pixel count of the rendered glyph
    arr = pygame.surfarray.array3d(sym_surf)
    bright_pixels = int((arr > 50).any(axis=2).sum())
    is_tofu = bright_pixels < 5  # very few pixels = box or empty

    # Compare dimensions: a box glyph typically has the same W*H as the font height
    w, h = sym_surf.get_size()

    # Status indicator
    status_col = RED if is_tofu else GREEN
    status_txt = "TOFU?" if is_tofu else "OK"
    status_surf = f_xs.render(status_txt, True, status_col)

    results.append((char, label, cat, bright_pixels, w, h, status_txt))

    # Draw row
    screen.blit(sym_surf, (x, y))
    screen.blit(lbl_surf, (x + 30, y + 3))
    screen.blit(status_surf, (x + 300, y + 3))
    screen.blit(sym_xs, (x + 16, y + 1))

    y += 30

pygame.display.flip()
pygame.image.save(screen, "glyph_render_test.png")
print("Saved glyph_render_test.png")
print()
print(f"{'CHAR':<6} {'PIXELS':>8} {'W':>5} {'H':>5}  {'STATUS':<8}  LABEL")
print("-" * 70)
for char, label, cat, px, w, h, status in results:
    u = f"U+{ord(char):04X}"
    print(f"{u:<8} {px:>8} {w:>5} {h:>5}  {status:<8}  {label}")

pygame.quit()
