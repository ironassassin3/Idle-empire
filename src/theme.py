"""Centralized visual theme: colors, fonts."""
import pygame

# Phase 122/127 — noir palette (aligned with landing/index.html)
NOIR_INK         = (  8,   7,  10)
NOIR_INK_2       = ( 14,  12,  16)
NOIR_SMOKE       = ( 21,  18,  26)
NOIR_GLASS       = ( 14,  12,  18)
NOIR_CARD        = ( 18,  16,  24)
NOIR_CARD_HOVER  = ( 28,  25,  36)
NOIR_GOLD        = (200, 163,  90)
NOIR_GOLD_BRIGHT = (236, 202, 125)
NOIR_GOLD_DEEP   = (138, 106,  47)
NOIR_BONE        = (233, 226, 212)
NOIR_BONE_DIM    = (165, 156, 138)
NOIR_CRIMSON     = (157,  28,  34)
NOIR_CRIMSON_DIM = (110,  22,  28)
NOIR_LINE        = (200, 163,  90)   # hairline accent — use with alpha at draw site

# Legacy names → noir (Phase 127). Semantic colors below stay distinct.
BG_DARK       = NOIR_INK
BG_PANEL      = NOIR_SMOKE
BG_CARD       = NOIR_CARD
BG_CARD_HOVER = NOIR_CARD_HOVER

ACCENT        = NOIR_GOLD_BRIGHT
ACCENT_DIM    = NOIR_GOLD_DEEP

BLUE_BRIGHT   = ( 80, 140, 255)
BLUE_MID      = ( 55, 100, 200)

GREEN         = ( 60, 210, 120)
RED           = (220,  70,  70)

TEXT_PRIMARY  = NOIR_BONE
TEXT_MUTED    = NOIR_BONE_DIM
TEXT_GOLD     = NOIR_GOLD_BRIGHT

PURPLE_CARD   = ( 35,  30,  55)
PURPLE_BRIGHT = (160,  80, 255)
PURPLE_DEEP   = ( 60,  20,  90)

BLUE_HIGHLIGHT = (100, 160, 255)   # legacy click highlight
BLUE_SHADOW    = ( 30,  60, 140)
PARTICLE_IDLE  = (100, 230, 160)

CLICK_STORM    = (200, 100, 255)
CRIT_COLOR     = (255, 140,  40)
PRESTIGE_LABEL = (220, 180, 255)
OVERLAY_DARK   = (  0,   0,   0)
BTN_YES        = ( 40, 150,  70)
BTN_NO         = (150,  50,  60)
BTN_DISABLED   = ( 50,  50,  65)


_SUFFIXES = [
    (1e33, "Dc"),
    (1e30, "No"),
    (1e27, "Oc"),
    (1e24, "Sp"),
    (1e21, "Sx"),
    (1e18, "Qi"),
    (1e15, "Qa"),
    (1e12, "T"),
    (1e9,  "B"),
    (1e6,  "M"),
    (1e3,  "K"),
]


def format_number(n: float) -> str:
    """Compact large numbers up to Decillion: 1.2K, 4.5M, 2.1B … 3.4Dc.
    Handles negative values, NaN, and inf without crashing."""
    try:
        n = float(n)
    except (TypeError, ValueError):
        return "0"
    if n != n or abs(n) == float('inf'):   # NaN or inf guard
        return "0"
    neg = n < 0
    n = abs(n)
    for threshold, suffix in _SUFFIXES:
        if n >= threshold:
            val = n / threshold
            # Use 1 decimal for large values, 2 for smaller suffixes
            decimals = 1 if val >= 10 else 2
            formatted = f"{val:.{decimals}f}".rstrip('0').rstrip('.')
            result = f"{formatted}{suffix}"
            return f"-{result}" if neg else result
    return f"{int(n)}" if not neg else f"-{int(n)}"


def format_money(n: float) -> str:
    """Like format_number but prefixed with $."""
    return f"${format_number(n)}"


def _match_mono() -> str | None:
    return (pygame.font.match_font("consolas")
            or pygame.font.match_font("couriernew")
            or pygame.font.match_font("courier"))


def _match_display() -> str | None:
    return (pygame.font.match_font("timesnewroman")
            or pygame.font.match_font("georgia")
            or pygame.font.match_font("palatino")
            or pygame.font.match_font("times")
            or pygame.font.match_font("serif"))


def make_fonts(screen_height: int = 720) -> dict:
    """Return font dict: lg/md/sm/xs = mono (numbers), disp_* = display (labels)."""
    scale = max(0.55, min(1.6, screen_height / 720.0))
    mono_sizes = {
        'lg': max(24, int(46 * scale)),
        'md': max(16, int(29 * scale)),
        'sm': max(12, int(21 * scale)),
        'xs': max(10, int(16 * scale)),
    }
    disp_sizes = {
        'disp_lg': max(24, int(38 * scale)),
        'disp_sm': max(13, int(20 * scale)),
        'disp_xs': max(10, int(14 * scale)),
    }
    mono_path = _match_mono()
    disp_path = _match_display() or mono_path
    fonts: dict = {}
    if mono_path:
        try:
            for k, v in mono_sizes.items():
                fonts[k] = pygame.font.Font(mono_path, v)
        except Exception:
            mono_path = None
    if not mono_path:
        for k, v in mono_sizes.items():
            fonts[k] = pygame.font.SysFont("monospace", v)
    if disp_path:
        try:
            for k, v in disp_sizes.items():
                fonts[k] = pygame.font.Font(disp_path, v)
        except Exception:
            disp_path = None
    if not disp_path:
        for k, v in disp_sizes.items():
            fonts[k] = pygame.font.SysFont("serif", v)
    return fonts
