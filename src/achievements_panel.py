"""Achievements browser — full-screen, scrollable, category-grouped overlay.

Exposes the existing achievement system (src/achievements.py) so players can
browse every achievement in the game: earned, locked, and per-category progress.
It does NOT redesign achievements — it reads state.achievements and renders them.
"""
from __future__ import annotations
import pygame
import config
import src.theme as theme
import src.sound as sound
from src.achievements import _CAT_COLORS

# Human-readable category labels and the order they appear in the panel.
_CATEGORY_ORDER = [
    ('money',      'MONEY'),
    ('clicks',     'CLICKING'),
    ('building',   'BUILDINGS & UPGRADES'),
    ('manager',    'MANAGERS'),
    ('prestige',   'PRESTIGE'),
    ('territory',  'TERRITORY'),
    ('rival',      'RIVALS'),
    ('operations', 'OPERATIONS'),
    ('time',       'TIME & COINS'),
    ('secret',     'SECRET'),
]

_ROW_H   = 40
_CAT_GAP = 16


class AchievementsState:
    """Full-screen scrollable achievement browser. Pushed over PlayingState."""

    _PANEL = pygame.Rect(40, 40, config.SCREEN_WIDTH - 80, config.SCREEN_HEIGHT - 80)

    def __init__(self, state_manager, playing):
        self.state_manager = state_manager
        self._playing = playing
        self._fonts = playing._fonts
        self._scroll = 0
        self._content_h = 0
        cx = self._PANEL.centerx
        self._back_r = pygame.Rect(cx - 70, self._PANEL.bottom - 44, 140, 34)

    def on_enter(self): pass
    def on_exit(self):  pass

    def handle_events(self, events):
        for ev in events:
            if ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE:
                self.state_manager.pop()
            elif ev.type == pygame.MOUSEWHEEL:
                view_h = self._PANEL.height - 150
                max_s = max(0, self._content_h - view_h)
                self._scroll = max(0, min(self._scroll - ev.y * 32, max_s))
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                if self._back_r.collidepoint(ev.pos):
                    sound.play('click')
                    self.state_manager.pop()

    def update(self, dt):
        pass

    def draw(self, surface):
        self._playing.draw(surface)

        ov = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
        ov.fill((*theme.OVERLAY_DARK, 215))
        surface.blit(ov, (0, 0))

        p = self._PANEL
        pygame.draw.rect(surface, theme.BG_PANEL, p, border_radius=14)
        pygame.draw.rect(surface, theme.ACCENT_DIM, p, border_radius=14, width=2)

        achievements = getattr(self._playing, 'achievements', [])
        total_earned = sum(1 for a in achievements if a.earned)
        total = len(achievements)

        # Title row
        title = self._fonts['lg'].render("ACHIEVEMENTS", True, theme.TEXT_GOLD)
        surface.blit(title, title.get_rect(midleft=(p.x + 20, p.top + 28)))
        count_s = self._fonts['md'].render(
            f"{total_earned} / {total} earned", True, theme.TEXT_PRIMARY)
        surface.blit(count_s, count_s.get_rect(midright=(p.right - 20, p.top + 28)))

        # Overall progress bar
        bar_w = p.width - 40
        bar_x = p.x + 20
        bar_y = p.top + 50
        pygame.draw.rect(surface, theme.BG_CARD, (bar_x, bar_y, bar_w, 8), border_radius=4)
        if total > 0:
            fw = max(4, int(bar_w * total_earned / total))
            pygame.draw.rect(surface, theme.GREEN, (bar_x, bar_y, fw, 8), border_radius=4)

        # ── Scrollable content (rendered to a virtual surface, then clipped) ──
        view_top = p.top + 70
        view_h   = p.bottom - 56 - view_top
        view_rect = pygame.Rect(p.x + 12, view_top, p.width - 24, view_h)

        virt_w = view_rect.width
        virt = pygame.Surface((virt_w, max(1, self._content_h or 4000)), pygame.SRCALPHA)
        y = self._render_content(virt, achievements, virt_w)
        self._content_h = y

        max_s = max(0, self._content_h - view_h)
        self._scroll = max(0, min(self._scroll, max_s))
        surface.blit(virt, view_rect.topleft,
                     pygame.Rect(0, self._scroll, virt_w, view_h))

        # Scroll thumb
        if self._content_h > view_h:
            thumb_h = max(24, int(view_h * view_h / self._content_h))
            thumb_y = view_top + int(self._scroll / max_s * (view_h - thumb_h)) if max_s else view_top
            pygame.draw.rect(surface, theme.ACCENT_DIM,
                             pygame.Rect(p.right - 16, thumb_y, 4, thumb_h), border_radius=2)

        # Back button
        mx, my = pygame.mouse.get_pos()
        hover = self._back_r.collidepoint(mx, my)
        col = theme.BG_CARD_HOVER if hover else theme.BG_CARD
        pygame.draw.rect(surface, col, self._back_r, border_radius=8)
        pygame.draw.rect(surface, theme.ACCENT_DIM, self._back_r, border_radius=8, width=1)
        bl = self._fonts['sm'].render("Back  (ESC)", True, theme.TEXT_PRIMARY)
        surface.blit(bl, bl.get_rect(center=self._back_r.center))

    def _render_content(self, virt, achievements, width) -> int:
        f_sm = self._fonts['sm']
        f_xs = self._fonts['xs']
        x = 6
        y = 4

        for cat_key, cat_label in _CATEGORY_ORDER:
            cat_achs = [a for a in achievements if a.category == cat_key]
            if not cat_achs:
                continue
            cat_col = _CAT_COLORS.get(cat_key, theme.ACCENT)
            earned = sum(1 for a in cat_achs if a.earned)
            total = len(cat_achs)

            # Category header with color bar + progress
            pygame.draw.rect(virt, cat_col, (x, y + 2, 4, 18), border_radius=2)
            hs = f_sm.render(cat_label, True, cat_col)
            virt.blit(hs, (x + 12, y))
            prog_s = f_xs.render(f"{earned}/{total}", True, theme.TEXT_MUTED)
            virt.blit(prog_s, prog_s.get_rect(topright=(width - 6, y + 3)))
            # Mini progress bar under header
            pbar_w = width - 12
            pygame.draw.rect(virt, (40, 42, 58), (x, y + 22, pbar_w, 3), border_radius=2)
            if total:
                fw = max(2, int(pbar_w * earned / total))
                pygame.draw.rect(virt, cat_col, (x, y + 22, fw, 3), border_radius=2)
            y += 32

            for a in cat_achs:
                rr = pygame.Rect(x, y, width - 12, _ROW_H - 4)
                is_secret_locked = (cat_key == 'secret' and not a.earned)

                if a.earned:
                    bg = (24, 40, 28, 220)
                else:
                    bg = (26, 28, 40, 160)
                bg_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
                pygame.draw.rect(bg_surf, bg, bg_surf.get_rect(), border_radius=8)
                virt.blit(bg_surf, rr.topleft)

                # Status icon (v earned / ○ locked — matches the rest of the UI)
                if a.earned:
                    icon = f_sm.render("v", True, theme.GREEN)
                else:
                    icon = f_sm.render("○", True, theme.TEXT_MUTED)
                virt.blit(icon, (rr.x + 8, rr.y + 6))

                # Name + description
                if is_secret_locked:
                    name_txt, desc_txt = "??? (Secret)", "Hidden until unlocked"
                    name_col = theme.TEXT_MUTED
                else:
                    name_txt, desc_txt = a.name, a.description
                    name_col = theme.TEXT_GOLD if a.earned else theme.TEXT_PRIMARY

                ns = f_xs.render(name_txt, True, name_col)
                virt.blit(ns, (rr.x + 30, rr.y + 4))
                ds = f_xs.render(desc_txt, True, theme.TEXT_MUTED)
                ds.set_alpha(190 if not a.earned else 230)
                virt.blit(ds, (rr.x + 30, rr.y + 19))

                # "EARNED" tag
                if a.earned:
                    tag = f_xs.render("EARNED", True, theme.GREEN)
                    virt.blit(tag, tag.get_rect(midright=(rr.right - 8, rr.centery)))

                y += _ROW_H
            y += _CAT_GAP

        return y
