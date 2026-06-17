"""Upgrades — tiered multipliers matching all 11 buildings."""
from __future__ import annotations
import math
from dataclasses import dataclass
from typing import List, Dict, Callable
import pygame
import config
import src.theme as theme
import src.sound as sound

_ROW_H = 80


@dataclass
class Upgrade:
    name: str
    description: str
    cost: float
    effect_key: str
    purchased: bool = False

    def apply(self, state) -> None:
        fn = _EFFECTS.get(self.effect_key)
        if fn:
            fn(state)


# ─── Effect functions ──────────────────────────────────────────────────────────

def _fx_pass(state): pass  # dynamic in PlayingState properties

def _fx_bld(idx, mult):
    def fn(state):
        if idx < len(state.buildings):
            state.buildings[idx].income_multiplier *= mult
    return fn

def _fx_all(mult):
    def fn(state):
        for b in state.buildings:
            b.income_multiplier *= mult
    return fn


_EFFECTS: Dict[str, Callable] = {
    'double_click':    _fx_pass,
    'quad_click':      _fx_pass,
    'octo_click':      _fx_pass,
    'hex_click':       _fx_pass,
    'prestige_boost':  _fx_pass,
    # Building T1 (2x)
    'bld0_2x': _fx_bld(0, 2.0),
    'bld1_2x': _fx_bld(1, 2.0),
    'bld2_2x': _fx_bld(2, 2.0),
    'bld3_2x': _fx_bld(3, 2.0),
    'bld4_2x': _fx_bld(4, 2.0),
    'bld5_2x': _fx_bld(5, 2.0),
    'bld6_2x': _fx_bld(6, 2.0),
    'bld7_2x': _fx_bld(7, 2.0),
    'bld8_2x': _fx_bld(8, 2.0),
    'bld9_2x': _fx_bld(9, 2.0),
    'bld10_2x': _fx_bld(10, 2.0),
    # Building T2 (4x)
    'bld0_4x': _fx_bld(0, 4.0),
    'bld1_4x': _fx_bld(1, 4.0),
    'bld2_4x': _fx_bld(2, 4.0),
    'bld3_4x': _fx_bld(3, 4.0),
    'bld4_4x': _fx_bld(4, 4.0),
    'bld5_4x': _fx_bld(5, 4.0),
    'bld6_4x': _fx_bld(6, 4.0),
    # Global
    'all_2x': _fx_all(2.0),
    'all_4x': _fx_all(4.0),
}

# (name, description, cost, effect_key)
# Costs raised proportionally to match new building cost curves.
# T1 upgrades anchor to ~10x the base building cost.
# T2 upgrades anchor to ~20-25x the T1 building cost.
_DEFS = [
    # ── Click upgrades ──────────────────────────────────────────────────────
    ("Quick Hands",          "2x click value",                        100.0,             'double_click'),
    ("Iron Knuckles",        "4x click value",                        150_000.0,         'quad_click'),
    ("God Finger",           "8x click value",                        20_000_000.0,      'octo_click'),
    ("Phantom Touch",        "16x click value",                       2_000_000_000.0,   'hex_click'),

    # ── T1: 2x per building ─────────────────────────────────────────────────
    ("Hustle Harder",        "2x Corner Dealer income",                300.0,             'bld0_2x'),
    ("Iron Grip",            "2x Protection Racket income",            3_000.0,           'bld1_2x'),
    ("Better Tools",         "2x Chop Shop income",                    30_000.0,          'bld2_2x'),
    ("Loaded Dice",          "2x Betting Ring income",                 250_000.0,         'bld3_2x'),
    ("Premium Junk",         "2x Pawn Shop income",                    2_000_000.0,       'bld4_2x'),
    ("Higher Interest",      "2x Loan Shark income",                   15_000_000.0,      'bld5_2x'),
    ("High Roller Tables",   "2x Casino income",                       120_000_000.0,     'bld6_2x'),
    ("VIP Section",          "2x Nightclub income",                    900_000_000.0,     'bld7_2x'),
    ("Faster Ships",         "2x Dock income",                         7_000_000_000.0,   'bld8_2x'),
    ("Black Market Bulk",    "2x Arms Broker income",                  50_000_000_000.0,  'bld9_2x'),
    ("Shadow Franchise",     "2x Syndicate HQ income",                 400_000_000_000.0, 'bld10_2x'),

    # ── T2: 4x per building ─────────────────────────────────────────────────
    ("Shadow Step",          "4x Corner Dealer income",                8_000_000.0,       'bld0_4x'),
    ("Concrete Reputation",  "4x Protection Racket income",            50_000_000.0,      'bld1_4x'),
    ("Chop Shop Pro",        "4x Chop Shop income",                    500_000_000.0,     'bld2_4x'),
    ("Fixed Fights",         "4x Betting Ring income",                 5_000_000_000.0,   'bld3_4x'),
    ("Hot Goods Network",    "4x Pawn Shop income",                    40_000_000_000.0,  'bld4_4x'),
    ("Kneecap Special",      "4x Loan Shark income",                   300_000_000_000.0, 'bld5_4x'),
    ("Stacked Deck",         "4x Casino income",                       2_000_000_000_000.0,'bld6_4x'),

    # ── Global ──────────────────────────────────────────────────────────────
    ("Grand Reinvestment",   "2x ALL building income",                 10_000_000_000.0,  'all_2x'),
    ("Crime Conglomerate",   "4x ALL building income",                 20_000_000_000_000.0,'all_4x'),

    # ── Prestige synergy ────────────────────────────────────────────────────
    ("Prestige Mastery",     "Income up to +150%, scales with tokens", 500_000.0,         'prestige_boost'),
]


def make_upgrades() -> List[Upgrade]:
    return [Upgrade(name=n, description=d, cost=c, effect_key=k)
            for n, d, c, k in _DEFS]


# ─── Panel drawing ─────────────────────────────────────────────────────────────

def draw_panel(surface: pygame.Surface, state, fonts: dict,
               panel_rect: pygame.Rect, scroll: int = 0) -> None:
    remaining = [u for u in state.upgrades if not u.purchased]
    purchased = [u for u in state.upgrades if u.purchased]
    mx, my    = pygame.mouse.get_pos()
    row_y     = panel_rect.y + 8

    if not remaining and not purchased:
        s = fonts['md'].render("All upgrades purchased!", True, theme.GREEN)
        surface.blit(s, s.get_rect(center=panel_rect.center))
        return

    full_list = list(state.upgrades)

    def _draw_icon(rr, idx, purchased_flag):
        icon_x = rr.x + 10
        icon_y = rr.y + (rr.height - 28) // 2
        ir = pygame.Rect(icon_x, icon_y, 28, 28)
        bg = (25, 55, 25) if purchased_flag else theme.BG_DARK
        pygame.draw.rect(surface, bg, ir, border_radius=6)
        cx2 = icon_x + 14
        cy2 = icon_y + 14
        if idx < 4:      # click — fist circle
            col = theme.GREEN if purchased_flag else theme.ACCENT
            pygame.draw.circle(surface, col, (cx2, cy2), 7)
            pygame.draw.circle(surface, bg, (cx2, cy2), 3)
        elif idx < 15:   # T1 building — building shape
            col = theme.GREEN if purchased_flag else theme.BLUE_BRIGHT
            pygame.draw.rect(surface, col, pygame.Rect(cx2 - 6, cy2 - 3, 12, 8))
            pts = [(cx2 - 7, cy2 - 3), (cx2, cy2 - 9), (cx2 + 7, cy2 - 3)]
            pygame.draw.polygon(surface, col, pts)
        elif idx < 22:   # T2 building — coin
            col = theme.GREEN if purchased_flag else theme.TEXT_GOLD
            pygame.draw.circle(surface, col, (cx2, cy2), 8)
            pygame.draw.circle(surface, bg, (cx2, cy2), 4)
        else:            # global / prestige — star
            col = theme.GREEN if purchased_flag else (160, 80, 255)
            for angle in range(0, 360, 72):
                rad = math.radians(angle)
                ex = int(cx2 + 8 * math.sin(rad))
                ey = int(cy2 - 8 * math.cos(rad))
                pygame.draw.line(surface, col, (cx2, cy2), (ex, ey), 2)

    # Unpurchased (scrollable)
    rem_skip = min(scroll, len(remaining))
    for u in remaining[rem_skip:]:
        if row_y + _ROW_H > panel_rect.bottom:
            break
        idx  = full_list.index(u) if u in full_list else 0
        rr   = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, _ROW_H - 4)
        can  = state.balance >= u.cost
        hover = rr.collidepoint(mx, my)

        card_bg = theme.BG_CARD_HOVER if hover else theme.PURPLE_CARD
        pygame.draw.rect(surface, card_bg, rr, border_radius=10)
        if hover:
            pygame.draw.rect(surface, theme.ACCENT,
                             pygame.Rect(rr.x, rr.y + 8, 3, rr.height - 16), border_radius=2)
        elif can:
            pulse = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
            a = int(70 + 50 * math.sin(getattr(state, '_time', 0.0) * 2.5))
            pygame.draw.rect(pulse, (*theme.ACCENT, a), pulse.get_rect(), border_radius=10, width=2)
            surface.blit(pulse, rr.topleft)

        _draw_icon(rr, idx, False)

        text_x = rr.x + 46
        ns = fonts['sm'].render(u.name, True, theme.TEXT_PRIMARY)
        ds = fonts['xs'].render(u.description, True, theme.TEXT_MUTED)
        surface.blit(ns, (text_x, rr.y + 8))
        surface.blit(ds, (text_x, rr.y + 35))

        eff_cost = _effective_cost(u, state)
        can = state.balance >= eff_cost

        btn = pygame.Rect(rr.right - 74, rr.y + (rr.height - 30) // 2, 68, 30)
        hover_btn = btn.collidepoint(mx, my)
        if can:
            col = tuple(min(255, v + 20) for v in theme.ACCENT) if hover_btn else theme.ACCENT
            pygame.draw.rect(surface, col, btn, border_radius=6)
            pygame.draw.rect(surface, (255, 235, 120), btn, border_radius=6, width=1)
            bl_col = theme.BG_DARK; cs_col = theme.BG_DARK
        else:
            pygame.draw.rect(surface, theme.BTN_DISABLED, btn, border_radius=6)
            bl_col = theme.TEXT_MUTED; cs_col = theme.TEXT_MUTED

        bl = fonts['xs'].render("Buy", True, bl_col)
        cs = fonts['xs'].render(_fmt(eff_cost), True, cs_col)
        surface.blit(bl, bl.get_rect(center=(btn.centerx, btn.centery - 7)))
        surface.blit(cs, cs.get_rect(center=(btn.centerx, btn.centery + 8)))

        sep = pygame.Surface((rr.width, 1), pygame.SRCALPHA)
        sep.fill((255, 255, 255, 30))
        surface.blit(sep, (rr.x, rr.bottom + 1))
        row_y += _ROW_H

    # Purchased (dim, after unpurchased)
    pur_skip = max(0, scroll - len(remaining))
    for u in purchased[pur_skip:]:
        if row_y + _ROW_H > panel_rect.bottom:
            break
        idx = full_list.index(u) if u in full_list else 0
        rr  = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, _ROW_H - 4)

        card_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
        pygame.draw.rect(card_surf, (*theme.PURPLE_CARD, 130),
                         card_surf.get_rect(), border_radius=10)
        surface.blit(card_surf, rr.topleft)

        _draw_icon(rr, idx, True)

        ns = fonts['sm'].render(u.name, True, theme.TEXT_MUTED)
        ds = fonts['xs'].render(u.description, True, theme.TEXT_MUTED)
        surface.blit(ns, (rr.x + 46, rr.y + 8))
        surface.blit(ds, (rr.x + 46, rr.y + 35))
        ck = fonts['sm'].render("v", True, theme.GREEN)
        surface.blit(ck, ck.get_rect(midright=(rr.right - 14, rr.centery)))

        row_y += _ROW_H


def _effective_cost(u: 'Upgrade', state) -> float:
    """Upgrade cost after pawn shop discount."""
    from src.buildings import pawn_cost_reduction
    discount = pawn_cost_reduction(state.buildings)
    return u.cost * (1.0 - discount)


def handle_click(state, pos: tuple, panel_rect: pygame.Rect, scroll: int = 0) -> bool:
    remaining = [u for u in state.upgrades if not u.purchased]
    card_h = _ROW_H - 4
    row_y  = panel_rect.y + 8
    for u in remaining[min(scroll, len(remaining)):]:
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, card_h)
        if row_y + card_h > panel_rect.bottom:
            break
        btn = pygame.Rect(rr.right - 74, rr.y + (card_h - 30) // 2, 68, 30)
        if btn.collidepoint(pos):
            cost = _effective_cost(u, state)
            if state.balance >= cost:
                state.balance -= cost
                was_first = not any(uu.purchased for uu in getattr(state, 'upgrades', []))
                u.purchased = True
                u.apply(state)
                sound.play('purchase')
                import src.ui as _ui
                import src.theme as _t
                _ui.push_notification(f"Upgrade: {u.name}!", _t.GREEN)
                if was_first:
                    try:
                        import src.analytics as _an
                        _an.first_upgrade()
                    except Exception:
                        pass
            return True
        row_y += _ROW_H
    return False


def _fmt(n: float) -> str:
    import src.theme as _t
    return _t.format_number(n)
