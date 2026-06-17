"""PauseState — overlay drawn on top of the frozen PlayingState."""
from __future__ import annotations
import pygame
import config
import src.theme as theme
from src.save_load import save_game


def _game_state_base():
    from src.states import GameState
    return GameState


class PauseState:
    """Pause overlay; duck-types GameState interface to avoid circular import."""

    _BTN_W, _BTN_H = 200, 44
    _PANEL_W, _PANEL_H = 300, 280

    def __init__(self, state_manager, playing):
        self.state_manager = state_manager
        self._playing = playing
        cx = config.SCREEN_WIDTH // 2
        cy = config.SCREEN_HEIGHT // 2
        self._resume_r = pygame.Rect(cx - self._BTN_W // 2, cy - 56, self._BTN_W, self._BTN_H)
        self._ach_r    = pygame.Rect(cx - self._BTN_W // 2, cy,      self._BTN_W, self._BTN_H)
        self._quit_r   = pygame.Rect(cx - self._BTN_W // 2, cy + 56, self._BTN_W, self._BTN_H)
        self._fonts    = playing._fonts

    def on_enter(self): pass
    def on_exit(self): pass

    def handle_events(self, events):
        for ev in events:
            if ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE:
                self.state_manager.pop()
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                if self._resume_r.collidepoint(ev.pos):
                    self.state_manager.pop()
                elif self._ach_r.collidepoint(ev.pos):
                    from src.achievements_panel import AchievementsState
                    self.state_manager.push(AchievementsState(self.state_manager, self._playing))
                elif self._quit_r.collidepoint(ev.pos):
                    save_game(self._playing)
                    self.state_manager.pop()
                    self.state_manager.pop()

    def update(self, dt):
        pass

    def draw(self, surface):
        self._playing.draw(surface)

        # Full screen overlay at alpha 200
        overlay = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT))
        overlay.fill(theme.BG_DARK)
        overlay.set_alpha(200)
        surface.blit(overlay, (0, 0))

        cx = config.SCREEN_WIDTH // 2
        cy = config.SCREEN_HEIGHT // 2
        panel = pygame.Rect(cx - self._PANEL_W // 2, cy - self._PANEL_H // 2,
                            self._PANEL_W, self._PANEL_H)
        pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=12)
        pygame.draw.rect(surface, theme.ACCENT_DIM, panel, border_radius=12, width=1)

        # Title at card top + 24px
        title = self._fonts['lg'].render("PAUSED", True, theme.TEXT_GOLD)
        surface.blit(title, title.get_rect(center=(cx, panel.top + 24 + title.get_height() // 2)))

        mx, my = pygame.mouse.get_pos()

        # Resume button
        hover_r = self._resume_r.collidepoint(mx, my)
        rc = tuple(min(255, v + 25) for v in theme.BLUE_MID) if hover_r else theme.BLUE_MID
        pygame.draw.rect(surface, rc, self._resume_r, border_radius=8)
        rs = self._fonts['sm'].render("RESUME", True, theme.TEXT_PRIMARY)
        surface.blit(rs, rs.get_rect(center=self._resume_r.center))

        # Achievements button
        ach_count = sum(1 for a in getattr(self._playing, 'achievements', []) if a.earned)
        ach_total = len(getattr(self._playing, 'achievements', []))
        hover_a = self._ach_r.collidepoint(mx, my)
        ac = theme.BG_CARD_HOVER if hover_a else theme.BG_CARD
        pygame.draw.rect(surface, ac, self._ach_r, border_radius=8)
        pygame.draw.rect(surface, theme.TEXT_GOLD, self._ach_r, border_radius=8, width=1)
        as_ = self._fonts['sm'].render(f"ACHIEVEMENTS  {ach_count}/{ach_total}", True, theme.TEXT_GOLD)
        surface.blit(as_, as_.get_rect(center=self._ach_r.center))

        # Save & Quit button
        hover_q = self._quit_r.collidepoint(mx, my)
        qc = (80, 25, 25) if hover_q else (50, 15, 15)
        pygame.draw.rect(surface, qc, self._quit_r, border_radius=8)
        pygame.draw.rect(surface, (200, 60, 60), self._quit_r, border_radius=8, width=1)
        qs = self._fonts['sm'].render("SAVE & QUIT", True, theme.TEXT_PRIMARY)
        surface.blit(qs, qs.get_rect(center=self._quit_r.center))

        # Hint
        hint = self._fonts['xs'].render("ESC to resume", True, theme.TEXT_MUTED)
        surface.blit(hint, hint.get_rect(center=(cx, panel.bottom - 16)))
