"""Scaling helpers for responsive UI.

All helpers read the live SCALE_X / SCALE_Y / UI_SCALE values from config,
which are updated by ui.reinit_layout() on every VIDEORESIZE event.

At the default design resolution (900×720) every function returns the
original pixel value unchanged — full backward compatibility.

Usage:
    from src.scale import sx, sy, sd, anchor_right, anchor_bottom, center_x, center_y

    pygame.draw.circle(surface, color, (sx(42), sy(32)), sd(14))
    surface.blit(text, (sx(64), sy(6)))
    r = pygame.Rect(anchor_right(bar_w, margin=12), sy(60), bar_w, bar_h)
"""
from __future__ import annotations
import config


def sx(px: float) -> int:
    """Scale a pixel value along the horizontal axis."""
    return int(px * config.SCALE_X)


def sy(px: float) -> int:
    """Scale a pixel value along the vertical axis."""
    return int(px * config.SCALE_Y)


def sd(px: float) -> int:
    """Scale a dimension uniformly (uses the smaller of SCALE_X / SCALE_Y).

    Use for radii, border widths, and square elements that must stay
    proportional rather than stretching to fill one axis.
    """
    return max(1, int(px * config.UI_SCALE))


def anchor_right(width: int, margin: int = 0) -> int:
    """Left edge for a widget of *width* flush against the right edge."""
    return config.SCREEN_WIDTH - width - margin


def anchor_bottom(height: int, margin: int = 0) -> int:
    """Top edge for a widget of *height* flush against the bottom edge."""
    return config.SCREEN_HEIGHT - height - margin


def center_x(width: int = 0) -> int:
    """Horizontal center of the screen, optionally offset by half *width*."""
    return (config.SCREEN_WIDTH - width) // 2


def center_y(height: int = 0) -> int:
    """Vertical center of the screen, optionally offset by half *height*."""
    return (config.SCREEN_HEIGHT - height) // 2


def ensure_gap(prev_bottom: int, rect, min_gap: int):
    """Modal safety rule (Phase 90): push *rect* down so its top sits at least
    *min_gap* below *prev_bottom*. Mutates and returns *rect*. Stacking every
    element through this guarantees adjacent controls can never collide."""
    if rect.top < prev_bottom + min_gap:
        rect.top = prev_bottom + min_gap
    return rect


def fit_footer(footer_rect, panel, bottom_margin: int):
    """Footer safety rule (Phase 90): keep *footer_rect* inside *panel* with at
    least *bottom_margin* below it. Mutates and returns *footer_rect*. Only ever
    moves the footer up, so the caller must already place it clear of any control
    above (otherwise raise the panel height instead)."""
    max_bottom = panel.bottom - bottom_margin
    if footer_rect.bottom > max_bottom:
        footer_rect.bottom = max_bottom
    return footer_rect
