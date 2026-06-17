"""Illegal Operations — long-duration missions that pay out after a delay."""
from __future__ import annotations
import random
import time
from dataclasses import dataclass, field
from typing import List, Optional

import pygame
import src.theme as theme
import src.scale as scale
import config

# ─── Operation definitions ───────────────────────────────────────────────────────

_OP_DEFS: list[dict] = [
    {
        'name':        'Drug Run',
        'desc':        'Transport product across three districts.',
        'duration':    300.0,     # 5 minutes
        'crew_cost':   5,
        'money_cost':  2_000.0,
        'turf_needed': 1,
        'reward_mult': 180.0,     # 3 min income after a 5 min wait — strategic, not free
        'heat_gain':   12.0,
        'color':       (180, 60,  60),
        'icon':        'DR',
    },
    {
        'name':        'Casino Skim',
        'desc':        'Quietly siphon from the house take.',
        'duration':    480.0,     # 8 minutes
        'crew_cost':   3,
        'money_cost':  5_000.0,
        'turf_needed': 1,
        'reward_mult': 300.0,     # 5 min income after 8 min wait
        'heat_gain':   6.0,
        'color':       (200, 160, 40),
        'icon':        'CS',
    },
    {
        'name':        'Union Extortion',
        'desc':        'Shake down a construction union for tribute.',
        'duration':    600.0,     # 10 minutes
        'crew_cost':   8,
        'money_cost':  15_000.0,
        'turf_needed': 2,
        'reward_mult': 480.0,     # 8 min income after 10 min wait
        'heat_gain':   16.0,
        'color':       (140, 100, 40),
        'icon':        'UE',
    },
    {
        'name':        'Political Bribery',
        'desc':        'Place a city councilman on retainer.',
        'duration':    900.0,     # 15 minutes
        'crew_cost':   2,
        'money_cost':  50_000.0,
        'turf_needed': 2,
        'reward_mult': 720.0,     # 12 min income after 15 min wait
        'heat_gain':   -20.0,    # negative = heat reduction as reward
        'color':       (80,  130, 200),
        'icon':        'PB',
    },
    {
        'name':        'International Smuggling',
        'desc':        'Ship contraband through the waterfront.',
        'duration':    1800.0,    # 30 minutes
        'crew_cost':   12,
        'money_cost':  150_000.0,
        'turf_needed': 3,
        'reward_mult': 1800.0,    # 30 min income after 30 min wait — 1:1 but with risk
        'heat_gain':   25.0,
        'color':       (60,  160, 180),
        'icon':        'IS',
    },
]


@dataclass
class Operation:
    name: str
    desc: str
    duration: float
    crew_cost: int
    money_cost: float
    turf_needed: int
    reward_mult: float
    heat_gain: float
    color: tuple
    icon: str
    # Runtime state
    active: bool     = False
    start_time: float = 0.0    # wall-clock time.time() when started
    reward: float    = 0.0     # computed at start time
    completed: bool  = False
    collected: bool  = False
    # Session 9: Cartel Fast Track shortens the effective duration (set at start).
    speed_mult: float = 1.0

    @property
    def _eff_duration(self) -> float:
        return self.duration * self.speed_mult

    @property
    def elapsed(self) -> float:
        if not self.active:
            return 0.0
        return time.time() - self.start_time

    @property
    def progress(self) -> float:
        """0.0 → 1.0"""
        if not self.active:
            return 0.0
        return min(1.0, self.elapsed / self._eff_duration)

    @property
    def is_ready(self) -> bool:
        return self.active and self.elapsed >= self._eff_duration and not self.collected

    @property
    def time_remaining(self) -> float:
        return max(0.0, self._eff_duration - self.elapsed)

    def can_start(self, state) -> tuple[bool, str]:
        if self.active and not self.collected:
            return False, "Already running"
        turf = sum(1 for t in getattr(state, 'territories', []) if t.unlocked)
        if turf < self.turf_needed:
            return False, f"Need {self.turf_needed} territories"
        ca = getattr(state, 'crew', None)
        assigned_total = ca.total() if ca else 0
        total_crew     = sum(b.owned for b in getattr(state, 'buildings', []))
        free_crew      = max(0, total_crew - assigned_total)
        if free_crew < self.crew_cost:
            return False, f"Need {self.crew_cost} free crew"
        if state.balance < self.money_cost:
            return False, f"Need {theme.format_money(self.money_cost)}"
        return True, ""

    def start(self, state):
        from src.crew import smuggling_op_mult
        ca = getattr(state, 'crew', None)
        mult = smuggling_op_mult(ca) if ca else 1.0
        # The Smuggler manager: +30% operation rewards.
        try:
            import src.managers as _mgr
            mult *= _mgr.operation_reward_mult(state)
        except Exception:
            pass
        # Industrial / Waterfront districts also boost operation rewards.
        try:
            import src.territory as _terr
            mult *= _terr.operation_reward_mult(state)
        except Exception:
            pass
        # Rank perk: cumulative operation reward bonus per rank tier.
        try:
            import src.prestige as _prestige
            mult *= 1.0 + _prestige.rank_operation_reward_bonus(
                getattr(state, 'prestige_tokens', 0))
        except Exception:
            pass
        # Cartel branch perks: Supply Lines / Kingmaker Network reward, Fast Track speed.
        try:
            import src.prestige_tree as _ptree
            mult *= _ptree.operation_reward_mult(state)
            self.speed_mult = _ptree.operation_speed_mult(state)
        except Exception:
            self.speed_mult = 1.0
        # Dragon: Jade -15% reward, Black combo +35%.
        try:
            import src.dragon as _dragon
            mult *= _dragon.op_reward_mult(state)
        except Exception:
            pass
        self.reward      = state.income_per_second * self.reward_mult * mult
        self.start_time  = time.time()
        self.active      = True
        self.completed   = False
        self.collected   = False
        state.balance    = max(0.0, state.balance - self.money_cost)
        # Dragon Black: +25% more heat from operations.
        heat_mult = 1.0
        try:
            import src.dragon as _dragon
            heat_mult = _dragon.op_heat_gain_mult(state)
        except Exception:
            pass
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + max(0.0, self.heat_gain * 0.3 * heat_mult))

    def success_chance(self, state) -> float:
        """
        Context-aware success probability at collect time.
        Crew smuggling, Waterfront territory, and low heat boost success.
        Federal Informants power and high heat reduce it.
        """
        base = 0.80
        heat = float(getattr(state, 'heat', 0.0) or 0.0)

        # Heat penalty: -0.4% per heat point above 40
        heat_penalty = max(0.0, (heat - 40.0) * 0.004)

        # Waterfront territory bonus
        terr_bonus = 0.0
        territories = getattr(state, 'territories', [])
        if any(t.name == 'Waterfront' and t.unlocked for t in territories):
            terr_bonus += 0.10

        # Crew smuggling bonus (already applied to reward at start; also helps success)
        from src.crew import smuggling_op_mult
        ca = getattr(state, 'crew', None)
        crew_mult = smuggling_op_mult(ca) if ca else 1.0
        crew_bonus = min(0.15, (crew_mult - 1.0) * 0.5)

        # Federal Informants penalty
        rival_penalty = 0.0
        try:
            from src.rivals import get_empire_impact
            impact = get_empire_impact(state)
            # Investigative trait active?
            rivals = getattr(state, 'rivals', []) or []
            if any(r.trait == 'Investigative' and r.status != 'Eliminated' for r in rivals if r):
                rival_penalty = 0.15
        except Exception:
            pass

        chance = base + terr_bonus + crew_bonus - heat_penalty - rival_penalty
        return max(0.20, min(0.95, chance))

    def collect(self, state) -> str:
        """Collect completed operation. Returns outcome string."""
        if not self.is_ready:
            return ""

        success = random.random() < self.success_chance(state)
        import src.theme as _theme

        self.active    = False
        self.completed = True
        self.collected = True

        if success:
            state.balance           = float(getattr(state, 'balance', 0.0)) + self.reward
            state.lifetime_earnings = float(getattr(state, 'lifetime_earnings', 0.0)) + self.reward
            import src.money_debug as _md
            _md.credit(state, self.reward, 'money_from_operations')
            if self.heat_gain < 0:
                state.heat = max(0.0, getattr(state, 'heat', 0.0) + self.heat_gain)
            else:
                state.heat = min(100.0, getattr(state, 'heat', 0.0) + self.heat_gain * 0.7)
            state.prestige_tokens = int(getattr(state, 'prestige_tokens', 0)) + 1
            state.influence       = int(getattr(state, 'influence', 0)) + 5
            # Dragon Black: record combo timestamp for next op
            try:
                import src.dragon as _dragon
                _dragon.on_op_collected(state)
            except Exception:
                pass
            was_first = getattr(state, '_total_ops_completed', 0) == 0
            state._total_ops_completed = getattr(state, '_total_ops_completed', 0) + 1
            if was_first:
                try:
                    import src.analytics as _an
                    _an.first_operation()
                except Exception:
                    pass
            return f"{self.name} Complete\n+{_theme.format_money(self.reward)}\n+5 Respect"
        else:
            # Partial loss on failure — lose the money cost, get heat
            penalty = self.money_cost * 0.5
            state.balance = max(0.0, float(getattr(state, 'balance', 0.0)) - penalty)
            state.heat    = min(100.0, getattr(state, 'heat', 0.0) + self.heat_gain * 0.5 + 5.0)
            return f"{self.name} FAILED\nLost {_theme.format_money(penalty)}  +heat"


def make_operations() -> List[Operation]:
    ops = []
    for d in _OP_DEFS:
        ops.append(Operation(
            name=d['name'], desc=d['desc'], duration=d['duration'],
            crew_cost=d['crew_cost'], money_cost=d['money_cost'],
            turf_needed=d['turf_needed'], reward_mult=d['reward_mult'],
            heat_gain=d['heat_gain'], color=d['color'], icon=d['icon'],
        ))
    return ops


# ─── UI ──────────────────────────────────────────────────────────────────────────
# Phase 90: geometry is font-driven. Row height, text rows and the action button
# all derive from the live (scaled) font metrics + shared config spacing, so the
# layout never collides when fonts grow at higher resolutions. draw_panel and
# handle_click consume the same helpers (_ops_list_top / _op_row_height /
# _op_layout) — a single source of truth for both visuals and click targets.

_GAP = 6   # vertical gap between cards (design px; scaled at use site)


def _op_button_size(fonts: dict) -> tuple[int, int]:
    """COLLECT/START button size — wide enough for the label, tall enough for
    the two-line COLLECT (label + reward) at any font scale."""
    sm_h = fonts['sm'].get_height()
    xs_h = fonts['xs'].get_height()
    bw = max(scale.sd(90), fonts['sm'].size("COLLECT")[0] + scale.sd(20))
    bh = sm_h + xs_h + scale.sd(6)
    return bw, bh


def _op_row_height(fonts: dict) -> int:
    """Row height derived from its four stacked text lines and the button zone."""
    sm_h = fonts['sm'].get_height()
    xs_h = fonts['xs'].get_height()
    pad = scale.sd(6)
    g = scale.sd(4)
    text_h = pad + sm_h + g + xs_h + g + xs_h + g + xs_h + pad
    _, bh = _op_button_size(fonts)
    return max(text_h, bh + 2 * pad, scale.sd(config.UI_CARD_MIN_HEIGHT))


def _op_layout(rr: pygame.Rect, fonts: dict) -> dict:
    """Single source of truth for one row's geometry (text rows + button rect)."""
    sm_h = fonts['sm'].get_height()
    xs_h = fonts['xs'].get_height()
    pad = scale.sd(6)
    g = scale.sd(4)
    badge_d = scale.sd(32)
    text_x = rr.x + scale.sd(10) + badge_d + scale.sd(8)
    y_name = rr.y + pad
    y_desc = y_name + sm_h + g
    y_req = y_desc + xs_h + g
    y_heat = y_req + xs_h + g
    bw, bh = _op_button_size(fonts)
    btn = pygame.Rect(rr.right - bw - scale.sd(6), rr.centery - bh // 2, bw, bh)
    return {'text_x': text_x, 'badge_d': badge_d, 'name': y_name, 'desc': y_desc,
            'req': y_req, 'heat': y_heat, 'btn': btn}


def _ops_list_top(state, fonts: dict, panel_rect: pygame.Rect,
                  ops: List[Operation]) -> int:
    """Y where the operation list begins — pushed down past the onboarding tip
    when one is shown. Shared by draw and click so rows stay aligned."""
    top = panel_rect.y + fonts['xs'].get_height() + scale.sd(12)
    crew = getattr(state, 'crew', None)
    any_active = any(op.active and not op.collected for op in ops)
    if crew is not None and crew.total() == 0 and not any_active:
        top += _op_tip_height(fonts) + scale.sd(6)
    return top


def _op_tip_height(fonts: dict) -> int:
    sm_h = fonts['sm'].get_height()
    xs_h = fonts['xs'].get_height()
    tpad = scale.sd(8)
    return tpad + sm_h + scale.sd(6) + xs_h + scale.sd(4) + xs_h + tpad


def draw_panel(surface: pygame.Surface, state, fonts: dict,
               panel_rect: pygame.Rect) -> None:
    ops: List[Operation] = getattr(state, 'operations', [])
    mx, my = pygame.mouse.get_pos()
    t = getattr(state, '_time', 0.0)

    hdr = fonts['xs'].render(
        "ILLEGAL OPERATIONS  —  commit crew & cash, collect later", True, theme.TEXT_MUTED)
    surface.blit(hdr, (panel_rect.x + scale.sd(8), panel_rect.y + scale.sd(6)))

    # Onboarding: if no crew is assigned anywhere, show a helpful prompt.
    crew = getattr(state, 'crew', None)
    any_active = any(op.active and not op.collected for op in ops)
    if crew is not None and crew.total() == 0 and not any_active:
        tip_h = _op_tip_height(fonts)
        tip_top = panel_rect.y + fonts['xs'].get_height() + scale.sd(12)
        tip_rect = pygame.Rect(panel_rect.x + 4, tip_top, panel_rect.width - 8, tip_h)
        tip_surf = pygame.Surface((tip_rect.width, tip_rect.height), pygame.SRCALPHA)
        pygame.draw.rect(tip_surf, (40, 55, 80, 210), tip_surf.get_rect(), border_radius=10)
        pygame.draw.rect(tip_surf, (80, 130, 200, 160), tip_surf.get_rect(),
                         border_radius=10, width=1)
        tpad = scale.sd(8)
        ty = tpad
        tip_surf.blit(fonts['sm'].render("Assign Crew to begin Operations", True, (160, 200, 255)),
                      (scale.sd(12), ty))
        ty += fonts['sm'].get_height() + scale.sd(6)
        tip_surf.blit(fonts['xs'].render(
            "Go to the Crew tab →  distribute crew across roles.", True, (120, 155, 200)),
            (scale.sd(12), ty))
        ty += fonts['xs'].get_height() + scale.sd(4)
        tip_surf.blit(fonts['xs'].render(
            "Smuggling crew boosts op rewards. Territory crew helps capture districts.",
            True, (100, 135, 180)), (scale.sd(12), ty))
        surface.blit(tip_surf, tip_rect.topleft)

    row_h = _op_row_height(fonts)
    row_y = _ops_list_top(state, fonts, panel_rect, ops)
    for op in ops:
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, row_h)
        if row_y + row_h > panel_rect.bottom:
            break

        hover = rr.collidepoint(mx, my)
        can, reason = op.can_start(state)
        L = _op_layout(rr, fonts)

        # Background
        if op.is_ready:
            pulse_a = int(60 + 40 * __import__('math').sin(t * 3.5))
            bg_col  = (*op.color, pulse_a)
        elif op.active:
            bg_col = (*op.color, 20)
        elif hover and can:
            bg_col = (*op.color, 30)
        else:
            bg_col = (30, 32, 48, 200)

        bg_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
        pygame.draw.rect(bg_surf, bg_col, bg_surf.get_rect(), border_radius=10)
        surface.blit(bg_surf, rr.topleft)

        # Accent bar
        bar = pygame.Surface((scale.sd(3), rr.height - scale.sd(12)), pygame.SRCALPHA)
        bar.fill((*op.color, 180 if not op.active else 240))
        surface.blit(bar, (rr.x, rr.y + scale.sd(6)))

        # Icon badge
        bd = L['badge_d']
        badge = pygame.Surface((bd, bd), pygame.SRCALPHA)
        pygame.draw.circle(badge, (*op.color, 200), (bd // 2, bd // 2), bd // 2 - 1)
        ic = fonts['xs'].render(op.icon, True, (230, 230, 230))
        badge.blit(ic, ic.get_rect(center=(bd // 2, bd // 2)))
        surface.blit(badge, (rr.x + scale.sd(10), rr.centery - bd // 2))

        # Name + desc
        ns = fonts['sm'].render(op.name, True, theme.TEXT_PRIMARY)
        surface.blit(ns, (L['text_x'], L['name']))
        ds = fonts['xs'].render(op.desc, True, theme.TEXT_MUTED)
        surface.blit(ds, (L['text_x'], L['desc']))

        # Requirements row
        req_parts = [
            f"Crew: {op.crew_cost}",
            theme.format_money(op.money_cost),
            f"Turf: {op.turf_needed}",
            f"Time: {_fmt_time(op.duration)}",
        ]
        req_s = fonts['xs'].render("  ·  ".join(req_parts), True, theme.TEXT_MUTED)
        surface.blit(req_s, (L['text_x'], L['req']))

        # Heat gain / heat reduction label
        if op.heat_gain < 0:
            hc = theme.GREEN
            ht = f"-{abs(op.heat_gain):.0f} heat on collect"
        else:
            hc = (220, 100, 60)
            ht = f"+{op.heat_gain:.0f} heat on collect"
        hs = fonts['xs'].render(ht, True, hc)
        surface.blit(hs, (L['text_x'], L['heat']))

        # Right side: progress bar or button
        btn = L['btn']
        if op.is_ready:
            hov_btn = btn.collidepoint(mx, my)
            col = (60, 200, 80) if not hov_btn else (80, 230, 100)
            pygame.draw.rect(surface, col, btn, border_radius=6)
            collect_s = fonts['sm'].render("COLLECT", True, (20, 20, 20))
            reward_s = fonts['xs'].render(theme.format_money(op.reward), True, (20, 20, 20))
            surface.blit(collect_s, collect_s.get_rect(centerx=btn.centerx, y=btn.y + scale.sd(3)))
            surface.blit(reward_s, reward_s.get_rect(
                centerx=btn.centerx, y=btn.y + scale.sd(3) + fonts['sm'].get_height()))

        elif op.active:
            bar_h = scale.sd(16)
            bar_r = pygame.Rect(btn.x, rr.centery - bar_h // 2, btn.width, bar_h)
            pygame.draw.rect(surface, (30, 32, 50), bar_r, border_radius=bar_h // 2)
            fw = max(scale.sd(4), int(btn.width * op.progress))
            pygame.draw.rect(surface, op.color,
                             pygame.Rect(btn.x, bar_r.y, fw, bar_h), border_radius=bar_h // 2)
            pct_s = fonts['xs'].render(f"{op.progress*100:.0f}%", True, theme.TEXT_PRIMARY)
            surface.blit(pct_s, pct_s.get_rect(center=bar_r.center))
            tr_s = fonts['xs'].render(_fmt_time(op.time_remaining), True, theme.TEXT_PRIMARY)
            surface.blit(tr_s, tr_s.get_rect(centerx=bar_r.centerx, y=bar_r.bottom + scale.sd(2)))

        else:
            hov_btn = btn.collidepoint(mx, my)
            if can:
                col = tuple(min(255, v + 20) for v in op.color) if hov_btn else op.color
            else:
                col = (40, 42, 60)
            pygame.draw.rect(surface, col, btn, border_radius=6)
            bl = fonts['sm'].render("START", True, (230, 230, 230) if can else theme.TEXT_MUTED)
            surface.blit(bl, bl.get_rect(center=btn.center))
            if not can:
                rs = fonts['xs'].render(reason, True, (150, 80, 80))
                surface.blit(rs, rs.get_rect(centerx=btn.centerx, y=btn.bottom + scale.sd(2)))

        sep = pygame.Surface((rr.width, 1), pygame.SRCALPHA)
        sep.fill((255, 255, 255, 20))
        surface.blit(sep, (rr.x, rr.bottom + scale.sd(_GAP) // 2))
        row_y += row_h + scale.sd(_GAP)


def handle_click(state, pos: tuple, panel_rect: pygame.Rect) -> bool:
    ops: List[Operation] = getattr(state, 'operations', [])
    fonts = getattr(state, '_fonts', {})
    if not fonts:
        return False
    row_h = _op_row_height(fonts)
    row_y = _ops_list_top(state, fonts, panel_rect, ops)

    for op in ops:
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, row_h)
        if row_y + row_h > panel_rect.bottom:
            break
        if rr.collidepoint(pos):
            btn = _op_layout(rr, fonts)['btn']
            if btn.collidepoint(pos):
                if op.is_ready:
                    outcome = op.collect(state)
                    import src.ui as _ui
                    import src.theme as _theme
                    import src.sound as sound
                    success = outcome and 'FAILED' not in outcome
                    col = _theme.GREEN if success else _theme.RED
                    _ui.push_notification(outcome or f"{op.name} complete!", col)
                    if not success:
                        sound.play('error')
                    elif getattr(state, '_total_ops_completed', 0) == 1:
                        # First-ever op: a recurring income subsystem just came
                        # online — milestone, not a routine collect. Reuses the
                        # existing completion counter (incremented inside collect).
                        sound.play('manager')
                    else:
                        sound.play('achievement')
                    return True
                elif not op.active:
                    can, _ = op.can_start(state)
                    if can:
                        op.start(state)
                        import src.sound as sound
                        sound.play('purchase')
                        return True
        row_y += row_h + scale.sd(_GAP)

    return False


def _fmt_time(seconds: float) -> str:
    s = int(seconds)
    if s >= 3600:
        return f"{s // 3600}h {(s % 3600) // 60}m"
    if s >= 60:
        return f"{s // 60}m {s % 60}s"
    return f"{s}s"
