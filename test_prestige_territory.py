"""Verify prestige button/panel and territory check marks rendering."""
import os
os.environ["SDL_AUDIODRIVER"] = "dummy"
import pygame
pygame.init()

import src.theme as theme
import config

W, H = 900, 520
screen = pygame.display.set_mode((W, H))
screen.fill(theme.BG_DARK)
fonts = theme.make_fonts(H)
f_xs = fonts['xs']
f_sm = fonts['sm']
f_md = fonts['md']
f_lg = fonts['lg']

GOLD = (255, 210, 80)
GREEN = theme.GREEN
MUTED = theme.TEXT_MUTED
PRESTIGE_COL = (220, 180, 255)

# Title
screen.blit(f_md.render("PHASE 64 — Prestige + Territory verification", True, GOLD), (10, 8))

y = 48
screen.blit(f_xs.render("PRESTIGE BUTTON (unlocked state):", True, MUTED), (10, y)); y += 20

# Draw the prestige button area (left panel bottom strip)
pr = pygame.Rect(10, y, 400, 90)
pygame.draw.rect(screen, (28, 30, 45), pr, border_radius=10)
pygame.draw.rect(screen, (60, 40, 90), pr, border_radius=10, width=2)
pygame.draw.rect(screen, (80, 50, 110), pygame.Rect(pr.x, pr.y, 3, pr.height))

pad_x = pr.x + 14
ls = f_sm.render("* PRESTIGE", True, PRESTIGE_COL)
screen.blit(ls, ls.get_rect(midleft=(pad_x, pr.centery - 16)))
rs = f_xs.render("+3 Influence  •  +6% permanent income", True, (180, 100, 255))
screen.blit(rs, rs.get_rect(midleft=(pad_x, pr.centery + 2)))
ks = f_xs.render("Keeps: Influence, Respect, Perks, Stats", True, (120, 90, 170))
screen.blit(ks, ks.get_rect(midleft=(pad_x, pr.centery + 16)))
y += 100

# Locked prestige
screen.blit(f_xs.render("PRESTIGE BUTTON (locked state):", True, MUTED), (10, y)); y += 20
pr2 = pygame.Rect(10, y, 400, 90)
pygame.draw.rect(screen, (28, 30, 45), pr2, border_radius=10)
pygame.draw.rect(screen, (50, 40, 70), pr2, border_radius=10, width=1)
title_s = f_xs.render("* PRESTIGE  —  LOCKED", True, PRESTIGE_COL)
screen.blit(title_s, title_s.get_rect(midleft=(pr2.x + 14, pr2.y + 12)))
# Req rows
reqs = [("v", "Rank ≥ Made Man:   Associate / 0 tokens", True),
        ("x", "Rival actions ≥ 3:  1 / 3",             False),
        ("v", "Earnings target:    $850K / $850K",       True)]
for i, (mark, text, met) in enumerate(reqs):
    col = (70, 200, 70) if met else (210, 70, 55)
    ck = f_xs.render(mark, True, col)
    tx = f_xs.render(text, True, (100,160,100) if met else (145,120,175))
    screen.blit(ck, (pr2.x + 14, pr2.y + 30 + i * 18))
    screen.blit(tx, (pr2.x + 28, pr2.y + 30 + i * 18))
y += 100

# Prestige confirm dialog
screen.blit(f_xs.render("PRESTIGE CONFIRM DIALOG:", True, MUTED), (10, y)); y += 20
panel = pygame.Rect(10, y, 480, 200)
pygame.draw.rect(screen, theme.BG_PANEL, panel, border_radius=14)
pygame.draw.rect(screen, theme.ACCENT_DIM, panel, border_radius=14, width=1)
cx = panel.centerx
title_s = f_lg.render("* PRESTIGE?", True, GOLD)
screen.blit(title_s, title_s.get_rect(center=(cx, panel.top + 28)))
gain_s = f_sm.render("+3 Influence  →  permanent +6% income", True, theme.ACCENT)
screen.blit(gain_s, gain_s.get_rect(center=(cx, panel.top + 58)))
pygame.draw.line(screen, (*theme.ACCENT_DIM, 60), (panel.left+20, panel.top+76), (panel.right-20, panel.top+76))
ry = panel.top + 85
col_w = (panel.width - 40) // 2
left_x, right_x = panel.left + 10, panel.left + 20 + col_w
screen.blit(f_xs.render("RESETS", True, (220,90,70)), (left_x, ry))
pygame.draw.line(screen, (220,90,70), (left_x, ry+14), (left_x+col_w-4, ry+14))
for i, item in enumerate(("Cash & balance", "Buildings", "Upgrades", "Temp progress")):
    s = f_xs.render(f"x  {item}", True, (200, 110, 90))
    screen.blit(s, (left_x + 4, ry + 20 + i * 16))
screen.blit(f_xs.render("YOU KEEP", True, GREEN), (right_x, ry))
pygame.draw.line(screen, GREEN, (right_x, ry+14), (right_x+col_w-4, ry+14))
for i, item in enumerate(("Influence (tokens)", "Respect", "Perks", "Statistics")):
    s = f_xs.render(f"v  {item}", True, (100, 190, 110))
    screen.blit(s, (right_x + 4, ry + 20 + i * 16))
y += 210

# Territory check marks
screen.blit(f_xs.render("TERRITORY MILESTONE CHECK MARKS:", True, MUTED), (10, y)); y += 18
for earned, label in [(True, "25% territory control"), (True, "50% territory control"),
                       (False, "75% territory control"), (False, "100% control")]:
    bg = pygame.Rect(10, y, 300, 22)
    pygame.draw.rect(screen, (30, 45, 30) if earned else (28, 28, 40), bg, border_radius=5)
    check = "v" if earned else "○"
    col = GREEN if earned else MUTED
    ck = f_xs.render(check, True, col)
    screen.blit(ck, (14, y + 3))
    pct = f_xs.render(label, True, GOLD if earned else MUTED)
    screen.blit(pct, (28, y + 3))
    y += 26

pygame.display.flip()
pygame.image.save(screen, "prestige_territory.png")
print("Saved prestige_territory.png")
pygame.quit()
