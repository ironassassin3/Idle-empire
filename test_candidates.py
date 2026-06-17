"""Test specific candidate replacement characters at real display size.
Saves candidate_glyphs.png for visual inspection."""
import os
os.environ["SDL_AUDIODRIVER"] = "dummy"
import pygame
pygame.init()

screen = pygame.display.set_mode((900, 520))
screen.fill((20, 22, 35))

import src.theme as theme
fonts = theme.make_fonts(720)
f_sm = fonts['sm']
f_xs = fonts['xs']
GOLD  = (255, 210, 80)
RED   = (255, 80, 80)
GREEN = (80, 220, 120)
WHITE = (235, 235, 245)
MUTED = (130, 135, 160)
BG    = (20, 22, 35)

# Title
screen.blit(f_sm.render("CANDIDATE GLYPHS - Consolas sm/xs", True, GOLD), (10, 6))

# Known failures (to show what boxes look like)
FAILING = [
    ("❖", "Silver Hand - FAILS"),
    ("⚙", "Iron Union - FAILS"),
    ("◎", "Network - FAILS"),
    ("⚓", "Blackwater - FAILS"),
    ("★", "Star - FAILS"),
    ("✦", "4-star Prestige - FAILS"),
    ("✓", "Check mark - FAILS"),
]

# Candidate replacements
CANDIDATES = [
    # ASCII (always work)
    ("*",  "asterisk"),
    ("+",  "plus"),
    ("^",  "caret"),
    ("~",  "tilde"),
    ("#",  "hash"),
    ("-",  "dash"),
    ("@",  "at"),
    ("&",  "ampersand"),
    ("%",  "percent"),
    ("$",  "dollar"),
    ("!",  "bang"),
    ("|",  "pipe"),
    # Latin-1 (should work)
    ("·", "middle-dot"),
    ("×", "times"),
    ("±", "plus-minus"),
    ("°", "degree"),
    ("§", "section"),
    ("¶", "pilcrow"),
    ("®", "registered"),
    # Geometric shapes (partial Consolas coverage)
    ("◆", "black-diamond ◆"),
    ("◇", "white-diamond ◇"),
    ("◈", "diamond-dot ◈"),
    ("◊", "lozenge ◊"),
    ("●", "circle ●"),
    ("○", "white-circle ○"),
    ("◐", "half-circle ◐"),
    ("■", "black-square ■"),
    ("□", "white-square □"),
    ("▪", "small-square ▪"),
    ("▫", "small-wsquare ▫"),
    ("▬", "black-rect ▬"),
    ("▲", "up-triangle ▲"),
    ("△", "white-up-tri △"),
    ("▶", "right-tri ▶"),
    ("►", "right-ptr ►"),
    ("▼", "down-tri ▼"),
    ("◄", "left-tri ◄"),
    ("◦", "bullet-white ◦"),
    ("•", "bullet •"),
    ("‣", "tri-bullet ‣"),
    # Arrows
    ("→", "right-arrow →"),
    ("←", "left-arrow ←"),
    ("↑", "up-arrow ↑"),
    ("↓", "down-arrow ↓"),
    ("⇒", "fat-right ⇒"),
    ("⇔", "iff ⇔"),
    # Math
    ("−", "minus −"),
    ("≈", "approx ≈"),
    ("≠", "not-equal ≠"),
    ("≤", "le ≤"),
    ("≥", "ge ≥"),
    ("×", "times ×"),
    ("∞", "infinity ∞"),
    ("±", "plus-minus ±"),
    ("√", "sqrt √"),
    ("∂", "partial ∂"),
    ("∑", "sum ∑"),
    ("∅", "empty-set ∅"),
]

# Draw failing chars (reference boxes)
y = 36
screen.blit(f_xs.render("FAILING (tofu reference):", True, RED), (10, y)); y += 20
row_x = 10
for ch, label in FAILING:
    s = f_sm.render(ch + " " + label[:20], True, RED)
    screen.blit(s, (row_x, y))
    row_x += 220
    if row_x > 680:
        row_x = 10
        y += 24
y += 28

# Draw candidates in a grid
screen.blit(f_xs.render("CANDIDATES (sm size above, xs below):", True, GREEN), (10, y)); y += 20
start_y = y
col_w = 160
cols = 5
row_h = 38
idx = 0
for ch, label in CANDIDATES:
    col = idx % cols
    row = idx // cols
    x = 10 + col * col_w
    cy = start_y + row * row_h

    # sm render
    s_sm = f_sm.render(ch, True, WHITE)
    # xs render
    s_xs = f_xs.render(ch, True, MUTED)
    # label
    s_lbl = f_xs.render(label[:15], True, MUTED)

    screen.blit(s_sm, (x, cy))
    screen.blit(s_xs, (x + 18, cy + 2))
    screen.blit(s_lbl, (x + 32, cy + 5))
    idx += 1

pygame.display.flip()
pygame.image.save(screen, "candidate_glyphs.png")
print("Saved candidate_glyphs.png")
pygame.quit()
