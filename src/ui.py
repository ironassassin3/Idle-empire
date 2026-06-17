"""Rendering helpers for PlayingState — polished criminal empire UI."""
from __future__ import annotations
import math
import time
import pygame
import config
from src.scale import sx, sy, sd, anchor_right
import src.buildings as bld
import src.upgrades as upg
import src.prestige as prestige
import src.theme as theme
import src.sound as sound
import src.managers as mgr_mod
import src.territory as territory_mod
import src.heat as heat_mod
import src.rivals as rivals_mod
import src.crew as crew_mod
import src.operations as ops_mod
import src.goals as goals_mod

# ─────────────────────── layout constants ──────────────────────────
# All layout values are recomputed by reinit_layout() at startup and on resize.
# Defaults here match the original 900×720 desktop target so existing saves/
# tests work without change when reinit_layout is never called.

HEADER_H      = 104
STRIP1_H      = 50
STRIP2_H      = 32
TICKER_Y      = 82
TICKER_H      = 22
RIGHT_X       = 420
TAB_H         = 34
CONTENT_Y     = HEADER_H + TAB_H
CLICK_RECT    = pygame.Rect(55, HEADER_H + 4, 260, 260)
PRESTIGE_RECT = pygame.Rect(55, HEADER_H + 272, 260, 44)
SCENE_TOP     = HEADER_H + 8
STAT_CLUSTER_Y = 668
STAT_CLUSTER_H = 42
# Phase 124 — city-first: scene dominates left column; goals/prestige/stats stack below.
GOALS_TOP     = HEADER_H + 480
GOALS_H       = 64
_GOALS_FULL_H = 72    # compact: hdr + 2 goal rows
_PRESTIGE_H_MIN = 72  # ready-state minimum
_PRESTIGE_H_FULL = 100  # locked-state: title + 5 requirement rows
_SCENE_MIN_H  = 120   # city must stay visible — no sliver hide at normal sizes
_LEFT_PAD     = 8

# Portrait mode: right panel is shown below instead of to the right
_PORTRAIT = False

# Tab widths — recomputed in reinit_layout
_TAB_W_MAIN = 76
_SUBTAB_W   = 70

# Minimum right-panel content height that must survive in portrait mode. The
# click+prestige stack is shrunk before the panel is ever allowed below this,
# so the content area never collapses (Phase 85). 150px guarantees at least one
# of the tallest card (managers, _ROW_H=110) plus header + scroll indicator.
MIN_CONTENT_H = 150


def reinit_layout(w: int, h: int) -> None:
    """Recompute all layout globals for window size (w, h).

    Call once after pygame.display.set_mode() and again on every RESIZABLE
    event so the UI adapts to the actual display dimensions.
    """
    global HEADER_H, STRIP1_H, STRIP2_H, TICKER_Y, TICKER_H, RIGHT_X, TAB_H, CONTENT_Y
    global CLICK_RECT, PRESTIGE_RECT, SCENE_TOP, STAT_CLUSTER_Y, STAT_CLUSTER_H
    global GOALS_TOP, GOALS_H, _LEFT_PAD
    global _NOTIF_X, _NOTIF_START_Y, _PORTRAIT, _TAB_W_MAIN, _SUBTAB_W
    global _SCENE_RECT

    # ── Live scale factors (read by src.scale helpers) ───────────────
    config.SCALE_X  = w / config.BASE_WIDTH
    config.SCALE_Y  = h / config.BASE_HEIGHT
    config.UI_SCALE = min(config.SCALE_X, config.SCALE_Y)

    # Determine layout mode
    portrait = w < h or w < 600
    _PORTRAIT = portrait

    # ── Header (Phase 122 — command center: strip1 + strip2 + ticker) ──
    scale_h = h / 720.0
    STRIP1_H = max(42, min(56, int(50 * scale_h)))
    STRIP2_H = max(26, min(38, int(32 * scale_h)))
    TICKER_H = max(18, int(22 * scale_h))
    HEADER_H = STRIP1_H + STRIP2_H + TICKER_H
    TICKER_Y = STRIP1_H + STRIP2_H
    TAB_H    = max(28, min(40, int(34 * scale_h)))

    # ── Column split ────────────────────────────────────────────────
    if portrait:
        # Left/click area gets top ~45% of remaining height;
        # right panel fills everything below header.
        RIGHT_X = 0         # right panel spans full width
        left_w  = w
    else:
        # Landscape: left panel is ~46% of width (min 260, max 420)
        left_w  = max(260, min(420, int(w * 0.465)))
        RIGHT_X = left_w

    # ── Left column (Phase 124 — city-first layout) ───────────────────
    # Visual priority: city scene ≥40% viewport → prestige → goals → stat strip.
    # Click target is an overlay inside the scene, not a separate panel block.
    gap = max(4, int(6 * scale_h))
    left_pad = max(6, int(8 * scale_h))
    _LEFT_PAD = left_pad

    cluster_h = max(34, int(42 * scale_h))
    STAT_CLUSTER_H = cluster_h
    prestige_h = max(_PRESTIGE_H_MIN, min(_PRESTIGE_H_FULL, int(100 * scale_h)))
    goals_h = max(52, min(_GOALS_FULL_H, int(_GOALS_FULL_H * scale_h)))

    if portrait:
        click_size = max(96, min(160, int(left_w * 0.45)))
        click_x = max(10, (left_w - click_size) // 2)
        click_y = HEADER_H + max(2, int(4 * scale_h))
        CLICK_RECT = pygame.Rect(click_x, click_y, click_size, click_size)
        prestige_y = CLICK_RECT.bottom + gap
        PRESTIGE_RECT = pygame.Rect(click_x, prestige_y, click_size, max(56, prestige_h))
        GOALS_H = 0
        SCENE_TOP = HEADER_H
        scene_h = 0
        scene_w = 0
        scene_x = left_pad
        STAT_CLUSTER_Y = h - cluster_h - 4
        GOALS_TOP = PRESTIGE_RECT.bottom + gap
        _SCENE_RECT = pygame.Rect(0, 0, 0, 0)
        reserve = TAB_H + 34 + MIN_CONTENT_H + 10
        overflow = (PRESTIGE_RECT.bottom + 6) - (h - reserve)
        if overflow > 0:
            new_click = max(88, click_size - overflow)
            click_size = new_click
            click_x = max(10, (left_w - click_size) // 2)
            CLICK_RECT = pygame.Rect(click_x, click_y, click_size, click_size)
            prestige_y = CLICK_RECT.bottom + gap
            remaining = overflow - (click_size - new_click)
            if remaining > 0:
                prestige_h = max(48, prestige_h - remaining)
            PRESTIGE_RECT = pygame.Rect(click_x, prestige_y, click_size, prestige_h)
    else:
        # Gap below header so ticker border never kisses the city frame.
        header_gap = max(4, int(6 * scale_h))
        body_top = HEADER_H + header_gap
        body_bottom = h - gap
        body_h = body_bottom - body_top
        stack_h = prestige_h + goals_h + cluster_h + gap * 3
        min_scene = max(_SCENE_MIN_H, int(h * 0.40))

        # Bottom-anchored stack first — guarantees stat cluster never clips the window.
        stat_y = body_bottom - cluster_h
        goals_top = stat_y - gap - goals_h
        prestige_y = goals_top - gap - prestige_h
        scene_h = prestige_y - gap - body_top

        if scene_h < min_scene:
            need = min_scene - scene_h
            goals_h = max(48, goals_h - need // 3)
            prestige_h = max(_PRESTIGE_H_MIN, prestige_h - (need - need // 3))
            stack_h = prestige_h + goals_h + cluster_h + gap * 3
            stat_y = body_bottom - cluster_h
            goals_top = stat_y - gap - goals_h
            prestige_y = goals_top - gap - prestige_h
            scene_h = max(_SCENE_MIN_H, prestige_y - gap - body_top)

        if scene_h + stack_h > body_h:
            scene_h = max(_SCENE_MIN_H, body_h - stack_h)
            prestige_y = body_top + scene_h + gap
            goals_top = prestige_y + prestige_h + gap
            stat_y = goals_top + goals_h + gap

        # Final sanity: bottom stack must fit inside the window with margin.
        margin = max(4, int(4 * scale_h))
        stack_bottom = stat_y + cluster_h
        if stack_bottom > body_bottom - margin:
            overshoot = stack_bottom - (body_bottom - margin)
            scene_h = max(_SCENE_MIN_H, scene_h - overshoot)
            prestige_y = body_top + scene_h + gap
            goals_top = prestige_y + prestige_h + gap
            stat_y = goals_top + goals_h + gap

        scene_w = max(0, left_w - left_pad * 2)
        scene_x = left_pad
        SCENE_TOP = body_top
        _SCENE_RECT = pygame.Rect(scene_x, SCENE_TOP, scene_w, scene_h)
        PRESTIGE_RECT = pygame.Rect(scene_x, prestige_y, scene_w, prestige_h)
        GOALS_TOP = goals_top
        GOALS_H = goals_h
        STAT_CLUSTER_Y = stat_y

        # Click overlay — lower-center of city; sized to stay inside the scene.
        click_size = max(88, min(int(scene_w * 0.34), int(scene_h * 0.30)))
        click_x = scene_x + (scene_w - click_size) // 2
        click_y = SCENE_TOP + int(scene_h * 0.58) - click_size // 2
        click_y = max(SCENE_TOP + sd(10),
                      min(click_y, SCENE_TOP + scene_h - click_size - sd(16)))
        CLICK_RECT = pygame.Rect(click_x, click_y, click_size, click_size)

    # ── Content Y ───────────────────────────────────────────────────
    CONTENT_Y = HEADER_H + TAB_H

    # ── Notification stack ──────────────────────────────────────────
    _NOTIF_X = w - _NOTIF_W - 8
    _NOTIF_START_Y = HEADER_H + TAB_H + max(4, int(4 * scale_h))

    # ── Tab widths ──────────────────────────────────────────────────
    # Fit 5 main tabs + gear icon inside the right panel
    right_w = w - RIGHT_X
    available = right_w - 40   # leave room for gear icon
    _TAB_W_MAIN = max(54, min(90, available // 5))
    _SUBTAB_W   = max(48, min(78, (right_w - 24) // 4))


# ─────────────────────── notification stack ────────────────────────
_NOTIF_MAX     = 6
_NOTIF_DURATION = 3.5
_NOTIF_FADE    = 0.6
_NOTIF_W       = 270   # Phase 60: widened from 230 so a rank/goal identity line fits
_NOTIF_H       = 34    # single-line height; 2-line notifications grow to ~48px
_NOTIF_LINES   = 3     # max wrapped lines; 3 lets operation notifications show name+cash+Respect
_NOTIF_X       = config.SCREEN_WIDTH - _NOTIF_W - 8
_NOTIF_START_Y = HEADER_H + TAB_H + 6   # below command center + tab bar

_notification_stack: list[dict] = []


def push_notification(text: str, color=None) -> None:
    """Add a notification to the top-right stack. Thread-safe-ish (single-threaded game).

    Full text is stored — draw_notifications word-wraps it to fit (Phase 60).
    A leading line (before any '\\n') is treated as the identity line; the rest
    follows beneath it.
    """
    if color is None:
        color = theme.TEXT_GOLD
    _notification_stack.append({
        'text': text,
        'color': color,
        'age': 0.0,
    })
    if len(_notification_stack) > _NOTIF_MAX:
        _notification_stack.pop(0)


def _wrap_notif_lines(text: str, font, max_w: int, max_lines: int) -> list[str]:
    """Word-wrap `text` (honoring explicit '\\n') to fit `max_w`, capped at
    `max_lines`. The final line is ellipsized only if content was dropped, so
    nothing is silently clipped mid-character (Phase 60)."""
    wrapped: list[str] = []
    overflow = False
    for seg in text.split("\n"):
        words = seg.split()
        if not words:
            continue
        cur = words[0]
        for w in words[1:]:
            if font.size(cur + " " + w)[0] <= max_w:
                cur += " " + w
            else:
                wrapped.append(cur)
                cur = w
        wrapped.append(cur)
    if not wrapped:
        return [text]
    if len(wrapped) > max_lines:
        overflow = True
        wrapped = wrapped[:max_lines]
    if overflow:
        last = wrapped[-1]
        while last and font.size(last + "…")[0] > max_w:
            last = last[:-1]
        wrapped[-1] = (last + "…") if last else "…"
    return wrapped


def update_notifications(dt: float) -> None:
    """Age notifications; call once per frame from PlayingState.update."""
    for n in _notification_stack:
        n['age'] += dt
    _notification_stack[:] = [n for n in _notification_stack if n['age'] < _NOTIF_DURATION]


def draw_notifications(surface: pygame.Surface, fonts: dict) -> None:
    """Render the notification stack below the tab bar (top-right)."""
    global _NOTIF_SURF
    if not _notification_stack:
        return
    pad_x   = 8
    line_h  = fonts['xs'].get_height() + 3
    max_box = max(_NOTIF_H, 10 + _NOTIF_LINES * line_h)
    if _NOTIF_SURF is None or _NOTIF_SURF.get_size() != (_NOTIF_W, max_box):
        _NOTIF_SURF = pygame.Surface((_NOTIF_W, max_box), pygame.SRCALPHA)

    y = _NOTIF_START_Y
    max_y = config.SCREEN_HEIGHT - sd(8)
    for n in reversed(_notification_stack):
        remaining = _NOTIF_DURATION - n['age']
        alpha = min(255, int(255 * min(1.0, remaining / _NOTIF_FADE)))
        lines  = _wrap_notif_lines(n['text'], fonts['xs'], _NOTIF_W - pad_x * 2,
                                   _NOTIF_LINES)
        box_h  = max(_NOTIF_H, 10 + len(lines) * line_h)
        if y + box_h > max_y:
            break

        _NOTIF_SURF.fill((0, 0, 0, 0))
        box_rect = pygame.Rect(0, 0, _NOTIF_W, box_h)
        pygame.draw.rect(_NOTIF_SURF, (*theme.NOIR_GLASS, int(210 * alpha / 255)),
                         box_rect, border_radius=6)
        pygame.draw.rect(_NOTIF_SURF, (*n['color'], int(120 * alpha / 255)),
                         box_rect, border_radius=6, width=1)
        ty = (box_h - len(lines) * line_h) // 2
        for ln in lines:
            ts = fonts['xs'].render(ln, True, n['color'])
            ts.set_alpha(alpha)
            _NOTIF_SURF.blit(ts, (pad_x, ty))
            ty += line_h
        surface.blit(_NOTIF_SURF, (_NOTIF_X, y), box_rect)
        y += box_h + 4

# ─────────────────────── shared overlay helper ─────────────────────
def draw_overlay(surface: pygame.Surface, alpha: int = 210) -> None:
    ov = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
    ov.fill((*theme.OVERLAY_DARK, alpha))
    surface.blit(ov, (0, 0))


# ── Modal geometry helpers (Phase 92) ─────────────────────────────────────────
# Fonts scale 1.0–1.6× with screen height; author-time fixed panels overflowed
# (text spilling out at 1080p+) or clipped (panel wider than a 480px window).
# Scaling the panel by sd() — which grows at least as fast as the fonts — keeps
# text proportional, and clamping to the screen keeps it fully on-screen. At the
# 900×720 design size sd()==identity, so base layout is unchanged.

def modal_panel_rect(base_w: int, base_h: int, margin: int = 16) -> pygame.Rect:
    """Centered modal panel, resolution-scaled and clamped inside the screen."""
    w = min(config.SCREEN_WIDTH - 2 * sd(margin), sd(base_w))
    h = min(config.SCREEN_HEIGHT - 2 * sd(margin), sd(base_h))
    x = (config.SCREEN_WIDTH - w) // 2
    y = (config.SCREEN_HEIGHT - h) // 2
    return pygame.Rect(x, y, w, h)


def blit_fit_center(surface, text_surf, max_w: int, center) -> None:
    """Blit *text_surf* centered, shrunk to fit *max_w* (preserves aspect)."""
    w = text_surf.get_width()
    if w > max_w > 0:
        f = max_w / w
        text_surf = pygame.transform.smoothscale(
            text_surf, (int(max_w), max(1, int(text_surf.get_height() * f))))
    surface.blit(text_surf, text_surf.get_rect(center=center))


def make_bg_surface() -> pygame.Surface:
    """Noir ledger backdrop — ink base with smoke gradient (Phase 127)."""
    w, h = config.SCREEN_WIDTH, config.SCREEN_HEIGHT
    surf = pygame.Surface((w, h))
    surf.fill(theme.NOIR_INK)
    grad = pygame.Surface((w, h), pygame.SRCALPHA)
    for y in range(0, h, 2):
        t = y / max(1, h)
        a = int(10 + 22 * t)
        pygame.draw.line(grad, (*theme.NOIR_SMOKE, a), (0, y), (w, y), 2)
    surf.blit(grad, (0, 0))
    for gy in range(0, h, 52):
        pygame.draw.line(surf, (*theme.NOIR_GOLD, 6), (0, gy), (w, gy))
    return surf


# Phase 127 — procedural grain + vignette (code-drawn, no image assets)
_GRAIN_CACHE: dict = {'w': 0, 'h': 0, 'surf': None}
_VIGNETTE_CACHE: dict = {'w': 0, 'h': 0, 'surf': None}


def invalidate_atmosphere_cache() -> None:
    _GRAIN_CACHE['surf'] = None
    _VIGNETTE_CACHE['surf'] = None


def _get_grain_surface(w: int, h: int) -> pygame.Surface:
    if _GRAIN_CACHE['surf'] is not None and _GRAIN_CACHE['w'] == w and _GRAIN_CACHE['h'] == h:
        return _GRAIN_CACHE['surf']
    import random
    grain = pygame.Surface((w, h), pygame.SRCALPHA)
    rng = random.Random(127)
    n = max(800, (w * h) // 900)
    for _ in range(n):
        x, y = rng.randint(0, w - 1), rng.randint(0, h - 1)
        a = rng.randint(6, 22)
        grain.set_at((x, y), (220, 210, 195, a))
    _GRAIN_CACHE.update({'w': w, 'h': h, 'surf': grain})
    return grain


def _get_vignette_surface(w: int, h: int) -> pygame.Surface:
    if _VIGNETTE_CACHE['surf'] is not None and _VIGNETTE_CACHE['w'] == w and _VIGNETTE_CACHE['h'] == h:
        return _VIGNETTE_CACHE['surf']
    vig = pygame.Surface((w, h), pygame.SRCALPHA)
    steps = 14
    for i in range(steps):
        alpha = int(4 + i * 3.2)
        inset = i * max(8, min(w, h) // 28)
        if inset * 2 >= w or inset * 2 >= h:
            break
        inner = pygame.Rect(inset, inset, w - inset * 2, h - inset * 2)
        frame = pygame.Rect(0, 0, w, h)
        # Top/bottom/left/right edge bands
        top = pygame.Rect(0, 0, w, max(1, inner.y))
        bot = pygame.Rect(0, inner.bottom, w, h - inner.bottom)
        left = pygame.Rect(0, inner.y, inner.x, inner.height)
        right = pygame.Rect(inner.right, inner.y, w - inner.right, inner.height)
        for band in (top, bot, left, right):
            if band.width > 0 and band.height > 0:
                s = pygame.Surface((band.width, band.height), pygame.SRCALPHA)
                s.fill((0, 0, 0, alpha))
                vig.blit(s, band.topleft)
    _VIGNETTE_CACHE.update({'w': w, 'h': h, 'surf': vig})
    return vig


def draw_noir_atmosphere(surface: pygame.Surface) -> None:
    """Film grain + edge vignette over the full frame."""
    w, h = surface.get_size()
    surface.blit(_get_grain_surface(w, h), (0, 0))
    surface.blit(_get_vignette_surface(w, h), (0, 0))


def _draw_noir_corners(surface: pygame.Surface, rect: pygame.Rect,
                       col=None, arm: int = 7) -> None:
    col = col or theme.NOIR_GOLD_BRIGHT
    for fx, fy, dx, dy in (
        (rect.x, rect.y, 1, 1),
        (rect.right, rect.y, -1, 1),
        (rect.x, rect.bottom, 1, -1),
        (rect.right, rect.bottom, -1, -1),
    ):
        pygame.draw.line(surface, col, (fx, fy), (fx + dx * arm, fy), 1)
        pygame.draw.line(surface, col, (fx, fy), (fx, fy + dy * arm), 1)


# ─────────────────────────── TOOLTIP SYSTEM ────────────────────────

_TOOLTIPS: dict[str, str] = {
    'heat':       "HEAT — rises as you operate. Above 60% triggers police raids that steal balance. "
                  "Crew and territories reduce heat. Federal Informants passively increase it.",
    'influence':  "INFLUENCE (Prestige Tokens) — the meta-currency. Spend it in the Prestige "
                  "Tree, to gate elite territories, and it sets your Rank. Earned from "
                  "prestiging, plus +1 per rival/territory/operation win.",
    'respect':    "RESPECT — your street reputation, earned from operations, territory, and "
                  "rivals. Each 25 Respect grants +1% global income (capped at +50%). "
                  "It accumulates permanently — even through prestige.",
    'power':      "RIVAL POWER — how strong a faction is militarily. High power reduces your "
                  "territory action success rates by up to 30%. Reduce it via attack or sabotage.",
    'aggression': "RIVAL AGGRESSION — probability of raiding you each AI tick. Aggressive "
                  "rivals raid more often and cause larger cash penalties.",
    'territory':  "TERRITORY — districts you control grant passive income, click, and heat "
                  "bonuses. Rivals also own territories; capturing theirs weakens them.",
    'crew':       "CREW — assigned from your total workers across 5 roles. "
                  "Protection reduces raid damage. Collection boosts income. "
                  "Smuggling boosts operation rewards. Territory adds action success. "
                  "Heat Reduction slowly lowers your heat passively.",
    'manager':    "MANAGERS — one per building. Hiring a manager automates it (no clicking needed) "
                  "and grants +1.5× income to that building permanently.",
    'operation':  "OPERATIONS — timed missions that pay out after a delay. Success chance is "
                  "affected by heat, Federal Informants, and whether you own the Waterfront.",
    'wealth':     "RIVAL WEALTH — a faction's financial reserves. Wealthy rivals have better "
                  "defenses (harder to bribe) and field stronger raids. Drain it via sabotage.",
    'prestige':   "PRESTIGE — reset your run to convert lifetime earnings into Influence "
                  "(Prestige Tokens) and a permanent income multiplier. Each reset escalates "
                  "and makes you stronger; perks, Influence, and Respect all carry forward.",
}

_tooltip_text: str | None = None
_tooltip_rect: pygame.Rect | None = None


def set_tooltip(key: str | None) -> None:
    """Set active tooltip by key. Pass None to clear."""
    global _tooltip_text, _tooltip_rect
    _tooltip_text = _TOOLTIPS.get(key, None) if key else None
    _tooltip_rect = None


def set_tooltip_text(text: str | None) -> None:
    """Set active tooltip to arbitrary text (for dynamic/computed tooltips)."""
    global _tooltip_text, _tooltip_rect
    _tooltip_text = text
    _tooltip_rect = None


def clear_tooltip() -> None:
    """Reset tooltip state — call once per frame before hover checks."""
    global _tooltip_text, _tooltip_rect
    _tooltip_text = None
    _tooltip_rect = None


def draw_tooltip(surface: pygame.Surface, fonts: dict) -> None:
    """Render the active tooltip near the mouse cursor. Call last in draw chain."""
    if not _tooltip_text:
        return
    mx, my = pygame.mouse.get_pos()
    max_w = 340
    line_h = fonts['xs'].get_height() + 3
    pad    = 8

    words = _tooltip_text.split()
    lines: list[str] = []
    cur = ""
    for w in words:
        test = (cur + " " + w).strip()
        if fonts['xs'].size(test)[0] <= max_w - pad * 2:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)

    box_w = max_w
    box_h = len(lines) * line_h + pad * 2

    tx = mx + 14
    ty = my - box_h - 10
    if tx + box_w > config.SCREEN_WIDTH - 4:
        tx = mx - box_w - 14
    tx = max(4, min(tx, config.SCREEN_WIDTH - box_w - 4))
    if ty < HEADER_H + 4:
        ty = my + 16
    ty = max(4, min(ty, config.SCREEN_HEIGHT - box_h - 4))

    bg = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
    pygame.draw.rect(bg, (*theme.NOIR_GLASS, 235), bg.get_rect(), border_radius=8)
    pygame.draw.rect(bg, (*theme.NOIR_GOLD, 120), bg.get_rect(), border_radius=8, width=1)
    surface.blit(bg, (tx, ty))

    cy = ty + pad
    for line in lines:
        ls = fonts['xs'].render(line, True, theme.NOIR_BONE)
        surface.blit(ls, (tx + pad, cy))
        cy += line_h


# ─────────────────────────── NEWS TICKER ───────────────────────────
_TICKER_SPEED = 85
_TICKER_CACHE: dict = {'idx': -1, 'surf': None, 'uw': 1}

# ─── Surface caches (avoid per-frame allocations) ──────────────────────────────
# Notification surface — one reusable SRCALPHA surface per notification slot.
_NOTIF_SURF: pygame.Surface | None = None

# Stats tab virtual surface — rebuilt on a 200ms timer instead of every frame.
_STATS_SURF_CACHE: dict = {'surf': None, 'last_t': -9999.0, 'rect_wh': None, 'content_h': 1800}
_STATS_REBUILD_INTERVAL = 0.2   # seconds

# Golden coin surface — one reusable SRCALPHA surface (80×80).
_COIN_SURF: pygame.Surface | None = None

# Orbit ring surface (draw_click_zone) — rebuilt when dimensions change.
_ORBIT_RING_CACHE: dict = {'surf': None, 'wh': None}

# Dot surfaces for orbit ring (3 dots, 10×10 each).
_ORBIT_DOTS: list | None = None

_NEWS = [
    # Classic
    "Local pickpocket hits record numbers — police baffled.",
    "Mayor says crime is down. Our books say otherwise.",
    "Chop shop processing {chop_count} vehicles this week alone.",
    "Front business wins Chamber of Commerce award. No questions asked.",
    "Street dealers report record customer satisfaction.",
    "Empire employs {total_buildings} operatives across all divisions.",
    "Detective assigned to our case found face-down in the harbor.",
    "Money laundering operation rated five stars on Yelp.",
    "Local politician assures city crime is under control — he would know.",
    "Pickpocket union demands dental coverage.",
    "Weekly earnings: {income:.0f}/sec — investors optimistic.",
    "Anonymous tip line receiving suspiciously zero calls.",
    "New front business opening: 'Definitely Just A Bakery'.",
    # Expansion
    "Federal investigation mysteriously disappears. Case closed.",
    "Neighborhood reports unusual prosperity. Nobody asks why.",
    "Anonymous donor funds new community center. Nice guy.",
    "Underground casino reports record attendance. Dress code enforced.",
    "Loan shark office opens 24-hour hotline. For customer convenience.",
    "Nightclub fire inspector found grateful. Inspection passed.",
    "Arms broker denies involvement. 'I sell antiques,' he says.",
    "Dock workers report working nights. No questions asked.",
    "Sports betting ring announces 'customer appreciation week.'",
    "Crime Syndicate HQ listed as consulting firm on LinkedIn.",
    "Police chief retires early. Very generous pension.",
    "City council unanimous: 'No organized crime here.'",
    "Newspaper editor reassigned after investigation story. Editor happy.",
    "FBI tip hotline receives zero calls this quarter.",
    "Rival gang relocates. Voluntarily. They say.",
    "Tax return filed: zero. Accountant is a wizard.",
    "Protection racket expands to new district. Warm welcome received.",
    "Corner dealer wins Yelp 'neighborhood favorite' award.",
    "Pawn shop inventory expands mysteriously overnight.",
    "Judge recuses himself from case. Has a very nice car now.",
    "Prosecutor drops charges. 'Insufficient evidence,' he said.",
    "Casino regulators approve expansion. Regulator spotted at slots.",
    "Nightclub bouncer recognized by Forbes: 'Most Persuasive Employee.'",
    "Informant found with selective amnesia. Doctors baffled.",
    "Bank robbery nearby. Not us this time. Probably.",
    "Mayor wins re-election. Campaign 'generously' funded.",
    "City contract awarded to shell company. Pure coincidence.",
    "Crime rates officially down. Statistics provided by us.",
    "New highway bypass approved. Very convenient for certain trucks.",
    "Import tariffs suspended. Customs officials very understanding.",
    "Port authority audit cancelled. Fire, apparently.",
    "Undercover officer identified. Now on our payroll.",
    "Legal counsel on retainer. Lots of retainer.",
    "Burner phones selling out citywide. Demand mysterious.",
    "Concrete supplier reporting record orders. Heavy industry booming.",
    "Safe manufacturer sees 400% revenue spike. Home security trending.",
    "Shredder sales up citywide. Document management is important.",
    "Coin laundry opens 47th location. Very popular.",
    "Construction permits approved same-day. City very efficient.",
    "Offshore account interest earned: {income:.0f}/sec. Investment pays.",
    "New manager hired. References: impeccable. Past: unverifiable.",
    "Building count: {total_buildings}. Growth: aggressive.",
    "Lifetime earnings approaching {balance:.0f}. Diversification working.",
    "Golden coin spotted. Free money for fast fingers.",
    "Prestige token value appreciating. Experts say buy.",
    "All managers reporting zero complaints. Workers love us.",
    "Street network expanded. No resistance encountered.",
    "Protection rates revised upward. Clients accept terms.",
    "Casino floor expanded. House edge unchanged at: favorable.",
    "Weekly numbers look good. Very good.",
    "Nobody is asking where the money comes from. Progress.",
    "City beautification project funded anonymously. Thank you, us.",
    "Neighborhood watch disbanded. Budget cuts, they say.",
    "CCTV cameras offline this weekend. Maintenance.",
    "School named after us. Charitable giving works.",
    "Hospital wing donated. Goodwill is an investment.",
    "The empire never sleeps. Income: {income:.0f}/sec.",
    "Chop count this week: {chop_count}. Volume discounts apply.",
    "Whispers downtown: 'Don't mess with the boss.'",
    "New district opened for business. Very business-friendly.",
    "Year-end report: exceptional. CFO says keep it up.",
    "Security upgraded at all locations. Nobody asking why.",
    "Employee loyalty at all-time high. Incentive structure revised.",
    "Competitors disappearing from market. Consolidation happening.",
    "Market share: growing. Details: classified.",
    "Legal department expanded. Preventive measure.",
    "PR team wins award. 'Best Narrative Management 5 years running.'",
    "Charity gala raises millions. Optics: immaculate.",
    "City endorses new development plan. Endorsed by us.",
    "Black market prices stabilize. Supply: consistent.",
    "National guard deployed elsewhere. Convenient timing.",
    "Revenue up. Costs down. Profit: classified.",
    "New shell company registered. Business is booming.",
    "Accountant requests 3-week vacation. Approved. He earned it.",
    "International wire transfers smooth. Correspondent banks cooperative.",
    "Offshore holdings diversified. Volatility: hedged.",
    "Quarterly review: all green. Green like money.",
    "Footprint expanding. Quietly.",
    "Street presence maintained. Message received by everyone.",
    "No comment. — Management",
    "Crime? What crime? — Public Relations",
    "We're just businesspeople. — The Boss",
    # Heat & territory headlines
    "Heat rising downtown. Authorities paying attention.",
    "Territorial expansion confirmed. Rivals retreating.",
    "South Side consolidated. Operations stable.",
    "Heat at critical levels — lawyers on standby.",
    "Downtown revenue streams secured. Permit filed.",
    "Industrial district acquisition complete. Discreet.",
    "Waterfront operations: smooth sailing, no manifest.",
    "City Hall cooperation assured. Signed, sealed, delivered.",
    "HEAT ALERT: Police mobilizing. Stay low.",
    "Heat cooling — lawyer earned his retainer today.",
    "Chop shop jackpot reported. Parts division profitable.",
    "Betting ring pays out. Odds were: ours.",
    "Syndicate event averted. Outcome: favorable.",
    "Rival approached with offer. Counter-offered. They accepted.",
    "Opportunity seized. Team acted decisively.",
]


def _ticker_msg(state) -> str:
    idx  = state._ticker_idx % len(_NEWS)
    tmpl = _NEWS[idx]
    chop_count = state.buildings[2].owned if len(state.buildings) > 2 else 0
    total_buildings = sum(b.owned for b in state.buildings)
    heat = getattr(state, 'heat', 0.0)
    territories = getattr(state, 'territories', [])
    turf_count = sum(1 for t in territories if t.unlocked)
    try:
        return tmpl.format(
            chop_count=chop_count,
            total_buildings=total_buildings,
            balance=state.balance,
            income=state.income_per_second,
            heat=heat,
            turf=turf_count,
        )
    except (KeyError, ValueError):
        return tmpl


# ─────────────────────── animated bg glow circles ──────────────────
_GLOW_SURFS: list | None = None

def _glow_surfs() -> list:
    global _GLOW_SURFS
    if _GLOW_SURFS is None:
        specs = [(240, 10), (270, 9), (190, 8)]
        _GLOW_SURFS = []
        for r, a in specs:
            s = pygame.Surface((r * 2 + 4, r * 2 + 4), pygame.SRCALPHA)
            pygame.draw.circle(s, (*theme.BLUE_MID, a), (r + 2, r + 2), r)
            _GLOW_SURFS.append((s, r))
    return _GLOW_SURFS

_BUFF_COLORS = {
    'frenzy':      theme.ACCENT,
    'lucky':       theme.GREEN,
    'click_storm': theme.CLICK_STORM,
    'hustle':      theme.TEXT_GOLD,
}


# ─────────────────────────────── background ────────────────────────────
def draw_background(surface: pygame.Surface, state) -> None:
    surface.blit(state._bg, (0, 0))
    t = getattr(state, '_time', 0.0)
    circles = [
        (200, 280, 0.12, 0.09, 0.0),
        (620, 190, 0.10, 0.08, 2.1),
        (510, 460, 0.11, 0.07, 4.3),
    ]
    for (base_cx, base_cy, fx, fy, ph), (surf, r) in zip(circles, _glow_surfs()):
        cx = int(base_cx + 28 * math.sin(t * fx + ph))
        cy = int(base_cy + 22 * math.sin(t * fy + ph + 1.0))
        surface.blit(surf, (cx - r - 2, cy - r - 2))
    # Crimson smoke drift (heat-adjacent atmosphere, presentation only)
    heat = float(getattr(state, 'heat', 0.0))
    if heat >= 15:
        sm = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
        a = int(min(28, heat * 0.22))
        sm.fill((*theme.NOIR_CRIMSON, a // 3))
        surface.blit(sm, (0, 0))
    draw_noir_atmosphere(surface)


# ─────────────────────────── stats bar (Phase 122 command center) ─
# Automation chip definitions: (manager name, abbrev, color)
_AUTOMATION_CHIPS = [
    ("Lucky Sal",        "SAL",  theme.NOIR_GOLD_BRIGHT),
    ("The Mechanic",     "MECH", theme.GREEN),
    ("The Accountant",   "ACC",  theme.BLUE_BRIGHT),
    ("The Promoter",     "PROM", theme.CRIT_COLOR),
    ("The Smuggler",     "SMUG", theme.PARTICLE_IDLE),
]


def _draw_glass_panel(surface: pygame.Surface, rect: pygame.Rect,
                      fill_alpha: int = 200) -> None:
    """Semi-transparent glass card with gold hairline (noir styling)."""
    glass = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
    pygame.draw.rect(glass, (*theme.NOIR_GLASS, fill_alpha), glass.get_rect(),
                     border_radius=sd(6))
    pygame.draw.rect(glass, (*theme.NOIR_GOLD, 55), glass.get_rect(),
                     border_radius=sd(6), width=1)
    surface.blit(glass, rect.topleft)
    shadow = pygame.Surface((rect.width, max(2, sd(3))), pygame.SRCALPHA)
    shadow.fill((0, 0, 0, 45))
    surface.blit(shadow, (rect.x, rect.bottom - shadow.get_height()))


def _draw_dossier_panel_bg(surface: pygame.Surface, rect: pygame.Rect) -> None:
    """Right-panel case-file backdrop (Phase 127)."""
    pygame.draw.rect(surface, theme.NOIR_INK_2, rect)
    inner = rect.inflate(-2, -2)
    pygame.draw.rect(surface, (*theme.NOIR_GOLD, 35), inner, width=1)
    _draw_noir_corners(surface, inner)


def _draw_dossier_tab(surface: pygame.Surface, rect: pygame.Rect, label: str,
                      fonts: dict, active: bool, hover: bool) -> None:
    """Case-file tab — display label, gold rule when active."""
    disp = fonts.get('disp_xs', fonts['xs'])
    label_up = label.upper()
    tab = pygame.Rect(rect.x + 1, rect.y + 3, rect.width - 2, rect.height - 5)
    if active:
        _draw_glass_panel(surface, tab, fill_alpha=210)
        pygame.draw.line(surface, theme.NOIR_GOLD_BRIGHT,
                         (tab.x + 4, tab.bottom - 1), (tab.right - 4, tab.bottom - 1), 2)
        tc = theme.NOIR_GOLD_BRIGHT
    elif hover:
        hs = pygame.Surface((tab.width, tab.height), pygame.SRCALPHA)
        pygame.draw.rect(hs, (*theme.NOIR_GLASS, 150), hs.get_rect(), border_radius=4)
        surface.blit(hs, tab.topleft)
        tc = theme.NOIR_BONE
    else:
        tc = theme.NOIR_BONE_DIM
    ts = disp.render(label_up, True, tc)
    surface.blit(ts, ts.get_rect(center=tab.center))


def _truncated_render(font, text: str, max_w: int, color: tuple):
    """Render text truncated with ellipsis to fit max_w."""
    surf = font.render(text, True, color)
    if surf.get_width() <= max_w:
        return surf
    for end in range(len(text), 0, -1):
        surf = font.render(text[:end] + "…", True, color)
        if surf.get_width() <= max_w:
            return surf
    return font.render("…", True, color)


def _header_primary_goal(state) -> str:
    """Single emphasized objective for the command strip."""
    goals = goals_mod.current_goals(state, max_count=1)
    if goals:
        g = goals[0]
        return (getattr(g, 'narrative', '') or g.label).strip()
    hint = goals_mod.next_focus_hint(state)
    if hint:
        return hint
    next_info = prestige.get_next_rank(state.prestige_tokens)
    if next_info:
        return f"Reach {next_info[0]}"
    return ""


def _header_ops_chip(state) -> tuple[str, bool, str] | None:
    """Return (label, is_ready_pulse, tooltip) for active operations, or None."""
    ops = getattr(state, 'operations', []) or []
    ready = [op for op in ops if op.is_ready]
    if ready:
        n = len(ready)
        lbl = "OP READY" if n == 1 else f"OP ×{n} READY"
        return lbl, True, "Operation ready to collect — open Turf → Ops"
    active = [op for op in ops if op.active and not op.collected and not op.is_ready]
    if active:
        best = min(active, key=lambda o: max(0.0, o._eff_duration - o.elapsed))
        rem = max(0.0, best._eff_duration - best.elapsed)
        return f"OP {rem:.0f}s", False, f"{best.name} in progress"
    return None


def _automation_chip_list(state) -> list[tuple[str, str, tuple, str]]:
    """Active hired automation managers as (abbrev, manager_name, color, tooltip)."""
    chips = []
    for name, abbrev, col in _AUTOMATION_CHIPS:
        if mgr_mod.manager_active(state, name):
            mgr = next((m for m in state.managers if m.name == name), None)
            tip = mgr.specialty if mgr else name
            chips.append((abbrev, name, col, tip))
    return chips


def _draw_vdivider(surface: pygame.Surface, x: int, y0: int, y1: int) -> None:
    div = pygame.Surface((1, y1 - y0), pygame.SRCALPHA)
    div.fill((*theme.NOIR_GOLD, 40))
    surface.blit(div, (x, y0))


def _draw_status_chip(surface: pygame.Surface, rect: pygame.Rect, label: str,
                      fonts: dict, color: tuple, pulse: bool, t: float,
                      tooltip: str = "") -> None:
    """Small glass badge for OP / automation abbreviations."""
    mx, my = pygame.mouse.get_pos()
    hover = rect.collidepoint(mx, my)
    if hover and tooltip:
        set_tooltip_text(tooltip)

    bg_a = 230 if hover else 200
    if pulse:
        bg_a = int(175 + 55 * (0.5 + 0.5 * math.sin(t * 4.5)))
    chip = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
    fill = tuple(int(c * 0.35) for c in color)
    pygame.draw.rect(chip, (*fill, bg_a), chip.get_rect(), border_radius=sd(4))
    border_a = 200 if pulse else 120
    pygame.draw.rect(chip, (*color, border_a), chip.get_rect(), border_radius=sd(4), width=1)
    surface.blit(chip, rect.topleft)
    ls = fonts['xs'].render(label, True, color if pulse else theme.NOIR_BONE)
    surface.blit(ls, ls.get_rect(center=rect.center))


def _draw_shield_indicator(surface: pygame.Surface, x: int, y: int, h: int,
                           fraction: float, fonts: dict, t: float) -> int:
    """Collector shield pips; returns width used."""
    label = fonts['disp_xs'].render("SHIELD", True, theme.BLUE_BRIGHT)
    surface.blit(label, (x, y))
    px = x + label.get_width() + sx(6)
    py = y + label.get_height() // 2
    pip_r = sd(4)
    gap = sd(5)
    filled = 3 if fraction >= 1.0 else max(0, int(round(fraction * 3)))
    pulse = fraction >= 1.0 and math.sin(t * 3.0) > 0.6
    for i in range(3):
        cx = px + i * (pip_r * 2 + gap)
        col = theme.BLUE_BRIGHT if i < filled else (40, 45, 65)
        if i < filled and pulse:
            glow = pygame.Surface((pip_r * 4, pip_r * 4), pygame.SRCALPHA)
            pygame.draw.circle(glow, (*theme.BLUE_BRIGHT, 90), (pip_r * 2, pip_r * 2), pip_r + 2)
            surface.blit(glow, (cx - pip_r * 2, py - pip_r * 2))
        pygame.draw.circle(surface, col, (cx, py), pip_r)
        if i < filled:
            pygame.draw.circle(surface, theme.TEXT_PRIMARY, (cx, py), pip_r, 1)
    total_w = label.get_width() + sx(6) + 3 * (pip_r * 2 + gap)
    mx, my = pygame.mouse.get_pos()
    if pygame.Rect(x, y, total_w, h).collidepoint(mx, my):
        pct = int(fraction * 100)
        set_tooltip_text(f"Collector shield — {pct}% raid protection ready")
    return total_w


def draw_stats(surface: pygame.Surface, state, fonts: dict) -> None:
    """Phase 122 — two-strip command center header + ticker slot."""
    w = config.SCREEN_WIDTH
    t = getattr(state, '_time', 0.0)

    # Noir header backdrop
    pygame.draw.rect(surface, theme.NOIR_INK, pygame.Rect(0, 0, w, HEADER_H))
    grad = pygame.Surface((w, STRIP1_H), pygame.SRCALPHA)
    for i in range(STRIP1_H):
        a = int(28 * (1 - i / max(1, STRIP1_H)))
        pygame.draw.line(grad, (*theme.NOIR_SMOKE, a), (0, i), (w, i))
    surface.blit(grad, (0, 0))

    _draw_command_strip(surface, state, fonts, t)
    _draw_status_strip(surface, state, fonts, t)

    # Strip divider + bottom border
    div_y = STRIP1_H + STRIP2_H
    div = pygame.Surface((w, 1), pygame.SRCALPHA)
    div.fill((*theme.NOIR_GOLD, 50))
    surface.blit(div, (0, div_y))
    border = pygame.Surface((w, 1), pygame.SRCALPHA)
    border.fill((*theme.NOIR_GOLD_DEEP, 90))
    surface.blit(border, (0, HEADER_H))


def _draw_command_strip(surface: pygame.Surface, state, fonts: dict, t: float) -> None:
    """Strip 1 — money, income, rank, single next goal."""
    y0, h = 0, STRIP1_H
    pad = sx(8)
    right = config.SCREEN_WIDTH - pad

    # ── Rank + goal block (right-anchored so huge income never overlaps) ──
    if state._buffs:
        right -= sx(108)
    goal_text = _header_primary_goal(state) or "Expand the empire"
    goal_lbl = fonts['disp_xs'].render("NEXT GOAL", True, theme.NOIR_GOLD)
    goal_s = _truncated_render(fonts['disp_sm'], goal_text, sx(220), theme.NOIR_BONE)
    goal_block_w = max(goal_lbl.get_width(), goal_s.get_width(), sx(120))
    rank = prestige.get_rank(state.prestige_tokens)
    rank_lbl = fonts['disp_xs'].render("RANK", True, theme.NOIR_GOLD)
    rank_name = fonts['disp_sm'].render(rank.upper(), True, theme.NOIR_BONE)
    rank_block_w = max(rank_lbl.get_width(), rank_name.get_width(), sx(96))
    rank_x = right - rank_block_w
    goal_x = rank_x - sx(14) - goal_block_w

    min_goal_x = pad + sx(205)
    if goal_x < min_goal_x:
        shift = min_goal_x - goal_x
        goal_x += shift
        rank_x += shift

    surface.blit(goal_lbl, (goal_x, y0 + sd(5)))
    surface.blit(goal_s, (goal_x, y0 + sd(20)))
    surface.blit(rank_lbl, (rank_x, y0 + sd(5)))
    surface.blit(rank_name, (rank_x, y0 + sd(17)))
    bar_y = min(y0 + h - sd(7), y0 + sd(34))
    _draw_rank_progress_compact(surface, state, fonts, rank_x, bar_y)

    if goal_x > pad + sx(200):
        _draw_vdivider(surface, goal_x - sx(8), y0 + sd(8), y0 + h - sd(8))

    # ── Money (glass panel) ──
    money_w = min(sx(210), max(sx(130), goal_x - pad - sx(12)))
    money_r = pygame.Rect(pad, y0 + sd(5), money_w, h - sd(10))
    _draw_glass_panel(surface, money_r)
    coin_cx = money_r.x + sd(22)
    coin_cy = money_r.centery
    pygame.draw.circle(surface, theme.NOIR_GOLD, (coin_cx, coin_cy), sd(13))
    pygame.draw.circle(surface, theme.NOIR_GOLD_DEEP, (coin_cx, coin_cy), sd(8))
    cs = fonts['xs'].render("$", True, theme.NOIR_INK)
    surface.blit(cs, cs.get_rect(center=(coin_cx, coin_cy)))
    bal_x = coin_cx + sd(18)
    bal_max_w = money_r.right - bal_x - sd(4)
    bal_s = _truncated_render(
        fonts['lg'], theme.format_number(state.balance), bal_max_w, theme.NOIR_GOLD_BRIGHT)
    surface.blit(bal_s, (bal_x, money_r.y + sd(4)))

    # ── Income (between money panel and goal block) ──
    inc_x = money_r.right + sx(10)
    inc_max_w = max(sx(60), goal_x - inc_x - sx(12))
    inc_lbl = fonts['disp_xs'].render("INCOME", True, theme.NOIR_BONE_DIM)
    surface.blit(inc_lbl, (inc_x, y0 + sd(8)))
    inc_val = _truncated_render(
        fonts['sm'],
        f"{theme.format_number(state.income_per_second)}/sec",
        inc_max_w,
        theme.NOIR_BONE,
    )
    surface.blit(inc_val, (inc_x, y0 + sd(24)))
    if state.prestige_tokens > 0:
        mult = prestige.income_mult(state.prestige_tokens)
        mult_s = fonts['xs'].render(f"×{mult:.2f}", True, theme.PRESTIGE_LABEL)
        mx = inc_x + min(inc_val.get_width(), inc_max_w) + sx(4)
        if mx + mult_s.get_width() < goal_x - sx(8):
            surface.blit(mult_s, (mx, y0 + sd(26)))

    if state._buffs:
        _draw_buff_pill(surface, state, fonts)


def _draw_rank_progress_compact(surface: pygame.Surface, state, fonts: dict,
                                x: int, y: int) -> None:
    """Mini rank progress bar under the rank name."""
    tokens = state.prestige_tokens
    next_info = prestige.get_next_rank(tokens)
    bar_w = sx(96)
    bar_h = sd(4)
    if next_info is None:
        return
    next_rank, next_thresh = next_info
    cur_thresh = 0
    for threshold, label in prestige.HIERARCHY:
        if tokens >= threshold:
            cur_thresh = threshold
        else:
            break
    span = max(1, next_thresh - cur_thresh)
    progress = min(1.0, (tokens - cur_thresh) / span)
    track = pygame.Surface((bar_w, bar_h), pygame.SRCALPHA)
    pygame.draw.rect(track, (30, 28, 38, 220), track.get_rect(), border_radius=2)
    surface.blit(track, (x, y))
    if progress > 0:
        fill_w = max(2, int(bar_w * progress))
        col = theme.NOIR_GOLD if progress < 0.9 else theme.NOIR_GOLD_BRIGHT
        fill = pygame.Surface((fill_w, bar_h), pygame.SRCALPHA)
        pygame.draw.rect(fill, (*col, 230), fill.get_rect(), border_radius=2)
        surface.blit(fill, (x, y))
    mx, my = pygame.mouse.get_pos()
    if pygame.Rect(x, y - sd(20), bar_w, sd(28)).collidepoint(mx, my):
        set_tooltip_text(f"→ {next_rank}  {tokens}/{next_thresh} Influence")


def _draw_status_strip(surface: pygame.Surface, state, fonts: dict, t: float) -> None:
    """Strip 2 — heat, shield, operations, automation employee chips."""
    y0 = STRIP1_H
    h = STRIP2_H
    pad = sx(8)
    x = pad

    # Subtle strip background
    strip_bg = pygame.Surface((config.SCREEN_WIDTH, h), pygame.SRCALPHA)
    strip_bg.fill((*theme.NOIR_SMOKE, 180))
    surface.blit(strip_bg, (0, y0))

    # ── Heat ──
    heat = getattr(state, 'heat', 0.0)
    col = heat_mod.heat_color(heat)
    heat_lbl = fonts['disp_xs'].render("HEAT", True, theme.NOIR_BONE_DIM)
    surface.blit(heat_lbl, (x, y0 + sd(4)))
    pct_s = fonts['xs'].render(f"{heat:.0f}%", True, col)
    surface.blit(pct_s, (x + heat_lbl.get_width() + sx(4), y0 + sd(5)))

    bar_w = sx(100)
    bar_h = sd(6)
    bx = x
    by = y0 + sd(18)
    track = pygame.Surface((bar_w, bar_h), pygame.SRCALPHA)
    pygame.draw.rect(track, (25, 22, 32, 220), track.get_rect(), border_radius=3)
    surface.blit(track, (bx, by))
    fill_w = max(2, int(bar_w * heat / 100.0))
    fill = pygame.Surface((fill_w, bar_h), pygame.SRCALPHA)
    pygame.draw.rect(fill, (*col, 230), fill.get_rect(), border_radius=3)
    surface.blit(fill, (bx, by))
    tick_x = bx + int(bar_w * 0.60)
    pygame.draw.line(surface, theme.NOIR_CRIMSON, (tick_x, by - 1), (tick_x, by + bar_h + 1), 2)
    if heat >= 60:
        warn = fonts['xs'].render("RAIDS", True, theme.NOIR_CRIMSON)
        surface.blit(warn, (bx + bar_w + sx(6), y0 + sd(14)))

    mx, my = pygame.mouse.get_pos()
    heat_hit = pygame.Rect(x, y0, bar_w + sx(50), h)
    if heat_hit.collidepoint(mx, my):
        set_tooltip('heat')

    x = bx + bar_w + sx(36)

    # Carl forecast (compact, near heat)
    if mgr_mod.manager_active(state, "Clean Carl"):
        delta = mgr_mod.heat_forecast_delta(state, 120.0)
        if abs(delta) >= 0.5:
            sign = '+' if delta >= 0 else ''
            fc = fonts['xs'].render(f"{sign}{delta:.0f}/2m", True, theme.NOIR_GOLD)
            surface.blit(fc, (x, y0 + sd(12)))
            x += fc.get_width() + sx(8)

    # ── Collector shield ──
    if mgr_mod.manager_active(state, "The Collector"):
        shield = mgr_mod.collector_shield_fraction(state)
        used = _draw_shield_indicator(surface, x, y0 + sd(6), h, shield, fonts, t)
        x += used + sx(12)

    # ── Operations chip ──
    ops_info = _header_ops_chip(state)
    if ops_info:
        lbl, pulse, tip = ops_info
        chip_w = max(sd(52), fonts['xs'].size(lbl)[0] + sd(14))
        chip_r = pygame.Rect(x, y0 + sd(5), chip_w, h - sd(10))
        col = theme.GREEN if pulse else theme.NOIR_GOLD
        _draw_status_chip(surface, chip_r, lbl, fonts, col, pulse, t, tip)
        x += chip_w + sx(6)

    # ── Automation / employee chips (right-aligned) ──
    chips = _automation_chip_list(state)
    chip_w = sd(42)
    chip_h = h - sd(10)
    chip_gap = sd(4)
    total = 0
    if chips:
        total = len(chips) * chip_w + (len(chips) - 1) * chip_gap
        cx = config.SCREEN_WIDTH - pad - total
        min_cx = x + sx(120)
        if cx < min_cx:
            cx = min_cx
        cy = y0 + sd(5)
        for abbrev, mgr_name, col, tip in chips:
            cr = pygame.Rect(cx, cy, chip_w, chip_h)
            _draw_status_chip(surface, cr, abbrev, fonts, col, False, t,
                              f"{mgr_name} — active. {tip}")
            cx += chip_w + chip_gap

    # Promoter heat target — left of automation chips
    if mgr_mod.manager_active(state, "The Promoter"):
        tgt = int(mgr_mod.promoter_heat_target(state))
        pt = fonts['xs'].render(f"≤{tgt}%", True, theme.BLUE_BRIGHT)
        pt_x = config.SCREEN_WIDTH - pad - total - pt.get_width() - sx(8) if chips else x
        if pt_x > x + sx(20):
            surface.blit(pt, (pt_x, y0 + sd(12)))


def _draw_buff_pill(surface: pygame.Surface, state, fonts: dict) -> None:
    b = state._buffs[0]
    remaining = b['remaining']
    total = b.get('total', max(remaining, 1))
    color = _BUFF_COLORS.get(b['name'], theme.TEXT_MUTED)
    label = b['name'].replace('_', ' ').title()
    text = fonts['xs'].render(f"{label} {remaining:.0f}s", True, theme.NOIR_GOLD_BRIGHT)
    pw = text.get_width() + sx(14)
    ph = sd(20)
    px = config.SCREEN_WIDTH - pw - sx(8)
    py = sd(8)

    pill = pygame.Surface((pw, ph), pygame.SRCALPHA)
    pygame.draw.rect(pill, (*theme.NOIR_SMOKE, 230), pill.get_rect(), border_radius=sd(10))
    pygame.draw.rect(pill, (*color, 180), pill.get_rect(), border_radius=sd(10), width=1)
    pill.blit(text, text.get_rect(center=(pw // 2, ph // 2)))
    surface.blit(pill, (px, py))

    ratio = remaining / total if total > 0 else 0
    bar_w = int((pw - sx(6)) * ratio)
    if bar_w > 0:
        bar_surf = pygame.Surface((bar_w, sd(2)), pygame.SRCALPHA)
        bar_surf.fill((*color, 160))
        surface.blit(bar_surf, (px + sx(3), py + ph - sd(3)))


def _draw_header_heat(surface: pygame.Surface, state, fonts: dict) -> None:
    """Legacy hook — heat now lives in _draw_status_strip (Phase 122)."""
    pass


def _draw_rank_progress(surface: pygame.Surface, state, fonts: dict) -> None:
    """Legacy hook — rank progress now in command strip (Phase 122)."""
    pass


# ──────────────────────────── ticker ───────────────────────────────
def draw_news_ticker(surface: pygame.Surface, state, fonts: dict) -> None:
    """Ticker lives inside the header at TICKER_Y — never overlaps tabs or content."""
    pygame.draw.rect(surface, theme.NOIR_INK,
                     pygame.Rect(0, TICKER_Y, config.SCREEN_WIDTH, TICKER_H))
    for yy in [TICKER_Y, TICKER_Y + TICKER_H]:
        border = pygame.Surface((config.SCREEN_WIDTH, 1), pygame.SRCALPHA)
        border.fill((*theme.NOIR_GOLD, 35))
        surface.blit(border, (0, yy))

    if _TICKER_CACHE['idx'] != state._ticker_idx:
        msg  = _ticker_msg(state)
        unit = f"  ◆  {msg}  "
        s    = fonts['disp_xs'].render(unit, True, theme.NOIR_BONE_DIM)
        _TICKER_CACHE['surf'] = s
        _TICKER_CACHE['uw']   = max(1, s.get_width())
        _TICKER_CACHE['idx']  = state._ticker_idx

    s  = _TICKER_CACHE['surf']
    uw = _TICKER_CACHE['uw']
    draw_x = int(state._ticker_x) % uw - uw
    text_y = TICKER_Y + (TICKER_H - s.get_height()) // 2
    while draw_x < config.SCREEN_WIDTH:
        surface.blit(s, (draw_x, text_y))
        draw_x += uw


# ──────────────────────────── buffs bar ────────────────────────────
def draw_buffs_bar(surface: pygame.Surface, state, fonts: dict) -> None:
    pass  # buff pill rendered in draw_stats


# draw_heat_bar removed — heat is now inline in draw_stats (see _draw_header_heat)


# ────────────────────────── event outcome ──────────────────────────
def draw_event_outcome(surface: pygame.Surface, state, fonts: dict) -> None:
    """Show a brief outcome message after a syndicate event choice."""
    outcome = getattr(state, '_event_outcome', None)
    if not outcome:
        return
    timer = getattr(state, '_event_outcome_timer', 0.0)
    if timer <= 0:
        return
    alpha = min(255, int(255 * min(1.0, timer / 0.5)))
    s = fonts['sm'].render(f"Outcome: {outcome}", True, theme.TEXT_GOLD)
    s.set_alpha(alpha)
    surface.blit(s, s.get_rect(centerx=config.SCREEN_WIDTH // 2, y=config.SCREEN_HEIGHT - 50))


# ────────────────────────── click glow cache ────────────────────────
_CLICK_GLOW_SURF: pygame.Surface | None = None
_CLICK_GLOW_HOVER: pygame.Surface | None = None

def _ensure_glow() -> None:
    global _CLICK_GLOW_SURF, _CLICK_GLOW_HOVER
    if _CLICK_GLOW_SURF is not None:
        return
    size = 300
    s = pygame.Surface((size, size), pygame.SRCALPHA)
    c = size // 2
    for r, a in [(150, 6), (134, 9), (118, 13), (102, 17), (86, 22), (70, 28), (54, 35)]:
        pygame.draw.circle(s, (*theme.BLUE_BRIGHT, a), (c, c), r)
    _CLICK_GLOW_SURF = s
    h = s.copy(); h.set_alpha(190)
    _CLICK_GLOW_HOVER = h


# ─────────────────────────── click zone (Phase 124 overlay) ────────
def draw_click_zone(surface: pygame.Surface, state, fonts: dict) -> None:
    """Glass hustle control overlaid on the city scene — not a separate menu panel."""
    if _PORTRAIT or _SCENE_RECT.height <= 0:
        return
    r = CLICK_RECT
    mx, my = pygame.mouse.get_pos()
    hover = r.collidepoint(mx, my)
    cx, cy = r.centerx, r.centery
    scale = state._click_scale
    bw = int(r.width * scale)
    bh = int(r.height * scale)
    btn = pygame.Rect(cx - bw // 2, cy - bh // 2, bw, bh)
    br = max(12, bw // 5)
    t = getattr(state, '_time', 0.0)

    # Soft gold pulse when idle income flows
    if getattr(state, 'income_per_second', 0.0) > 0:
        pulse = int(40 + 35 * (0.5 + 0.5 * math.sin(t * 2.2)))
        aura = pygame.Surface((bw + 40, bh + 40), pygame.SRCALPHA)
        pygame.draw.ellipse(aura, (*theme.NOIR_GOLD, pulse),
                            aura.get_rect(), width=2)
        surface.blit(aura, (btn.centerx - aura.get_width() // 2,
                              btn.centery - aura.get_height() // 2))

    # Glass body
    glass = pygame.Surface((bw, bh), pygame.SRCALPHA)
    fill_a = 165 if hover else 120
    pygame.draw.rect(glass, (*theme.NOIR_GLASS, fill_a), glass.get_rect(), border_radius=br)
    border_col = theme.NOIR_GOLD_BRIGHT if hover else theme.NOIR_GOLD
    pygame.draw.rect(glass, (*border_col, 220 if hover else 150),
                     glass.get_rect(), border_radius=br, width=2)
    surface.blit(glass, btn.topleft)

    # Inner ring — reads as street-level interaction, not app button
    inner = btn.inflate(-max(8, bw // 8), -max(8, bh // 8))
    pygame.draw.rect(surface, (*theme.NOIR_GOLD_DEEP, 80), inner, border_radius=br - 4, width=1)

    disp = fonts.get('disp_xs', fonts['xs'])
    lbl = disp.render("HUSTLE", True, theme.NOIR_BONE if not hover else theme.NOIR_GOLD_BRIGHT)
    surface.blit(lbl, lbl.get_rect(center=(cx, cy - sd(10))))
    hint = fonts['sm'].render(f"+{theme.format_number(state.click_value)}",
                              True, theme.NOIR_GOLD_BRIGHT)
    surface.blit(hint, hint.get_rect(center=(cx, cy + sd(14))))

    if hover:
        hint_y = btn.bottom + sd(4)
        if hint_y + fonts['xs'].get_height() <= _SCENE_RECT.bottom - sd(4):
            sub = fonts['xs'].render("tap the street", True, theme.NOIR_BONE_DIM)
            surface.blit(sub, sub.get_rect(midtop=(cx, hint_y)))


# ─────────────────────────── scene panel (Phase 124 city-first) ─────
# _SCENE_RECT is recomputed by reinit_layout(); default matches 900×720 target.
_SCENE_RECT = pygame.Rect(8, SCENE_TOP, 404, 320)


def draw_left_empire_frame(surface: pygame.Surface) -> None:
    """Noir frame around the left-column city viewport."""
    if _PORTRAIT or _SCENE_RECT.height <= 0:
        return
    sr = _SCENE_RECT
    # Side/bottom frame only — avoid overlapping the header ticker strip.
    frame = pygame.Rect(sr.x - 3, sr.y, sr.width + 6, sr.height + 5)
    pygame.draw.rect(surface, theme.NOIR_INK, frame, border_radius=10)
    pygame.draw.rect(surface, (*theme.NOIR_GOLD, 55), frame, border_radius=10, width=1)
    for fx, fy in ((frame.x, frame.y), (frame.right, frame.y),
                   (frame.x, frame.bottom), (frame.right, frame.bottom)):
        pygame.draw.line(surface, theme.NOIR_GOLD_BRIGHT, (fx - 4, fy), (fx + 4, fy), 1)
        pygame.draw.line(surface, theme.NOIR_GOLD_BRIGHT, (fx, fy - 4), (fx, fy + 4), 1)


def _draw_scene_atmosphere(surface: pygame.Surface, sr: pygame.Rect,
                           state, t: float) -> None:
    """Heat smoke, police flash, rank glow — presentation only."""
    if state is None:
        return
    heat = float(getattr(state, 'heat', 0.0))
    sx, sy, sw, sh = sr.x, sr.y, sr.width, sr.height

    if heat >= 25:
        haze_a = int(min(90, (heat - 25) * 1.4))
        haze = pygame.Surface((sw, sh), pygame.SRCALPHA)
        haze.fill((*theme.NOIR_CRIMSON, haze_a // 3))
        surface.blit(haze, (sx, sy))

    if heat >= 40:
        for i in range(3):
            wx = sx + int((sw * (0.2 + i * 0.28) + t * 12 * (i + 1)) % sw)
            wy = sy + sh - int(30 + 20 * math.sin(t * 0.8 + i * 2.1))
            wisp = pygame.Surface((24, 12), pygame.SRCALPHA)
            pygame.draw.ellipse(wisp, (80, 80, 90, 35), wisp.get_rect())
            surface.blit(wisp, (wx, wy))

    if heat >= 60 and int(t * 3) % 2 == 0:
        flash = pygame.Surface((sw, sh), pygame.SRCALPHA)
        flash.fill((40, 60, 180, 18))
        surface.blit(flash, (sx, sy))

    rank = prestige.get_rank(getattr(state, 'prestige_tokens', 0))
    if prestige._rank_index(rank) >= prestige._rank_index("Crime Lord"):
        glow = pygame.Surface((sw, 24), pygame.SRCALPHA)
        glow.fill((*theme.NOIR_GOLD, 25))
        surface.blit(glow, (sx, sy + sh - 44))

    territories = getattr(state, 'territories', []) or []
    owned = sum(1 for t_ in territories if getattr(t_, 'unlocked', False))
    if owned >= 5:
        for i in range(min(owned, 12)):
            lx = sx + 8 + (i * 17) % max(1, sw - 16)
            ly = sy + sh - 28 - (i % 3) * 8
            pygame.draw.circle(surface, (*theme.NOIR_GOLD_BRIGHT, 120), (lx, ly), 2)


def draw_scene(surface: pygame.Surface, total_buildings: int, t: float = 0.0,
               state=None) -> None:
    sr = _SCENE_RECT
    if sr.width <= 0 or sr.height <= 0:
        return
    sx, sy, sw, sh = sr.x, sr.y, sr.width, sr.height

    pygame.draw.rect(surface, theme.NOIR_INK, sr, border_radius=8)
    pygame.draw.rect(surface, (*theme.NOIR_GOLD, 40), sr, border_radius=8, width=1)

    clip = surface.get_clip()
    surface.set_clip(sr)

    ground_y = sy + sh - 20
    sky_h = ground_y - sy
    band0_h = int(sky_h * 0.40)
    band1_h = int(sky_h * 0.20)
    band2_h = sky_h - band0_h - band1_h
    pygame.draw.rect(surface, (8,  10, 25), pygame.Rect(sx, sy,                      sw, band0_h))
    pygame.draw.rect(surface, (15, 18, 40), pygame.Rect(sx, sy + band0_h,            sw, band1_h))
    pygame.draw.rect(surface, (20, 22, 30), pygame.Rect(sx, sy + band0_h + band1_h,  sw, band2_h))

    def _star(rx, ry, i):
        a = int(120 + 100 * math.sin(t * 0.7 + i * 1.7))
        ss = pygame.Surface((2, 2), pygame.SRCALPHA)
        ss.fill((220, 220, 255, a))
        surface.blit(ss, (sx + rx, sy + ry))

    def _lamppost(lx):
        pole_top = ground_y - 70
        pygame.draw.rect(surface, (80, 82, 100), pygame.Rect(lx, pole_top, 3, 70))
        pygame.draw.rect(surface, (80, 82, 100), pygame.Rect(lx - 1, pole_top, 14, 3))
        pygame.draw.circle(surface, (255, 220, 100), (lx + 12, pole_top), 5)
        pool = pygame.Surface((30, 8), pygame.SRCALPHA)
        pygame.draw.ellipse(pool, (255, 220, 80, 50), pool.get_rect())
        surface.blit(pool, (lx - 6, ground_y - 2))

    def _figure(fx, fy, col=(130, 120, 140)):
        pygame.draw.circle(surface, col, (fx, fy - 15), 5)
        pygame.draw.rect(surface, col, pygame.Rect(fx - 4, fy - 10, 8, 13))
        pygame.draw.rect(surface, col, pygame.Rect(fx - 4, fy + 3, 3, 10))
        pygame.draw.rect(surface, col, pygame.Rect(fx + 1, fy + 3, 3, 10))

    def _car(car_x, car_y, col=(120, 25, 25)):
        pygame.draw.rect(surface, col, pygame.Rect(car_x, car_y, 40, 16))
        pygame.draw.rect(surface, tuple(min(255, c + 30) for c in col),
                         pygame.Rect(car_x + 6, car_y - 9, 26, 10), border_radius=3)
        pygame.draw.rect(surface, (160, 190, 210), pygame.Rect(car_x + 8, car_y - 7, 10, 7))
        pygame.draw.rect(surface, (160, 190, 210), pygame.Rect(car_x + 20, car_y - 7, 10, 7))
        pygame.draw.circle(surface, (50, 50, 50), (car_x + 9,  car_y + 16), 5)
        pygame.draw.circle(surface, (50, 50, 50), (car_x + 31, car_y + 16), 5)
        pygame.draw.circle(surface, (85, 85, 85), (car_x + 9,  car_y + 16), 3)
        pygame.draw.circle(surface, (85, 85, 85), (car_x + 31, car_y + 16), 3)

    def _storefront(bx2, bw, bh, col, door=True, sign_col=None):
        pygame.draw.rect(surface, col, pygame.Rect(bx2, ground_y - bh, bw, bh))
        pygame.draw.rect(surface, tuple(min(255, c + 18) for c in col),
                         pygame.Rect(bx2, ground_y - bh, bw, 7))
        if door:
            dw = max(8, bw // 4)
            pygame.draw.rect(surface, (8, 8, 16),
                             pygame.Rect(bx2 + bw // 2 - dw // 2, ground_y - 30, dw, 30))
        for wi in range(2):
            wlx = bx2 + 6 + wi * (bw - 20) // 2
            if wlx + 16 < bx2 + bw:
                pygame.draw.rect(surface, (255, 220, 120),
                                 pygame.Rect(wlx, ground_y - bh + 14, 16, 12))
        if sign_col:
            pygame.draw.rect(surface, sign_col,
                             pygame.Rect(bx2 + 4, ground_y - bh - 7, bw - 8, 6), border_radius=2)

    pygame.draw.rect(surface, (22, 24, 34), pygame.Rect(sx, ground_y, sw, 20))
    pygame.draw.line(surface, (35, 37, 52), (sx, ground_y + 4), (sx + sw, ground_y + 4))

    if total_buildings < 5:
        for i, (rx, ry) in enumerate([(20,8),(55,5),(90,14),(135,7),(190,12),(250,6)]):
            _star(rx, ry, i)
        pygame.draw.rect(surface, (10, 10, 18),
                         pygame.Rect(sx + sw - 55, sy, 55, ground_y - sy))
        _lamppost(sx + 50)
        _figure(sx + 90, ground_y, (100, 95, 115))

    elif total_buildings < 15:
        for i, (rx, ry) in enumerate([(15,6),(60,9),(190,5),(230,12)]):
            _star(rx, ry, i)
        _storefront(sx + 35, 80, 50, (35, 38, 55), sign_col=theme.ACCENT_DIM)
        pygame.draw.rect(surface, theme.BG_DARK,
                         pygame.Rect(sx + 46, ground_y - 62, 58, 10), border_radius=2)
        _lamppost(sx + 18)
        _figure(sx + 145, ground_y, (110, 105, 125))
        _figure(sx + 163, ground_y, (90, 90, 110))

    elif total_buildings < 35:
        for i, (rx, ry) in enumerate([(10,5),(180,8),(240,6)]):
            _star(rx, ry, i)
        _storefront(sx + 4,   70, 60, (36, 40, 58), sign_col=(180, 55, 55))
        _storefront(sx + 82,  80, 70, (30, 34, 52), sign_col=theme.BLUE_BRIGHT)
        _storefront(sx + 172, 64, 55, (38, 42, 60), sign_col=(55, 170, 75))
        _lamppost(sx + sw - 22)
        car_x = sx + int((t * 25) % (sw + 60)) - 30
        _car(car_x, ground_y - 22)
        _figure(sx + 255, ground_y, (110, 105, 125))

    elif total_buildings < 80:
        bldefs = [(sx + 2,   50, 80,  (34, 38, 56)),
                  (sx + 56,  60, 100, (28, 32, 50)),
                  (sx + 122, 48, 80,  (36, 40, 58)),
                  (sx + 176, 58, 95,  (32, 36, 54)),
                  (sx + 240, 44, 72,  (38, 42, 60))]
        for bx2, bw, bh, col in bldefs:
            _storefront(bx2, bw, bh, col)
            pygame.draw.rect(surface, (55, 58, 75),
                             pygame.Rect(bx2 + bw // 2 - 1, ground_y - bh - 10, 2, 10))
            for wy in range(2):
                for wx in range(2):
                    seed = (bx2 // 10 + wx * 3 + wy * 7)
                    lit  = math.sin(t * (1.2 + seed % 3 * 0.4) + seed) > -0.3
                    wc   = (245, 210, 90) if lit else (20, 22, 32)
                    pygame.draw.rect(surface, wc,
                                     pygame.Rect(bx2 + 6 + wx * 18, ground_y - bh + 26 + wy * 22, 10, 10))
        nv = int(180 + 70 * math.sin(t * 2.2))
        pygame.draw.rect(surface, (nv, 35, 35),
                         pygame.Rect(sx + 58, ground_y - 73, 30, 6), border_radius=2)
        pygame.draw.rect(surface, theme.BLUE_BRIGHT,
                         pygame.Rect(sx + 124, ground_y - 62, 22, 5), border_radius=2)
        _lamppost(sx + 110)
        fig_x = sx + 10 + int((t * 22) % (sw - 25))
        _figure(fig_x, ground_y)

    else:
        # Full skyline
        towers = [(sx,      38, 130), (sx + 42,  55, 150), (sx + 104, 44, 145),
                  (sx + 156, 62, 155), (sx + 226, 36, 120), (sx + 268, 20, 100)]
        for i, (rx, ry) in enumerate([(18,5),(52,8),(98,4),(148,10),(198,6),(242,9),(278,4)]):
            _star(rx, ry, i)
        pygame.draw.circle(surface, (210, 215, 200), (sx + sw - 22, sy + 18), 10)
        pygame.draw.circle(surface, (8,  10, 25),    (sx + sw - 18, sy + 15),  8)
        for tx, tw, th in towers:
            pygame.draw.rect(surface, (24, 28, 44), pygame.Rect(tx, ground_y - th, tw, th))
            pygame.draw.rect(surface, (46, 50, 70),
                             pygame.Rect(tx + tw // 2 - 1, ground_y - th - 8, 2, 8))
            for wy in range(0, th - 6, 13):
                for wx in range(4, tw - 4, 10):
                    seed    = tx // 5 + wx + wy
                    flicker = math.sin(t * (1.4 + seed % 3 * 0.5) + seed) > -0.25
                    wc = (245, 215, 90) if flicker else (18, 20, 32)
                    pygame.draw.rect(surface, wc,
                                     pygame.Rect(tx + wx, ground_y - th + wy + 7, 6, 6))
        _lamppost(sx + 88)
        _lamppost(sx + 200)
        car_x = sx + int((t * 28) % (sw + 50)) - 50
        _car(car_x, ground_y - 22, (28, 90, 170))
        if total_buildings >= 80 and sw > 200:
            car2 = sx + int((t * 20 + sw * 0.4) % (sw + 40)) - 20
            _car(car2, ground_y - 22, (140, 30, 35))

    _draw_scene_atmosphere(surface, sr, state, t)

    lbl_font = pygame.font.SysFont("serif", max(11, sd(12)), bold=True)
    label_surf = lbl_font.render("YOUR EMPIRE", True, theme.NOIR_GOLD)
    label_surf.set_alpha(140)
    surface.blit(label_surf, (sx + 8, sy + 6))

    surface.set_clip(clip)


# ──────────────────────── dragon HUD ─────────────────────────────

def _draw_dragon_portrait(surface: pygame.Surface, cx: int, cy: int, sz: int,
                          dragon_key: str, stage: str, t: float = 0.0) -> None:
    """Draw a dragon portrait as pygame primitives.  sz = approximate radius."""
    import src.dragon as _d
    col = _d.DRAGON_META[dragon_key]['color']
    dim = tuple(max(20, v // 2) for v in col)
    pulse = int(12 * abs(math.sin(t * 1.4)))

    if stage == _d.EGG:
        # Pulsing egg
        r = pygame.Rect(cx - sz // 2, cy - int(sz * 0.65), sz, int(sz * 1.3))
        pygame.draw.ellipse(surface, dim, r)
        pygame.draw.ellipse(surface, col, r, 2)
        # Crack lines hinting at what's inside
        crack_a = (220, 210, 200)
        pygame.draw.line(surface, crack_a, (cx - 3, cy - 4), (cx + 2, cy + 8), 1)
        pygame.draw.line(surface, crack_a, (cx + 2, cy + 8), (cx - 1, cy + 14), 1)
    elif stage == _d.HATCHLING:
        # Small scrappy hatchling: body + head + tiny wings
        bx, by = cx - sz // 2, cy
        pygame.draw.ellipse(surface, dim, pygame.Rect(bx, by, sz, sz // 2))
        pygame.draw.circle(surface, col, (cx - 2, by - sz // 4), sz // 4)
        pygame.draw.circle(surface, (255, 255, 255), (cx - 4, by - sz // 4 - 2), 2)
        pygame.draw.circle(surface, (20, 10, 10), (cx - 4, by - sz // 4 - 2), 1)
        # Tiny wing stubs
        pygame.draw.polygon(surface, dim, [
            (bx, by + 4), (bx - sz // 4, by - sz // 3), (bx + sz // 4, by)])
        pygame.draw.polygon(surface, dim, [
            (bx + sz, by + 4), (bx + sz + sz // 4, by - sz // 3), (bx + sz - sz // 4, by)])
    elif stage == _d.YOUNG:
        # Young dragon: body + spread wings + head
        wing_col = tuple(max(0, v - 40) for v in col)
        # Body
        pygame.draw.ellipse(surface, col, pygame.Rect(cx - sz // 2, cy - 4, sz, sz // 2 + 4))
        # Wings
        pygame.draw.polygon(surface, wing_col, [
            (cx - sz // 2, cy), (cx - sz, cy - sz // 2), (cx - 2, cy - 2)])
        pygame.draw.polygon(surface, wing_col, [
            (cx + sz // 2, cy), (cx + sz, cy - sz // 2), (cx + 2, cy - 2)])
        # Head
        pygame.draw.circle(surface, col, (cx, cy - sz // 2), sz // 3 + 1)
        # Eye
        pygame.draw.circle(surface, (255, 240, 200), (cx + 4, cy - sz // 2 - 2), 3)
        pygame.draw.circle(surface, (20, 10, 10), (cx + 4, cy - sz // 2 - 2), 2)
        # Horn
        pygame.draw.polygon(surface, (255, 230, 130),
                            [(cx - 2, cy - sz), (cx + 6, cy - sz - sz // 3), (cx + 4, cy - sz)])
    elif stage in (_d.ADULT, _d.ANCIENT):
        # Adult/Ancient: dominant silhouette
        wing_col = tuple(max(0, v - 50) for v in col)
        # Large wings
        pygame.draw.polygon(surface, wing_col, [
            (cx - sz // 2, cy), (cx - sz - sz // 3, cy - sz * 2 // 3), (cx, cy - 4)])
        pygame.draw.polygon(surface, wing_col, [
            (cx + sz // 2, cy), (cx + sz + sz // 3, cy - sz * 2 // 3), (cx, cy - 4)])
        # Body
        pygame.draw.ellipse(surface, col, pygame.Rect(cx - sz // 2, cy - 8, sz, sz // 2 + 8))
        # Neck + head
        pygame.draw.line(surface, col, (cx - 4, cy - 8), (cx - 12, cy - sz * 2 // 3), 6)
        pygame.draw.circle(surface, col, (cx - 14, cy - sz * 2 // 3), sz // 3 + 2)
        # Eye
        pygame.draw.circle(surface, (255, 240, 200), (cx - 18, cy - sz * 2 // 3 - 3), 3)
        pygame.draw.circle(surface, (20, 10, 10),    (cx - 18, cy - sz * 2 // 3 - 3), 2)
        # Horns
        pygame.draw.polygon(surface, (255, 230, 130), [
            (cx - 18, cy - sz * 2 // 3 - 6),
            (cx - 10, cy - sz * 2 // 3 - sz // 2),
            (cx - 14, cy - sz * 2 // 3 - 4)])
        if stage == _d.ANCIENT:
            # Aura rings
            aura = (*col, 60 + pulse * 2)
            for radius in (sz + 4, sz + 8):
                aura_surf = pygame.Surface((radius * 2 + 4, radius * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(aura_surf, aura, (radius + 2, radius + 2), radius, 2)
                surface.blit(aura_surf, (cx - radius - 2, cy - radius - 2))


def draw_dragon_hud(surface: pygame.Surface, state, fonts: dict) -> None:
    """Compact dragon companion HUD drawn in the scene panel area of the left column."""
    import src.dragon as _d
    if _PORTRAIT:
        return
    patron = _d.active_dragon(state)
    if not patron:
        return
    sr = _SCENE_RECT
    if sr.width <= 0 or sr.height <= 0:
        return

    meta  = _d.DRAGON_META[patron]
    col   = meta['color']
    stage = _d.get_stage(state)
    mood  = _d.get_mood(state)
    t     = getattr(state, '_time', 0.0)

    # Background card
    pygame.draw.rect(surface, theme.BG_CARD, sr, border_radius=8)
    border_col = tuple(min(255, v + 40) for v in col) if mood == _d.MOOD_AWAKENING else col
    pygame.draw.rect(surface, border_col, sr, border_radius=8, width=1)

    # Portrait (left column, vertically centered upper half)
    portrait_sz = min(18, sr.height // 4)
    portrait_cx = sr.x + portrait_sz + 6
    portrait_cy = sr.y + portrait_sz + 8
    _draw_dragon_portrait(surface, portrait_cx, portrait_cy, portrait_sz, patron, stage, t)

    # Dragon name + stage
    name_x = portrait_cx + portrait_sz + 8
    name_s = fonts['sm'].render(meta['title'], True, col)
    surface.blit(name_s, (name_x, sr.y + 4))
    stage_s = fonts['xs'].render(_d.STAGE_LABELS[stage], True, theme.TEXT_MUTED)
    surface.blit(stage_s, (name_x, sr.y + 20))

    # Mood dot
    mood_col = _d.MOOD_COLORS[mood]
    mood_lbl = fonts['xs'].render(_d.MOOD_LABELS[mood], True, mood_col)
    surface.blit(mood_lbl, mood_lbl.get_rect(right=sr.right - 6, y=sr.y + 4))
    mx_dot = sr.right - 6 - mood_lbl.get_width() - 8
    pygame.draw.circle(surface, mood_col, (mx_dot, sr.y + 9), 4)

    # XP progress bar
    prog, total, next_s = _d.stage_xp_progress(state)
    bar_y    = sr.y + 34
    bar_x    = sr.x + 6
    bar_w    = sr.width - 12
    bar_h    = 8
    pygame.draw.rect(surface, theme.BG_DARK, pygame.Rect(bar_x, bar_y, bar_w, bar_h), border_radius=4)
    if total > 0:
        fill_w = max(4, int(bar_w * min(1.0, prog / total)))
        pygame.draw.rect(surface, col, pygame.Rect(bar_x, bar_y, fill_w, bar_h), border_radius=4)
        xp_lbl = fonts['xs'].render(f"{prog}/{total} XP → {_d.STAGE_LABELS[next_s]}", True, theme.TEXT_MUTED)
    else:
        pygame.draw.rect(surface, (240, 200, 80), pygame.Rect(bar_x, bar_y, bar_w, bar_h), border_radius=4)
        xp_lbl = fonts['xs'].render("ANCIENT — Fully evolved", True, (240, 200, 80))
    surface.blit(xp_lbl, (bar_x, bar_y + 10))

    # Active request — word-wrapped so authored titles render in full (Phase 62),
    # replacing the old hard 36-char cut that clipped faction requests mid-word.
    req = _d.get_active_request(state)
    req_y = bar_y + 22
    if req:
        usable = sr.width - 12
        line_h = fonts['xs'].get_height() + 2
        # Vertical band down to the ability-button strip (or the card bottom when
        # no abilities have unlocked yet).
        has_ab   = bool(_d.get_available_abilities(state))
        band_bot = (sr.bottom - 28) if has_ab else (sr.bottom - 4)
        max_total = max(2, (band_bot - req_y) // line_h)
        # The title (the dragon's voice) gets priority; the goal takes the rest.
        title_lines = _wrap_notif_lines(req[2], fonts['xs'], usable, max(1, max_total - 1))
        goal_cap    = max(1, max_total - len(title_lines))
        goal_lines  = _wrap_notif_lines(f"▸ {req[3]}", fonts['xs'], usable, goal_cap)
        ty = req_y
        for ln in title_lines:
            surface.blit(fonts['xs'].render(ln, True, theme.TEXT_MUTED), (sr.x + 6, ty))
            ty += line_h
        for ln in goal_lines:
            surface.blit(fonts['xs'].render(ln, True, col), (sr.x + 6, ty))
            ty += line_h
    else:
        cd = getattr(state, '_dragon_request_cooldown', 0.0)
        if cd > 1.0:
            wait_s = fonts['xs'].render("Dragon is resting…", True, theme.TEXT_MUTED)
            surface.blit(wait_s, (sr.x + 6, req_y + 6))

    # Ability buttons (bottom strip)
    abilities = _d.get_available_abilities(state)
    if not abilities:
        return

    btn_y = sr.bottom - 26
    btn_h = 22
    btn_w = max(60, (sr.width - 8 - (len(abilities) - 1) * 4) // len(abilities))
    ab_rects = {}

    for idx, key in enumerate(abilities):
        ab_dragon, ab_min_stage, ab_name, ab_desc, ab_cd = _d.ABILITIES[key]
        bx = sr.x + 4 + idx * (btn_w + 4)
        br = pygame.Rect(bx, btn_y, btn_w, btn_h)
        ab_rects[key] = br

        remaining = _d.ability_cooldown_remaining(state, key)
        on_cd = remaining > 0

        if on_cd:
            bg = theme.BG_DARK
            border = theme.ACCENT_DIM
            txt_col = theme.TEXT_MUTED
            # Cooldown fill overlay
            fill_frac = remaining / ab_cd
            fill_w = max(0, int(br.width * fill_frac))
            pygame.draw.rect(surface, bg, br, border_radius=4)
            pygame.draw.rect(surface, (40, 38, 60), pygame.Rect(br.x, br.y, fill_w, br.height), border_radius=4)
            label = f"{ab_name[:10]} {int(remaining)}s"
        else:
            bg = tuple(int(v * 0.4) for v in col)
            border = col
            txt_col = theme.TEXT_PRIMARY
            label = ab_name[:14]

        pygame.draw.rect(surface, bg, br, border_radius=4)
        pygame.draw.rect(surface, border, br, border_radius=4, width=1)
        lbl_s = fonts['xs'].render(label, True, txt_col)
        surface.blit(lbl_s, lbl_s.get_rect(center=br.center))

    state._dragon_ability_btn_rects = ab_rects


# ──────────────────────── left stat cluster ───────────────────────
def _fit_text_width(surf: pygame.Surface, max_w: int) -> pygame.Surface:
    """Shrink a rendered text surface to fit *max_w*, preserving aspect ratio.

    Phase 91: the left panel width is capped (~420px) even at 2560×1440, so the
    cluster cards stay narrow while the value font grows — long values like
    '6.45x' or '1.24M' overflow their card and collide with the neighbour. This
    guarantees the value never exceeds its card interior, at any resolution."""
    w = surf.get_width()
    if w <= max_w or w <= 0 or max_w <= 0:
        return surf
    sf = max_w / w
    return pygame.transform.smoothscale(
        surf, (max(1, int(w * sf)), max(1, int(surf.get_height() * sf))))


def draw_stat_cluster(surface: pygame.Surface, state, fonts: dict) -> None:
    # Skip in portrait mode — no room below click zone.
    if _PORTRAIT:
        return
    sr = _SCENE_RECT
    y = STAT_CLUSTER_Y
    # Card height is the resolution-scaled cluster height reserved in
    # reinit_layout (single source). It always exceeds the scaled font content
    # height, so label (top) / value (bottom) never collide vertically.
    card_h = STAT_CLUSTER_H
    pad = sd(5)
    # Use left panel width if scene rect is zero-width (shouldn't happen in landscape)
    left_w = RIGHT_X if RIGHT_X > 0 else config.SCREEN_WIDTH
    avail_w = min(sr.width, left_w - sr.x * 2) if sr.width > 0 else left_w - 20
    card_w = max(60, (avail_w - 16) // 3)
    inner_w = max(1, card_w - 2 * pad)
    cards = [
        ("CLICKS", f"{state._click_count:,}",                             theme.TEXT_PRIMARY),
        ("CREW",   str(sum(b.owned for b in state.buildings)),             theme.TEXT_PRIMARY),
        ("MULT",   f"{prestige.income_mult(state.prestige_tokens):.2f}x", theme.TEXT_GOLD),
    ]
    for i, (label, value, vc) in enumerate(cards):
        cx = sr.x + i * (card_w + 8)
        cr = pygame.Rect(cx, y, card_w, card_h)
        _draw_glass_panel(surface, cr, fill_alpha=185)
        ls = _fit_text_width(
            fonts.get('disp_xs', fonts['xs']).render(label, True, theme.NOIR_BONE_DIM), inner_w)
        vs = _fit_text_width(fonts['sm'].render(value, True, vc), inner_w)
        surface.blit(ls, ls.get_rect(midtop=(cr.centerx, cr.y + pad)))
        surface.blit(vs, vs.get_rect(midbottom=(cr.centerx, cr.bottom - pad)))


# ─────────────────────────── right panel ───────────────────────────
# Phase 100: five concrete, fixed main tabs (single source of truth lives in
# prestige.visible_tabs). The economy loop — Buildings/Upgrades/Managers — is
# now top-level instead of buried under an abstract "Empire" container. The
# Turf tab groups the city-conflict sub-tabs (Territory/Rivals/Crew/Ops).
# _MAIN_TABS is kept only as readable documentation; geometry uses visible_tabs.
_MAIN_TABS = [
    ("Buildings", "buildings"),
    ("Upgrades",  "upgrades"),
    ("Managers",  "managers"),
    ("Turf",      "turf"),
    ("Stats",     "stats"),
]
_TURF_SUBTABS = ("territory", "rivals", "crew", "operations")
_SUBTAB_Y_OFFSET = 34   # sub-tab bar sits below main tabs


def main_tab_rects(state, fonts):
    """Geometry for the main tab bar — single source of truth for draw + click
    (Phase 89). Each tab sizes itself to its label width + UI_TAB_PADDING so tab
    names can never collide. Returns [(rect, label, key), ...]."""
    panel_top = (PRESTIGE_RECT.bottom + 6) if _PORTRAIT else HEADER_H
    pad, gap = sd(config.UI_TAB_PADDING), sd(config.UI_TAB_GAP)
    rects, x = [], RIGHT_X + 4
    for label, key in prestige.visible_tabs(state):
        w = fonts['xs'].size(label)[0] + pad * 2
        rects.append((pygame.Rect(x, panel_top, w, TAB_H), label, key))
        x += w + gap
    return rects


def subtab_rects(state, fonts):
    """Geometry for the Turf sub-tab bar — shared by draw + click (Phase 89).
    Sub-tabs size to their label width + UI_TAB_PADDING and are gated through
    prestige.visible_turf_subtabs, so the bar grows as systems unlock. Returns
    [(rect, label, key), ...]."""
    panel_top = (PRESTIGE_RECT.bottom + 6) if _PORTRAIT else HEADER_H
    sub_y = panel_top + TAB_H
    pad, gap = sd(config.UI_TAB_PADDING), sd(config.UI_TAB_GAP)
    rects, x = [], RIGHT_X + 8
    for label, key, locked, req in prestige.visible_turf_subtabs(state):
        w = fonts['xs'].size(label)[0] + pad * 2
        rects.append((pygame.Rect(x, sub_y + 2, w, _SUBTAB_Y_OFFSET - 4), label, key, locked, req))
        x += w + gap
    return rects


def _is_turf_subtab(tab: str) -> bool:
    return tab in _TURF_SUBTABS


def _tab_display_name(tab: str) -> str:
    """Return the main-tab key for a given internal content-tab key."""
    if _is_turf_subtab(tab):
        return "turf"
    return tab


def draw_right_panel(surface: pygame.Surface, state, fonts: dict) -> None:
    # In portrait mode the right panel starts below the click+prestige area.
    if _PORTRAIT:
        panel_top = PRESTIGE_RECT.bottom + 6
    else:
        panel_top = HEADER_H

    panel_rect = pygame.Rect(RIGHT_X, panel_top,
                             config.SCREEN_WIDTH - RIGHT_X,
                             config.SCREEN_HEIGHT - panel_top)
    _draw_dossier_panel_bg(surface, panel_rect)

    rank = prestige.get_rank(state.prestige_tokens)
    rank_idx = prestige._rank_index(rank)

    # ── Main tab bar (case files) ──
    mx, my = pygame.mouse.get_pos()
    tab_bar_y = panel_top
    tab_bar_rect = pygame.Rect(RIGHT_X, tab_bar_y, panel_rect.width, TAB_H)
    bar_bg = pygame.Surface((tab_bar_rect.width, tab_bar_rect.height), pygame.SRCALPHA)
    bar_bg.fill((*theme.NOIR_GLASS, 200))
    surface.blit(bar_bg, tab_bar_rect.topleft)
    pygame.draw.line(surface, (*theme.NOIR_GOLD, 50),
                     (tab_bar_rect.x, tab_bar_rect.bottom - 1),
                     (tab_bar_rect.right, tab_bar_rect.bottom - 1), 1)

    current_main = _tab_display_name(state._tab)
    for tr, label, key in main_tab_rects(state, fonts):
        active = (current_main == key)
        hover_tab = tr.collidepoint(mx, my) and not active
        _draw_dossier_tab(surface, tr, label, fonts, active, hover_tab)
        # Operations-ready indicator: pulsing dot when an op is ready to collect.
        if key == 'operations':
            ready = sum(1 for op in getattr(state, 'operations', []) if getattr(op, 'is_ready', False))
            if ready > 0:
                t = getattr(state, '_time', 0.0)
                pulse = int(180 + 75 * math.sin(t * 4.0))
                dot_c = (60, 230, 90, pulse)
                dot = pygame.Surface((14, 14), pygame.SRCALPHA)
                pygame.draw.circle(dot, dot_c, (7, 7), 6)
                surface.blit(dot, (tr.right - 16, tr.y + 3))
                if ready > 1:
                    cnt = fonts['xs'].render(str(ready), True, (10, 30, 15))
                    surface.blit(cnt, cnt.get_rect(center=(tr.right - 9, tr.y + 10)))

    # Settings gear icon — right side of tab bar
    gear_r = pygame.Rect(config.SCREEN_WIDTH - 36, tab_bar_y + 4, 28, 26)
    hover_gear = gear_r.collidepoint(mx, my)
    gear_active = state._tab == 'settings'
    gear_col = theme.NOIR_GOLD_BRIGHT if gear_active else (
        theme.NOIR_BONE if hover_gear else theme.NOIR_BONE_DIM)
    gs = fonts.get('disp_xs', fonts['xs']).render("#", True, gear_col)
    surface.blit(gs, gs.get_rect(center=gear_r.center))
    if not hasattr(state, '_gear_rect'):
        state._gear_rect = gear_r
    else:
        state._gear_rect = gear_r

    # ── Turf sub-tab bar ──
    sub_y = panel_top + TAB_H
    sub_content_offset = 0
    if current_main == 'turf':
        sub_content_offset = _SUBTAB_Y_OFFSET
        subtab_bar = pygame.Rect(RIGHT_X, sub_y, panel_rect.width, _SUBTAB_Y_OFFSET)
        sub_bg = pygame.Surface((subtab_bar.width, subtab_bar.height), pygame.SRCALPHA)
        sub_bg.fill((*theme.NOIR_INK_2, 230))
        surface.blit(sub_bg, subtab_bar.topleft)
        for sr2, slabel, skey, slocked, sreq in subtab_rects(state, fonts):
            s_active = (state._tab == skey) and not slocked
            s_hover = sr2.collidepoint(mx, my) and not s_active
            if slocked:
                sc = (92, 88, 108)
                if s_hover:
                    set_tooltip_text(f"{slabel} — LOCKED. {sreq}")
                ss2 = fonts['xs'].render(slabel.upper(), True, sc)
                surface.blit(ss2, ss2.get_rect(center=sr2.center))
                continue
            _draw_dossier_tab(surface, sr2, slabel, fonts, s_active, s_hover and not slocked)

    # ── Content rect ──
    content_top = panel_top + TAB_H + sub_content_offset
    cr = pygame.Rect(RIGHT_X + 4, content_top + 2, panel_rect.width - 8,
                     config.SCREEN_HEIGHT - content_top - 4)

    if state._tab == 'buildings':
        bld.draw_panel(surface, state, fonts, cr, state._bld_scroll)
        _draw_scrollbar(surface, cr, state._bld_scroll, max(0, len(state.buildings) - 5))
    elif state._tab == 'upgrades':
        upg.draw_panel(surface, state, fonts, cr, state._upg_scroll)
        _draw_scrollbar(surface, cr, state._upg_scroll, max(0, len(state.upgrades) - 6))
    elif state._tab == 'territory':
        territory_mod.draw_panel(surface, state, fonts, cr)
    elif state._tab == 'rivals':
        rivals_mod.draw_panel(surface, state, fonts, cr)
    elif state._tab == 'crew':
        crew_mod.draw_panel(surface, state, fonts, cr)
    elif state._tab == 'operations':
        ops_mod.draw_panel(surface, state, fonts, cr)
    elif state._tab == 'stats':
        draw_stats_tab(surface, state, fonts, cr)
    elif state._tab == 'managers':
        mgr_mod.draw_panel(surface, state, fonts, cr)
    elif state._tab == 'settings':
        draw_settings_tab(surface, state, fonts, cr)


def get_content_rect(tab: str) -> pygame.Rect:
    """Return the content rect for a given tab (used by click handlers)."""
    sub_offset = _SUBTAB_Y_OFFSET if _is_turf_subtab(tab) else 0
    panel_top = (PRESTIGE_RECT.bottom + 6) if _PORTRAIT else HEADER_H
    content_top = panel_top + TAB_H + sub_offset
    return pygame.Rect(RIGHT_X + 4, content_top + 2,
                       config.SCREEN_WIDTH - RIGHT_X - 8,
                       config.SCREEN_HEIGHT - content_top - 4)


def _draw_scrollbar(surface, cr, scroll, max_scroll) -> None:
    if max_scroll <= 0:
        return
    track_x = min(cr.right - 8, config.SCREEN_WIDTH - 10)
    track_y = cr.top + 4
    track_h = cr.height - 8
    # Phase 85 safety: a collapsed content area yields a non-positive track
    # height — never hand pygame.Surface a negative/zero dimension (it raises
    # "Invalid resolution for Surface"). Nothing to scroll, so just bail.
    if track_h <= 0:
        return
    track_surf = pygame.Surface((4, track_h), pygame.SRCALPHA)
    track_surf.fill((*theme.BG_CARD, 150))
    surface.blit(track_surf, (track_x, track_y))
    ratio  = 1.0 / (max_scroll + 1)
    thumb_h = max(1, min(track_h, max(20, int(track_h * ratio))))
    pos_ratio = scroll / max_scroll if max_scroll > 0 else 0.0
    thumb_y = track_y + int((track_h - thumb_h) * pos_ratio)
    thumb_surf = pygame.Surface((4, thumb_h), pygame.SRCALPHA)
    pygame.draw.rect(thumb_surf, (*theme.ACCENT_DIM, 210),
                     thumb_surf.get_rect(), border_radius=2)
    surface.blit(thumb_surf, (track_x, thumb_y))


# ─────────────────────────── stats tab ────────────────────────────
def _draw_section_header(surface, fonts, label, x, y, width):
    ls = fonts['xs'].render(label, True, theme.TEXT_MUTED)
    surface.blit(ls, (x, y))
    sep = pygame.Surface((width - ls.get_width() - 12, 1), pygame.SRCALPHA)
    sep.fill((*theme.ACCENT_DIM, 70))
    surface.blit(sep, (x + ls.get_width() + 8, y + ls.get_height() // 2))


def _draw_stat_card(surface, fonts, cx, cy, cw, ch, label, value, gold=False):
    cr = pygame.Rect(cx, cy, cw, ch)
    pygame.draw.rect(surface, theme.BG_CARD, cr, border_radius=8)
    pygame.draw.rect(surface, theme.ACCENT_DIM, cr, border_radius=8, width=1)
    ls = fonts['xs'].render(label, True, theme.TEXT_MUTED)
    vc = theme.TEXT_GOLD if gold else theme.TEXT_PRIMARY
    vs = fonts['sm'].render(value, True, vc)
    surface.blit(ls, (cx + 8, cy + 7))
    surface.blit(vs, (cx + 8, cy + 26))


def draw_stats_tab(surface: pygame.Surface, state, fonts: dict,
                   rect: pygame.Rect) -> None:
    # Phase 85 safety: never build/blit a surface for a collapsed content rect.
    if rect.width <= 0 or rect.height <= 0:
        return
    t_now = getattr(state, '_time', 0.0)
    cache = _STATS_SURF_CACHE
    rect_wh = (rect.width, rect.height)
    if (cache['surf'] is None
            or t_now - cache['last_t'] >= _STATS_REBUILD_INTERVAL
            or cache['rect_wh'] != rect_wh):
        cache['surf'], cache['content_h'] = _build_stats_virt(state, fonts, rect)
        cache['last_t'] = t_now
        cache['rect_wh'] = rect_wh

    virt = cache['surf']
    content_h = cache['content_h']
    scroll = max(0, min(getattr(state, '_stats_scroll', 0), max(0, content_h - rect.height)))
    state._stats_scroll = scroll
    surface.blit(virt, rect.topleft, pygame.Rect(0, scroll, rect.width, rect.height))

    if content_h > rect.height:
        track_h = rect.height
        thumb_ratio = rect.height / content_h
        thumb_h = max(20, int(track_h * thumb_ratio))
        thumb_y = int(scroll / max(1, content_h - rect.height) * (track_h - thumb_h))
        pygame.draw.rect(surface, theme.ACCENT_DIM,
                         pygame.Rect(rect.right - 4, rect.top + thumb_y, 3, thumb_h),
                         border_radius=2)

    mx, my = pygame.mouse.get_pos()
    btn = pygame.Rect(rect.right - 150, rect.bottom - 34, 144, 28)
    state._ach_btn_rect = btn
    ach_count = sum(1 for a in state.achievements if a.earned)
    hover = btn.collidepoint(mx, my)
    pygame.draw.rect(surface, theme.BG_CARD_HOVER if hover else theme.BG_CARD, btn, border_radius=8)
    pygame.draw.rect(surface, theme.TEXT_GOLD, btn, border_radius=8, width=1)
    bs = fonts['xs'].render(f"View Achievements  {ach_count}/{len(state.achievements)}",
                            True, theme.TEXT_GOLD)
    surface.blit(bs, bs.get_rect(center=btn.center))


def _build_stats_virt(state, fonts: dict, rect: pygame.Rect) -> pygame.Surface:
    """Build the full stats-tab virtual surface. Called at most every 200ms."""
    play_secs = int(getattr(state, '_play_time', state._time))
    ph = play_secs // 3600
    pm = (play_secs % 3600) // 60
    time_str = f"{ph}h {pm}m" if ph else f"{pm}m"

    # Phase 89: all vertical metrics derive from the (resolution-scaled) font
    # heights so nothing collapses/overlaps when fonts grow at 1080p/1440p.
    xs_h = fonts['xs'].get_height()
    sm_h = fonts['sm'].get_height()
    col_w = (rect.width - 20) // 2
    pad = sd(6)
    section_gap = sd(config.UI_SECTION_GAP)
    line_h = xs_h + sd(2)                       # one body text line
    hdr_adv = xs_h + sd(6)                      # header text + gap to content
    card_h = pad + xs_h + sd(2) + sm_h + pad    # label + value card

    VIRTUAL_H = max(1800, int(2600 * (config.SCREEN_HEIGHT / 720.0)))
    virt = pygame.Surface((rect.width, VIRTUAL_H), pygame.SRCALPHA)
    x0 = 6
    y  = 8

    def _vhdr(label, y_):
        ls = fonts['xs'].render(label, True, theme.TEXT_MUTED)
        virt.blit(ls, (x0, y_))
        sep = pygame.Surface((rect.width - ls.get_width() - 20, 1), pygame.SRCALPHA)
        sep.fill((*theme.ACCENT_DIM, 70))
        virt.blit(sep, (x0 + ls.get_width() + 8, y_ + ls.get_height() // 2))

    def _vcard(cx_, cy_, cw_, ch_, lbl_, val_, gold_=False):
        cr_ = pygame.Rect(cx_, cy_, cw_, ch_)
        pygame.draw.rect(virt, theme.BG_CARD, cr_, border_radius=8)
        pygame.draw.rect(virt, theme.ACCENT_DIM, cr_, border_radius=8, width=1)
        ls_ = fonts['xs'].render(lbl_, True, theme.TEXT_MUTED)
        vc_ = theme.TEXT_GOLD if gold_ else theme.TEXT_PRIMARY
        vs_ = fonts['sm'].render(str(val_), True, vc_)
        virt.blit(ls_, (cx_ + 8, cy_ + pad))
        virt.blit(vs_, (cx_ + 8, cy_ + pad + xs_h + sd(2)))

    # ── SESSION ──────────────────────────────────────────────────────────────
    _vhdr("SESSION", y)
    y += hdr_adv
    session_cards = [
        ("Balance",       theme.format_number(state.balance),           True),
        ("Income / sec",  theme.format_number(state.income_per_second), False),
        ("Click Value",   theme.format_number(state.click_value),       False),
        ("Prestige Mult", f"{prestige.income_mult(state.prestige_tokens):.2f}x", True),
    ]
    for i, (lbl, val, gold) in enumerate(session_cards):
        col = i % 2; row = i // 2
        _vcard(x0 + col * (col_w + pad), y + row * (card_h + pad), col_w, card_h, lbl, val, gold)
    y += 2 * (card_h + pad) + section_gap

    # ── ROB'S EMPIRE DASHBOARD (Phase 119) ───────────────────────────────────
    try:
        import src.managers as _mgr
        rob_rep = _mgr.empire_efficiency_report(state)
        if rob_rep:
            _vhdr("ROB'S EMPIRE DASHBOARD", y)
            y += hdr_adv
            sub = fonts['xs'].render(
                "The numbers guy — where your money comes from", True, theme.TEXT_MUTED)
            virt.blit(sub, (x0, y))
            y += line_h
            share_rows = (
                ('Buildings', rob_rep['shares']['buildings']),
                ('Operations', rob_rep['shares']['operations']),
                ('Territories', rob_rep['shares']['territory']),
                ('Clicks', rob_rep['shares']['clicks']),
            )
            bar_max_w = rect.width - 120
            for lbl, pct in share_rows:
                ls_ = fonts['xs'].render(f"{lbl}", True, theme.TEXT_MUTED)
                virt.blit(ls_, (x0, y))
                pct_s = fonts['xs'].render(f"{pct:.0f}%", True, theme.TEXT_PRIMARY)
                virt.blit(pct_s, pct_s.get_rect(topright=(rect.width - 6, y)))
                bar_y = y + xs_h + 2
                pygame.draw.rect(virt, (40, 43, 60),
                                 pygame.Rect(x0, bar_y, bar_max_w, 5), border_radius=2)
                if pct > 0:
                    fw = max(2, int(bar_max_w * min(100.0, pct) / 100.0))
                    col = theme.GREEN if lbl == rob_rep['strongest'][0] else (
                        theme.TEXT_MUTED if lbl == rob_rep['weakest'][0] else theme.ACCENT_DIM)
                    pygame.draw.rect(virt, col,
                                     pygame.Rect(x0, bar_y, fw, 5), border_radius=2)
                y += xs_h + sd(8)
            st_l, st_p = rob_rep['strongest']
            wk_l, wk_p = rob_rep['weakest']
            sum_s = fonts['xs'].render(
                f"Strongest: {st_l} ({st_p:.0f}%)  •  Weakest: {wk_l} ({wk_p:.0f}%)",
                True, theme.TEXT_GOLD)
            virt.blit(sum_s, (x0, y))
            y += line_h
            for rec in rob_rep['recommendations']:
                rs = fonts['xs'].render(f"→ {rec}", True, theme.BLUE_BRIGHT)
                virt.blit(rs, (x0 + 4, y))
                y += line_h
            y += section_gap
    except Exception:
        pass

    # ── RESOURCES (Phase 12 clarity: each currency's role at a glance) ─────────
    _vhdr("RESOURCES", y)
    y += hdr_adv
    respect = int(getattr(state, 'influence', 0))
    respect_bonus = prestige.respect_income_bonus(respect)
    resource_cards = [
        ("Influence (spend on perks/turf)", f"{state.prestige_tokens:,}", True),
        ("Respect (street reputation)",     f"{respect:,}",               True),
    ]
    for i, (lbl, val, gold) in enumerate(resource_cards):
        col = i % 2; row = i // 2
        _vcard(x0 + col * (col_w + pad), y + row * (card_h + pad), col_w, card_h, lbl, val, gold)
    y += (card_h + pad)
    rb_s = fonts['xs'].render(
        f"Respect income bonus: +{respect_bonus*100:.0f}%  (caps at +50% @ 1,250 Respect)",
        True, theme.GREEN)
    virt.blit(rb_s, (x0, y))
    y += line_h + section_gap

    # ── HEAT BREAKDOWN (Phase 12 visibility) ──────────────────────────────────
    try:
        import src.heat as _heat
        cur_heat = float(getattr(state, 'heat', 0.0))
        bd = _heat.heat_breakdown(state)
        _vhdr("HEAT BREAKDOWN", y)
        y += hdr_adv
        hc = _heat.heat_color(cur_heat)
        hlabel = _heat.heat_label(cur_heat)
        big = fonts['md'].render(f"{cur_heat:.0f}%  ({hlabel})", True, hc)
        virt.blit(big, (x0, y))
        net = bd['net']
        net_col = (230, 110, 80) if net > 0 else theme.GREEN
        net_s = fonts['xs'].render(
            f"Net {'+' if net >= 0 else ''}{net*60:.2f}/min", True, net_col)
        virt.blit(net_s, net_s.get_rect(topright=(rect.width - 6, y + 4)))
        y += big.get_height() + 4
        if bd['raid_risk']:
            warn = fonts['xs'].render(
                f"! RAID RISK — heat is above {int(bd['raid_threshold'])}%! Raids seize cash.",
                True, (240, 90, 70))
            virt.blit(warn, (x0, y)); y += line_h
        else:
            safe = fonts['xs'].render(
                f"Safe — raids begin at {int(bd['raid_threshold'])}% heat.", True, theme.TEXT_MUTED)
            virt.blit(safe, (x0, y)); y += line_h
        try:
            import src.managers as _mgr
            if _mgr.manager_active(state, "The Collector"):
                sh = _mgr.collector_shield_fraction(state)
                sh_txt = "Collector shield: READY" if sh >= 1.0 else f"Collector shield: {int(sh * 100)}% recharged"
                virt.blit(fonts['xs'].render(sh_txt, True, theme.BLUE_BRIGHT), (x0, y)); y += line_h
            if _mgr.manager_active(state, "Clean Carl"):
                delta = _mgr.heat_forecast_delta(state, 120.0)
                sign = '+' if delta >= 0 else ''
                fc_txt = f"Carl forecast (2 min): {sign}{delta:.1f}%"
                used = "used" if getattr(state, '_carl_emergency_used', False) else "ready"
                virt.blit(fonts['xs'].render(f"{fc_txt}  |  Emergency dump: {used}",
                                               True, theme.TEXT_GOLD), (x0, y)); y += line_h
        except Exception:
            pass
        # Rise sources
        for lbl, v in bd['rise']:
            txt = f"{lbl}" if v == 0 else f"{lbl}: +{v*60:.2f}/min"
            s = fonts['xs'].render(txt, True, (220, 140, 90))
            virt.blit(s, (x0 + 6, y)); y += line_h - sd(2)
        for lbl, v in bd['decay']:
            s = fonts['xs'].render(f"{lbl}: -{v*60:.2f}/min", True, (110, 200, 130))
            virt.blit(s, (x0 + 6, y)); y += line_h - sd(2)
        y += section_gap
    except Exception:
        pass

    # ── LIFETIME STATISTICS ───────────────────────────────────────────────────
    _vhdr("LIFETIME STATISTICS", y)
    y += hdr_adv
    ach_count = sum(1 for a in state.achievements if a.earned)
    total_bld_purchased = getattr(state, '_total_buildings_purchased', 0)
    total_terr = getattr(state, '_total_territories_captured', 0)
    total_rivals = getattr(state, '_total_rivals_defeated', 0)
    total_ops = getattr(state, '_total_ops_completed', 0)
    total_heat = getattr(state, '_total_heat_generated', 0.0)
    total_respect = getattr(state, '_total_respect_earned', 0)
    total_influence = getattr(state, '_total_influence_earned', 0)
    highest_cash = getattr(state, '_highest_cash_held', 0.0)
    lifetime_cards = [
        ("Cash Earned",         theme.format_number(state.lifetime_earnings),  True),
        ("Highest Cash Held",   theme.format_number(highest_cash),             True),
        ("Peak Income/sec",     theme.format_number(getattr(state, '_peak_income', 0.0)), False),
        ("Play Time",           time_str,                                       False),
        ("Buildings Bought",    f"{total_bld_purchased:,}",                    False),
        ("Territories Captured",f"{total_terr:,}",                             False),
        ("Rivals Defeated",     f"{total_rivals:,}",                           False),
        ("Ops Completed",       f"{total_ops:,}",                              False),
        ("Total Heat Generated",f"{total_heat:,.0f}",                          False),
        ("Total Influence Earned", f"{total_influence:,}",                     False),
        ("Total Respect Earned", f"{total_respect:,}",                         False),
        ("Total Prestiges",     str(getattr(state, '_prestige_count', 0)),      False),
        ("Achievements",        f"{ach_count}/{len(state.achievements)}",       False),
        ("Total Clicks",        f"{state._click_count:,}",                     False),
    ]
    for i, (lbl, val, gold) in enumerate(lifetime_cards):
        col = i % 2; row = i // 2
        _vcard(x0 + col * (col_w + pad), y + row * (card_h + pad), col_w, card_h, lbl, val, gold)
    y += 7 * (card_h + pad) + section_gap

    # ── RANK ─────────────────────────────────────────────────────────────────
    tokens = state.prestige_tokens
    rank = prestige.get_rank(tokens)
    _vhdr("RANK", y)
    y += hdr_adv
    rank_s = fonts['sm'].render(rank, True, theme.PRESTIGE_LABEL)
    virt.blit(rank_s, (x0, y))
    active_perks = prestige.get_cumulative_rank_perks(tokens)
    perk_parts = []
    if active_perks.get("territory_success"):
        perk_parts.append(f"+{active_perks['territory_success']*100:.0f}% terr.")
    if active_perks.get("operation_reward"):
        perk_parts.append(f"+{active_perks['operation_reward']*100:.0f}% op rewards")
    if active_perks.get("heat_decay"):
        perk_parts.append(f"+{active_perks['heat_decay']:.2f}/s heat decay")
    if active_perks.get("income_bonus"):
        perk_parts.append(f"+{active_perks['income_bonus']*100:.0f}% income")
    if perk_parts:
        ps = fonts['xs'].render("  •  ".join(perk_parts), True, theme.GREEN)
        virt.blit(ps, (x0, y + sm_h + sd(2)))
    y += sm_h + xs_h + sd(6)
    nri = prestige.get_next_rank(tokens)
    if nri:
        nr_label, nr_thresh = nri
        cur_thresh = 0
        for threshold, lbl in prestige.HIERARCHY:
            if tokens >= threshold:
                cur_thresh = threshold
        span = max(1, nr_thresh - cur_thresh)
        pct = int(min(1.0, (tokens - cur_thresh) / span) * 100)
        nr_s = fonts['xs'].render(f"Next: {nr_label}  ({tokens}/{nr_thresh}, {pct}%)", True, theme.TEXT_MUTED)
        virt.blit(nr_s, (x0, y))
        unlock_desc = prestige.RANK_UNLOCKS.get(nr_label, "")
        if unlock_desc:
            ul_s = fonts['xs'].render(unlock_desc, True, theme.PRESTIGE_LABEL)
            ul_s.set_alpha(160)
            virt.blit(ul_s, (x0, y + line_h))
        y += line_h * 2
    y += section_gap

    # ── CITY DOMINATION ───────────────────────────────────────────────────────
    territories = getattr(state, 'territories', [])
    total_t = max(1, len(territories))
    player_t = sum(1 for t in territories if t.unlocked)
    ctrl_pct = player_t / total_t
    highest_ctrl = getattr(state, '_highest_city_control', ctrl_pct)

    _vhdr("CITY DOMINATION", y)
    y += hdr_adv

    # Big control percentage display
    ctrl_str = f"{ctrl_pct * 100:.0f}%"
    ctrl_color = theme.GREEN if ctrl_pct >= 1.0 else (
        (100, 220, 100) if ctrl_pct >= 0.75 else (
        (255, 200, 50) if ctrl_pct >= 0.50 else theme.TEXT_PRIMARY))
    big_s = fonts['lg'].render(ctrl_str, True, ctrl_color)
    virt.blit(big_s, (x0, y))
    sub_s = fonts['xs'].render(f"of the city under your control  ({player_t}/{total_t} districts)", True, theme.TEXT_MUTED)
    virt.blit(sub_s, (x0 + big_s.get_width() + 10, y + big_s.get_height() // 2 - 6))
    y += big_s.get_height() + 6

    # Chunky control bar
    bar_w = rect.width - 20
    bar_h = 18
    bar_rect = pygame.Rect(x0, y, bar_w, bar_h)
    pygame.draw.rect(virt, (25, 28, 45), bar_rect, border_radius=6)
    fill_w = max(4, int(bar_w * ctrl_pct))
    pygame.draw.rect(virt, (*ctrl_color, 220), pygame.Rect(x0, y, fill_w, bar_h), border_radius=6)
    pygame.draw.rect(virt, theme.ACCENT_DIM, bar_rect, border_radius=6, width=1)
    y += bar_h + 8

    # Territory income bonus (Phase 10)
    try:
        from src.territory import (territory_district_count_bonus,
                                   territory_income_mult, milestone_income_mult)
        count_bonus = int(territory_district_count_bonus(territories) * 100)
        mile_mult = milestone_income_mult(state)
        bonus_parts = [f"+{count_bonus}% from {player_t} districts (2%×count)"]
        if mile_mult > 1.0:
            bonus_parts.append(f"+50% from 100% milestone")
        bonus_s = fonts['xs'].render(
            "Territory income: " + ", ".join(bonus_parts), True, theme.GREEN)
        virt.blit(bonus_s, (x0, y))
        y += line_h
    except Exception:
        pass

    # Peak control
    peak_s = fonts['xs'].render(f"Peak control: {highest_ctrl * 100:.0f}%  |  Territories: {player_t}/{total_t}",
                                True, theme.TEXT_MUTED)
    virt.blit(peak_s, (x0, y))
    y += line_h

    # Per-faction breakdown
    try:
        from src.territory import get_city_control
        control = get_city_control(territories, getattr(state, 'rivals', []))
        bar_total_w = rect.width - 20
        for name, share in control[:6]:
            is_player = (name == 'player')
            label = "You" if is_player else name[:20]
            p = int(share * 100)
            col = theme.GREEN if is_player else (200, 90, 70)
            ls2 = fonts['xs'].render(label, True, col)
            ps2 = fonts['xs'].render(f"{p}%", True, col)
            virt.blit(ls2, (x0, y))
            virt.blit(ps2, ps2.get_rect(topright=(rect.width - 6, y)))
            bar_y2 = y + fonts['xs'].get_height() + 2
            trk = pygame.Surface((bar_total_w, 3), pygame.SRCALPHA)
            pygame.draw.rect(trk, (30, 32, 50, 160), trk.get_rect(), border_radius=2)
            virt.blit(trk, (x0, bar_y2))
            fw2 = max(2, int(bar_total_w * share))
            fl2 = pygame.Surface((fw2, 3), pygame.SRCALPHA)
            pygame.draw.rect(fl2, (*col, 200), fl2.get_rect(), border_radius=2)
            virt.blit(fl2, (x0, bar_y2))
            y += fonts['xs'].get_height() + 9
    except Exception:
        pass
    y += section_gap

    # ── ENDGAME OBJECTIVES ────────────────────────────────────────────────────
    _vhdr("ENDGAME OBJECTIVES", y)
    y += hdr_adv

    rivals = getattr(state, 'rivals', []) or []
    all_rivals_eliminated = len(rivals) > 0 and all(r.status == 'Eliminated' for r in rivals if r)
    all_territory = len(territories) > 0 and all(t.unlocked for t in territories)

    _kingpin_ranks = {"Kingpin", "City Controller", "State Influence",
                      "National Influence", "Shadow Government"}
    current_rank = prestige.get_rank(tokens)
    _rank_order = {lbl: i for i, (_, lbl) in enumerate(prestige.HIERARCHY)}

    def _rank_gte(r_label: str) -> bool:
        return _rank_order.get(current_rank, 0) >= _rank_order.get(r_label, 999)

    objectives = [
        ("Reach Kingpin",             _rank_gte("Kingpin"),          theme.PRESTIGE_LABEL),
        ("Reach Shadow Government",   _rank_gte("Shadow Government"), (220, 160, 255)),
        ("Control Entire City",       all_territory,                  theme.GREEN),
        ("Defeat Every Rival",        all_rivals_eliminated,          (220, 80, 60)),
        ("Earn $1 Trillion",          state.lifetime_earnings >= 1e12, theme.TEXT_GOLD),
        ("Earn $1 Quadrillion",       state.lifetime_earnings >= 1e15, theme.TEXT_GOLD),
        ("Earn $1 Decillion",         state.lifetime_earnings >= 1e33, theme.TEXT_GOLD),
        ("Prestige 10 Times",         getattr(state, '_prestige_count', 0) >= 10, theme.PRESTIGE_LABEL),
        ("Defeat 10 Rivals (Total)",  total_rivals >= 10,             (220, 80, 60)),
        ("Complete 100 Operations",   total_ops >= 100,               (160, 100, 220)),
    ]

    obj_h = max(26, sm_h + sd(8))
    for obj_label, done, obj_col in objectives:
        bg_col = (30, 45, 30) if done else (28, 28, 40)
        ob = pygame.Rect(x0, y, rect.width - 12, obj_h)
        pygame.draw.rect(virt, bg_col, ob, border_radius=6)
        check = "v" if done else "○"
        check_col = theme.GREEN if done else theme.TEXT_MUTED
        check_s = fonts['sm'].render(check, True, check_col)
        virt.blit(check_s, (x0 + 8, y + (obj_h - check_s.get_height()) // 2))
        lbl_col = obj_col if done else theme.TEXT_MUTED
        lbl_s = fonts['xs'].render(obj_label, True, lbl_col)
        virt.blit(lbl_s, (x0 + 28, y + (obj_h - lbl_s.get_height()) // 2))
        y += obj_h + 3

    return virt, y + 12


# ─────────────────────────── panel divider ─────────────────────────
def draw_panel_divider(surface: pygame.Surface, state) -> None:
    if _PORTRAIT or RIGHT_X <= 0:
        return
    div_x = RIGHT_X - sd(4)
    div = pygame.Surface((1, config.SCREEN_HEIGHT - HEADER_H), pygame.SRCALPHA)
    div.fill((*theme.NOIR_GOLD, 45))
    surface.blit(div, (div_x, HEADER_H))


# ─────────────────────── objectives / goals panel ─────────────────────────
def draw_objectives(surface: pygame.Surface, state, fonts: dict) -> None:
    """Compact goals panel below prestige — complements city, does not cover it."""
    if _PORTRAIT or GOALS_H <= 0:
        return
    x = PRESTIGE_RECT.x
    w = PRESTIGE_RECT.width
    y = GOALS_TOP
    bottom_limit = GOALS_TOP + GOALS_H

    if y >= bottom_limit:
        return

    card = pygame.Rect(x, y, w, bottom_limit - y)
    clip = surface.get_clip()
    surface.set_clip(card)
    _draw_glass_panel(surface, card, fill_alpha=190)

    active_goals = goals_mod.current_goals(state, max_count=2)

    if not active_goals:
        done_s = fonts['xs'].render("Objectives complete", True, theme.GREEN)
        surface.blit(done_s, done_s.get_rect(center=card.center))
        surface.set_clip(clip)
        return

    disp = fonts.get('disp_xs', fonts['xs'])
    hdr = disp.render("OBJECTIVES", True, theme.NOIR_GOLD)
    surface.blit(hdr, (x + 8, y + 4))
    cy = y + 18
    row_h = max(20, (bottom_limit - y - 20) // max(1, len(active_goals[:2])))

    for g in active_goals[:2]:
        if cy + row_h > bottom_limit:
            break
        try:
            cur, target = g.progress(state)
            cur, target = float(cur), float(target)
        except Exception:
            cur, target = 0.0, 1.0
        ratio = min(1.0, cur / max(1.0, target)) if target > 0 else 0.0
        display_label = getattr(g, 'narrative', '') or g.label
        _draw_obj_row(surface, fonts, x + 8, cy, w - 16, display_label, ratio, g.color)
        cy += row_h
    surface.set_clip(clip)


def _draw_obj_row(surface, fonts, x, y, w, label, ratio, color) -> None:
    """Single objective row: label + thin progress bar."""
    max_label_w = w - 4
    ls = fonts['xs'].render(label, True, color)
    if ls.get_width() > max_label_w:
        # Truncate
        for end in range(len(label), 0, -1):
            candidate = label[:end] + "…"
            ls = fonts['xs'].render(candidate, True, color)
            if ls.get_width() <= max_label_w:
                break
    surface.blit(ls, (x, y))
    # Progress bar
    bar_y = y + 14
    bar_w = w - 4
    bar_h = 4
    track = pygame.Surface((bar_w, bar_h), pygame.SRCALPHA)
    pygame.draw.rect(track, (30, 32, 50, 180), track.get_rect(), border_radius=2)
    surface.blit(track, (x, bar_y))
    if ratio > 0:
        fill_w = max(2, int(bar_w * ratio))
        fill = pygame.Surface((fill_w, bar_h), pygame.SRCALPHA)
        pygame.draw.rect(fill, (*color, 200), fill.get_rect(), border_radius=2)
        surface.blit(fill, (x, bar_y))


# ─────────────────────────── idle particles ────────────────────────
def draw_idle_particles(surface: pygame.Surface, state, fonts: dict) -> None:
    for p in state._idle_particles:
        t = p['age'] / 0.8
        y_pos = p['y'] - 25.0 * t
        alpha = int(180 * (1.0 - t))
        s = fonts['xs'].render("+", True, theme.PARTICLE_IDLE)
        s.set_alpha(alpha)
        surface.blit(s, s.get_rect(center=(int(p['x']), int(y_pos))))


# ──────────────────────────── golden coin ──────────────────────────
_COIN_GLOW_SURF: pygame.Surface | None = None

def _ensure_coin_glow() -> pygame.Surface:
    global _COIN_GLOW_SURF
    if _COIN_GLOW_SURF is None:
        s = pygame.Surface((80, 80), pygame.SRCALPHA)
        pygame.draw.circle(s, (*theme.ACCENT, 22), (40, 40), 38)
        _COIN_GLOW_SURF = s
    return _COIN_GLOW_SURF


def draw_golden_coin(surface: pygame.Surface, state, fonts: dict) -> None:
    if not state._coin:
        return
    global _COIN_SURF
    if _COIN_SURF is None:
        _COIN_SURF = pygame.Surface((80, 80), pygame.SRCALPHA)

    c = state._coin
    t = state._time
    base_r = int(18 + 2 * math.sin(t * 3))
    base_r = max(16, min(20, base_r))
    x, y   = int(c['x']), int(c['y'])

    import src.managers as _mgr
    sal_collects = _mgr.manager_active(state, "Lucky Sal")
    lifetime_cap = 0.75 if sal_collects else 8.0
    remaining = max(0.0, lifetime_cap - c['lifetime'])
    if not sal_collects and remaining < 3.0:
        visible = math.sin(t * 10) > 0
        coin_alpha = 255 if visible else int(255 * 0.4)
    else:
        coin_alpha = 255

    glow = _ensure_coin_glow()
    surface.blit(glow, (x - 40, y - 40))

    if not sal_collects:
        _draw_coin_arrow(surface, fonts, x, y, t)

    _COIN_SURF.fill((0, 0, 0, 0))
    cx2, cy2 = 40, 40
    pygame.draw.circle(_COIN_SURF, (*theme.ACCENT, 255), (cx2, cy2), base_r + 4, 2)
    pygame.draw.circle(_COIN_SURF, (*theme.ACCENT, 255), (cx2, cy2), base_r)
    pygame.draw.circle(_COIN_SURF, (*theme.ACCENT_DIM, 255), (cx2, cy2), max(1, base_r - 5))
    sym = fonts['sm'].render("$", True, theme.BG_DARK)
    _COIN_SURF.blit(sym, sym.get_rect(center=(cx2, cy2)))
    _COIN_SURF.set_alpha(coin_alpha)
    surface.blit(_COIN_SURF, (x - 40, y - 40))

    if sal_collects:
        lbl = fonts['xs'].render("SAL", True, theme.TEXT_GOLD)
        surface.blit(lbl, lbl.get_rect(midtop=(x, y + base_r + 6)))
    else:
        ts = fonts['xs'].render(f"{remaining:.1f}s", True, theme.TEXT_GOLD)
        surface.blit(ts, ts.get_rect(midtop=(x, y + base_r + 6)))


def _draw_coin_arrow(surface: pygame.Surface, fonts: dict,
                     coin_x: int, coin_y: int, t: float) -> None:
    """Draw a pulsing arrow indicator so the player never misses a golden coin."""
    pulse = 0.55 + 0.45 * math.sin(t * 5.0)
    alpha = int(210 * pulse)
    arrow_col = (*theme.ACCENT, alpha)

    # Small triangle arrow drawn 28px above the coin (pointing down toward it)
    ax, ay = coin_x, coin_y - 36
    pts = [(ax, ay + 14), (ax - 9, ay), (ax + 9, ay)]
    arrow_surf = pygame.Surface((24, 20), pygame.SRCALPHA)
    local_pts = [(p[0] - ax + 12, p[1] - ay) for p in pts]
    pygame.draw.polygon(arrow_surf, arrow_col, local_pts)
    surface.blit(arrow_surf, (ax - 12, ay))

    # "COIN!" label
    lbl = fonts['xs'].render("COIN!", True, theme.ACCENT)
    lbl.set_alpha(alpha)
    surface.blit(lbl, lbl.get_rect(midbottom=(coin_x, coin_y - 38)))


# ───────────────────────────── particles ───────────────────────────
def draw_particles(surface: pygame.Surface, state, fonts: dict) -> None:
    """Phase 95 — render click-feedback particles. Text particles show the value
    captured at click time (small/gold for normal, larger/hot for crit); empty
    text means a crit spark dot. No per-frame surface allocation: text uses the
    shared font cache + set_alpha, sparks are direct circle draws faded by radius."""
    for p in state._particles:
        dur = getattr(p, 'dur', p.DURATION)
        t = p.lifetime / dur if dur else 1.0
        if t >= 1.0:
            continue
        rise = getattr(p, 'rise', p.RISE)
        y_pos = p.y - rise * t
        if p.text:
            x_pos = p.x + getattr(p, 'vx', 0.0) * t
            font = fonts['md'] if p.crit else fonts['sm']
            color = theme.CRIT_COLOR if p.crit else theme.TEXT_GOLD
            s = font.render(p.text, True, color)
            s.set_alpha(int(255 * (1.0 - t)))
            surface.blit(s, s.get_rect(center=(int(x_pos), int(y_pos))))
        else:
            # Crit spark dot — fan out horizontally, fade by shrinking radius.
            x_pos = int(p.x + getattr(p, 'vx', 0.0) * t)
            radius = max(0, int(4 * (1.0 - t)))
            if radius > 0:
                pygame.draw.circle(surface, theme.CRIT_COLOR, (x_pos, int(y_pos)), radius)


# ────────────────────────── income popups ──────────────────────────
def draw_income_popups(surface: pygame.Surface, state, fonts: dict) -> None:
    """Income popups are now routed to the notification stack in update().
    This function is kept as a no-op for compatibility."""
    pass


# ─────────────────────── settings tab ─────────────────────────────
_FPS_OPTIONS  = [30, 60, 120]
_VOL_STEPS    = [0.0, 0.25, 0.5, 0.75, 1.0]
_SET_BTN_W, _SET_BTN_H = 54, 32
_SET_BTN_GAP = 6


def _settings_metrics(fonts):
    """Font-driven vertical metrics for the settings tab (Phase 89). Tight enough
    that the whole page fits the content area at 1080p/1440p without scrolling,
    but never overlapping. Returned values are shared by draw + click + helpers.
    -> (btn_h, lbl_off, row_h, hdr_h)."""
    xs_h = fonts['xs'].get_height()
    btn_h   = max(sd(26), xs_h + sd(8))   # button contains one line of text
    lbl_off = xs_h + sd(2)                # label top -> button top
    row_h   = lbl_off + btn_h + sd(8)     # full option row pitch
    hdr_h   = xs_h + sd(4)                # section header -> first row
    return btn_h, lbl_off, row_h, hdr_h


def _opt_btn_w(fonts, opt, fmt_fn) -> int:
    """Width for a settings option button — sized to its label so text labels
    like 'Enabled'/'Disabled' never overflow/collide at 1080p+ (Phase 89)."""
    txt = fmt_fn(opt) if fmt_fn else str(opt)
    return max(sd(_SET_BTN_W), fonts['xs'].size(txt)[0] + sd(config.UI_CARD_PADDING) * 2)


def _opt_row_rects(fonts, x0, by, options, fmt_fn=None):
    """Per-option button rects for a settings row — single source of truth for
    draw + click (Phase 89) so text-sized buttons hit-test where they're drawn."""
    btn_h, _lbl_off, _row_h, _hdr_h = _settings_metrics(fonts)
    rects, bx = [], x0
    for opt in options:
        w = _opt_btn_w(fonts, opt, fmt_fn)
        rects.append((pygame.Rect(bx, by, w, btn_h), opt))
        bx += w + _SET_BTN_GAP
    return rects


def _draw_option_row(surface, fonts, rect, y, label, options, current, fmt_fn=None):
    ls = fonts['xs'].render(label, True, theme.TEXT_MUTED)
    surface.blit(ls, (rect.x + 14, y))
    _bh, lbl_off, _rh, _hh = _settings_metrics(fonts)
    mx, my = pygame.mouse.get_pos()
    for r, opt in _opt_row_rects(fonts, rect.x + 14, y + lbl_off, options, fmt_fn):
        opt_str = fmt_fn(opt) if fmt_fn else str(opt)
        active = abs(opt - current) < 0.01 if isinstance(opt, float) else opt == current
        hover = r.collidepoint(mx, my)
        if active:
            pygame.draw.rect(surface, theme.ACCENT, r, border_radius=6)
            tc = theme.BG_DARK
        elif hover:
            pygame.draw.rect(surface, theme.BG_CARD_HOVER, r, border_radius=6)
            pygame.draw.rect(surface, theme.ACCENT_DIM, r, border_radius=6, width=1)
            tc = theme.TEXT_PRIMARY
        else:
            pygame.draw.rect(surface, theme.BG_CARD, r, border_radius=6)
            tc = theme.TEXT_MUTED
        ts = fonts['xs'].render(opt_str, True, tc)
        surface.blit(ts, ts.get_rect(center=r.center))


def draw_settings_tab(surface: pygame.Surface, state, fonts: dict,
                      rect: pygame.Rect) -> None:
    x0 = rect.x + 14
    y = rect.top + 8
    # Phase 89: font-driven offsets (shared with handle_settings_click) so labels
    # never overlap their rows at 1080p+ while still fitting the content area.
    btn_h, lbl_off, row_h, hdr_h = _settings_metrics(fonts)
    sect_h = row_h + sd(8)                      # last row of a section + gap

    # AUDIO
    _draw_section_header(surface, fonts, "AUDIO", x0, y, rect.width - 16)
    y += hdr_h
    _draw_option_row(surface, fonts, rect, y, "Master Volume", _VOL_STEPS,
                     getattr(state, '_master_volume', 1.0), fmt_fn=lambda v: f"{int(v*100)}%")
    y += row_h
    _draw_option_row(surface, fonts, rect, y, "SFX Volume", _VOL_STEPS,
                     getattr(state, '_sfx_volume', 1.0), fmt_fn=lambda v: f"{int(v*100)}%")
    y += row_h
    _draw_option_row(surface, fonts, rect, y, "Music Volume", _VOL_STEPS,
                     getattr(state, '_music_volume', 0.5), fmt_fn=lambda v: f"{int(v*100)}%")
    y += row_h
    # Mute All toggle
    muted = getattr(state, '_mute_all', False)
    _draw_option_row(surface, fonts, rect, y, "Mute All",
                     [False, True], muted, fmt_fn=lambda v: "ON" if v else "OFF")
    y += sect_h

    # DISPLAY
    _draw_section_header(surface, fonts, "DISPLAY", x0, y, rect.width - 16)
    y += hdr_h
    _draw_option_row(surface, fonts, rect, y, "FPS Cap", _FPS_OPTIONS,
                     getattr(state, '_fps_cap', 60))
    y += row_h
    show_p = getattr(config, 'SHOW_PARTICLES', True)
    _draw_option_row(surface, fonts, rect, y, "Show Particles",
                     [True, False], show_p, fmt_fn=lambda v: "ON" if v else "OFF")
    y += sect_h

    # DATA
    _draw_section_header(surface, fonts, "DATA", x0, y, rect.width - 16)
    y += hdr_h
    mx, my = pygame.mouse.get_pos()

    # Analytics toggle
    import src.analytics as _an
    an_enabled = _an.is_enabled()
    _draw_option_row(surface, fonts, rect, y, "Analytics",
                     [True, False], an_enabled,
                     fmt_fn=lambda v: "Enabled" if v else "Disabled")
    an_note = fonts['xs'].render("Anonymous gameplay events help improve balance.", True, theme.TEXT_MUTED)
    surface.blit(an_note, (x0 + 2, y + lbl_off + btn_h + sd(2)))
    y += row_h + fonts['xs'].get_height() + sd(4)

    tut_r = pygame.Rect(x0, y, sd(150), sd(32))
    hover_tut = tut_r.collidepoint(mx, my)
    col_tut = theme.BG_CARD_HOVER if hover_tut else theme.BG_CARD
    pygame.draw.rect(surface, col_tut, tut_r, border_radius=6)
    if hover_tut:
        pygame.draw.rect(surface, theme.ACCENT_DIM, tut_r, border_radius=6, width=1)
    ts = fonts['xs'].render("Reset Tutorial", True, theme.TEXT_PRIMARY if hover_tut else theme.TEXT_MUTED)
    surface.blit(ts, ts.get_rect(center=tut_r.center))
    y += sd(32) + sd(12)

    del_r = pygame.Rect(x0, y, sd(150), sd(32))
    hover_del = del_r.collidepoint(mx, my)
    col_del = theme.RED if hover_del else (90, 35, 35)
    pygame.draw.rect(surface, col_del, del_r, border_radius=6)
    ds = fonts['xs'].render("Delete Save", True, theme.TEXT_PRIMARY)
    surface.blit(ds, ds.get_rect(center=del_r.center))

    # Autosave indicator
    y += sd(32) + sd(18)
    as_s = fonts['xs'].render("Auto-save: every 30 seconds", True, theme.TEXT_MUTED)
    surface.blit(as_s, (x0, y))
    y += fonts['xs'].get_height() + sd(8)

    # ── Beta Feedback ──────────────────────────────────────────────────
    _draw_section_header(surface, fonts, "BETA FEEDBACK", x0, y, rect.width - 16)
    y += sd(18)
    # Buttons sized to their labels so they never overlap at 1080p+ (Phase 89).
    bh = sd(30)
    bug_w  = fonts['xs'].size("Report Bug")[0] + sd(config.UI_CARD_PADDING) * 2
    feat_w = fonts['xs'].size("Suggest Feature")[0] + sd(config.UI_CARD_PADDING) * 2
    bug_r  = pygame.Rect(x0, y, bug_w, bh)
    feat_r = pygame.Rect(bug_r.right + sd(8), y, feat_w, bh)
    for btn_r, label, col_h, col_n in [
        (bug_r,  "Report Bug",      (160, 55, 55),  (90, 35, 35)),
        (feat_r, "Suggest Feature", (55, 90, 160),  (30, 55, 100)),
    ]:
        hov = btn_r.collidepoint(mx, my)
        pygame.draw.rect(surface, col_h if hov else col_n, btn_r, border_radius=6)
        bs = fonts['xs'].render(label, True, theme.TEXT_PRIMARY)
        surface.blit(bs, bs.get_rect(center=btn_r.center))
    y += bh + sd(8)
    note = fonts['xs'].render("Copies system info to clipboard. Then send it to:", True, theme.TEXT_MUTED)
    surface.blit(note, (x0, y))
    y += fonts['xs'].get_height() + sd(2)
    dest = fonts['xs'].render("ironassassin03@gmail.com", True, theme.TEXT_GOLD)
    surface.blit(dest, (x0, y))


def _apply_audio(state) -> None:
    """Recompute effective SFX volume from master + sfx + mute and apply."""
    muted  = getattr(state, '_mute_all', False)
    master = float(getattr(state, '_master_volume', 1.0))
    sfx    = float(getattr(state, '_sfx_volume', 1.0))
    effective = 0.0 if muted else (sfx * master)
    sound.set_volume(effective)
    # Store music volume for future music playback
    music_vol = 0.0 if muted else (float(getattr(state, '_music_volume', 0.5)) * master)
    config.MUSIC_VOLUME = music_vol


def handle_settings_click(state, pos: tuple, rect: pygame.Rect) -> None:
    from src.save_load import delete_save, save_game
    fonts = state._fonts
    x0 = rect.x + 14
    # Mirror draw_settings_tab vertical layout exactly (Phase 89).
    btn_h, lbl_off, row_h, hdr_h = _settings_metrics(fonts)
    sect_h = row_h + sd(8)
    y = rect.top + 8 + hdr_h
    _pct = lambda v: f"{int(v * 100)}%"
    _onoff = lambda v: "ON" if v else "OFF"

    # Master volume
    for r, opt in _opt_row_rects(fonts, x0, y + lbl_off, _VOL_STEPS, _pct):
        if r.collidepoint(pos):
            state._master_volume = opt; _apply_audio(state); return
    y += row_h
    # SFX
    for r, opt in _opt_row_rects(fonts, x0, y + lbl_off, _VOL_STEPS, _pct):
        if r.collidepoint(pos):
            state._sfx_volume = opt; _apply_audio(state); return
    y += row_h
    # Music
    for r, opt in _opt_row_rects(fonts, x0, y + lbl_off, _VOL_STEPS, _pct):
        if r.collidepoint(pos):
            state._music_volume = opt; _apply_audio(state); return
    y += row_h
    # Mute All
    for r, opt in _opt_row_rects(fonts, x0, y + lbl_off, [False, True], _onoff):
        if r.collidepoint(pos):
            state._mute_all = opt; _apply_audio(state); return
    y += sect_h + hdr_h  # after DISPLAY header
    # FPS
    for r, opt in _opt_row_rects(fonts, x0, y + lbl_off, _FPS_OPTIONS, None):
        if r.collidepoint(pos):
            state._fps_cap = opt; config.FPS = opt; return
    y += row_h
    # Particles
    for r, opt in _opt_row_rects(fonts, x0, y + lbl_off, [True, False], _onoff):
        if r.collidepoint(pos):
            config.SHOW_PARTICLES = opt; return
    y += sect_h + hdr_h  # after DATA header
    # Analytics toggle
    import src.analytics as _an
    for r, opt in _opt_row_rects(fonts, x0, y + lbl_off, [True, False],
                                 lambda v: "Enabled" if v else "Disabled"):
        if r.collidepoint(pos):
            _an.set_enabled(opt)
            save_game(state); return
    y += row_h + fonts['xs'].get_height() + sd(4)
    # Reset tutorial
    tut_r = pygame.Rect(x0, y, sd(150), sd(32))
    if tut_r.collidepoint(pos):
        state._tutorial_step = 0; state._tutorial_age = 0.0
        state._tutorial_age_step4 = 0.0; state._shown_milestones = set()
        save_game(state); return
    y += sd(32) + sd(12)
    # Delete save
    del_r = pygame.Rect(x0, y, sd(150), sd(32))
    if del_r.collidepoint(pos):
        delete_save()
    y += sd(32) + sd(18) + fonts['xs'].get_height() + sd(8) + sd(18)  # autosave + BETA header
    # Beta feedback buttons (sized to labels, matching draw_settings_tab)
    bh = sd(30)
    bug_w  = fonts['xs'].size("Report Bug")[0] + sd(config.UI_CARD_PADDING) * 2
    feat_w = fonts['xs'].size("Suggest Feature")[0] + sd(config.UI_CARD_PADDING) * 2
    bug_r  = pygame.Rect(x0, y, bug_w, bh)
    feat_r = pygame.Rect(bug_r.right + sd(8), y, feat_w, bh)
    if bug_r.collidepoint(pos):
        _copy_beta_info(state, kind="bug")
        push_notification("Bug report info copied to clipboard!", theme.TEXT_PRIMARY)
        return
    if feat_r.collidepoint(pos):
        _copy_beta_info(state, kind="feature")
        push_notification("Feature request info copied to clipboard!", theme.TEXT_PRIMARY)
        return


def _copy_beta_info(state, kind: str = "bug") -> None:
    """Build a short support blob and copy it to the OS clipboard."""
    import platform
    import src.analytics as _an
    import src.prestige as _pres

    prestige_count = getattr(state, '_prestige_count', 0)
    influence      = getattr(state, 'prestige_tokens', 0)
    rank           = _pres.get_rank(influence)
    lifetime       = getattr(state, 'lifetime_earnings', 0.0)
    play_time_s    = getattr(state, '_play_time', 0.0)
    play_hrs       = int(play_time_s) // 3600
    play_mins      = (int(play_time_s) % 3600) // 60
    an_ver         = _an.ANALYTICS_VERSION

    lines = [
        f"[{'Bug Report' if kind == 'bug' else 'Feature Request'}]",
        f"Game version: {config.VERSION} | Analytics schema: v{an_ver}",
        f"Platform: {platform.system()} {platform.release()}",
        f"Prestige: {prestige_count}  |  Influence: {influence}  |  Rank: {rank}",
        f"Lifetime earnings: {theme.format_number(lifetime)}",
        f"Play time: {play_hrs}h {play_mins}m",
        "",
        "--- Describe the issue / suggestion below ---",
    ]
    text = "\n".join(lines)
    try:
        import pygame
        pygame.scrap.init()
        pygame.scrap.put(pygame.SCRAP_TEXT, text.encode("utf-8"))
    except Exception:
        # Fallback: try tkinter clipboard
        try:
            import tkinter as _tk
            r = _tk.Tk(); r.withdraw()
            r.clipboard_clear(); r.clipboard_append(text); r.update()
            r.destroy()
        except Exception:
            pass


# ─────────────────────── overlay screens ──────────────────────────
def draw_elimination_overlay(surface: pygame.Surface, state, fonts: dict) -> None:
    """Full-screen overlay shown when a rival is eliminated."""
    draw_overlay(surface, 200)
    panel = modal_panel_rect(580, 320)
    cx = panel.centerx
    inner_w = panel.width - 2 * sd(24)
    # Red-tinted panel
    panel_surf = pygame.Surface((panel.width, panel.height), pygame.SRCALPHA)
    pygame.draw.rect(panel_surf, (60, 10, 10, 240), panel_surf.get_rect(), border_radius=16)
    pygame.draw.rect(panel_surf, (200, 60, 60, 200), panel_surf.get_rect(), border_radius=16, width=2)
    surface.blit(panel_surf, panel.topleft)

    rival_name = getattr(state, '_elim_overlay', 'Rival') or 'Rival'
    rewards    = getattr(state, '_elim_rewards', '') or ''

    title = fonts['lg'].render("RIVAL ELIMINATED", True, (255, 80, 80))
    blit_fit_center(surface, title, inner_w, (cx, panel.top + sd(60)))

    name_s = fonts['md'].render(rival_name, True, theme.TEXT_GOLD)
    blit_fit_center(surface, name_s, inner_w, (cx, panel.top + sd(116)))

    epitaph = getattr(state, '_elim_flavor', '') or "has collapsed."
    collapsed = fonts['sm'].render(epitaph, True, theme.TEXT_MUTED)
    blit_fit_center(surface, collapsed, inner_w, (cx, panel.top + sd(146)))

    if rewards:
        rew_s = fonts['sm'].render(rewards, True, theme.GREEN)
        blit_fit_center(surface, rew_s, inner_w, (cx, panel.top + sd(196)))

    pulse = 0.6 + 0.4 * math.sin(getattr(state, '_time', 0.0) * 3.0)
    tap_s = fonts['xs'].render("[ Click or press any key to continue ]", True, theme.TEXT_MUTED)
    tap_s.set_alpha(int(220 * pulse))
    blit_fit_center(surface, tap_s, inner_w, (cx, panel.bottom - sd(52)))


def draw_prestige_climax_overlay(surface: pygame.Surface, state, fonts: dict) -> None:
    """Phase 101 — the run-ending ceremony. Full-screen, brief, skippable.

    Fades in (0.3s) then out (0.6s) so the instant reset underneath is hidden and
    the fresh run is 'revealed' as it fades. Reuses the timed-overlay + modal-panel
    pattern (Phase 92) — no new engines, fonts, or assets."""
    timer = getattr(state, '_prestige_climax_timer', 0.0)
    dur   = config.PRESTIGE_CLIMAX_DURATION
    elapsed = dur - timer
    fade = max(0.0, min(1.0, elapsed / 0.3, timer / 0.6))

    draw_overlay(surface, int(205 * fade))
    panel = modal_panel_rect(560, 300)
    cx = panel.centerx
    inner_w = panel.width - 2 * sd(24)

    panel_surf = pygame.Surface((panel.width, panel.height), pygame.SRCALPHA)
    pygame.draw.rect(panel_surf, (40, 32, 8, int(244 * fade)), panel_surf.get_rect(), border_radius=16)
    pygame.draw.rect(panel_surf, (*theme.TEXT_GOLD, int(220 * fade)), panel_surf.get_rect(), border_radius=16, width=2)
    surface.blit(panel_surf, panel.topleft)

    count  = int(getattr(state, '_prestige_climax_count', 1) or 1)
    tokens = int(getattr(state, '_prestige_climax_tokens', 0) or 0)
    rank   = getattr(state, '_prestige_climax_rank', '') or ''

    def _fa(surf):
        surf.set_alpha(int(255 * fade))
        return surf

    headline = "FIRST PRESTIGE" if count <= 1 else "EMPIRE ASCENDED"
    title = _fa(fonts['lg'].render(headline, True, theme.TEXT_GOLD))
    blit_fit_center(surface, title, inner_w, (cx, panel.top + sd(58)))

    reward = _fa(fonts['md'].render(f"+{tokens} Influence Earned", True, theme.GREEN))
    blit_fit_center(surface, reward, inner_w, (cx, panel.top + sd(122)))

    if rank:
        rs = _fa(fonts['sm'].render(f"→  {rank}", True, theme.PRESTIGE_LABEL))
        blit_fit_center(surface, rs, inner_w, (cx, panel.top + sd(164)))

    fl = _fa(fonts['sm'].render("Your bonuses carry forward. A new empire begins.",
                                True, theme.TEXT_MUTED))
    blit_fit_center(surface, fl, inner_w, (cx, panel.top + sd(202)))

    pulse = 0.6 + 0.4 * math.sin(getattr(state, '_time', 0.0) * 3.0)
    tap = fonts['xs'].render("[ Click or press any key to continue ]", True, theme.TEXT_MUTED)
    tap.set_alpha(int(220 * pulse * fade))
    blit_fit_center(surface, tap, inner_w, (cx, panel.bottom - sd(40)))


def draw_offline_overlay(surface: pygame.Surface, state, fonts: dict) -> None:
    """Full return summary screen — shown whenever the player has been away."""
    draw_overlay(surface, 225)
    panel = modal_panel_rect(560, 460)
    cx = panel.centerx
    inner_w = panel.width - 2 * sd(24)
    pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=16)
    pygame.draw.rect(surface, theme.ACCENT_DIM, panel, border_radius=16, width=2)

    xs_h = fonts['xs'].get_height()
    sm_h = fonts['sm'].get_height()

    # ── Title ──────────────────────────────────────────────────────────────
    title = fonts['lg'].render("WELCOME BACK, BOSS", True, theme.TEXT_GOLD)
    blit_fit_center(surface, title, inner_w, (cx, panel.top + sd(32)))

    secs_away = getattr(state, '_offline_secs_away', 0)
    hours = int(secs_away) // 3600
    mins  = (int(secs_away) % 3600) // 60
    away_str = f"Away for {hours}h {mins}m" if hours else f"Away for {mins}m"
    away_s = fonts['sm'].render(away_str, True, theme.TEXT_MUTED)
    blit_fit_center(surface, away_s, inner_w, (cx, panel.top + sd(62)))

    # ── Divider ────────────────────────────────────────────────────────────
    div_y = panel.top + sd(84)
    pygame.draw.line(surface, theme.ACCENT_DIM, (panel.left + sd(20), div_y), (panel.right - sd(20), div_y))

    # ── Summary rows (font-driven pitch so they never collide) ─────────────
    row_y = div_y + sd(16)
    left_x  = panel.left + sd(24)
    right_x = panel.right - sd(24)

    def _row(label: str, value: str, val_col, note: str = ""):
        nonlocal row_y
        lbl_s = fonts['sm'].render(label, True, theme.TEXT_MUTED)
        surface.blit(lbl_s, (left_x, row_y))
        val_s = fonts['sm'].render(value, True, val_col)
        surface.blit(val_s, val_s.get_rect(midright=(right_x, row_y + sm_h // 2)))
        if note:
            note_s = fonts['xs'].render(note, True, theme.TEXT_MUTED)
            surface.blit(note_s, (left_x + sd(4), row_y + sm_h + sd(2)))
            row_y += sm_h + xs_h + sd(12)
        else:
            row_y += sm_h + sd(14)

    # Cash earned
    capped = getattr(state, '_offline_capped', False)
    gain   = getattr(state, '_offline_gain', 0.0)
    cash_note = "Cap reached — check in sooner for more" if capped else ""
    _row("Cash Earned", f"+{theme.format_number(gain)}", theme.ACCENT, cash_note)

    # Divider
    pygame.draw.line(surface, (*theme.ACCENT_DIM, 60),
                     (panel.left + sd(20), row_y), (panel.right - sd(20), row_y))
    row_y += sd(10)

    # Operations
    ops_ready = getattr(state, '_return_ops_ready', 0)
    if ops_ready > 0:
        ops_note = "Go to Operations tab to collect"
        _row("Operations Ready", f"{ops_ready} complete", theme.GREEN, ops_note)
    else:
        ops_active = sum(1 for op in getattr(state, 'operations', [])
                         if op.active and not op.collected)
        if ops_active > 0:
            _row("Operations", f"{ops_active} in progress", theme.TEXT_MUTED)

    # Territory
    t_player = getattr(state, '_return_territory_player', 0)
    t_total  = getattr(state, '_return_territory_total', 0)
    if t_total > 0:
        t_col = theme.ACCENT if t_player > 0 else theme.TEXT_MUTED
        _row("Territory", f"{t_player} / {t_total} districts", t_col)

    # Rivals
    r_active = getattr(state, '_return_rival_active', 0)
    r_war    = getattr(state, '_return_rival_at_war', 0)
    if r_active > 0:
        if r_war > 0:
            _row("Rivals", f"{r_active} active, {r_war} at war", (220, 100, 80))
        else:
            _row("Rivals", f"{r_active} active", theme.TEXT_MUTED)

    # ── Rival Activity ─────────────────────────────────────────────────────
    rival_events = getattr(state, '_offline_rival_events', [])
    if rival_events:
        pygame.draw.line(surface, (*theme.ACCENT_DIM, 60),
                         (panel.left + sd(20), row_y), (panel.right - sd(20), row_y))
        row_y += sd(8)
        hdr_s = fonts['xs'].render("Rival Activity", True, (180, 100, 80))
        surface.blit(hdr_s, (left_x, row_y))
        row_y += hdr_s.get_height() + sd(4)
        for ev in rival_events[:3]:
            ev_s = fonts['xs'].render(f"• {ev}", True, (160, 120, 100))
            surface.blit(ev_s, (left_x + sd(8), row_y))
            row_y += ev_s.get_height() + sd(3)

    # ── Divider ────────────────────────────────────────────────────────────
    pygame.draw.line(surface, theme.ACCENT_DIM,
                     (panel.left + sd(20), row_y + sd(4)), (panel.right - sd(20), row_y + sd(4)))

    pulse = 0.6 + 0.4 * math.sin(getattr(state, '_time', 0.0) * 3.0)
    tap_s = fonts['sm'].render("[ Click or press any key to collect ]", True, theme.TEXT_PRIMARY)
    tap_s.set_alpha(int(255 * pulse))
    blit_fit_center(surface, tap_s, inner_w, (cx, panel.bottom - sd(28)))


def draw_daily_reward_overlay(surface: pygame.Surface, state, fonts: dict) -> None:
    draw_overlay(surface, 220)
    panel = modal_panel_rect(560, 380)
    cx = panel.centerx
    inner_w = panel.width - 2 * sd(24)
    pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=16)
    pygame.draw.rect(surface, theme.ACCENT_DIM, panel, border_radius=16, width=2)

    title = fonts['lg'].render("DAILY BONUS", True, theme.TEXT_GOLD)
    blit_fit_center(surface, title, inner_w, (cx, panel.top + sd(42)))

    streak = getattr(state, '_daily_streak', 1)
    reward = getattr(state, '_daily_reward', 0.0)
    # Day strip sized to fit the panel interior (7 cards + 6 gaps).
    gap = sd(6)
    card_w = max(sd(24), min(sd(58), (inner_w - 6 * gap) // 7))
    card_h = sd(70)
    total_w = 7 * card_w + 6 * gap
    strip_x = cx - total_w // 2
    strip_y = panel.top + sd(100)
    for day in range(1, 8):
        cx_card = strip_x + (day - 1) * (card_w + gap) + card_w // 2
        cy_card = strip_y + card_h // 2
        if day < streak:
            bg = theme.ACCENT_DIM; border_col = theme.ACCENT; border_w = 1; tc = theme.BG_DARK
        elif day == streak:
            bg = theme.ACCENT; border_col = theme.TEXT_GOLD; border_w = 2; tc = theme.BG_DARK
        else:
            bg = theme.BG_CARD; border_col = theme.BG_CARD; border_w = 1; tc = theme.TEXT_MUTED
        cr = pygame.Rect(strip_x + (day - 1) * (card_w + gap), strip_y, card_w, card_h)
        pygame.draw.rect(surface, bg, cr, border_radius=8)
        pygame.draw.rect(surface, border_col, cr, border_radius=8, width=border_w)
        day_s = fonts['xs'].render(f"Day {day}", True, tc)
        blit_fit_center(surface, day_s, card_w - sd(4), (cx_card, cy_card - sd(12)))
        star_s = fonts['sm'].render("*" if day <= streak else "·", True, tc)
        surface.blit(star_s, star_s.get_rect(center=(cx_card, cy_card + sd(14))))

    reward_s = fonts['lg'].render(f"+{theme.format_number(reward)}", True, theme.ACCENT)
    blit_fit_center(surface, reward_s, inner_w, (cx, panel.top + sd(230)))

    pulse = 0.6 + 0.4 * math.sin(getattr(state, '_time', 0.0) * 3.0)
    tap_s = fonts['sm'].render("[ Click or press any key ]", True, theme.TEXT_PRIMARY)
    tap_s.set_alpha(int(255 * pulse))
    blit_fit_center(surface, tap_s, inner_w, (cx, panel.bottom - sd(40)))


_MILESTONE_DATA = {
    1_000:             ("SMALL TIME",         "Every empire starts somewhere"),
    10_000:            ("GETTING NOTICED",    "The streets are talking"),
    100_000:           ("MADE MAN",           "You run this neighborhood"),
    1_000_000:         ("CRIME LORD",         "The whole city is yours"),
    10_000_000:        ("UNTOUCHABLE",        "Nobody can stop you now"),
    100_000_000:       ("KINGPIN",            "Entire districts bow to you"),
    1_000_000_000:     ("SHADOW GOVERNMENT",  "You are the system"),
}


def _draw_milestone_footer(surface: pygame.Surface, fonts: dict, cx: int,
                           panel: pygame.Rect, state) -> None:
    """Timer bar + dismiss hint anchored to the panel bottom."""
    from src.tutorial import _MILESTONE_AUTO_DISMISS
    timer = getattr(state, '_milestone_timer', 0.0)
    ratio = max(0.0, timer / _MILESTONE_AUTO_DISMISS)
    bar_w = panel.width - sd(40)
    bar_x = cx - bar_w // 2
    bar_h = sd(6)
    bar_y = panel.bottom - sd(48)
    pygame.draw.rect(surface, theme.BG_CARD,
                     pygame.Rect(bar_x, bar_y, bar_w, bar_h), border_radius=3)
    if ratio > 0:
        pygame.draw.rect(surface, theme.ACCENT,
                         pygame.Rect(bar_x, bar_y, int(bar_w * ratio), bar_h), border_radius=3)
    pulse = 0.55 + 0.45 * math.sin(getattr(state, '_time', 0.0) * 2.8)
    tap_s = fonts['sm'].render("[ click · enter · space to continue ]", True, theme.TEXT_PRIMARY)
    tap_s.set_alpha(int(255 * pulse))
    blit_fit_center(surface, tap_s, panel.width - sd(40), (cx, panel.bottom - sd(24)))


def draw_milestone_overlay(surface: pygame.Surface, state, fonts: dict,
                            threshold) -> None:
    draw_overlay(surface, 205)
    cx = config.SCREEN_WIDTH // 2
    cy = config.SCREEN_HEIGHT // 2

    # ── Money milestones (int keys in _MILESTONE_DATA) ────────────────────────
    if not isinstance(threshold, str):
        title_str, subtitle_str = _MILESTONE_DATA.get(threshold, ("MILESTONE", ""))
        try:
            amt_text = f"${theme.format_number(float(threshold))}"
        except (TypeError, ValueError):
            amt_text = str(threshold)

        panel = modal_panel_rect(500, 300)
        cx = panel.centerx
        inner_w = panel.width - 2 * sd(24)
        pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=16)
        pygame.draw.rect(surface, theme.ACCENT_DIM, panel, border_radius=16, width=2)

        amt_s = fonts['xs'].render(amt_text, True, theme.TEXT_MUTED)
        blit_fit_center(surface, amt_s, inner_w, (cx, panel.top + sd(50)))
        title_s = fonts['lg'].render(title_str, True, theme.TEXT_GOLD)
        blit_fit_center(surface, title_s, inner_w, (cx, panel.top + sd(108)))
        sub_s = fonts['md'].render(subtitle_str, True, theme.TEXT_MUTED)
        blit_fit_center(surface, sub_s, inner_w, (cx, panel.top + sd(172)))
        _draw_milestone_footer(surface, fonts, cx, panel, state)
        return

    # ── RANK UP\n<name>\n<flavor>\n<desc> ─────────────────────────────────────
    # Identity-first (Phase 59): rank name is the gold headline, an optional
    # flavor line says what the player BECAME, then the mechanical unlocks.
    # Robust to the legacy 3-part form ("RANK UP\n<name>\n<desc>", no flavor).
    if threshold.startswith("RANK UP\n"):
        parts = threshold.split("\n")
        rank_name = parts[1] if len(parts) > 1 else "RANK UP"
        if len(parts) >= 4:
            flavor_str = parts[2].strip()
            mech_str   = parts[3]
        else:
            flavor_str = ""
            mech_str   = parts[2] if len(parts) > 2 else ""
        # Split " • "-joined unlocks onto separate lines so nothing overflows
        # the fixed-width panel (the single md line previously clipped badly).
        mech_lines = [s.strip() for s in mech_str.split("•") if s.strip()]

        # Height grows with the number of unlock lines so they never overflow.
        body_h = (fonts['sm'].get_height() + sd(10) if flavor_str else 0) \
            + len(mech_lines) * (fonts['xs'].get_height() + sd(5))
        content_h = sd(140) + body_h + sd(56)
        pw = min(config.SCREEN_WIDTH - 2 * sd(16), sd(500))
        ph = min(config.SCREEN_HEIGHT - 2 * sd(16), content_h)
        panel = pygame.Rect((config.SCREEN_WIDTH - pw) // 2,
                            (config.SCREEN_HEIGHT - ph) // 2, pw, ph)
        cx = panel.centerx
        inner_w = panel.width - 2 * sd(24)
        pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=16)
        pygame.draw.rect(surface, theme.ACCENT_DIM, panel, border_radius=16, width=2)

        hdr_s = fonts['xs'].render("RANK UP", True, theme.TEXT_MUTED)
        blit_fit_center(surface, hdr_s, inner_w, (cx, panel.top + sd(38)))
        title_s = fonts['lg'].render(rank_name, True, theme.TEXT_GOLD)
        blit_fit_center(surface, title_s, inner_w, (cx, panel.top + sd(92)))

        y = panel.top + sd(134)
        if flavor_str:
            fl_s = fonts['sm'].render(flavor_str, True, theme.TEXT_PRIMARY)
            blit_fit_center(surface, fl_s, inner_w, (cx, y))
            y += fl_s.get_height() + sd(10)
        for line in mech_lines:
            ms = fonts['xs'].render(line, True, theme.TEXT_MUTED)
            blit_fit_center(surface, ms, inner_w, (cx, y))
            y += ms.get_height() + sd(5)
        _draw_milestone_footer(surface, fonts, cx, panel, state)
        return

    # ── Custom multi-line tutorial/event message ───────────────────────────────
    # Format: "TITLE\nLine 1\nLine 2\n..."
    # First non-empty line = title (large gold); remaining = body lines (xs, muted)
    parts = [p for p in threshold.split("\n") if p.strip()]
    title_str  = parts[0] if parts else "MESSAGE"
    body_lines = parts[1:]

    line_h = fonts['xs'].get_height() + sd(7)
    content_h = sd(36) + fonts['lg'].get_height() + sd(14) + sd(12) \
        + len(body_lines) * line_h + sd(70)
    ph = min(config.SCREEN_HEIGHT - 2 * sd(16), max(sd(260), content_h))
    pw = min(config.SCREEN_WIDTH - 2 * sd(16), sd(520))
    panel = pygame.Rect((config.SCREEN_WIDTH - pw) // 2,
                        (config.SCREEN_HEIGHT - ph) // 2, pw, ph)
    cx = panel.centerx
    inner_w = panel.width - 2 * sd(24)
    pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=16)
    pygame.draw.rect(surface, theme.ACCENT_DIM, panel, border_radius=16, width=2)

    y = panel.top + sd(36)
    title_s = fonts['lg'].render(title_str, True, theme.TEXT_GOLD)
    blit_fit_center(surface, title_s, inner_w, (cx, y + title_s.get_height() // 2))
    y += title_s.get_height() + sd(14)

    if body_lines:
        pygame.draw.rect(surface, theme.ACCENT_DIM, pygame.Rect(cx - sd(80), y, sd(160), 1))
        y += sd(12)
        for line in body_lines:
            ls = fonts['xs'].render(line, True, theme.TEXT_MUTED)
            blit_fit_center(surface, ls, inner_w, (cx, y + fonts['xs'].get_height() // 2))
            y += line_h

    _draw_milestone_footer(surface, fonts, cx, panel, state)


def _blit_fit_left(surface, text_surf, max_w, midleft):
    """Blit *text_surf* at *midleft*, uniformly scaled down to fit *max_w*
    (Phase 89). The prestige button has a capped width while fonts scale with
    resolution, so the info lines must shrink-to-fit rather than clip/overflow."""
    w = text_surf.get_width()
    if w > max_w and max_w > 0:
        f = max_w / w
        text_surf = pygame.transform.smoothscale(
            text_surf, (int(max_w), max(1, int(text_surf.get_height() * f))))
    surface.blit(text_surf, text_surf.get_rect(midleft=midleft))


def _prestige_advice_lines(adv: dict) -> list[str]:
    """Format prestige intel for the prestige button / confirm dialog."""
    if adv.get('enhanced'):
        tags = {
            'NOW': 'PRESTIGE NOW — peak window',
            'WAIT_5': 'WAIT 5M — more Influence incoming',
            'WAIT_10': 'WAIT 10M — patience pays',
            'BUILD': adv['recommend'],
        }
        tag = tags.get(adv.get('window', ''), adv['recommend'])
        cmp_line = (
            f"now +{adv['gain_now']}  |  5m +{adv['gain_5m']} (+{adv['delta_5m']})  "
            f"|  10m +{adv['gain_10m']} (+{adv['delta_10m']})"
        )
        conf = adv.get('confidence')
        head = f"Rudy: {tag}"
        if conf is not None and adv.get('window') != 'BUILD':
            head += f"  ({conf}% confidence)"
        return [head, cmp_line, adv.get('summary', '')]
    return [
        f"Consigliere: {adv['recommend']}  "
        f"(now +{adv['gain_now']} vs 5m +{adv['gain_5m']})",
    ]


def draw_prestige_btn(surface: pygame.Surface, state, fonts: dict) -> None:
    r = PRESTIGE_RECT
    mx, my = pygame.mouse.get_pos()
    hover = r.collidepoint(mx, my)
    can_p = prestige.can_prestige(state)
    clip = surface.get_clip()
    surface.set_clip(r)

    if can_p:
        bg_col     = (45, 22, 58) if hover else (36, 18, 48)
        border_col = theme.NOIR_GOLD_BRIGHT if hover else theme.NOIR_GOLD
        bar_col    = theme.PRESTIGE_LABEL
        label_col  = theme.PRESTIGE_LABEL
    else:
        bg_col     = (22, 20, 30) if hover else (16, 14, 22)
        border_col = theme.NOIR_GOLD_BRIGHT if hover else theme.NOIR_GOLD_DEEP
        bar_col    = theme.NOIR_GOLD_DEEP
        label_col  = theme.NOIR_BONE_DIM

    _draw_glass_panel(surface, r, fill_alpha=200 if can_p else 170)
    tint = pygame.Surface((r.width, r.height), pygame.SRCALPHA)
    pygame.draw.rect(tint, (*bg_col, 140 if can_p else 100), tint.get_rect(), border_radius=8)
    surface.blit(tint, r.topleft)

    # Progress fill bar (earnings-based, always visible while locked).
    if not can_p:
        req_earnings = prestige.prestige_earnings_required(state)
        if req_earnings > 0:
            fill_ratio = min(1.0, state.lifetime_earnings / req_earnings)
            fill_w = max(0, int(r.width * fill_ratio))
            if fill_w > 4:
                fill_col = (70, 40, 110) if fill_ratio < 0.9 else (110, 50, 170)
                fill_surf = pygame.Surface((fill_w, r.height), pygame.SRCALPHA)
                pygame.draw.rect(fill_surf, (*fill_col, 180), fill_surf.get_rect(), border_radius=8)
                surface.blit(fill_surf, r.topleft)

    pygame.draw.rect(surface, border_col, r, border_radius=8, width=1)
    pygame.draw.rect(surface, bar_col, pygame.Rect(r.x, r.y, 3, r.height))

    pad_x = r.x + 14
    if can_p:
        gain = prestige.calc_influence_gain(state.lifetime_earnings)
        avail_w = r.right - 8 - pad_x
        ls = fonts['sm'].render("* PRESTIGE", True, label_col)
        y_line = r.y + 8
        _blit_fit_left(surface, ls, avail_w, (pad_x, y_line))
        y_line += max(14, ls.get_height() - 2)
        income_full  = f"+{gain} Influence  •  +{gain * 2}% permanent income"
        income_short = f"+{gain} Influence  •  +{gain * 2}% income"
        income_txt = income_full if fonts['xs'].size(income_full)[0] <= avail_w else income_short
        rs = fonts['xs'].render(income_txt, True, (180, 100, 255))
        _blit_fit_left(surface, rs, avail_w, (pad_x, y_line))
        y_line += 13
        keeps_full  = "Keeps: Influence, Respect, Perks, Stats"
        keeps_short = "Keeps: Inf, Respect, Perks"
        keeps_txt = keeps_full if fonts['xs'].size(keeps_full)[0] <= avail_w else keeps_short
        ks = fonts['xs'].render(keeps_txt, True, (120, 90, 170))
        _blit_fit_left(surface, ks, avail_w, (pad_x, y_line))
        try:
            import src.managers as _mgr
            adv = _mgr.prestige_advice(state)
            if adv and y_line + 11 <= r.bottom - 4:
                lines = _prestige_advice_lines(adv)
                y_adv = min(r.bottom - 12, y_line + 14)
                for line in lines:
                    if y_adv + 11 > r.bottom - 2:
                        break
                    cs = fonts['xs'].render(line, True, theme.TEXT_GOLD)
                    _blit_fit_left(surface, cs, avail_w, (pad_x, y_adv))
                    y_adv += 11
        except Exception:
            pass
    else:
        # ── Locked: show every requirement with live progress ────────
        reqs = prestige.check_requirements(state)

        title_s = fonts['xs'].render("* PRESTIGE  —  LOCKED", True, label_col)
        surface.blit(title_s, title_s.get_rect(midleft=(pad_x, r.y + 11)))

        # Thin divider
        pygame.draw.line(surface, (*border_col, 80),
                         (r.x + 8, r.y + 22), (r.right - 8, r.y + 22))

        row_y = r.y + 28
        row_h = max(14, (r.height - 32) // max(1, len(reqs)))
        row_h = min(row_h, 17)

        _req_labels = {
            'earnings': ('Earnings', lambda c, t: f"{theme.format_number(c)} / {theme.format_number(t)}"),
            'rank':     ('Rank',     lambda c, t: f"{c}  →  need {t}"),
            'dealers':  ('Dealers',  lambda c, t: f"{int(c)} / {int(t)}"),
            'rackets':  ('Rackets',  lambda c, t: f"{int(c)} / {int(t)}"),
            'chops':    ('Chops',    lambda c, t: f"{int(c)} / {int(t)}"),
        }
        for key, (cur, req, met) in reqs.items():
            if row_y + row_h > r.bottom - 4:
                break
            cfg = _req_labels.get(key)
            if cfg is None:
                continue
            lbl, fmt_fn = cfg
            try:
                detail = fmt_fn(cur, req)
            except Exception:
                detail = f"{cur} / {req}"

            check_col = (70, 200, 70) if met else (210, 70, 55)
            check_s = fonts['xs'].render("v" if met else "x", True, check_col)
            surface.blit(check_s, (pad_x, row_y))

            text_col = (100, 160, 100) if met else (145, 120, 175)
            req_s = fonts['xs'].render(f"{lbl}:  {detail}", True, text_col)
            surface.blit(req_s, (pad_x + 14, row_y))
            row_y += row_h
        try:
            import src.managers as _mgr
            adv = _mgr.prestige_advice(state)
            if adv and row_y + row_h <= r.bottom - 4:
                for line in _prestige_advice_lines(adv):
                    if row_y + row_h > r.bottom - 4:
                        break
                    cs = fonts['xs'].render(line, True, theme.TEXT_GOLD)
                    surface.blit(cs, (pad_x, row_y))
                    row_y += row_h
        except Exception:
            pass
    surface.set_clip(clip)


def draw_prestige_confirm(surface: pygame.Surface, state, fonts: dict) -> None:
    draw_overlay(surface, 190)
    cx, cy = config.SCREEN_WIDTH // 2, config.SCREEN_HEIGHT // 2
    try:
        import src.managers as _mgr
        adv = _mgr.prestige_advice(state)
    except Exception:
        adv = None
    extra = 56 if adv and adv.get('enhanced') else 0
    panel  = pygame.Rect(cx - 240, cy - 155 - extra // 2, 480, 310 + extra)
    pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=14)
    pygame.draw.rect(surface, theme.ACCENT_DIM, panel, border_radius=14, width=1)

    gain = prestige.calc_influence_gain(state.lifetime_earnings)

    title_s = fonts['lg'].render("* PRESTIGE?", True, theme.TEXT_GOLD)
    surface.blit(title_s, title_s.get_rect(center=(cx, panel.top + 28)))

    gain_s = fonts['sm'].render(
        f"+{gain} Influence  →  permanent +{gain * 2}% income", True, theme.ACCENT)
    surface.blit(gain_s, gain_s.get_rect(center=(cx, panel.top + 58)))

    pygame.draw.line(surface, (*theme.ACCENT_DIM, 60),
                     (panel.left + 20, panel.top + 76), (panel.right - 20, panel.top + 76))

    # Two-column breakdown
    col_w = 200
    left_x  = cx - col_w - 4
    right_x = cx + 4
    row_y   = panel.top + 88

    # Left column: RESETS
    hdr_reset = fonts['xs'].render("RESETS", True, (220, 90, 70))
    surface.blit(hdr_reset, (left_x, row_y))
    pygame.draw.line(surface, (220, 90, 70),
                     (left_x, row_y + 14), (left_x + col_w - 4, row_y + 14))
    for i, item in enumerate(("Cash & balance", "Buildings", "Upgrades", "Temporary progress")):
        s = fonts['xs'].render(f"x  {item}", True, (200, 110, 90))
        surface.blit(s, (left_x + 4, row_y + 20 + i * 16))

    # Right column: YOU KEEP
    hdr_keep = fonts['xs'].render("YOU KEEP", True, theme.GREEN)
    surface.blit(hdr_keep, (right_x, row_y))
    pygame.draw.line(surface, theme.GREEN,
                     (right_x, row_y + 14), (right_x + col_w - 4, row_y + 14))
    for i, item in enumerate(("Influence (Prestige Tokens)", "Respect", "Prestige perks",
                               "Lifetime statistics")):
        s = fonts['xs'].render(f"v  {item}", True, (100, 190, 110))
        surface.blit(s, (right_x + 4, row_y + 20 + i * 16))

    if adv and adv.get('enhanced'):
        rudy_y = panel.bottom - 92
        pygame.draw.line(surface, (*theme.ACCENT_DIM, 60),
                         (panel.left + 20, rudy_y - 8), (panel.right - 20, rudy_y - 8))
        hdr = fonts['xs'].render("RUDY'S PRESTIGE WINDOWS", True, theme.TEXT_GOLD)
        surface.blit(hdr, hdr.get_rect(center=(cx, rudy_y + 6)))
        rows = [
            ("Now", f"+{adv['gain_now']} Influence"),
            ("5 min", f"+{adv['gain_5m']} (+{adv['delta_5m']})"),
            ("10 min", f"+{adv['gain_10m']} (+{adv['delta_10m']})"),
        ]
        for i, (lbl, val) in enumerate(rows):
            highlight = (
                (adv['window'] == 'NOW' and lbl == 'Now')
                or (adv['window'] == 'WAIT_5' and lbl == '5 min')
                or (adv['window'] == 'WAIT_10' and lbl == '10 min')
            )
            col = theme.GREEN if highlight else theme.TEXT_MUTED
            ls = fonts['xs'].render(lbl, True, col)
            vs = fonts['xs'].render(val, True, col)
            surface.blit(ls, (panel.left + 40, rudy_y + 22 + i * 14))
            surface.blit(vs, (panel.left + 120, rudy_y + 22 + i * 14))
        rec = fonts['xs'].render(f"→ {adv['recommend']}", True, theme.TEXT_GOLD)
        surface.blit(rec, rec.get_rect(center=(cx, rudy_y + 68)))

    yes_r = pygame.Rect(cx - 110, panel.bottom - 52, 95, 38)
    no_r  = pygame.Rect(cx + 15,  panel.bottom - 52, 95, 38)
    pygame.draw.rect(surface, theme.BTN_YES, yes_r, border_radius=8)
    pygame.draw.rect(surface, theme.BTN_NO,  no_r,  border_radius=8)
    ys = fonts['md'].render("Yes", True, theme.TEXT_PRIMARY)
    ns = fonts['md'].render("No",  True, theme.TEXT_PRIMARY)
    surface.blit(ys, ys.get_rect(center=yes_r.center))
    surface.blit(ns, ns.get_rect(center=no_r.center))
