"""Prestige upgrade tree — Session 9 branching archetypes.

The player commits to exactly ONE branch (Kingpin / Warlord / Cartel /
Consigliere) per prestige cycle. Only the committed branch's owned perks are
active; the commitment resets at prestige so a future run can choose a different
identity. Each branch strengthens a DIFFERENT subsystem so the choice produces a
genuinely different playstyle rather than another universal income multiplier.

Legacy (pre-S9) universal perks are no longer buyable but are still honoured for
their original effect so existing saves lose nothing (see _LEGACY_PERK_DEFS).
"""
from __future__ import annotations
import math
import pygame
import config
import src.theme as theme
import src.prestige as prestige
import src.sound as sound

# ─── Legacy perks (pre-S9) — grandfathered, NOT buyable ──────────────────────
# Old saves keep the exact effects they already purchased. This avoids a
# destructive refund migration. New progression is the branching tree below.
_LEGACY_PERK_DEFS = [
    ('click_power_1', 'Iron Fist',        1,  '+10% click power',        1),
    ('income_1',      'Street Smarts',    1,  '+10% all income',         1),
    ('offline_1',     'Night Shift',      1,  '+25% offline earnings',   1),
    ('auto_buy',      'Talent Scout',     3,  'Auto-buys buildings',     2),
    ('manager_unlock','Crew Network',     3,  'Managers give 2x income', 2),
    ('auto_upgrade',  'The Machine',      6,  'Auto-buys upgrades',      3),
    ('income_2',      'Money Laundering', 6,  '+25% all income',         3),
    ('click_power_2', 'Enforcer',         10, '+50% click power',        4),
    ('faster_prog',   'Inside Track',     10, '+20% building income',    4),
    ('empire_bonus',  'Crime Syndicate',  20, '2x all income + clicks',  5),
]
_LEGACY_KEYS = {d[0] for d in _LEGACY_PERK_DEFS}

# ─── Branching prestige tree (Session 9) ─────────────────────────────────────
KINGPIN, WARLORD, CARTEL, CONSIGLIERE = 'kingpin', 'warlord', 'cartel', 'consigliere'
BRANCH_ORDER = [KINGPIN, WARLORD, CARTEL, CONSIGLIERE]

BRANCH_META = {
    KINGPIN:     {'name': 'Kingpin',     'tag': 'Economic Empire', 'short': 'Economy',
                  'color': (210, 170, 60),
                  'blurb': 'Income, offline gains, automation. Weak in conflict.'},
    WARLORD:     {'name': 'Warlord',     'tag': 'Force & Intimidation', 'short': 'Force',
                  'color': (205, 75, 60),
                  'blurb': 'Rival pressure, clicks, intimidation. Slow economy.'},
    CARTEL:      {'name': 'Cartel',      'tag': 'Operations & Logistics', 'short': 'Operations',
                  'color': (60, 175, 140),
                  'blurb': 'Operations, expansion, efficiency. Fragile if disrupted.'},
    CONSIGLIERE: {'name': 'Consigliere', 'tag': 'Influence & Corruption', 'short': 'Influence',
                  'color': (155, 110, 220),
                  'blurb': 'Influence, heat control, Respect. Lower direct output.'},
}

# branch -> [(key, name, cost, effect_text, within-branch tier 1..4)]
BRANCH_PERKS = {
    KINGPIN: [
        ('kp_cashflow', 'Cash Flow',         2,  '+15% all passive income',             1),
        ('kp_ledger',   'Off the Books',     4,  '+40% offline earnings',               2),
        ('kp_payroll',  'Syndicate Payroll', 7,  'Managers give +0.5x more income',     3),
        ('kp_monopoly', 'Monopoly',          12, '+25% per-building income + auto-buy',  4),
    ],
    WARLORD: [
        ('wl_knuckles', 'Brass Knuckles',  2,  '+40% click power',                     1),
        ('wl_force',    'Show of Force',   4,  '+20% rival action success',            2),
        ('wl_spoils',   'Spoils of War',   7,  '+60% cash seized from rival attacks',  3),
        ('wl_terror',   'Reign of Terror', 12, '+4% income per district held (max +24%)', 4),
    ],
    CARTEL: [
        ('ct_supply',  'Supply Lines',      2,  '+30% operation rewards',                  1),
        ('ct_fast',    'Fast Track',        4,  'Operations finish 20% faster',            2),
        ('ct_expand',  'Expansion',         7,  '+15% territory success, +12% district income', 3),
        ('ct_network', 'Kingmaker Network', 12, '+60% operation rewards (stacks)',         4),
    ],
    CONSIGLIERE: [
        ('cs_tongue', 'Silver Tongue', 2,  '+25% Influence from prestige',          1),
        ('cs_clean',  'Clean Money',   4,  '+0.10/s heat decay',                    2),
        ('cs_favors', 'Favors Owed',   7,  '+60% Respect income bonus',             3),
        ('cs_puppet', 'Puppet Master', 12, '+50% Influence from prestige (stacks)', 4),
    ],
}

BRANCH_OF = {k: br for br, lst in BRANCH_PERKS.items() for (k, *_rest) in lst}
PERK_DEF  = {k: (k, n, c, e, t)
             for br, lst in BRANCH_PERKS.items() for (k, n, c, e, t) in lst}
PERK_COST = {k: d[2] for k, d in PERK_DEF.items()}

# Hover tooltips — full sentences. Must match the implementation.
PERK_DETAILS: dict[str, str] = {
    # Kingpin
    'kp_cashflow': "All passive income ×1.15 while you run the Kingpin path.",
    'kp_ledger':   "Offline earnings +40% on top of the base rate. Rewards check-ins.",
    'kp_payroll':  "Every hired manager grants +0.5× extra income (stacks with Crew Network).",
    'kp_monopoly': "Each building earns +25% AND buildings auto-buy every 5s. The economic capstone.",
    # Warlord
    'wl_knuckles': "Each manual click is worth 40% more cash.",
    'wl_force':    "+20% success chance on all actions against rival factions.",
    'wl_spoils':   "Attacks on rivals seize 60% more cash.",
    'wl_terror':   "Income +4% for every district you control, up to +24%. Turf = power.",
    # Cartel
    'ct_supply':   "Illegal operations pay out 30% more.",
    'ct_fast':     "Operations complete 20% faster — more payouts per hour.",
    'ct_expand':   "+15% territory action success and +12% income from controlled districts.",
    'ct_network':  "Operations pay out a further +60% (multiplies with Supply Lines). Logistics capstone.",
    # Consigliere
    'cs_tongue':   "Every prestige grants 25% more Influence.",
    'cs_clean':    "Heat decays 0.10/s faster — corruption keeps the law off your back.",
    'cs_favors':   "Your Respect income bonus is 60% stronger.",
    'cs_puppet':   "Prestige Influence +50% more (stacks with Silver Tongue). Corruption capstone.",
}

# Seconds between automation purchases for auto-buy / auto-upgrade perks.
_PERK_AUTO_INTERVAL = 5.0

# Card / layout constants (used by the UI below).
_CARD_W = 200
_CARD_H = 92
_GAP_X  = 16
_GAP_Y  = 12
_COLS   = 2


# ─── Ownership / branch helpers ───────────────────────────────────────────────

def has_perk(state, key: str) -> bool:
    return key in getattr(state, 'perks_purchased', [])


def _active(state, key: str) -> bool:
    """Owned AND belongs to the branch committed this prestige cycle."""
    return (key in getattr(state, 'perks_purchased', [])
            and BRANCH_OF.get(key) == getattr(state, 'prestige_branch', None))


def branch_perk_count(state, branch: str) -> int:
    perks = getattr(state, 'perks_purchased', [])
    return sum(1 for k in perks if BRANCH_OF.get(k) == branch)


def branch_tier_unlocked(state, branch: str, tier: int) -> bool:
    """Strictly sequential: tier N needs (N-1) perks already owned in this branch."""
    return branch_perk_count(state, branch) >= (tier - 1)


def can_buy_perk(state, key: str) -> tuple[bool, str]:
    """Whether the player may purchase `key` right now. Returns (ok, reason)."""
    if key in getattr(state, 'perks_purchased', []):
        return False, "Owned"
    branch = BRANCH_OF.get(key)
    if branch is None:
        return False, "Unavailable"
    committed = getattr(state, 'prestige_branch', None)
    if committed is None:
        return False, "Choose a path first"
    if committed != branch:
        return False, "Locked (other path)"
    _, _, cost, _, tier = PERK_DEF[key]
    if not branch_tier_unlocked(state, branch, tier):
        return False, f"Unlock tier {tier}"
    if getattr(state, 'prestige_tokens', 0) < cost:
        return False, f"Need {cost} inf"
    return True, ""


def select_branch(state, branch: str) -> bool:
    """Commit to a branch for this prestige cycle. Permanent until next prestige.

    Allowed only when no branch is committed yet this cycle. Returns success.
    """
    if branch not in BRANCH_PERKS:
        return False
    if getattr(state, 'prestige_branch', None) is not None:
        return False
    state.prestige_branch = branch
    return True


def reset_branch(state) -> None:
    """Clear the cycle commitment (called at prestige). Owned perks persist."""
    state.prestige_branch = None


# ─── Effect accessors ─────────────────────────────────────────────────────────
# All branch-gated: return neutral values unless the owning branch is active.

def offline_earnings_mult(state) -> float:
    """Legacy Night Shift (+25%) + Kingpin Off the Books (+40%), additive."""
    bonus = 0.0
    if has_perk(state, 'offline_1'):
        bonus += 0.25
    if _active(state, 'kp_ledger'):
        bonus += 0.40
    return 1.0 + bonus


def manager_income_mult(state) -> float:
    """Base 1.5×; legacy Crew Network → 2.0×; Kingpin Payroll adds +0.5×."""
    base = 2.0 if has_perk(state, 'manager_unlock') else 1.5
    if _active(state, 'kp_payroll'):
        base += 0.5
    return base


def operation_reward_mult(state) -> float:
    """Cartel Supply Lines (×1.30) and Kingmaker Network (×1.60), multiplicative."""
    m = 1.0
    if _active(state, 'ct_supply'):
        m *= 1.30
    if _active(state, 'ct_network'):
        m *= 1.60
    return m


def operation_speed_mult(state) -> float:
    """Duration multiplier (<1 = faster). Cartel Fast Track = 0.80."""
    return 0.80 if _active(state, 'ct_fast') else 1.0


def territory_action_bonus(state) -> float:
    """Additive territory success bonus. Cartel Expansion = +0.15."""
    return 0.15 if _active(state, 'ct_expand') else 0.0


def district_income_mult(state) -> float:
    """Global income multiplier from Cartel Expansion's district bonus."""
    return 1.12 if _active(state, 'ct_expand') else 1.0


def combat_success_bonus(state) -> float:
    """Additive rival-action success. Warlord Show of Force = +0.20."""
    return 0.20 if _active(state, 'wl_force') else 0.0


def combat_reward_mult(state) -> float:
    """Cash multiplier on attack/sabotage rewards. Warlord Spoils of War = ×1.60."""
    return 1.60 if _active(state, 'wl_spoils') else 1.0


def turf_intimidation_income_mult(state) -> float:
    """Warlord Reign of Terror: +4% income per controlled district, cap +24%."""
    if not _active(state, 'wl_terror'):
        return 1.0
    districts = sum(1 for t in getattr(state, 'territories', [])
                    if getattr(t, 'unlocked', False)
                    and getattr(t, 'owner', '') == 'player')
    return 1.0 + min(0.24, districts * 0.04)


def influence_gain_mult(state) -> float:
    """Consigliere Silver Tongue (×1.25) and Puppet Master (×1.50)."""
    m = 1.0
    if _active(state, 'cs_tongue'):
        m *= 1.25
    if _active(state, 'cs_puppet'):
        m *= 1.50
    return m


def heat_decay_bonus(state) -> float:
    """Extra heat decay /s. Consigliere Clean Money = 0.10/s."""
    return 0.10 if _active(state, 'cs_clean') else 0.0


def respect_income_mult(state) -> float:
    """Amplifies the Respect→income bonus. Consigliere Favors Owed = ×1.60."""
    return 1.60 if _active(state, 'cs_favors') else 1.0


# ─── Apply / tick ─────────────────────────────────────────────────────────────

def apply_perks(state) -> None:
    """Recompute every flat multiplier/flag the perks control.

    Folds the per-frame income/click/building multipliers into cached state
    attributes (the existing `_perk_*` pattern). Cross-system effects
    (operations, rivals, territory, heat, prestige) read the accessors above on
    demand. Call after loading, prestiging, purchasing, or selecting a branch.
    """
    perks = getattr(state, 'perks_purchased', [])
    state._perk_click_mult  = 1.0
    state._perk_income_mult = 1.0
    perk_bld_mults = [1.0] * len(state.buildings)

    # Legacy universal perks (grandfathered — old saves keep their power).
    for key in perks:
        if key == 'click_power_1':
            state._perk_click_mult  *= 1.10
        elif key == 'income_1':
            state._perk_income_mult *= 1.10
        elif key == 'click_power_2':
            state._perk_click_mult  *= 1.50
        elif key == 'income_2':
            state._perk_income_mult *= 1.25
        elif key == 'empire_bonus':
            state._perk_click_mult  *= 2.0
            state._perk_income_mult *= 2.0
        elif key == 'faster_prog':
            for i in range(len(perk_bld_mults)):
                perk_bld_mults[i] *= 1.20

    # Active branch flat multipliers.
    if _active(state, 'kp_cashflow'):
        state._perk_income_mult *= 1.15
    if _active(state, 'wl_knuckles'):
        state._perk_click_mult *= 1.40
    if _active(state, 'kp_monopoly'):
        for i in range(len(perk_bld_mults)):
            perk_bld_mults[i] *= 1.25

    state._perk_bld_mults = perk_bld_mults
    # Automation flags (read by tick_perk_effects). Kingpin Monopoly auto-buys.
    state._perk_auto_buy     = ('auto_buy' in perks) or _active(state, 'kp_monopoly')
    state._perk_auto_upgrade = ('auto_upgrade' in perks)


def tick_perk_effects(state, dt: float) -> None:
    """Tick permanent automation perks. Called once per frame from PlayingState."""
    if getattr(state, '_perk_auto_buy', False):
        state._perk_autobuy_timer = getattr(state, '_perk_autobuy_timer', 0.0) + dt
        if state._perk_autobuy_timer >= _PERK_AUTO_INTERVAL:
            state._perk_autobuy_timer = 0.0
            try:
                import src.managers as _mgr
                _mgr._auto_buy_best(state)
            except Exception:
                pass

    if getattr(state, '_perk_auto_upgrade', False):
        state._perk_autoupg_timer = getattr(state, '_perk_autoupg_timer', 0.0) + dt
        if state._perk_autoupg_timer >= _PERK_AUTO_INTERVAL:
            state._perk_autoupg_timer = 0.0
            _auto_buy_upgrade(state)


def _auto_buy_upgrade(state) -> None:
    """Buy the cheapest affordable, not-yet-purchased upgrade (The Machine)."""
    import src.upgrades as _upg
    candidates = [u for u in getattr(state, 'upgrades', [])
                  if not u.purchased and state.balance >= _upg._effective_cost(u, state)]
    if not candidates:
        return
    best = min(candidates, key=lambda u: _upg._effective_cost(u, state))
    cost = _upg._effective_cost(best, state)
    state.balance -= cost
    best.purchased = True
    best.apply(state)
    try:
        import src.ui as _ui
        import src.theme as _t
        _ui.push_notification(f"Auto-upgrade: {best.name}", _t.GREEN)
    except Exception:
        pass


# ─── PrestigeTreeState (UI) ─────────────────────────────────────────────────

class PrestigeTreeState:
    """Full-screen branching prestige tree with a path-commitment selector."""

    _PANEL = pygame.Rect(60, 60, config.SCREEN_WIDTH - 120, config.SCREEN_HEIGHT - 120)

    def __init__(self, state_manager, playing):
        self.state_manager = state_manager
        self._playing = playing
        self._fonts = playing._fonts
        self._confirm = False
        self._scroll = 0
        self._pending_branch = None   # branch awaiting commit confirmation
        self._hovered_perk = None
        self._first_visit = not getattr(playing, '_shown_prestige_tree_tutorial', False)
        playing._shown_prestige_tree_tutorial = True
        cx = self._PANEL.centerx
        bot = self._PANEL.bottom - 18
        self._back_r     = pygame.Rect(cx - 230, bot - 38, 140, 38)
        self._patron_r   = pygame.Rect(cx - 70,  bot - 38, 140, 38)
        self._prestige_r = pygame.Rect(cx + 90,  bot - 38, 140, 38)
        self._branch_rects: dict[str, pygame.Rect] = {}
        self._perk_btn_rects: list[tuple[pygame.Rect, str]] = []

    def on_enter(self): pass
    def on_exit(self):  pass

    def handle_events(self, events):
        for ev in events:
            if ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE:
                    if self._pending_branch:
                        self._pending_branch = None
                    elif self._confirm:
                        self._confirm = False
                    else:
                        self.state_manager.pop()
                elif ev.key in (pygame.K_RETURN, pygame.K_SPACE) and self._confirm:
                    self._do_prestige()
            elif ev.type == pygame.MOUSEWHEEL:
                self._scroll = max(0, self._scroll - ev.y * 20)
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                self._handle_click(ev.pos)

    def _do_prestige(self):
        try:
            sound.play('prestige')
            prestige.PrestigeManager.execute(self._playing)
        except Exception:
            import traceback
            traceback.print_exc()
        finally:
            self._confirm = False
            if self.state_manager.current is self:
                self.state_manager.pop()

    def _handle_click(self, pos):
        # Branch commit confirmation dialog takes priority.
        if self._pending_branch:
            cx = self._PANEL.centerx
            cy = config.SCREEN_HEIGHT // 2
            yes_r = pygame.Rect(cx - 110, cy + 40, 100, 42)
            no_r  = pygame.Rect(cx + 10,  cy + 40, 100, 42)
            if yes_r.collidepoint(pos):
                if select_branch(self._playing, self._pending_branch):
                    apply_perks(self._playing)
                    sound.play('purchase')
                self._pending_branch = None
            elif no_r.collidepoint(pos):
                self._pending_branch = None
            return

        if self._confirm:
            cx = self._PANEL.centerx
            cy = config.SCREEN_HEIGHT // 2
            yes_r = pygame.Rect(cx - 110, cy + 80, 100, 42)
            no_r  = pygame.Rect(cx + 10,  cy + 80, 100, 42)
            if yes_r.collidepoint(pos):
                self._do_prestige()
            elif no_r.collidepoint(pos):
                self._confirm = False
            return

        if self._back_r.collidepoint(pos):
            self.state_manager.pop()
            return

        if self._patron_r.collidepoint(pos):
            from src.dragon import DragonPatronState
            self.state_manager.push(DragonPatronState(self.state_manager, self._playing))
            return

        if self._prestige_r.collidepoint(pos) and prestige.can_prestige(self._playing):
            self._confirm = True
            return

        # Branch selector buttons (only actionable when nothing is committed).
        committed = getattr(self._playing, 'prestige_branch', None)
        if committed is None:
            for br, rect in self._branch_rects.items():
                if rect.collidepoint(pos):
                    self._pending_branch = br
                    return

        # Perk buy buttons (active branch only).
        for btn, key in self._perk_btn_rects:
            if btn.collidepoint(pos):
                ok, _reason = can_buy_perk(self._playing, key)
                if ok:
                    self._playing.prestige_tokens -= PERK_COST[key]
                    self._playing.perks_purchased.append(key)
                    apply_perks(self._playing)
                    sound.play('purchase')
                return

    def update(self, dt):
        pass

    # ── Drawing ────────────────────────────────────────────────────────────────

    def draw(self, surface):
        self._playing.draw(surface)

        ov = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
        ov.fill((*theme.OVERLAY_DARK, 215))
        surface.blit(ov, (0, 0))

        p = self._PANEL
        pygame.draw.rect(surface, theme.BG_PANEL, p, border_radius=14)
        pygame.draw.rect(surface, theme.PURPLE_BRIGHT, p, border_radius=14, width=2)

        title = self._fonts['lg'].render("PRESTIGE TREE", True, theme.PRESTIGE_LABEL)
        surface.blit(title, title.get_rect(center=(p.centerx, p.top + 28)))

        inf = self._playing.prestige_tokens
        tok_s = self._fonts['sm'].render(f"Influence: {inf}", True, theme.ACCENT)
        surface.blit(tok_s, tok_s.get_rect(center=(p.centerx, p.top + 54)))

        content_rect = pygame.Rect(p.x + 4, p.top + 76, p.width - 8, p.height - 130)
        old_clip = surface.get_clip()
        surface.set_clip(content_rect)
        self._draw_branches(surface, content_rect)
        surface.set_clip(old_clip)

        if self._hovered_perk:
            self._draw_perk_detail(surface)
        elif self._first_visit and getattr(self._playing, 'prestige_branch', None) is None:
            self._draw_first_visit_banner(surface)

        if not prestige.can_prestige(self._playing):
            self._draw_locked_strip(surface)

        can_p = prestige.can_prestige(self._playing)
        mx, my = pygame.mouse.get_pos()
        # Patron button colour: tinted by active dragon if chosen
        try:
            import src.dragon as _dragon
            _cur = _dragon.active_dragon(self._playing)
            _patron_col = _dragon.DRAGON_META[_cur]['color'] if _cur else theme.BG_CARD
        except Exception:
            _patron_col = theme.BG_CARD
        for rect, label, color in [
            (self._back_r,     "Back",        theme.BG_CARD),
            (self._patron_r,   "Patron",      _patron_col),
            (self._prestige_r, "PRESTIGE",    theme.PURPLE_DEEP if can_p else (40, 35, 55)),
        ]:
            clickable = (label in ("Back", "Patron")) or can_p
            hover = rect.collidepoint(mx, my) and clickable
            c = tuple(min(255, v + 30) for v in color) if hover else color
            pygame.draw.rect(surface, c, rect, border_radius=8)
            if label == "Back":
                border_c = theme.ACCENT_DIM
            elif label == "Patron":
                border_c = _patron_col if _patron_col != theme.BG_CARD else theme.ACCENT_DIM
            else:
                border_c = theme.PURPLE_BRIGHT if can_p else (70, 60, 90)
            pygame.draw.rect(surface, border_c, rect, border_radius=8, width=1)
            tc = theme.PRESTIGE_LABEL if (label == "PRESTIGE" and can_p) else theme.TEXT_PRIMARY
            if label == "PRESTIGE" and not can_p:
                tc = (90, 80, 110)
            ls = self._fonts['sm'].render(label, True, tc)
            surface.blit(ls, ls.get_rect(center=rect.center))

        hint_s = self._fonts['xs'].render("ESC: back  |  Enter: confirm prestige", True, theme.TEXT_MUTED)
        surface.blit(hint_s, hint_s.get_rect(center=(p.centerx, p.bottom - 8)))

        if self._pending_branch:
            self._draw_branch_confirm(surface)
        elif self._confirm:
            self._draw_confirm(surface)

    def _draw_branches(self, surface, content_rect):
        self._branch_rects = {}
        self._perk_btn_rects = []
        self._hovered_perk = None
        mx, my = pygame.mouse.get_pos()
        committed = getattr(self._playing, 'prestige_branch', None)

        top = content_rect.top + 6 - self._scroll

        # Path prompt
        if committed is None:
            prompt = self._fonts['sm'].render(
                "Choose your path — permanent until your next prestige", True, theme.TEXT_GOLD)
        else:
            meta = BRANCH_META[committed]
            prompt = self._fonts['sm'].render(
                f"Path: {meta['name']} — {meta['tag']}  (locked this cycle)",
                True, meta['color'])
        surface.blit(prompt, prompt.get_rect(center=(content_rect.centerx, top + 8)))

        # Branch selector buttons — 4 across.
        btn_w = (content_rect.width - 5 * 10) // 4
        btn_h = 54
        bx = content_rect.x + 10
        by = top + 24
        for br in BRANCH_ORDER:
            meta = BRANCH_META[br]
            rect = pygame.Rect(bx, by, btn_w, btn_h)
            self._branch_rects[br] = rect
            is_committed = (committed == br)
            is_lockedout = (committed is not None and not is_committed)
            hover = rect.collidepoint(mx, my)
            if is_committed:
                bg = tuple(int(v * 0.4) for v in meta['color'])
                border = meta['color']
            elif is_lockedout:
                bg = (26, 24, 34)
                border = (55, 52, 66)
            else:
                bg = tuple(int(v * 0.30) for v in meta['color']) if hover else (32, 30, 42)
                border = meta['color']
            pygame.draw.rect(surface, bg, rect, border_radius=9)
            pygame.draw.rect(surface, border, rect, border_radius=9, width=2 if is_committed else 1)
            name_col = meta['color'] if not is_lockedout else (90, 86, 104)
            ns = self._fonts['sm'].render(meta['name'], True, name_col)
            surface.blit(ns, ns.get_rect(centerx=rect.centerx, y=rect.y + 6))
            owned = branch_perk_count(self._playing, br)
            sub = f"{owned}/4 perks" if (is_committed or owned) else meta['short']
            ss = self._fonts['xs'].render(sub, True, theme.TEXT_MUTED)
            surface.blit(ss, ss.get_rect(centerx=rect.centerx, y=rect.y + 28))
            if is_committed:
                tag = self._fonts['xs'].render("ACTIVE", True, meta['color'])
                surface.blit(tag, tag.get_rect(centerx=rect.centerx, y=rect.y + 40))
            elif is_lockedout:
                tag = self._fonts['xs'].render("locked", True, (90, 86, 104))
                surface.blit(tag, tag.get_rect(centerx=rect.centerx, y=rect.y + 40))
            bx += btn_w + 10

        perk_top = by + btn_h + 16

        if committed is None:
            # Show each branch's theme blurb so the player can choose informed.
            yy = perk_top + 6
            for br in BRANCH_ORDER:
                meta = BRANCH_META[br]
                ds = self._fonts['xs'].render(f"{meta['name']}: {meta['blurb']}", True, theme.TEXT_MUTED)
                surface.blit(ds, (content_rect.x + 16, yy))
                yy += 22
            return

        # Active branch's 4 perks in a 2×2 grid (reading order = tier order).
        self._draw_active_perks(surface, content_rect, committed, perk_top)

    def _draw_active_perks(self, surface, content_rect, branch, perk_top):
        mx, my = pygame.mouse.get_pos()
        perks = BRANCH_PERKS[branch]
        meta = BRANCH_META[branch]
        total_w = _COLS * _CARD_W + (_COLS - 1) * _GAP_X
        start_x = content_rect.centerx - total_w // 2
        owned_perks = getattr(self._playing, 'perks_purchased', [])
        influence = self._playing.prestige_tokens

        for i, (key, name, cost, eff, tier) in enumerate(perks):
            col = i % _COLS
            row = i // _COLS
            cr = pygame.Rect(start_x + col * (_CARD_W + _GAP_X),
                             perk_top + row * (_CARD_H + _GAP_Y), _CARD_W, _CARD_H)
            owned = key in owned_perks
            unlocked = branch_tier_unlocked(self._playing, branch, tier)
            can, reason = can_buy_perk(self._playing, key)
            hover = cr.collidepoint(mx, my)
            if hover and unlocked:
                self._hovered_perk = (name, PERK_DETAILS.get(key, eff), owned, cost)

            if owned:
                bg, border = tuple(int(v * 0.35) for v in meta['color']), meta['color']
            elif not unlocked:
                bg, border = (22, 20, 32), (45, 42, 60)
            elif can:
                bg = theme.BG_CARD_HOVER if hover else theme.BG_CARD
                border = meta['color']
            else:
                bg, border = theme.BG_DARK, theme.BG_CARD
            pygame.draw.rect(surface, bg, cr, border_radius=10)
            pygame.draw.rect(surface, border, cr, border_radius=10, width=1)

            tier_s = self._fonts['xs'].render(f"TIER {tier}", True, theme.TEXT_MUTED)
            surface.blit(tier_s, (cr.x + 8, cr.y + 6))
            tc = theme.TEXT_PRIMARY if (owned or can) else theme.TEXT_MUTED
            ns = self._fonts['sm'].render(name, True, tc)
            surface.blit(ns, (cr.x + 8, cr.y + 20))
            es = self._fonts['xs'].render(eff, True, theme.GREEN if owned else theme.TEXT_MUTED)
            surface.blit(es, (cr.x + 8, cr.y + 42))

            btn = pygame.Rect(cr.x + 8, cr.bottom - 28, cr.width - 16, 22)
            if owned:
                pygame.draw.rect(surface, theme.BTN_YES, btn, border_radius=6)
                bl = self._fonts['xs'].render("Owned", True, theme.TEXT_PRIMARY)
            elif not unlocked:
                pygame.draw.rect(surface, (30, 28, 45), btn, border_radius=6)
                bl = self._fonts['xs'].render("LOCKED", True, (70, 65, 90))
            elif can:
                self._perk_btn_rects.append((btn, key))
                hbtn = btn.collidepoint(mx, my)
                bcol = tuple(min(255, v + 20) for v in theme.ACCENT) if hbtn else theme.ACCENT
                pygame.draw.rect(surface, bcol, btn, border_radius=6)
                bl = self._fonts['xs'].render(f"Buy ({cost} inf)", True, theme.BG_DARK)
            else:
                pygame.draw.rect(surface, theme.BTN_DISABLED, btn, border_radius=6)
                bl = self._fonts['xs'].render(reason or f"Need {cost} inf", True, theme.TEXT_MUTED)
            surface.blit(bl, bl.get_rect(center=btn.center))

    def _draw_branch_confirm(self, surface):
        from src.ui import draw_overlay
        draw_overlay(surface, 210)
        cx = self._PANEL.centerx
        cy = config.SCREEN_HEIGHT // 2
        meta = BRANCH_META[self._pending_branch]
        panel = pygame.Rect(cx - 240, cy - 110, 480, 230)
        pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=14)
        pygame.draw.rect(surface, meta['color'], panel, border_radius=14, width=2)
        ts = self._fonts['lg'].render(f"Commit: {meta['name']}?", True, meta['color'])
        surface.blit(ts, ts.get_rect(center=(cx, cy - 78)))
        for i, ln in enumerate([
                meta['tag'],
                meta['blurb'],
                "This path is LOCKED until your next prestige.",
                "Other branches' perks stay inactive this cycle."]):
            col = theme.TEXT_PRIMARY if i < 2 else theme.TEXT_MUTED
            s = self._fonts['xs'].render(ln, True, col)
            surface.blit(s, s.get_rect(center=(cx, cy - 44 + i * 18)))
        yes_r = pygame.Rect(cx - 110, cy + 40, 100, 42)
        no_r  = pygame.Rect(cx + 10,  cy + 40, 100, 42)
        mx, my = pygame.mouse.get_pos()
        yc = tuple(min(255, v + 20) for v in theme.BTN_YES) if yes_r.collidepoint(mx, my) else theme.BTN_YES
        nc = tuple(min(255, v + 20) for v in theme.BTN_NO)  if no_r.collidepoint(mx, my)  else theme.BTN_NO
        pygame.draw.rect(surface, yc, yes_r, border_radius=8)
        pygame.draw.rect(surface, nc, no_r, border_radius=8)
        surface.blit(self._fonts['sm'].render("Commit", True, theme.TEXT_PRIMARY),
                     self._fonts['sm'].render("Commit", True, theme.TEXT_PRIMARY).get_rect(center=yes_r.center))
        surface.blit(self._fonts['sm'].render("Cancel", True, theme.TEXT_PRIMARY),
                     self._fonts['sm'].render("Cancel", True, theme.TEXT_PRIMARY).get_rect(center=no_r.center))

    def _draw_first_visit_banner(self, surface: pygame.Surface):
        p = self._PANEL
        lines = [
            "Prestiging resets your run but converts lifetime earnings into Influence.",
            "Spend Influence here on ONE archetype per run: Kingpin (economy), Warlord",
            "(force), Cartel (operations), or Consigliere (influence). Your choice is",
            "locked for the cycle — pick a different path after your next prestige.",
        ]
        pad = 10
        line_h = self._fonts['xs'].get_height() + 3
        box_w = min(580, p.width - 40)
        box_h = 24 + len(lines) * line_h + pad
        bx = p.centerx - box_w // 2
        # Sit in the empty mid-panel band so it never overlaps the locked strip.
        by = p.top + 320
        bg = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
        pygame.draw.rect(bg, (16, 20, 34, 240), bg.get_rect(), border_radius=10)
        pygame.draw.rect(bg, (*theme.ACCENT, 200), bg.get_rect(), border_radius=10, width=1)
        surface.blit(bg, (bx, by))
        hs = self._fonts['sm'].render("HOW THE PRESTIGE TREE WORKS", True, theme.TEXT_GOLD)
        surface.blit(hs, (bx + pad, by + 6))
        cy = by + 26
        for ln in lines:
            ls = self._fonts['xs'].render(ln, True, theme.TEXT_MUTED)
            surface.blit(ls, (bx + pad, cy))
            cy += line_h

    def _draw_perk_detail(self, surface: pygame.Surface):
        hp = self._hovered_perk
        if not hp:
            return
        name, detail, owned, cost = hp
        p = self._PANEL
        pad = 10
        box_w = min(420, p.width - 40)
        words = detail.split()
        lines: list[str] = []
        cur = ""
        for w in words:
            test = (cur + " " + w).strip()
            if self._fonts['xs'].size(test)[0] <= box_w - pad * 2:
                cur = test
            else:
                if cur:
                    lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        line_h = self._fonts['xs'].get_height() + 2
        box_h = 26 + len(lines) * line_h + pad
        bx = p.centerx - box_w // 2
        by = p.bottom - 56 - box_h
        box = pygame.Rect(bx, by, box_w, box_h)
        bg = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
        pygame.draw.rect(bg, (16, 14, 28, 240), bg.get_rect(), border_radius=10)
        pygame.draw.rect(bg, (*theme.PURPLE_BRIGHT, 200), bg.get_rect(), border_radius=10, width=1)
        surface.blit(bg, box.topleft)
        status = "OWNED" if owned else f"Cost: {cost} Influence"
        status_col = theme.GREEN if owned else theme.TEXT_GOLD
        ns = self._fonts['sm'].render(name, True, theme.TEXT_PRIMARY)
        surface.blit(ns, (bx + pad, by + 6))
        st = self._fonts['xs'].render(status, True, status_col)
        surface.blit(st, st.get_rect(topright=(box.right - pad, by + 9)))
        cy = by + 26
        for ln in lines:
            ls = self._fonts['xs'].render(ln, True, theme.TEXT_MUTED)
            surface.blit(ls, (bx + pad, cy))
            cy += line_h

    def _draw_locked_strip(self, surface: pygame.Surface):
        """Compact 1–2 line prestige-locked status above the action buttons.

        Replaces the old large requirements panel, which collided with the
        branch selector. Shows the earnings gate (always) plus the first-prestige
        teaching gates (building counts + rank) when they apply.
        """
        p = self._PANEL
        reqs = prestige.check_requirements(self._playing)
        cur, req, _met = reqs['earnings']
        gain = prestige.calc_influence_gain(self._playing.lifetime_earnings)
        gain_info = f"     (+{gain} Influence at prestige)" if gain > 0 else ""
        line1 = (f"PRESTIGE LOCKED   —   Lifetime ${_fmt(float(cur))} / ${_fmt(float(req))}"
                 + gain_info)
        parts2 = []
        for key, label in (('dealers', 'Dealers'), ('rackets', 'Rackets'),
                           ('chops', 'Chops')):
            if key in reqs:
                c, r, _ = reqs[key]
                parts2.append(f"{label} {int(c)}/{int(r)}")
        if 'rank' in reqs:
            _, rr, _ = reqs['rank']
            parts2.append(f"Rank: {rr}")
        y = self._back_r.top - 16
        s1 = self._fonts['xs'].render(line1, True, (200, 120, 255))
        surface.blit(s1, s1.get_rect(center=(p.centerx, y)))
        if parts2:
            s2 = self._fonts['xs'].render("   •   ".join(parts2), True, theme.TEXT_MUTED)
            surface.blit(s2, s2.get_rect(center=(p.centerx, y + 16)))

    def _draw_confirm(self, surface: pygame.Surface):
        from src.ui import draw_overlay
        draw_overlay(surface, 210)
        cx = self._PANEL.centerx
        cy = config.SCREEN_HEIGHT // 2
        gain = prestige.calc_influence_gain(self._playing.lifetime_earnings)
        rank_after = prestige.get_rank(self._playing.prestige_tokens + gain)
        next_thresh = prestige.next_influence_threshold(self._playing.prestige_tokens + gain)
        panel = pygame.Rect(cx - 260, cy - 185, 520, 380)
        pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=14)
        pygame.draw.rect(surface, theme.PURPLE_BRIGHT, panel, border_radius=14, width=2)
        ts = self._fonts['lg'].render("PRESTIGE?", True, theme.TEXT_GOLD)
        surface.blit(ts, ts.get_rect(center=(cx, cy - 155)))
        reset_lines = [
            ("RESETS:", theme.TEXT_MUTED),
            ("  • Current balance", theme.TEXT_MUTED),
            ("  • All buildings owned", theme.TEXT_MUTED),
            ("  • All upgrades purchased", theme.TEXT_MUTED),
            ("  • Prestige path (re-choose)", theme.TEXT_MUTED),
        ]
        kept_lines = [
            ("KEPT:", theme.TEXT_MUTED),
            ("  • Lifetime earnings", theme.GREEN),
            ("  • Influence & perks", theme.GREEN),
            ("  • Achievements", theme.GREEN),
        ]
        y = cy - 108
        for text, col in reset_lines:
            s = self._fonts['xs'].render(text, True, col if text != "RESETS:" else (220, 100, 100))
            surface.blit(s, (cx - 240, y))
            y += 16
        y = cy - 108
        for text, col in kept_lines:
            s = self._fonts['xs'].render(text, True, col if text != "KEPT:" else (100, 220, 100))
            surface.blit(s, (cx + 20, y))
            y += 16
        sep = pygame.Surface((460, 1), pygame.SRCALPHA)
        sep.fill((*theme.ACCENT_DIM, 80))
        surface.blit(sep, (cx - 230, cy - 36))
        ig_s = self._fonts['sm'].render(f"Influence Gain:  +{gain}", True, (180, 120, 255))
        surface.blit(ig_s, ig_s.get_rect(center=(cx, cy - 16)))
        rank_s = self._fonts['xs'].render(f"New rank: {rank_after}", True, theme.PRESTIGE_LABEL)
        surface.blit(rank_s, rank_s.get_rect(center=(cx, cy + 8)))
        bonus_s = self._fonts['xs'].render(
            f"Income bonus after: ×{prestige.income_mult(self._playing.prestige_tokens + gain):.2f}",
            True, theme.TEXT_MUTED)
        surface.blit(bonus_s, bonus_s.get_rect(center=(cx, cy + 28)))
        next_s = self._fonts['xs'].render(
            f"Next influence at: ${_fmt(next_thresh)} lifetime", True, theme.TEXT_MUTED)
        surface.blit(next_s, next_s.get_rect(center=(cx, cy + 48)))
        yes_r = pygame.Rect(cx - 115, cy + 80, 105, 44)
        no_r  = pygame.Rect(cx + 10,  cy + 80, 105, 44)
        mx2, my2 = pygame.mouse.get_pos()
        yes_col = tuple(min(255, v + 20) for v in theme.BTN_YES) if yes_r.collidepoint(mx2, my2) else theme.BTN_YES
        no_col  = tuple(min(255, v + 20) for v in theme.BTN_NO)  if no_r.collidepoint(mx2, my2)  else theme.BTN_NO
        pygame.draw.rect(surface, yes_col, yes_r, border_radius=8)
        pygame.draw.rect(surface, no_col,  no_r,  border_radius=8)
        ys = self._fonts['md'].render("PRESTIGE", True, theme.TEXT_PRIMARY)
        ns = self._fonts['md'].render("Cancel",   True, theme.TEXT_PRIMARY)
        surface.blit(ys, ys.get_rect(center=yes_r.center))
        surface.blit(ns, ns.get_rect(center=no_r.center))
        hint = self._fonts['xs'].render("Enter = PRESTIGE  |  ESC = Cancel", True, theme.TEXT_MUTED)
        surface.blit(hint, hint.get_rect(center=(cx, no_r.bottom + 14)))


def _fmt(n: float) -> str:
    import src.theme as _t
    return _t.format_number(n)
