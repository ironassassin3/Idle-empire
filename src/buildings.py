"""Buildings — 11 themed criminal buildings with icons and descriptions."""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import List
import math
import random
import pygame
import config
import src.theme as theme
import src.sound as sound


def _building_has_manager(state, building_idx: int) -> bool:
    managers = getattr(state, 'managers', [])
    return any(m.hired and m.building_index == building_idx for m in managers)


def _fit_line(font, text: str, max_w: int, color, alpha: int = 255) -> pygame.Surface:
    """Truncate with ellipsis so card text never runs under buy/badges."""
    surf = font.render(text, True, color)
    if surf.get_width() <= max_w:
        if alpha < 255:
            surf.set_alpha(alpha)
        return surf
    ell = "…"
    for end in range(len(text), 0, -1):
        candidate = font.render(text[:end] + ell, True, color)
        if candidate.get_width() <= max_w:
            if alpha < 255:
                candidate.set_alpha(alpha)
            return candidate
    tiny = font.render(ell, True, color)
    if alpha < 255:
        tiny.set_alpha(alpha)
    return tiny


def _text_gutter_x(row_rect: pygame.Rect) -> int:
    """Right edge for description lines — leaves room for BUY + count/AUTO badges."""
    btn = _btn_rect(row_rect)
    return btn.x - max(108, _BTN_W + 48)


def _draw_front_card(surface, rr: pygame.Rect, hover: bool, can: bool, dim: bool) -> None:
    """Noir dossier card for a front business (Phase 127)."""
    if not can:
        cs_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
        pygame.draw.rect(cs_surf, (*theme.NOIR_GLASS, 120 if hover else 90),
                         cs_surf.get_rect(), border_radius=8)
        surface.blit(cs_surf, rr.topleft)
    else:
        fill = theme.NOIR_CARD_HOVER if hover else theme.NOIR_CARD
        card = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
        pygame.draw.rect(card, (*fill, 230), card.get_rect(), border_radius=8)
        surface.blit(card, rr.topleft)
    border_c = theme.NOIR_GOLD_BRIGHT if (can and hover) else theme.NOIR_GOLD_DEEP
    pygame.draw.rect(surface, border_c, rr, border_radius=8, width=1)
    if dim:
        veil = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
        veil.fill((0, 0, 0, 55))
        surface.blit(veil, rr.topleft)


def _draw_seal_button(surface, btn: pygame.Rect, can: bool, hover: bool,
                      fonts, top_label: str, cost_label: str) -> None:
    """Wax-seal style buy control — gold when affordable."""
    if can:
        base = theme.NOIR_GOLD if not hover else theme.NOIR_GOLD_BRIGHT
        pygame.draw.ellipse(surface, theme.NOIR_GOLD_DEEP,
                            btn.inflate(4, 4))
        pygame.draw.rect(surface, base, btn, border_radius=8)
        pygame.draw.rect(surface, theme.NOIR_INK, btn, border_radius=8, width=1)
        tc = theme.NOIR_INK
    else:
        pygame.draw.rect(surface, (32, 30, 40), btn, border_radius=8)
        pygame.draw.rect(surface, (55, 52, 68), btn, border_radius=8, width=1)
        tc = theme.NOIR_BONE_DIM
    bl = fonts['xs'].render(top_label, True, tc)
    cs = fonts['xs'].render(cost_label, True, tc)
    surface.blit(bl, bl.get_rect(center=(btn.centerx, btn.centery - 10)))
    surface.blit(cs, cs.get_rect(center=(btn.centerx, btn.centery + 10)))


_ROW_H = 100
_GAP   = 5
_HEADER_H = 44
_BTN_W, _BTN_H = 80, 42


@dataclass
class Building:
    name: str
    base_cost: float
    base_income: float
    cost_scale: float
    description: str = ""
    icon_key: str = "generic"
    owned: int = 0
    income_multiplier: float = 1.0
    # Special ability description shown in UI
    special: str = ""
    # Internal cooldown timer for proc effects
    _special_timer: float = 0.0

    @property
    def current_cost(self) -> float:
        return self.base_cost * (self.cost_scale ** self.owned)

    @property
    def income_per_second(self) -> float:
        return self.base_income * self.owned * self.income_multiplier

    def cost_for_n(self, n: int) -> float:
        if n <= 0:
            return 0.0
        s = self.cost_scale
        return self.base_cost * (s ** self.owned) * (s ** n - 1.0) / (s - 1.0)


# (name, base_cost, base_income, cost_scale, description, icon_key, special)
# Cost scale 1.15 (tier 1) / 1.18-1.20 (rest) — steep enough to prevent
# spam-buying a single tier.
#
# base_income is tuned so income-per-dollar RISES with tier (≈0.003 → 0.082 inc/$):
# each newly-affordable building becomes the best-value buy, so the player is
# always pulled toward saving up for the next tier (AdVenture-Capitalist style
# curve). Previously inc/$ FELL every tier, making Corner Dealer the eternal best
# buy and higher tiers pure cash sinks — see AUDIT.md / sim_econ.py.
#
# Corner Dealer keeps a slightly elevated 0.10 income (good first-impression feel
# + it carries the click bonus); from Racket onward the curve follows
#   inc = cost * 0.002 * 1.45^tier   (validated in sim_curve2.py / sim_econ.py).
# Magnitude tuned (divisor 5 of the steeper draft) so first prestige lands in the
# ~30-45 min window and all 11 tiers are reachable within a first session.
_DEFS = [
    ("Corner Dealer",       10.0,          0.11,  1.15,
     "Moves product on the block",          "dealer",
     "Click bonus: +0.10 cash per dealer owned"),
    ("Protection Racket",   150.0,          0.48,   1.18,
     "Businesses pay for 'insurance'",      "racket",
     "Multiplies Corner Dealer income ×1.05 per racket"),
    ("Chop Shop",           2_000.0,        9.24,   1.18,
     "Cars in, parts out, no questions",    "chop",
     "10% chance each sec for a bonus payout (3× income)"),
    ("Sports Betting Ring", 20_000.0,       134.2,  1.18,
     "The house always wins",               "betting",
     "Random jackpot every 30–90s: 60s of income instantly"),
    ("Pawn Shop",           150_000.0,      1_330.0, 1.18,
     "No serial numbers, no problems",      "pawn",
     "Reduces all upgrade costs by 2% per pawn shop"),
    ("Loan Shark Office",   1_200_000.0,    15_400.0, 1.20,
     "Generous terms. Very generous.",      "loan",
     "Passive interest: +0.5% of balance per minute"),
    ("Underground Casino",  10_000_000.0,   186_000.0, 1.20,
     "High stakes, no tax man",             "casino",
     "Boosts manager effectiveness by +10% per casino"),
    ("Nightclub",           80_000_000.0,   2_160_000.0, 1.20,
     "Laundromat with a dance floor",       "club",
     "Launders heat: -0.5 heat per second per nightclub"),
    ("Dock Smuggling Op",   600_000_000.0,  23_400_000.0, 1.20,
     "Containers of plausible deniability", "dock",
     "Multiplies all passive income by ×1.015 per dock"),
    ("Arms Broker",         5_000_000_000.0, 283_000_000.0, 1.20,
     "Supply and demand, emphasis supply",  "arms",
     "Generates 0.1 Influence fragments per hour per broker"),
    ("Crime Syndicate HQ",  40_000_000_000.0, 3_290_000_000.0, 1.20,
     "The whole city answers to you",       "hq",
     "Global multiplier: ×1.1 all income per HQ owned"),
]


def global_special_mult(buildings: List['Building']) -> float:
    """Combined global income multiplier from Dock and HQ special abilities."""
    dock = buildings[8] if len(buildings) > 8 else None
    hq   = buildings[10] if len(buildings) > 10 else None
    mult = 1.0
    if dock and dock.owned > 0:
        mult *= 1.015 ** dock.owned
    if hq and hq.owned > 0:
        mult *= 1.06 ** hq.owned
    return mult


def dealer_click_bonus(buildings: List['Building']) -> float:
    """Extra flat cash per click from Corner Dealers (config-tuned, Phase 104)."""
    dealer = buildings[0] if buildings else None
    return float(dealer.owned) * config.CLICK_DEALER_BONUS if dealer else 0.0


def pawn_cost_reduction(buildings: List['Building']) -> float:
    """Fraction by which pawn shops reduce upgrade costs (0.0 – 1.0)."""
    pawn = buildings[4] if len(buildings) > 4 else None
    if not pawn or pawn.owned == 0:
        return 0.0
    return min(0.50, 0.02 * pawn.owned)


def casino_manager_bonus(buildings: List['Building']) -> float:
    """Manager income bonus from casinos (additive multiplier over 1.0)."""
    casino = buildings[6] if len(buildings) > 6 else None
    if not casino or casino.owned == 0:
        return 1.0
    return 1.0 + 0.10 * casino.owned


def make_buildings() -> List[Building]:
    return [Building(name=n, base_cost=c, base_income=i, cost_scale=s,
                     description=d, icon_key=k, special=sp)
            for n, c, i, s, d, k, sp in _DEFS]


# ─── Building special ability ticks ────────────────────────────────────────────

def update_building_specials(state, dt: float) -> None:
    """Tick per-building special abilities. Modifies state in place."""
    buildings = state.buildings
    if not buildings:
        return

    # Chop Shop: 8% flat chance per second (not stacking per shop) for a 2× income payout.
    # NO notification — this procs ~every 12s and would spam the feed, burying the
    # genuinely exciting events (rank-ups, jackpots, prestige). It's ambient income;
    # the player feels it as a steady boost, not an interrupt. (See SESSION2.md.)
    chop = buildings[2]
    if chop.owned > 0:
        chop._special_timer += dt
        if chop._special_timer >= 1.0:
            chop._special_timer -= 1.0
            if random.random() < 0.08:
                bonus = chop.income_per_second * 2.0
                state.balance += bonus
                state.lifetime_earnings += bonus
                import src.money_debug as _md
                _md.credit(state, bonus, 'money_from_buildings')

    # Sports Betting Ring: jackpot every 60–150s (less frequent, 30s window instead of 60s)
    betting = buildings[3]
    if betting.owned > 0:
        betting._special_timer -= dt
        if betting._special_timer <= 0:
            bonus = betting.income_per_second * 30.0
            state.balance += bonus
            state.lifetime_earnings += bonus
            import src.money_debug as _md
            _md.credit(state, bonus, 'money_from_buildings')
            import src.ui as _ui
            _ui.push_notification(f"Betting jackpot! +{_fmt(bonus)}", theme.TEXT_GOLD)
            betting._special_timer = random.uniform(60.0, 150.0)

    # Loan Shark: +0.05% balance per minute per office (capped at 2 offices)
    # Reduced from 0.2%/min x3 offices — compound interest on large balances snowballed
    loan = buildings[5]
    if loan.owned > 0:
        effective_offices = min(loan.owned, 2)
        interest = state.balance * (0.0005 / 60.0) * effective_offices * dt
        state.balance += interest
        state.lifetime_earnings += interest
        import src.money_debug as _md
        _md.credit(state, interest, 'money_from_buildings')

    # Nightclub: reduce heat
    club = buildings[7]
    if club.owned > 0:
        import src.heat as heat_mod
        reduction = 0.5 * club.owned * dt
        state.heat = max(heat_mod.HEAT_MIN, getattr(state, 'heat', 0.0) - reduction)

    # Arms Broker: generates 0.1 Influence fragments per hour per broker.
    # Influence == prestige_tokens (the meta currency). Fragments accumulate in a
    # float and convert to a whole Influence point once they reach 1.0, so the
    # special does something real (previously it was advertised but never ticked).
    arms = buildings[9] if len(buildings) > 9 else None
    if arms and arms.owned > 0:
        frac = getattr(state, '_arms_influence_frac', 0.0)
        frac += arms.owned * (0.1 / 3600.0) * dt
        if frac >= 1.0:
            whole = int(frac)
            state.prestige_tokens = int(getattr(state, 'prestige_tokens', 0)) + whole
            frac -= whole
        state._arms_influence_frac = frac

    # Protection Racket multiplier: boosts Corner Dealer income, capped at +100% (x2.0)
    # Uncapped exponential caused runaway snowball — 20+ rackets = 3x+ multiplier
    racket = buildings[1]
    dealer = buildings[0]
    if racket.owned > 0:
        dealer.income_multiplier = min(1.0 + 0.05 * racket.owned, 2.0)
    else:
        dealer.income_multiplier = 1.0


# ─── Icon rendering ────────────────────────────────────────────────────────────
_ICON_CACHE: dict[str, pygame.Surface] = {}
_ICON_SIZE = 36


def _make_icon(key: str) -> pygame.Surface:
    s = pygame.Surface((_ICON_SIZE, _ICON_SIZE), pygame.SRCALPHA)
    c = _ICON_SIZE // 2
    bg = (*theme.BG_DARK, 255)
    pygame.draw.rect(s, bg, s.get_rect(), border_radius=7)

    if key == "dealer":
        # Money bag
        pygame.draw.circle(s, theme.ACCENT_DIM, (c, c + 3), 10)
        pygame.draw.rect(s, theme.ACCENT_DIM, pygame.Rect(c - 4, c - 10, 8, 6), border_radius=3)
        pygame.draw.circle(s, theme.BG_DARK, (c, c + 3), 5)
        pygame.draw.line(s, theme.ACCENT, (c - 2, c + 1), (c + 2, c + 5), 2)
    elif key == "racket":
        # Fist
        for i, dx in enumerate([-5, -1, 3, 7]):
            pygame.draw.rect(s, theme.TEXT_MUTED,
                             pygame.Rect(c + dx - 3, c - 7 + i % 2 * 2, 5, 9), border_radius=2)
        pygame.draw.rect(s, theme.TEXT_MUTED, pygame.Rect(c - 8, c + 2, 20, 7), border_radius=3)
    elif key == "chop":
        # Car outline
        pygame.draw.rect(s, theme.TEXT_MUTED, pygame.Rect(c - 12, c, 24, 10), border_radius=2)
        pygame.draw.rect(s, theme.TEXT_MUTED, pygame.Rect(c - 7, c - 7, 14, 8), border_radius=3)
        pygame.draw.circle(s, theme.BG_DARK, (c - 7, c + 10), 4)
        pygame.draw.circle(s, theme.BG_DARK, (c + 7, c + 10), 4)
        pygame.draw.circle(s, theme.TEXT_MUTED, (c - 7, c + 10), 3)
        pygame.draw.circle(s, theme.TEXT_MUTED, (c + 7, c + 10), 3)
    elif key == "betting":
        # Dice
        pygame.draw.rect(s, theme.TEXT_MUTED, pygame.Rect(c - 9, c - 9, 18, 18), border_radius=3)
        for dx, dy in [(-5, -5), (0, 0), (5, 5)]:
            pygame.draw.circle(s, theme.BG_DARK, (c + dx, c + dy), 2)
    elif key == "pawn":
        # Pawn ticket
        pygame.draw.rect(s, theme.ACCENT_DIM, pygame.Rect(c - 9, c - 11, 18, 22), border_radius=3)
        pygame.draw.line(s, theme.BG_DARK, (c - 5, c - 6), (c + 5, c - 6), 2)
        pygame.draw.line(s, theme.BG_DARK, (c - 5, c - 1), (c + 5, c - 1), 2)
        pygame.draw.line(s, theme.BG_DARK, (c - 5, c + 4), (c + 2, c + 4), 2)
    elif key == "loan":
        # Dollar sign in circle
        pygame.draw.circle(s, (60, 150, 60), (c, c), 12)
        pygame.draw.line(s, theme.TEXT_PRIMARY, (c, c - 9), (c, c + 9), 2)
        pygame.draw.line(s, theme.TEXT_PRIMARY, (c - 5, c - 5), (c + 5, c - 5), 2)
        pygame.draw.line(s, theme.TEXT_PRIMARY, (c - 6, c + 4), (c + 6, c + 4), 2)
    elif key == "casino":
        # Poker chip
        pygame.draw.circle(s, (160, 30, 30), (c, c), 12)
        pygame.draw.circle(s, theme.BG_DARK, (c, c), 7)
        pygame.draw.circle(s, (160, 30, 30), (c, c), 4)
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            x1 = int(c + 9 * math.cos(rad))
            y1 = int(c + 9 * math.sin(rad))
            pygame.draw.circle(s, theme.TEXT_PRIMARY, (x1, y1), 2)
    elif key == "club":
        # Music note
        pygame.draw.circle(s, theme.BLUE_BRIGHT, (c + 4, c - 2), 7)
        pygame.draw.rect(s, theme.BLUE_BRIGHT, pygame.Rect(c + 9, c - 10, 3, 14))
        pygame.draw.ellipse(s, theme.BLUE_BRIGHT, pygame.Rect(c + 5, c + 4, 10, 6))
    elif key == "dock":
        # Container stack
        for row in range(3):
            col_offset = row % 2 * 6
            pygame.draw.rect(s, theme.BLUE_MID,
                             pygame.Rect(c - 12 + col_offset, c + 4 - row * 8, 10, 7),
                             border_radius=1)
            pygame.draw.rect(s, theme.BG_DARK,
                             pygame.Rect(c - 12 + col_offset, c + 4 - row * 8, 10, 7),
                             border_radius=1, width=1)
    elif key == "arms":
        # Briefcase with lock
        pygame.draw.rect(s, theme.TEXT_MUTED, pygame.Rect(c - 11, c - 6, 22, 16), border_radius=3)
        pygame.draw.arc(s, theme.TEXT_MUTED,
                        pygame.Rect(c - 5, c - 14, 10, 10), 0, math.pi, 2)
        pygame.draw.rect(s, theme.BG_DARK, pygame.Rect(c - 3, c - 1, 6, 6), border_radius=2)
        pygame.draw.circle(s, theme.ACCENT, (c, c + 2), 2)
    elif key == "hq":
        # Crown
        pygame.draw.rect(s, theme.ACCENT, pygame.Rect(c - 11, c + 3, 22, 7))
        for tx, th in [(-9, 10), (-2, 14), (5, 10)]:
            pts = [(c + tx, c + 3), (c + tx + 5, c + 3), (c + tx + 2, c + 3 - th)]
            pygame.draw.polygon(s, theme.ACCENT, pts)
        for dx in [-7, 0, 7]:
            pygame.draw.circle(s, (255, 100, 50), (c + dx, c - 8), 2)
    else:
        pygame.draw.circle(s, theme.ACCENT_DIM, (c, c), 10)

    return s


def _get_icon(key: str) -> pygame.Surface:
    if key not in _ICON_CACHE:
        _ICON_CACHE[key] = _make_icon(key)
    return _ICON_CACHE[key]


# ─── Panel drawing ─────────────────────────────────────────────────────────────

def draw_panel(surface: pygame.Surface, state, fonts: dict,
               panel_rect: pygame.Rect, scroll: int = 0) -> None:
    _draw_toggle(surface, state, fonts, panel_rect)
    row_y = panel_rect.y + _HEADER_H
    mx, my = pygame.mouse.get_pos()
    card_h = _ROW_H - 4
    t = getattr(state, '_time', 0.0)

    for bld_idx, b in enumerate(state.buildings[scroll:], start=scroll):
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, card_h)
        if row_y + card_h > panel_rect.bottom:
            break

        hover = rr.collidepoint(mx, my)
        cost_n = b.cost_for_n(state.buy_count)
        can = state.balance >= cost_n

        import src.managers as _mgr
        pete_pick = _mgr.pete_recommends_index(state)
        is_pete_pick = pete_pick is not None and bld_idx == pete_pick and can

        # Card background (Phase 127 — front-business dossier)
        dim = b.owned == 0 and not can
        _draw_front_card(surface, rr, hover, can, dim)

        # Sticky Pete (Phase 109): highlight best-value affordable buy
        if is_pete_pick:
            pulse_a = int(100 + 80 * math.sin(t * 3.2))
            pick_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
            pygame.draw.rect(pick_surf, (*theme.NOIR_GOLD, pulse_a),
                             pick_surf.get_rect(), border_radius=8, width=2)
            surface.blit(pick_surf, rr.topleft)
            pick_lbl = fonts.get('disp_xs', fonts['xs']).render("PETE'S PICK", True, theme.NOIR_GOLD_BRIGHT)
            surface.blit(pick_lbl, (rr.right - pick_lbl.get_width() - 10, rr.y + 6))

        # Left accent bar — crimson/gold ledger mark
        if can:
            ab = pygame.Surface((3, card_h - 16), pygame.SRCALPHA)
            ab.fill((*theme.NOIR_GOLD, 200))
            surface.blit(ab, (rr.x, rr.y + 8))
        elif hover:
            pygame.draw.rect(surface, theme.NOIR_GOLD_DEEP,
                             pygame.Rect(rr.x, rr.y + 8, 3, card_h - 16), border_radius=2)

        # Icon
        icon = _get_icon(b.icon_key)
        icon_x = rr.x + 10
        icon_y = rr.y + (card_h - _ICON_SIZE) // 2
        alpha_icon = 255 if b.owned > 0 or can else 100
        if alpha_icon < 255:
            icon_copy = icon.copy()
            icon_copy.set_alpha(alpha_icon)
            surface.blit(icon_copy, (icon_x, icon_y))
        else:
            surface.blit(icon, (icon_x, icon_y))

        text_x = icon_x + _ICON_SIZE + 8
        text_right = _text_gutter_x(rr)
        text_max_w = max(60, text_right - text_x)

        # Name — display font for business identity
        dim = b.owned == 0 and not can
        nc = theme.NOIR_BONE_DIM if dim else (theme.NOIR_BONE if can else theme.NOIR_BONE_DIM)
        name_font = fonts.get('disp_sm', fonts['sm'])
        name_surf = _fit_line(name_font, b.name, text_max_w, nc, 130 if dim else 255)
        surface.blit(name_surf, (text_x, rr.y + 8))

        # Description (xs font)
        desc_surf = _fit_line(fonts['xs'], b.description, text_max_w, theme.NOIR_BONE_DIM,
                              90 if dim else 255)
        surface.blit(desc_surf, (text_x, rr.y + 28))

        # Special ability
        if b.special:
            sp_col = (120, 190, 255) if b.owned > 0 else theme.TEXT_MUTED
            sp_surf = _fit_line(fonts['xs'], f"* {b.special}", text_max_w, sp_col,
                                  70 if dim else 255)
            surface.blit(sp_surf, (text_x, rr.y + 44))

        # Income
        ic = theme.TEXT_MUTED if b.owned == 0 else theme.GREEN
        ins = _fit_line(fonts['xs'], f"+{_fmt(b.income_per_second)}/s", text_max_w, ic,
                        90 if dim else 255)
        surface.blit(ins, (text_x, rr.y + 60))

        # Buy button — wax seal
        btn = _btn_rect(rr)
        btn_hover = btn.collidepoint(mx, my)
        top_label = f"x{state.buy_count}" if state.buy_count > 1 else "BUY"
        _draw_seal_button(surface, btn, can, btn_hover, fonts, top_label, _fmt(cost_n))

        # Count badge
        if b.owned > 0:
            _draw_count_badge(surface, fonts, btn, b, state, bld_idx)

        # Separator
        sep = pygame.Surface((rr.width, 1), pygame.SRCALPHA)
        sep.fill((255, 255, 255, 30))
        surface.blit(sep, (rr.x, rr.bottom + _GAP // 2))

        row_y += _ROW_H + _GAP
        if row_y >= panel_rect.bottom:
            break


def _draw_count_badge(surface, fonts, btn, b, state, bld_idx):
    badge_text = fonts['xs'].render(f"x{b.owned}", True, theme.TEXT_GOLD)
    bpad_x, bpad_y = 6, 3
    bw2 = badge_text.get_width() + bpad_x * 2
    bh2 = badge_text.get_height() + bpad_y * 2
    badge_x = btn.x - bw2 - 6
    badge_y = btn.y + 4
    badge_r = pygame.Rect(badge_x, badge_y, bw2, bh2)

    if b.owned >= 100:
        pill_bg = (70, 20, 20); pill_border = (230, 80, 80)
    elif b.owned >= 25:
        pill_bg = (50, 20, 20); pill_border = (200, 60, 60)
    elif b.owned >= 10:
        pill_bg = (40, 35, 65); pill_border = theme.ACCENT_DIM
    else:
        pill_bg = theme.BG_DARK; pill_border = theme.ACCENT_DIM

    pill_surf = pygame.Surface((bw2, bh2), pygame.SRCALPHA)
    pygame.draw.rect(pill_surf, (*pill_bg, 255), pill_surf.get_rect(), border_radius=99)
    pygame.draw.rect(pill_surf, (*pill_border, 255), pill_surf.get_rect(), border_radius=99, width=1)
    pill_surf.blit(badge_text, badge_text.get_rect(center=(bw2 // 2, bh2 // 2)))
    surface.blit(pill_surf, (badge_x, badge_y))

    if _building_has_manager(state, bld_idx):
        auto_s = fonts['xs'].render("AUTO", True, theme.GREEN)
        aw = auto_s.get_width() + 8
        ah = auto_s.get_height() + 4
        auto_x = badge_x - aw - 4
        auto_y = badge_y
        auto_surf = pygame.Surface((aw, ah), pygame.SRCALPHA)
        pygame.draw.rect(auto_surf, (20, 50, 30, 255), auto_surf.get_rect(), border_radius=4)
        auto_surf.blit(auto_s, auto_s.get_rect(center=(aw // 2, ah // 2)))
        surface.blit(auto_surf, (auto_x, auto_y))


def handle_click(state, pos: tuple, panel_rect: pygame.Rect, scroll: int = 0) -> bool:
    if _check_toggle(state, pos, panel_rect):
        return True
    row_y = panel_rect.y + _HEADER_H
    card_h = _ROW_H - 4
    for bld_idx, b in enumerate(state.buildings[scroll:], start=scroll):
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, card_h)
        if row_y + card_h > panel_rect.bottom:
            break
        if _btn_rect(rr).collidepoint(pos):
            cost_n = b.cost_for_n(state.buy_count)
            if state.balance >= cost_n:
                import src.managers as _mgr
                rec = _mgr.pete_recommends_index(state)
                if rec is not None:
                    if bld_idx == rec:
                        state._pete_followed_buys = getattr(state, '_pete_followed_buys', 0) + 1
                    else:
                        state._pete_other_buys = getattr(state, '_pete_other_buys', 0) + 1
                state.balance -= cost_n
                was_first = getattr(state, '_total_buildings_purchased', 0) == 0
                b.owned += state.buy_count
                state._total_buildings_purchased = getattr(state, '_total_buildings_purchased', 0) + state.buy_count
                sound.play('purchase')
                import src.ui as _ui
                _ui.push_notification(f"Bought: {b.name}", theme.GREEN)
                if was_first:
                    try:
                        import src.analytics as _an
                        _an.first_building()
                    except Exception:
                        pass
            return True
        row_y += _ROW_H + _GAP
    return False


def _btn_rect(row_rect: pygame.Rect) -> pygame.Rect:
    return pygame.Rect(row_rect.right - _BTN_W - 6,
                       row_rect.y + (row_rect.height - _BTN_H) // 2,
                       _BTN_W, _BTN_H)


def _fmt(n: float) -> str:
    import src.theme as _t
    return _t.format_number(n)


# Buy-quantity toggle geometry — shared by draw and hit-test so they never
# drift. Sized up to ~36px tall for comfortable touch targets on mobile.
_TOGGLE_H = 36
_TOGGLE_Y = 6


def _toggle_rect(n: int, panel_rect) -> pygame.Rect:
    x = panel_rect.right - 4
    for nn in (100, 10, 1):
        w = 48 if nn == 100 else 40
        x -= w + 4
        if nn == n:
            return pygame.Rect(x, panel_rect.y + _TOGGLE_Y, w, _TOGGLE_H)
    return pygame.Rect(0, 0, 0, 0)


def _draw_toggle(surface, state, fonts, panel_rect):
    disp = fonts.get('disp_xs', fonts['xs'])
    for n in (100, 10, 1):
        r = _toggle_rect(n, panel_rect)
        active = state.buy_count == n
        mx2, my2 = pygame.mouse.get_pos()
        hover = r.collidepoint(mx2, my2)
        if active:
            pygame.draw.rect(surface, theme.NOIR_GOLD, r, border_radius=5)
            tc = theme.NOIR_INK
        elif hover:
            hs = pygame.Surface((r.width, r.height), pygame.SRCALPHA)
            pygame.draw.rect(hs, (*theme.NOIR_GLASS, 180), hs.get_rect(), border_radius=5)
            surface.blit(hs, r.topleft)
            pygame.draw.rect(surface, theme.NOIR_GOLD_DEEP, r, border_radius=5, width=1)
            tc = theme.NOIR_BONE
        else:
            pygame.draw.rect(surface, theme.NOIR_CARD, r, border_radius=5)
            pygame.draw.rect(surface, (*theme.NOIR_GOLD, 40), r, border_radius=5, width=1)
            tc = theme.NOIR_BONE_DIM
        s = disp.render(f"x{n}", True, tc)
        surface.blit(s, s.get_rect(center=r.center))


def _check_toggle(state, pos, panel_rect) -> bool:
    for n in (100, 10, 1):
        if _toggle_rect(n, panel_rect).collidepoint(pos):
            state.buy_count = n
            return True
    return False
