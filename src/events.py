"""Syndicate Events — random choice events every few minutes."""
from __future__ import annotations
import random
from dataclasses import dataclass, field
from typing import List, Callable

import pygame
import src.theme as theme
import src.scale as scale
import config

_EVENT_INTERVAL_MIN = 180.0   # 3 minutes minimum between events
_EVENT_INTERVAL_MAX = 360.0   # 6 minutes maximum

_OUTCOME_DURATION   = 3.5     # seconds the outcome popup is visible


@dataclass
class SyndicateEvent:
    title: str
    description: str
    choices: list[dict]     # [{'label': str, 'action': callable, 'desc': str}]


def _income_bonus(state, multiplier: float, seconds: float):
    state._add_buff(f'syndicate_bonus_{int(multiplier*100)}', seconds)
    # We piggyback on frenzy-style buffs; store a generic income mult buff
    state._buffs.append({'name': 'syndicate_income', 'remaining': seconds,
                         'total': seconds, 'mult': multiplier})


def _gain_cash(state, amount_fn: Callable):
    amount = amount_fn(state)
    state.balance += amount
    state.lifetime_earnings += amount
    import src.money_debug as _md
    _md.credit(state, amount, 'money_from_other')
    return amount


def _reduce_heat(state, amount: float):
    state.heat = max(0.0, getattr(state, 'heat', 0.0) - amount)


_EVENT_POOL: list[tuple] = [
    # (title, description, choices_list)
    # Each choice: (label, desc, action_key, action_arg)
    ("Rival Gang Warehouse",
     "A rival crew abandoned a warehouse on the edge of your territory.",
     [
         ("Take by Force",   "High risk. +15% income for 2 min but +10 heat.",   'warehouse_force'),
         ("Bribe Officials", "Safe. +8% income for 90s, -5 heat.",                'warehouse_bribe'),
         ("Ignore It",       "Nothing gained, nothing lost.",                      'ignore'),
     ]),

    ("Undercover Cop",
     "Your crew spotted a cop trying to infiltrate operations.",
     [
         ("Expose & Scare",  "+cash equal to 30s income, -8 heat.",               'cop_expose'),
         ("Put on Payroll",  "Expensive. -5% balance but -15 heat permanently.",   'cop_payroll'),
         ("Ignore It",       "He stays. Heat keeps climbing.",                     'ignore'),
     ]),

    ("Black Market Auction",
     "Rare goods up for bid — could double returns on a building.",
     [
         ("Bid High",        "Costs 5% of balance. +25% income for 3 min.",       'auction_bid'),
         ("Watch & Wait",    "+10% income for 1 min, free.",                       'auction_watch'),
         ("Ignore It",       "The lot goes to a rival.",                           'ignore'),
     ]),

    ("Shipment Opportunity",
     "A contact offers a one-time smuggling route — fast cash.",
     [
         ("Take the Deal",   "+cash equal to 2 min income. +12 heat.",             'ship_take'),
         ("Negotiate Down",  "+cash equal to 60s income. +4 heat.",                'ship_negotiate'),
         ("Ignore It",       "The contact moves on.",                              'ignore'),
     ]),

    ("Politician Needs a Favor",
     "A city councilman wants something done quietly.",
     [
         ("Help Him",        "-10% balance, but unlock -20 heat reduction.",       'politician_help'),
         ("Threaten Him",    "Free. +20% income 90s but +8 heat.",                 'politician_threaten'),
         ("Ignore It",       "He goes elsewhere.",                                 'ignore'),
     ]),

    ("Street War Brewing",
     "A rival gang is muscling into your territory.",
     [
         ("Crush Them",      "+10% income 3 min, +15 heat.",                       'war_crush'),
         ("Pay Them Off",    "-8% balance, -10 heat, peace for now.",              'war_pay'),
         ("Ignore It",       "They take a sliver of income.",                      'war_ignore'),
     ]),

    # ── Blackwater Mob faction events — only spawn when Blackwater is active ──
    ("The Tide Comes In",
     "Blackwater Mob coordinates a major smuggling run through your territory.",
     [
         ("Intercept",       "+cash equal to 90s income, +18 heat.",               'bw_intercept'),
         ("Let It Run",      "Blackwater grows wealthier. Nothing gained.",        'ignore'),
         ("Exploit the Run", "+cash equal to 45s income, +6 heat, -5 op cost.",    'bw_exploit'),
     ],
     'blackwater'),

    ("Crab Trap",
     "The Blackwater Mob fortifies a harbor district. It will be harder to capture.",
     [
         ("Storm It Now",    "+15% attack success vs Blackwater for 3 min, +12 heat.", 'bw_storm'),
         ("Bribe the Dockmaster", "-8% balance, Blackwater loses 1 turf.",         'bw_bribe_dock'),
         ("Ignore It",       "The district hardens. Your next capture costs +20%.", 'ignore'),
     ],
     'blackwater'),

    ("The Harbor Burns",
     "A shipping conflict erupts between Blackwater and the Iron Union. Both are weakened.",
     [
         ("Side with Blackwater", "+15% op rewards 3 min. Blackwater gains turf.",  'bw_side_black'),
         ("Side with Iron Union", "+10% income 3 min. Iron Union gains turf.",      'bw_side_iron'),
         ("Stay Out",             "Both factions lose power. Neither gains.",        'bw_stay_out'),
     ],
     'blackwater'),

    ("Salt Water Warning",
     "A Blackwater Mob lieutenant delivers a message outside your front office.",
     [
         ("Send Them Back",   "+8 heat. Blackwater becomes more aggressive.",       'bw_send_back'),
         ("Listen",           "-10 heat. Negotiate success +15% for 2 min.",        'bw_listen'),
         ("Ignore It",        "Blackwater claims an unclaimed industrial district.", 'bw_ignore_warn'),
     ],
     'blackwater'),

    ("The Dockmaster's Deal",
     "Blackwater offers a smuggling partnership — cuts through red tape, strings attached.",
     [
         ("Take the Deal",   "+20% op income 3 min. Blackwater gains +5 power.",   'bw_take_deal'),
         ("Counter-Offer",   "+1 Influence, Blackwater steps back from one district.", 'bw_counter'),
         ("Refuse",          "Nothing gained, nothing lost.",                       'ignore'),
     ],
     'blackwater'),
]


def _apply_action(state, action_key: str) -> str:
    """Apply the chosen action. Returns outcome description string."""
    ips = state.income_per_second

    if action_key == 'ignore' or action_key == 'war_ignore':
        if action_key == 'war_ignore':
            import src.ui as _ui
            import src.theme as _theme
            _ui.push_notification("Rival crew takes a cut...", _theme.TEXT_MUTED)
        return "You let it pass."

    if action_key == 'warehouse_force':
        state._add_buff('syndicate_income', 120.0)
        state._buffs[-1]['mult'] = 1.15
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + 10.0)
        return "+15% income 2min, +10 heat"

    if action_key == 'warehouse_bribe':
        state._add_buff('syndicate_income', 90.0)
        state._buffs[-1]['mult'] = 1.08
        state.heat = max(0.0, getattr(state, 'heat', 0.0) - 5.0)
        return "+8% income 90s, -5 heat"

    if action_key == 'cop_expose':
        gain = ips * 30.0
        state.balance += gain
        state.lifetime_earnings += gain
        import src.money_debug as _md
        _md.credit(state, gain, 'money_from_other')
        state.heat = max(0.0, getattr(state, 'heat', 0.0) - 8.0)
        return f"+{gain:,.0f} cash, -8 heat"

    if action_key == 'cop_payroll':
        cost = state.balance * 0.05
        state.balance = max(0.0, state.balance - cost)
        state.heat = max(0.0, getattr(state, 'heat', 0.0) - 15.0)
        return f"-{cost:,.0f} balance, -15 heat permanently"

    if action_key == 'auction_bid':
        cost = state.balance * 0.05
        state.balance = max(0.0, state.balance - cost)
        state._add_buff('syndicate_income', 180.0)
        state._buffs[-1]['mult'] = 1.25
        return f"-{cost:,.0f} balance, +25% income 3min"

    if action_key == 'auction_watch':
        state._add_buff('syndicate_income', 60.0)
        state._buffs[-1]['mult'] = 1.10
        return "+10% income 1min"

    if action_key == 'ship_take':
        gain = ips * 120.0
        state.balance += gain
        state.lifetime_earnings += gain
        import src.money_debug as _md
        _md.credit(state, gain, 'money_from_other')
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + 12.0)
        return f"+{gain:,.0f} cash, +12 heat"

    if action_key == 'ship_negotiate':
        gain = ips * 60.0
        state.balance += gain
        state.lifetime_earnings += gain
        import src.money_debug as _md
        _md.credit(state, gain, 'money_from_other')
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + 4.0)
        return f"+{gain:,.0f} cash, +4 heat"

    if action_key == 'politician_help':
        cost = state.balance * 0.10
        state.balance = max(0.0, state.balance - cost)
        state.heat = max(0.0, getattr(state, 'heat', 0.0) - 20.0)
        return f"-{cost:,.0f} balance, -20 heat"

    if action_key == 'politician_threaten':
        state._add_buff('syndicate_income', 90.0)
        state._buffs[-1]['mult'] = 1.20
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + 8.0)
        return "+20% income 90s, +8 heat"

    if action_key == 'war_crush':
        state._add_buff('syndicate_income', 180.0)
        state._buffs[-1]['mult'] = 1.10
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + 15.0)
        return "+10% income 3min, +15 heat"

    if action_key == 'war_pay':
        cost = state.balance * 0.08
        state.balance = max(0.0, state.balance - cost)
        state.heat = max(0.0, getattr(state, 'heat', 0.0) - 10.0)
        return f"-{cost:,.0f} balance, -10 heat"

    # ── Blackwater Mob event actions ─────────────────────────────────────────
    if action_key == 'bw_intercept':
        gain = ips * 90.0
        state.balance += gain
        state.lifetime_earnings += gain
        import src.money_debug as _md
        _md.credit(state, gain, 'money_from_other')
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + 18.0)
        return f"+{gain:,.0f} cash, +18 heat"

    if action_key == 'bw_exploit':
        gain = ips * 45.0
        state.balance += gain
        state.lifetime_earnings += gain
        import src.money_debug as _md
        _md.credit(state, gain, 'money_from_other')
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + 6.0)
        state._add_buff('bw_op_exploit', 60.0)
        state._buffs[-1]['mult'] = 1.08
        return f"+{gain:,.0f} cash, +6 heat, +8% op income 1 min"

    if action_key == 'bw_storm':
        state._add_buff('bw_storm', 180.0)
        state._buffs[-1]['mult'] = 1.0  # placeholder; rivals.py checks this flag
        state._bw_attack_bonus = getattr(state, '_bw_attack_bonus', 0.0) + 0.15
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + 12.0)
        return "+15% attack vs Blackwater 3 min, +12 heat"

    if action_key == 'bw_bribe_dock':
        cost = state.balance * 0.08
        state.balance = max(0.0, state.balance - cost)
        try:
            rivals = getattr(state, 'rivals', []) or []
            bw = next((r for r in rivals
                       if getattr(r, 'faction_key', '') == 'blackwater'
                       and r.status != 'Eliminated'), None)
            if bw:
                bw.turf   = max(0, bw.turf - 1)
                bw.wealth = max(0.0, bw.wealth - 500_000.0)
        except Exception:
            pass
        return f"-{cost:,.0f} balance, Blackwater loses 1 turf"

    if action_key == 'bw_side_black':
        state._add_buff('bw_side_black', 180.0)
        state._buffs[-1]['mult'] = 1.15
        try:
            rivals = getattr(state, 'rivals', []) or []
            bw = next((r for r in rivals
                       if getattr(r, 'faction_key', '') == 'blackwater'
                       and r.status != 'Eliminated'), None)
            iu = next((r for r in rivals
                       if getattr(r, 'faction_key', '') == 'iron_union'
                       and r.status != 'Eliminated'), None)
            if bw:
                bw.turf  = min(8, bw.turf + 1)
            if iu:
                iu.power = max(0, iu.power - 8)
        except Exception:
            pass
        return "+15% op rewards 3 min, Blackwater grows"

    if action_key == 'bw_side_iron':
        state._add_buff('bw_side_iron', 180.0)
        state._buffs[-1]['mult'] = 1.10
        try:
            rivals = getattr(state, 'rivals', []) or []
            bw = next((r for r in rivals
                       if getattr(r, 'faction_key', '') == 'blackwater'
                       and r.status != 'Eliminated'), None)
            iu = next((r for r in rivals
                       if getattr(r, 'faction_key', '') == 'iron_union'
                       and r.status != 'Eliminated'), None)
            if bw:
                bw.power = max(0, bw.power - 8)
            if iu:
                iu.turf  = min(8, iu.turf + 1)
        except Exception:
            pass
        return "+10% income 3 min, Iron Union grows"

    if action_key == 'bw_stay_out':
        try:
            rivals = getattr(state, 'rivals', []) or []
            for fkey in ('blackwater', 'iron_union'):
                r = next((x for x in rivals
                          if getattr(x, 'faction_key', '') == fkey
                          and x.status != 'Eliminated'), None)
                if r:
                    r.power  = max(0, r.power - 6)
                    r.wealth = max(0.0, r.wealth - 1_000_000.0)
        except Exception:
            pass
        return "Both factions weakened."

    if action_key == 'bw_send_back':
        state.heat = min(100.0, getattr(state, 'heat', 0.0) + 8.0)
        try:
            rivals = getattr(state, 'rivals', []) or []
            bw = next((r for r in rivals
                       if getattr(r, 'faction_key', '') == 'blackwater'
                       and r.status != 'Eliminated'), None)
            if bw:
                bw.aggression = min(0.95, bw.aggression + 0.10)
        except Exception:
            pass
        return "+8 heat, Blackwater more aggressive"

    if action_key == 'bw_listen':
        state.heat = max(0.0, getattr(state, 'heat', 0.0) - 10.0)
        state._add_buff('bw_negotiate', 120.0)
        state._buffs[-1]['mult'] = 1.0  # flag only; territory.py checks
        state._bw_negotiate_bonus = getattr(state, '_bw_negotiate_bonus', 0.0) + 0.15
        return "-10 heat, +15% negotiate success 2 min"

    if action_key == 'bw_ignore_warn':
        try:
            rivals = getattr(state, 'rivals', []) or []
            bw = next((r for r in rivals
                       if getattr(r, 'faction_key', '') == 'blackwater'
                       and r.status != 'Eliminated'), None)
            if bw:
                import src.territory as _terr
                _terr.rival_claim_preferred(
                    getattr(state, 'territories', []), bw.name,
                    preferred_names=getattr(bw, 'preferred_district_names', []),
                    preferred_types=getattr(bw, 'preferred_district_types', []))
                bw.turf = min(8, bw.turf + 1)
        except Exception:
            pass
        return "Blackwater claims an industrial district."

    if action_key == 'bw_take_deal':
        state._add_buff('bw_deal', 180.0)
        state._buffs[-1]['mult'] = 1.20
        try:
            rivals = getattr(state, 'rivals', []) or []
            bw = next((r for r in rivals
                       if getattr(r, 'faction_key', '') == 'blackwater'
                       and r.status != 'Eliminated'), None)
            if bw:
                bw.power = min(300, bw.power + 5)
        except Exception:
            pass
        return "+20% op income 3 min, Blackwater gains +5 power"

    if action_key == 'bw_counter':
        state.prestige_tokens = getattr(state, 'prestige_tokens', 0) + 1
        try:
            rivals = getattr(state, 'rivals', []) or []
            bw = next((r for r in rivals
                       if getattr(r, 'faction_key', '') == 'blackwater'
                       and r.status != 'Eliminated'), None)
            if bw and bw.turf > 0:
                import src.territory as _terr
                freed = _terr.release_rival_territories(
                    getattr(state, 'territories', []), bw.name)
                if freed:
                    bw.turf = max(0, bw.turf - freed)
        except Exception:
            pass
        return "+1 Influence, Blackwater steps back"

    return "Done."


# ─── State glue ────────────────────────────────────────────────────────────────

def update_events(state, dt: float) -> None:
    """Tick the event timer. Triggers a pending event when ready."""
    timer = getattr(state, '_event_timer', None)
    if timer is None:
        state._event_timer = random.uniform(_EVENT_INTERVAL_MIN, _EVENT_INTERVAL_MAX)
        state._pending_event = None
        state._event_outcome = None
        state._event_outcome_timer = 0.0
        return

    # Outcome display countdown
    if getattr(state, '_event_outcome', None):
        state._event_outcome_timer -= dt
        if state._event_outcome_timer <= 0:
            state._event_outcome = None

    if getattr(state, '_pending_event', None):
        return  # waiting for player choice

    state._event_timer -= dt
    if state._event_timer <= 0:
        _spawn_event(state)


def _active_faction_keys(state) -> set:
    """Return set of faction_key values for non-eliminated rivals."""
    try:
        rivals = getattr(state, 'rivals', []) or []
        return {getattr(r, 'faction_key', '') for r in rivals
                if getattr(r, 'status', '') != 'Eliminated'}
    except Exception:
        return set()


def _spawn_event(state) -> None:
    # Filter pool: faction-specific events (4-tuple) only when that faction is active
    active_keys = _active_faction_keys(state)
    pool = []
    for entry in _EVENT_POOL:
        if len(entry) == 4:
            _, _, _, fkey = entry
            if fkey in active_keys:
                pool.append(entry)
        else:
            pool.append(entry)
    if not pool:
        pool = [e for e in _EVENT_POOL if len(e) == 3]  # generic events only

    entry = random.choice(pool)
    title, desc, choices_raw = entry[0], entry[1], entry[2]
    choices = [{'label': c[0], 'desc': c[1], 'action': c[2]} for c in choices_raw]
    state._pending_event = {'title': title, 'description': desc, 'choices': choices}
    state._event_timer = random.uniform(_EVENT_INTERVAL_MIN, _EVENT_INTERVAL_MAX)
    state._event_is_first = not getattr(state, '_shown_syndicate_tutorial', False)


def resolve_event(state, choice_idx: int) -> None:
    event = getattr(state, '_pending_event', None)
    if not event:
        return
    choices = event['choices']
    if 0 <= choice_idx < len(choices):
        action_key = choices[choice_idx]['action']
        outcome = _apply_action(state, action_key)
        state._event_outcome = f"{choices[choice_idx]['label']}: {outcome}"
        state._event_outcome_timer = _OUTCOME_DURATION
    if getattr(state, '_event_is_first', False):
        state._shown_syndicate_tutorial = True
        state._event_is_first = False
    state._pending_event = None


# ─── UI ────────────────────────────────────────────────────────────────────────

_OVERLAY_W = 480   # design-space base; scaled & clamped at runtime (Phase 92)


def _blit_fit(surface, text_surf, max_w, **rect_kw):
    """Blit text shrunk to fit max_w, positioned by the given Rect kwargs."""
    w = text_surf.get_width()
    if w > max_w > 0:
        f = max_w / w
        text_surf = pygame.transform.smoothscale(
            text_surf, (int(max_w), max(1, int(text_surf.get_height() * f))))
    surface.blit(text_surf, text_surf.get_rect(**rect_kw))


def _event_layout(state, fonts: dict):
    """Single source of truth for the event overlay — panel, text rows and
    button rects. Font-driven height, resolution-scaled width, clamped to the
    screen. Consumed by both draw_event_overlay and handle_event_click so the
    buttons are clickable exactly where they render (Phase 92)."""
    event = getattr(state, '_pending_event', None)
    if not event or not fonts:
        return None
    xs_h = fonts['xs'].get_height()
    sm_h = fonts['sm'].get_height()
    md_h = fonts['md'].get_height()
    pad = scale.sd(16)
    gap = scale.sd(8)
    has_tut = bool(getattr(state, '_event_is_first', False))
    n = len(event['choices'])
    btn_h = sm_h + xs_h + scale.sd(12)
    btn_gap = scale.sd(10)

    content_h = pad + (xs_h + gap) + (md_h + gap) + (xs_h + gap)
    if has_tut:
        content_h += xs_h + gap
    content_h += n * btn_h + (n - 1) * btn_gap + pad

    pw = min(config.SCREEN_WIDTH - 2 * scale.sd(16), scale.sd(_OVERLAY_W))
    ph = min(config.SCREEN_HEIGHT - 2 * scale.sd(16), content_h)
    ox = (config.SCREEN_WIDTH - pw) // 2
    oy = (config.SCREEN_HEIGHT - ph) // 2
    panel = pygame.Rect(ox, oy, pw, ph)

    y = oy + pad
    tag_y = y; y += xs_h + gap
    title_y = y; y += md_h + gap
    desc_y = y; y += xs_h + gap
    tut_y = None
    if has_tut:
        tut_y = y; y += xs_h + gap

    btn_x = ox + scale.sd(20)
    btn_w = pw - 2 * scale.sd(20)
    btns = [pygame.Rect(btn_x, y + i * (btn_h + btn_gap), btn_w, btn_h)
            for i in range(n)]
    return {'panel': panel, 'tag_y': tag_y, 'title_y': title_y, 'desc_y': desc_y,
            'tut_y': tut_y, 'btns': btns, 'inner_w': pw - 2 * scale.sd(20)}


def draw_event_overlay(surface: pygame.Surface, state, fonts: dict) -> None:
    event = getattr(state, '_pending_event', None)
    L = _event_layout(state, fonts)
    if not L:
        return
    panel = L['panel']
    cx = panel.centerx
    inner_w = L['inner_w']

    # Dim background
    dim = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
    dim.fill((0, 0, 0, 170))
    surface.blit(dim, (0, 0))

    # Panel
    panel_surf = pygame.Surface((panel.width, panel.height), pygame.SRCALPHA)
    pygame.draw.rect(panel_surf, (22, 24, 38, 245), panel_surf.get_rect(), border_radius=14)
    pygame.draw.rect(panel_surf, (*theme.ACCENT, 200), panel_surf.get_rect(), border_radius=14, width=2)
    surface.blit(panel_surf, panel.topleft)

    # Header
    tag_s = fonts['xs'].render("OPPORTUNITY", True, theme.ACCENT)
    surface.blit(tag_s, tag_s.get_rect(midtop=(cx, L['tag_y'])))
    title_s = fonts['md'].render(event['title'], True, theme.TEXT_PRIMARY)
    _blit_fit(surface, title_s, inner_w, midtop=(cx, L['title_y']))
    desc_s = fonts['xs'].render(event['description'], True, theme.TEXT_MUTED)
    _blit_fit(surface, desc_s, inner_w, midtop=(cx, L['desc_y']))

    # First-event tutorial line (Part 7) — concise, shown only the first time.
    if L['tut_y'] is not None:
        tut_s = fonts['xs'].render(
            "New: Syndicate Events are one-time choices — weigh income vs. heat.",
            True, theme.TEXT_GOLD)
        _blit_fit(surface, tut_s, inner_w, midtop=(cx, L['tut_y']))

    mx, my = pygame.mouse.get_pos()
    for ch, btn in zip(event['choices'], L['btns']):
        hover = btn.collidepoint(mx, my)
        col = (50, 55, 80) if not hover else (70, 75, 110)
        pygame.draw.rect(surface, col, btn, border_radius=8)
        pygame.draw.rect(surface, (*theme.ACCENT_DIM, 160), btn, border_radius=8, width=1)
        txt_w = btn.width - scale.sd(20)
        lbl_s = fonts['sm'].render(ch['label'], True, theme.TEXT_PRIMARY)
        _blit_fit(surface, lbl_s, txt_w, topleft=(btn.x + scale.sd(10), btn.y + scale.sd(5)))
        desc2_s = fonts['xs'].render(ch['desc'], True, theme.TEXT_MUTED)
        _blit_fit(surface, desc2_s, txt_w,
                  topleft=(btn.x + scale.sd(10), btn.y + scale.sd(5) + fonts['sm'].get_height()))


def handle_event_click(state, pos: tuple) -> bool:
    L = _event_layout(state, getattr(state, '_fonts', {}))
    if not L:
        return False
    for i, btn in enumerate(L['btns']):
        if btn.collidepoint(pos):
            resolve_event(state, i)
            return True
    return False
