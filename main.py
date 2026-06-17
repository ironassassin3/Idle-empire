import math
import pygame
import config
import src.theme as theme
import src.ui as ui
from src.engine import Engine
from src.states import GameState, PlayingState
import src.sound as sound
from src.save_load import load_game_preview, delete_save
from src.scale import sx, sy, sd, ensure_gap, fit_footer

VERSION = config.VERSION


class MenuState(GameState):
    """Title screen: Continue / New Game / Settings / Credits / Exit."""

    def __init__(self, state_manager):
        super().__init__(state_manager)
        self._time = 0.0
        self._fonts = theme.make_fonts()
        self._save_info = load_game_preview()
        self._sub = 'main'   # 'main' | 'confirm' | 'credits' | 'settings'
        self._sfx_vol = sound.get_volume()
        self._muted = False

    # ── Button list (dynamic based on save state) ─────────────────────────────
    def _btn_list(self):
        items = []
        if self._save_info:
            items.append(("CONTINUE",  'continue'))
        items.append(("NEW GAME",  'new_game'))
        items.append(("SETTINGS",  'settings'))
        items.append(("CREDITS",   'credits'))
        items.append(("EXIT",      'exit'))
        return items

    def _main_button_rects(self):
        """Compute button rects, vertically centered around design y=430."""
        btn_w   = sd(240)
        btn_h   = sd(44)
        btn_gap = sd(8)
        items = self._btn_list()
        n = len(items)
        total_h = n * btn_h + (n - 1) * btn_gap
        cx = config.SCREEN_WIDTH // 2
        start_y = sy(430) - total_h // 2
        rects = []
        for i, (label, action) in enumerate(items):
            y = start_y + i * (btn_h + btn_gap)
            rects.append((pygame.Rect(cx - btn_w // 2, y, btn_w, btn_h), label, action))
        return rects

    # ── Event handling ────────────────────────────────────────────────────────
    def handle_events(self, events):
        for ev in events:
            if ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE and self._sub != 'main':
                    self._sub = 'main'
                elif ev.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    if self._sub == 'main':
                        # Activate the primary button (first in list)
                        items = self._btn_list()
                        if items:
                            self._do_action(items[0][1])
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                self._handle_click(ev.pos)

    def _handle_click(self, pos):
        cx = config.SCREEN_WIDTH // 2
        cy = config.SCREEN_HEIGHT // 2

        if self._sub == 'main':
            for r, label, action in self._main_button_rects():
                if r.collidepoint(pos):
                    self._do_action(action)
                    return

        elif self._sub == 'confirm':
            yes_r, no_r = self._confirm_rects()
            if yes_r.collidepoint(pos):
                delete_save()
                self._save_info = None
                self.state_manager.replace(PlayingState(self.state_manager))
            elif no_r.collidepoint(pos):
                self._sub = 'main'

        elif self._sub == 'credits':
            self._sub = 'main'

        elif self._sub == 'settings':
            self._handle_settings_click(pos)

    # ── Computed modal layouts (single source of truth: draw + hit-test) ──────
    # Each element is stacked below the previous one through ensure_gap() using
    # the global spacing constants, so sections can never overlap and the panel
    # height is derived from its contents (Phase 90).
    def _confirm_layout(self):
        cx = config.SCREEN_WIDTH // 2
        cy = config.SCREEN_HEIGHT // 2
        f = self._fonts
        SECTION, LABELG, GROUP = sd(config.SECTION_GAP), sd(config.LABEL_GAP), sd(config.GROUP_GAP)
        BMARGIN, pad_top = sd(config.BOTTOM_MARGIN), sd(config.SECTION_GAP)
        th, lh = f['sm'].get_height(), f['xs'].get_height()
        btn_h = sd(40)

        # Stack in panel-local space starting at y=pad_top, then center the panel.
        y = pad_top
        title_y = y;                 y += th + SECTION
        warn1_y = y;                 y += lh + LABELG
        warn2_y = y;                 y += lh + SECTION
        btn_y   = y;                 y += btn_h + GROUP
        foot_y  = y;                 y += lh + BMARGIN
        pw, ph = sd(340), y
        panel = pygame.Rect(cx - pw // 2, cy - ph // 2, pw, ph)
        t = panel.top
        bw = sd(100)
        return {
            'panel':   panel,
            'title_c': (cx, t + title_y + th // 2),
            'warn1_c': (cx, t + warn1_y + lh // 2),
            'warn2_c': (cx, t + warn2_y + lh // 2),
            'yes_r':   pygame.Rect(cx - bw - sd(8), t + btn_y, bw, btn_h),
            'no_r':    pygame.Rect(cx + sd(8),      t + btn_y, bw, btn_h),
            'foot_c':  (cx, t + foot_y + lh // 2),
        }

    def _confirm_rects(self):
        lay = self._confirm_layout()
        return lay['yes_r'], lay['no_r']

    def _settings_layout(self):
        cx = config.SCREEN_WIDTH // 2
        cy = config.SCREEN_HEIGHT // 2
        f = self._fonts
        SECTION, LABELG = sd(config.SECTION_GAP), sd(config.LABEL_GAP)
        BMARGIN, pad_top = sd(config.BOTTOM_MARGIN), sd(config.SECTION_GAP)
        th, lh = f['sm'].get_height(), f['xs'].get_height()
        vol_h, mute_w, mute_h = sd(30), sd(80), sd(30)
        back_w, back_h = sd(110), sd(36)

        # Volume button row (kept same size/order, perfectly centered).
        steps = [0.0, 0.25, 0.5, 0.75, 1.0]
        step_w, step_gap = sd(52), sd(6)
        row_w = len(steps) * step_w + (len(steps) - 1) * step_gap
        row_x = cx - row_w // 2

        # Stack everything top→down in panel-local space, then center the panel.
        y = pad_top
        title_y  = y;                 y += th + SECTION
        vlabel_y = y;                 y += lh + LABELG
        vbtn_y   = y;                 y += vol_h + SECTION
        mlabel_y = y;                 y += lh + LABELG
        mute_y   = y;                 y += mute_h + SECTION
        back_y   = y;                 y += back_h + SECTION
        foot_y   = y;                 y += lh + BMARGIN
        pw, ph = sd(380), y
        panel = pygame.Rect(cx - pw // 2, cy - ph // 2, pw, ph)
        t = panel.top

        vol_rects = [
            (pygame.Rect(row_x + i * (step_w + step_gap), t + vbtn_y, step_w, vol_h), s)
            for i, s in enumerate(steps)
        ]
        return {
            'panel':     panel,
            'title_c':   (cx, t + title_y + th // 2),
            'vlabel_tl': (row_x, t + vlabel_y),                 # left-aligned to row
            'vol_rects': vol_rects,
            'mlabel_c':  (cx, t + mlabel_y + lh // 2),
            'mute_r':    pygame.Rect(cx - mute_w // 2, t + mute_y, mute_w, mute_h),
            'back_r':    pygame.Rect(cx - back_w // 2, t + back_y, back_w, back_h),
            'foot_c':    (cx, t + foot_y + lh // 2),
        }

    def _settings_vol_rects(self):
        return self._settings_layout()['vol_rects']

    def _settings_mute_rect(self):
        return self._settings_layout()['mute_r']

    def _settings_back_rect(self):
        return self._settings_layout()['back_r']

    def _handle_settings_click(self, pos):
        for br, step in self._settings_vol_rects():
            if br.collidepoint(pos):
                self._sfx_vol = step
                sound.set_volume(0.0 if self._muted else step)
                return
        if self._settings_mute_rect().collidepoint(pos):
            self._muted = not self._muted
            sound.set_volume(0.0 if self._muted else self._sfx_vol)
            return
        if self._settings_back_rect().collidepoint(pos):
            self._sub = 'main'

    def _do_action(self, action):
        if action == 'continue':
            self.state_manager.replace(PlayingState(self.state_manager))
        elif action == 'new_game':
            if self._save_info:
                self._sub = 'confirm'
            else:
                self.state_manager.replace(PlayingState(self.state_manager))
        elif action == 'settings':
            self._sub = 'settings'
        elif action == 'credits':
            self._sub = 'credits'
        elif action == 'exit':
            pygame.event.post(pygame.event.Event(pygame.QUIT))

    # ── Update ────────────────────────────────────────────────────────────────
    def update(self, dt):
        self._time += dt

    # ── Draw ─────────────────────────────────────────────────────────────────
    def draw(self, surface):
        surface.fill(theme.NOIR_INK)
        ui.draw_noir_atmosphere(surface)
        self._draw_main(surface)
        if self._sub == 'confirm':
            self._draw_overlay_confirm(surface)
        elif self._sub == 'credits':
            self._draw_overlay_credits(surface)
        elif self._sub == 'settings':
            self._draw_overlay_settings(surface)

    def _draw_main(self, surface):
        fonts = self._fonts
        cx = config.SCREEN_WIDTH // 2

        # Hero frame (landing-page corner brackets)
        frame = pygame.Rect(sx(24), sy(48), config.SCREEN_WIDTH - sx(48),
                            config.SCREEN_HEIGHT - sy(96))
        pygame.draw.rect(surface, (*theme.NOIR_GOLD, 30), frame, width=1)
        ui._draw_noir_corners(surface, frame, arm=10)

        # Title — criminal empire wordmark
        disp = fonts.get('disp_lg', fonts['lg'])
        title_txt = "CRIMINAL EMPIRE"
        shadow = disp.render(title_txt, True, (40, 32, 18))
        title  = disp.render(title_txt, True, theme.NOIR_GOLD_BRIGHT)
        ty = sy(150)
        surface.blit(shadow, shadow.get_rect(center=(cx + sd(2), ty + sd(2))))
        surface.blit(title,  title.get_rect(center=(cx, ty)))

        # Subtitle
        sub = fonts.get('disp_sm', fonts['sm']).render(
            "BUILD YOUR SYNDICATE", True, theme.NOIR_BONE_DIM)
        surface.blit(sub, sub.get_rect(center=(cx, sy(210))))

        # Separator
        pygame.draw.line(surface, (*theme.NOIR_GOLD, 80),
                         (cx - sx(110), sy(232)), (cx + sx(110), sy(232)), 1)

        # Buttons
        mx, my = pygame.mouse.get_pos()
        interactive = self._sub == 'main'
        for i, (r, label, action) in enumerate(self._main_button_rects()):
            hover = r.collidepoint(mx, my) and interactive
            is_primary = (i == 0)

            if is_primary:
                pulse_a = int(180 + 50 * (0.5 + 0.5 * math.sin(self._time * 2.0)))
                btn_s = pygame.Surface((r.width, r.height), pygame.SRCALPHA)
                pygame.draw.rect(btn_s, (*theme.NOIR_GOLD, pulse_a), btn_s.get_rect(),
                                 border_radius=sd(8))
                pygame.draw.rect(btn_s, (*theme.NOIR_INK, 80), btn_s.get_rect(),
                                 border_radius=sd(8), width=1)
                surface.blit(btn_s, r.topleft)
                tc = theme.NOIR_INK
            else:
                glass = pygame.Surface((r.width, r.height), pygame.SRCALPHA)
                pygame.draw.rect(glass, (*theme.NOIR_GLASS, 200 if hover else 160),
                                 glass.get_rect(), border_radius=sd(8))
                pygame.draw.rect(glass, (*theme.NOIR_GOLD, 70 if hover else 45),
                                 glass.get_rect(), border_radius=sd(8), width=1)
                surface.blit(glass, r.topleft)
                tc = theme.NOIR_BONE if hover else theme.NOIR_BONE_DIM

            ls = fonts.get('disp_xs', fonts['sm']).render(label, True, tc)
            surface.blit(ls, ls.get_rect(center=r.center))

        # Save slot status
        bot_y = config.SCREEN_HEIGHT - sy(54)
        if self._save_info:
            pc  = self._save_info.get('prestige_count', 0)
            pt  = self._save_info.get('prestige_tokens', 0)
            run_lbl = f"{pc} Run{'s' if pc != 1 else ''}"
            inf_lbl = f"{pt} Influence"
            info_s = fonts['xs'].render(f"Save: {run_lbl}  ·  {inf_lbl}", True, theme.NOIR_BONE_DIM)
        else:
            info_s = fonts['xs'].render("No save found", True, theme.NOIR_BONE_DIM)
        surface.blit(info_s, info_s.get_rect(center=(cx, bot_y)))

        ver_s = fonts['xs'].render(f"Criminal Empire  {VERSION}", True, (90, 85, 100))
        surface.blit(ver_s, ver_s.get_rect(center=(cx, config.SCREEN_HEIGHT - sy(24))))

    def _draw_overlay_confirm(self, surface):
        cx = config.SCREEN_WIDTH // 2
        cy = config.SCREEN_HEIGHT // 2
        fonts = self._fonts

        dim = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
        dim.fill((0, 0, 0, 190))
        surface.blit(dim, (0, 0))

        lay = self._confirm_layout()
        panel = lay['panel']
        pygame.draw.rect(surface, theme.NOIR_INK_2, panel, border_radius=sd(12))
        pygame.draw.rect(surface, theme.NOIR_CRIMSON, panel, border_radius=sd(12), width=1)
        ui._draw_noir_corners(surface, panel, arm=8)

        title_s = fonts.get('disp_sm', fonts['sm']).render("START NEW GAME?", True, theme.NOIR_BONE)
        surface.blit(title_s, title_s.get_rect(center=lay['title_c']))

        warn1 = fonts['xs'].render("Your existing save will be erased.", True, theme.TEXT_MUTED)
        surface.blit(warn1, warn1.get_rect(center=lay['warn1_c']))

        warn2 = fonts['xs'].render("This cannot be undone.", True, (200, 80, 80))
        surface.blit(warn2, warn2.get_rect(center=lay['warn2_c']))

        mx, my = pygame.mouse.get_pos()
        for r, base_col, label in [(lay['yes_r'], theme.BTN_YES, "CONFIRM"),
                                   (lay['no_r'], theme.BTN_NO, "BACK")]:
            hover = r.collidepoint(mx, my)
            c = tuple(min(255, v + 24) for v in base_col) if hover else base_col
            pygame.draw.rect(surface, c, r, border_radius=sd(8))
            ls = fonts['sm'].render(label, True, theme.TEXT_PRIMARY)
            surface.blit(ls, ls.get_rect(center=r.center))

        # Footer safety: keep the hint clear of the panel edge.
        esc_s = fonts['xs'].render("ESC to go back", True, (70, 73, 90))
        esc_r = fit_footer(esc_s.get_rect(center=lay['foot_c']), panel, sd(config.BOTTOM_MARGIN))
        surface.blit(esc_s, esc_r)

    def _draw_overlay_credits(self, surface):
        cx = config.SCREEN_WIDTH // 2
        cy = config.SCREEN_HEIGHT // 2
        fonts = self._fonts

        dim = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
        dim.fill((0, 0, 0, 200))
        surface.blit(dim, (0, 0))

        pw, ph = sd(420), sd(310)
        panel = pygame.Rect(cx - pw // 2, cy - ph // 2, pw, ph)
        pygame.draw.rect(surface, theme.NOIR_INK_2, panel, border_radius=sd(12))
        pygame.draw.rect(surface, (*theme.NOIR_GOLD, 80), panel, border_radius=sd(12), width=1)
        ui._draw_noir_corners(surface, panel, arm=8)

        title_s = fonts.get('disp_lg', fonts['lg']).render("CRIMINAL EMPIRE", True, theme.NOIR_GOLD_BRIGHT)
        surface.blit(title_s, title_s.get_rect(center=(cx, panel.top + sd(36))))

        lines = [
            (f"Version {VERSION}", 'xs', theme.NOIR_BONE_DIM),
            ("", None, None),
            ("A criminal idle empire builder.", 'xs', theme.NOIR_BONE),
            ("Build your syndicate · Prestige · Dominate the city.", 'xs', theme.NOIR_BONE_DIM),
            ("", None, None),
            ("Built with Python + Pygame", 'xs', theme.NOIR_BONE_DIM),
            ("", None, None),
            ("[ click anywhere to close ]", 'xs', (90, 85, 100)),
        ]

        y = panel.top + sd(58)
        for text, size, color in lines:
            if text and size:
                s = fonts[size].render(text, True, color)
                surface.blit(s, s.get_rect(center=(cx, y + s.get_height() // 2)))
                y += s.get_height() + sd(10)
            else:
                y += sd(10)

    def _draw_overlay_settings(self, surface):
        cx = config.SCREEN_WIDTH // 2
        cy = config.SCREEN_HEIGHT // 2
        fonts = self._fonts

        dim = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
        dim.fill((0, 0, 0, 200))
        surface.blit(dim, (0, 0))

        lay = self._settings_layout()
        panel = lay['panel']
        pygame.draw.rect(surface, theme.NOIR_INK_2, panel, border_radius=sd(12))
        pygame.draw.rect(surface, (*theme.NOIR_GOLD, 70), panel, border_radius=sd(12), width=1)
        ui._draw_noir_corners(surface, panel, arm=8)

        title_s = fonts.get('disp_sm', fonts['sm']).render("SETTINGS", True, theme.NOIR_GOLD_BRIGHT)
        surface.blit(title_s, title_s.get_rect(center=lay['title_c']))

        # SFX Volume
        vol_label = fonts['xs'].render("SFX VOLUME", True, theme.TEXT_MUTED)
        surface.blit(vol_label, lay['vlabel_tl'])

        mx, my = pygame.mouse.get_pos()
        for br, step in lay['vol_rects']:
            active = abs(step - self._sfx_vol) < 0.01
            hover  = br.collidepoint(mx, my)
            if active:
                pygame.draw.rect(surface, theme.ACCENT, br, border_radius=sd(6))
                tc = theme.BG_DARK
            elif hover:
                pygame.draw.rect(surface, theme.BG_CARD_HOVER, br, border_radius=sd(6))
                pygame.draw.rect(surface, theme.ACCENT_DIM, br, border_radius=sd(6), width=1)
                tc = theme.TEXT_PRIMARY
            else:
                pygame.draw.rect(surface, theme.BG_CARD, br, border_radius=sd(6))
                tc = theme.TEXT_MUTED
            sv = fonts['xs'].render(f"{int(step * 100)}%", True, tc)
            surface.blit(sv, sv.get_rect(center=br.center))

        # Mute toggle
        mute_label = fonts['xs'].render("MUTE ALL", True, theme.TEXT_MUTED)
        surface.blit(mute_label, mute_label.get_rect(center=lay['mlabel_c']))
        mute_r = lay['mute_r']
        mc = theme.ACCENT if self._muted else theme.BG_CARD
        pygame.draw.rect(surface, mc, mute_r, border_radius=sd(6))
        if not self._muted:
            pygame.draw.rect(surface, theme.ACCENT_DIM, mute_r, border_radius=sd(6), width=1)
        ms = fonts['xs'].render("ON" if self._muted else "OFF",
                                True, theme.BG_DARK if self._muted else theme.TEXT_MUTED)
        surface.blit(ms, ms.get_rect(center=mute_r.center))

        # Back button
        back_r = lay['back_r']
        hover_b = back_r.collidepoint(mx, my)
        bc = theme.BG_CARD_HOVER if hover_b else theme.BG_CARD
        pygame.draw.rect(surface, bc, back_r, border_radius=sd(8))
        pygame.draw.rect(surface, theme.ACCENT_DIM, back_r, border_radius=sd(8), width=1)
        bs = fonts['xs'].render("BACK", True, theme.TEXT_PRIMARY)
        surface.blit(bs, bs.get_rect(center=back_r.center))

        # Footer safety: keep the note clear of the panel edge.
        note = fonts['xs'].render("More settings available in-game", True, (70, 73, 90))
        note_r = fit_footer(note.get_rect(center=lay['foot_c']), panel, sd(config.BOTTOM_MARGIN))
        surface.blit(note, note_r)


def main():
    engine = Engine()
    sound.init()
    engine.push_state(MenuState(engine.state_manager))
    engine.run()


if __name__ == "__main__":
    import sys
    import traceback
    try:
        main()
    except Exception:
        with open("crash.log", "w") as _cf:
            traceback.print_exc(file=_cf)
        traceback.print_exc()
        sys.exit(1)
