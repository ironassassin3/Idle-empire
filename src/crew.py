"""Crew Assignment System — distribute crew across roles for different strategic effects."""
from __future__ import annotations
import math
from dataclasses import dataclass, field
from typing import List

import pygame
import src.theme as theme
import src.scale as scale
import config

# ─── Role definitions ────────────────────────────────────────────────────────────

ROLES = [
    {
        'key':   'protection',
        'name':  'Protection',
        'color': (180, 80,  60),
        'desc':  'Reduces rival raid damage',
        'detail': 'Each crew unit cuts raid damage 1.5% (cap −70%).\n'
                  'Why: rivals raid often in early-mid game — protection\n'
                  'stops them wiping your cash. Best use: invest early,\n'
                  'then move crew to income once rivals are weakened.',
        'icon':  'P',
    },
    {
        'key':   'collection',
        'name':  'Collection',
        'color': (200, 160, 40),
        'desc':  'Boosts passive income',
        'detail': 'Each unit adds +0.8% global income (cap +60%).\n'
                  'Why: stacks with every other income multiplier, making\n'
                  'it the best long-term passive investment. Best use:\n'
                  'fill this role after protection needs are covered.',
        'icon':  'C',
    },
    {
        'key':   'smuggling',
        'name':  'Smuggling',
        'color': (60,  180, 140),
        'desc':  'Boosts operation rewards',
        'detail': 'Each unit adds +1% to operation payouts (cap +75%).\n'
                  'Why: operations are the biggest single-payout events.\n'
                  'Best use: assign before launching International Smuggling\n'
                  'or Union Extortion for maximum return.',
        'icon':  'S',
    },
    {
        'key':   'territory',
        'name':  'Territory',
        'color': (80,  130, 200),
        'desc':  'Speeds territory action success',
        'detail': 'Each unit adds +0.5% territory action success (cap +25%).\n'
                  'Why: capturing districts gives income bonuses, Influence,\n'
                  'and weakens rivals. Best use: pile in while actively\n'
                  'expanding; reassign once your turf is locked down.',
        'icon':  'T',
    },
    {
        'key':   'heat',
        'name':  'Heat Reduction',
        'color': (120, 200, 120),
        'desc':  'Passively lowers heat over time',
        'detail': 'Each unit removes 0.003 heat/sec (cap 0.5/sec).\n'
                  'Why: heat above 60% triggers police raids. This is a\n'
                  'slow but free heat drain that never stops working.\n'
                  'Best use: keep a few units here if raids are frequent.',
        'icon':  'H',
    },
]


@dataclass
class CrewAssignment:
    protection: int = 0
    collection: int  = 0
    smuggling: int   = 0
    territory: int   = 0
    heat: int        = 0

    def total(self) -> int:
        return self.protection + self.collection + self.smuggling + self.territory + self.heat

    def available(self, state) -> int:
        """Total crew = buildings owned × capacity multiplier (Black Dragon: ×1.25)."""
        base = sum(b.owned for b in getattr(state, 'buildings', []))
        try:
            import src.dragon as _dragon
            base = int(base * _dragon.crew_capacity_mult(state))
        except Exception:
            pass
        return max(0, base)

    def unassigned(self, state) -> int:
        return max(0, self.available(state) - self.total())

    def clamp_to_capacity(self, capacity: int) -> None:
        """Scale assignments down to fit `capacity`, preserving role ratios.

        No-op when already within capacity. Crew identity (the ratio between
        roles = the player's specialization) survives prestige, but its raw
        size — and therefore its effect magnitude — must scale with the
        rebuilt economy. Without this, a specialized crew keeps full bonuses
        with no buildings to staff it and operations see a negative free-crew
        count. Buildings only shrink at prestige, so this is called there and
        on load (legacy saves); during normal play the +/- UI already prevents
        over-assignment, so it stays a no-op.
        """
        cap = max(0, int(capacity))
        total = self.total()
        if total <= cap:
            return
        if cap == 0:
            self.protection = self.collection = self.smuggling = 0
            self.territory = self.heat = 0
            return
        factor = cap / total
        self.protection = int(self.protection * factor)
        self.collection = int(self.collection * factor)
        self.smuggling  = int(self.smuggling * factor)
        self.territory  = int(self.territory * factor)
        self.heat       = int(self.heat * factor)

    def as_dict(self) -> dict:
        return {
            'protection': self.protection,
            'collection':  self.collection,
            'smuggling':   self.smuggling,
            'territory':   self.territory,
            'heat':        self.heat,
        }

    @classmethod
    def from_dict(cls, d: dict) -> 'CrewAssignment':
        return cls(
            protection=int(d.get('protection', 0)),
            collection=int(d.get('collection', 0)),
            smuggling=int(d.get('smuggling', 0)),
            territory=int(d.get('territory', 0)),
            heat=int(d.get('heat', 0)),
        )


# ─── Effect calculations ─────────────────────────────────────────────────────────

def protection_damage_mult(ca: CrewAssignment) -> float:
    """Multiplier on raid damage received (0 = no damage, 1 = full). Capped at 70% reduction."""
    return max(0.30, 1.0 - ca.protection * 0.015)


def collection_income_mult(ca: CrewAssignment, state=None) -> float:
    """Passive income multiplier from collection crew. Each unit = +0.8% (×1.5 with Black Dragon)."""
    per_unit = 0.008
    try:
        if state is not None:
            import src.dragon as _dragon
            per_unit *= _dragon.collection_efficiency_mult(state)
    except Exception:
        pass
    return 1.0 + min(ca.collection * per_unit, 0.60)


def smuggling_op_mult(ca: CrewAssignment) -> float:
    """Operation reward multiplier from smuggling crew."""
    return 1.0 + min(ca.smuggling * 0.01, 0.75)


def territory_action_bonus(ca: CrewAssignment) -> float:
    """Additive success-rate bonus for territory actions (0.0–0.25)."""
    return min(ca.territory * 0.005, 0.25)


def heat_reduction_per_sec(ca: CrewAssignment) -> float:
    """Passive heat reduction per second from heat-crew. Each unit = 0.003/s, cap 0.5/s."""
    return min(ca.heat * 0.003, 0.50)


# ─── UI ──────────────────────────────────────────────────────────────────────────
# Phase 90: row height, badge, progress bar and the +/- buttons all derive from
# the live (scaled) font metrics. draw_panel and handle_click share
# _crew_row_height / _crew_layout, so click targets always match what's drawn.

_GAP = 8   # vertical gap between cards (design px; scaled at use site)


def _crew_button_size(fonts: dict) -> int:
    """Square +/- button sized to the 'sm' glyph it contains."""
    return max(scale.sd(24), fonts['sm'].get_height() + scale.sd(6))


def _crew_row_height(fonts: dict) -> int:
    sm_h = fonts['sm'].get_height()
    xs_h = fonts['xs'].get_height()
    md_h = fonts['md'].get_height()
    pad = scale.sd(6)
    g = scale.sd(4)
    bar_h = scale.sd(6)
    content = pad + sm_h + g + xs_h + g + bar_h + pad
    btn = _crew_button_size(fonts)
    return max(content, md_h + 2 * pad, btn + 2 * pad,
               scale.sd(config.UI_CARD_MIN_HEIGHT))


def _crew_layout(rr: pygame.Rect, fonts: dict) -> dict:
    """Single source of truth for a role row — text, bar, count and button rects."""
    sm_h = fonts['sm'].get_height()
    xs_h = fonts['xs'].get_height()
    pad = scale.sd(6)
    g = scale.sd(4)
    badge_d = max(scale.sd(24), sm_h + scale.sd(6))
    text_x = rr.x + scale.sd(10) + badge_d + scale.sd(8)
    btn = _crew_button_size(fonts)
    plus_btn = pygame.Rect(rr.right - scale.sd(8) - btn, rr.centery - btn // 2, btn, btn)
    minus_btn = pygame.Rect(plus_btn.x - scale.sd(4) - btn, rr.centery - btn // 2, btn, btn)
    return {
        'badge_d': badge_d,
        'text_x': text_x,
        'y_name': rr.y + pad,
        'y_effect': rr.y + pad + sm_h + g,
        'y_bar': rr.y + pad + sm_h + g + xs_h + g,
        'bar_h': scale.sd(6),
        'minus_btn': minus_btn,
        'plus_btn': plus_btn,
    }


def draw_panel(surface: pygame.Surface, state, fonts: dict,
               panel_rect: pygame.Rect) -> None:
    ca: CrewAssignment = getattr(state, 'crew', CrewAssignment())
    total    = ca.available(state)
    unassign = ca.unassigned(state)
    mx, my   = pygame.mouse.get_pos()
    t        = getattr(state, '_time', 0.0)

    # Header
    hdr = fonts['xs'].render(
        f"CREW ASSIGNMENTS  —  {total} total crew, {unassign} unassigned",
        True, theme.TEXT_MUTED if unassign >= 0 else (255, 80, 80))
    surface.blit(hdr, (panel_rect.x + scale.sd(8), panel_rect.y + scale.sd(6)))

    row_h = _crew_row_height(fonts)
    row_y = panel_rect.y + fonts['xs'].get_height() + scale.sd(12)
    role_values = [
        ca.protection, ca.collection, ca.smuggling, ca.territory, ca.heat
    ]

    for i, role in enumerate(ROLES):
        count = role_values[i]
        rr    = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, row_h)
        if row_y + row_h > panel_rect.bottom:
            break

        L = _crew_layout(rr, fonts)

        # Card bg
        hover = rr.collidepoint(mx, my)
        bg_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
        pygame.draw.rect(bg_surf, (*role['color'], 18 if not hover else 35),
                         bg_surf.get_rect(), border_radius=10)
        surface.blit(bg_surf, rr.topleft)

        # Accent bar
        bar = pygame.Surface((scale.sd(3), rr.height - scale.sd(12)), pygame.SRCALPHA)
        bar.fill((*role['color'], 200))
        surface.blit(bar, (rr.x, rr.y + scale.sd(6)))

        # Icon badge
        bd = L['badge_d']
        badge = pygame.Surface((bd, bd), pygame.SRCALPHA)
        pygame.draw.circle(badge, (*role['color'], 200), (bd // 2, bd // 2), bd // 2 - 1)
        ic = fonts['sm'].render(role['icon'], True, (230, 230, 230))
        badge.blit(ic, ic.get_rect(center=(bd // 2, bd // 2)))
        surface.blit(badge, (rr.x + scale.sd(10), rr.centery - bd // 2))

        # Name + effect
        ns = fonts['sm'].render(role['name'], True, theme.TEXT_PRIMARY)
        surface.blit(ns, (L['text_x'], L['y_name']))
        effect = _role_effect_str(role['key'], count)
        es = fonts['xs'].render(effect, True, theme.GREEN)
        surface.blit(es, (L['text_x'], L['y_effect']))

        # Count display (left of the buttons)
        count_s = fonts['md'].render(str(count), True, role['color'])
        count_rect = count_s.get_rect(
            right=L['minus_btn'].x - scale.sd(8), centery=rr.centery)
        surface.blit(count_s, count_rect)

        # Role detail tooltip on hover (replaces the bar area while hovering)
        if hover:
            detail_lines = role.get('detail', '').split('\n')
            dy = L['y_bar']
            xs_h = fonts['xs'].get_height()
            for dl in detail_lines:
                dl_s = fonts['xs'].render(dl.strip(), True, (160, 180, 200))
                dl_s.set_alpha(200)
                surface.blit(dl_s, (L['text_x'], dy))
                dy += xs_h + scale.sd(2)
        else:
            # Progress bar spanning from text to the count column
            bar_x = L['text_x']
            bar_w = max(scale.sd(10), count_rect.left - scale.sd(8) - bar_x)
            bar_y = L['y_bar']
            bar_h = L['bar_h']
            ratio = min(1.0, count / max(1, total)) if total > 0 else 0.0
            track_s = pygame.Surface((bar_w, bar_h), pygame.SRCALPHA)
            pygame.draw.rect(track_s, (30, 32, 50, 180), track_s.get_rect(), border_radius=3)
            surface.blit(track_s, (bar_x, bar_y))
            if ratio > 0:
                fill_w = max(2, int(bar_w * ratio))
                fill_s = pygame.Surface((fill_w, bar_h), pygame.SRCALPHA)
                pygame.draw.rect(fill_s, (*role['color'], 210), fill_s.get_rect(), border_radius=3)
                surface.blit(fill_s, (bar_x, bar_y))

        # Minus / Plus buttons
        for btn, lbl, can in [
            (L['minus_btn'], "-", count > 0),
            (L['plus_btn'],  "+", unassign > 0),
        ]:
            col = role['color'] if can else (50, 52, 70)
            hov = btn.collidepoint(mx, my) and can
            draw_col = tuple(min(255, v + 30) for v in col) if hov else col
            pygame.draw.rect(surface, draw_col, btn, border_radius=5)
            ls = fonts['sm'].render(lbl, True, (230, 230, 230) if can else theme.TEXT_MUTED)
            surface.blit(ls, ls.get_rect(center=btn.center))

        sep = pygame.Surface((rr.width, 1), pygame.SRCALPHA)
        sep.fill((255, 255, 255, 20))
        surface.blit(sep, (rr.x, rr.bottom + scale.sd(_GAP) // 2))
        row_y += row_h + scale.sd(_GAP)

    # Summary card at bottom
    _draw_summary(surface, state, fonts, panel_rect, row_y)


def _role_effect_str(key: str, count: int) -> str:
    if key == 'protection':
        pct = min(int(count * 1.5), 70)
        return f"-{pct}% raid damage"
    elif key == 'collection':
        pct = min(round(count * 0.8, 1), 60.0)
        return f"+{pct}% passive income"
    elif key == 'smuggling':
        pct = min(int(count * 1.0), 75)
        return f"+{pct}% operation rewards"
    elif key == 'territory':
        pct = min(round(count * 0.5, 1), 25.0)
        return f"+{pct}% territory action success"
    elif key == 'heat':
        val = min(round(count * 0.003, 3), 0.5)
        return f"-{val:.3f} heat/sec"
    return ""


def _draw_summary(surface: pygame.Surface, state, fonts: dict,
                  panel_rect: pygame.Rect, y: int) -> None:
    ca: CrewAssignment = getattr(state, 'crew', CrewAssignment())
    total    = ca.available(state)
    unassign = ca.unassigned(state)
    sr_h = max(scale.sd(40), fonts['xs'].get_height() + scale.sd(20))
    sr = pygame.Rect(panel_rect.x + 4, y, panel_rect.width - 8, sr_h)
    if sr.bottom > panel_rect.bottom:
        return
    pygame.draw.rect(surface, theme.BG_CARD, sr, border_radius=8)
    pygame.draw.rect(surface, theme.ACCENT_DIM, sr, border_radius=8, width=1)

    col = theme.TEXT_GOLD if unassign > 0 else theme.GREEN
    txt = (f"! {unassign} crew unassigned — assign them for maximum effect!"
           if unassign > 0 else "All crew deployed.")
    ts = fonts['xs'].render(txt, True, col)
    surface.blit(ts, ts.get_rect(center=sr.center))


def handle_click(state, pos: tuple, panel_rect: pygame.Rect) -> bool:
    ca: CrewAssignment = getattr(state, 'crew', CrewAssignment())
    fonts = getattr(state, '_fonts', {})
    if not fonts:
        return False
    row_h = _crew_row_height(fonts)
    row_y = panel_rect.y + fonts['xs'].get_height() + scale.sd(12)
    role_keys = ['protection', 'collection', 'smuggling', 'territory', 'heat']

    for i, role in enumerate(ROLES):
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, row_h)
        if row_y + row_h > panel_rect.bottom:
            break
        if rr.collidepoint(pos):
            count    = getattr(ca, role_keys[i])
            unassign = ca.unassigned(state)
            L = _crew_layout(rr, fonts)
            if L['minus_btn'].collidepoint(pos) and count > 0:
                setattr(ca, role_keys[i], count - 1)
                return True
            if L['plus_btn'].collidepoint(pos) and unassign > 0:
                setattr(ca, role_keys[i], count + 1)
                return True
        row_y += row_h + scale.sd(_GAP)

    return False
