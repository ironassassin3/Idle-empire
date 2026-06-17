"""Territory system — capture districts via Attack/Bribe/Negotiate/Sabotage."""
from __future__ import annotations
import math
import random
from dataclasses import dataclass, field
from typing import List

import pygame
import src.theme as theme
import src.scale as scale
import config


@dataclass
class Territory:
    name: str
    description: str
    unlock_cost: float          # legacy — used only as minimum influence gate
    income_bonus: float
    click_bonus: float
    heat_resistance: float
    news_tag: str
    color: tuple = (100, 100, 140)
    perk: str = ""              # short identity label shown in UI
    perk_key: str = ""          # mechanical identity (read by other systems)
    district_type: str = ""     # 'residential'|'industrial'|'commercial'|'government'|''
    unlocked: bool = False
    contested: bool = False     # rival is challenging this territory
    owner: str = "unclaimed"    # 'player' | 'unclaimed' | rival name


# 5 original named districts (perk_key system, special perks) +
# 15 new generic districts (district_type system, stacking bonuses).
# Total: 20 districts.
#
# Format: (name, desc, cost, income, click, heat_resist, tag, color, perk, perk_key, district_type)
_TERRITORY_DEFS: list[tuple] = [
    # ── Special districts (strategic identities) ─────────────────────────────
    ("South Side",
     "Your home turf. Cheap and loyal.",
     0, 0.0, 0.0, 0.0, "south_side", (80, 120, 80),
     "Home Turf", "", ""),

    ("Downtown",
     "The money district. Biggest straight income boost.",
     0, 0.20, 0.06, 0.0, "downtown", (80, 120, 180),
     "CASH: +20% income, +6% clicks", "cash", ""),

    ("Industrial District",
     "Warehouses and chop shops — your operations hub.",
     5, 0.10, 0.0, 0.12, "industrial", (160, 120, 60),
     "OPERATIONS: +25% op rewards, -12% heat", "operations", ""),

    ("Waterfront",
     "Open smuggling routes. Risky work pays the most.",
     15, 0.15, 0.05, 0.04, "waterfront", (60, 140, 180),
     "SMUGGLING: +15% op success & rewards", "smuggling", ""),

    ("City Hall",
     "You own the politicians. Heat can't touch you here.",
     40, 0.30, 0.12, 0.25, "city_hall", (200, 160, 60),
     "POLITICS: heat shield + prestige boost", "politics", ""),

    # ── Residential districts (+income stacking) ─────────────────────────────
    ("Eastside Heights",
     "Working neighborhoods. Steady, reliable revenue.",
     2, 0.01, 0.0, 0.0, "eastside", (100, 150, 100),
     "RESIDENTIAL: +1% income", "", "residential"),

    ("Sunset Gardens",
     "Quiet streets. Consistent flow, low exposure.",
     8, 0.01, 0.0, 0.0, "sunset", (120, 160, 90),
     "RESIDENTIAL: +1% income", "", "residential"),

    ("Millbrook Park",
     "Upscale housing. High rent keeps you funded.",
     20, 0.015, 0.0, 0.0, "millbrook", (130, 170, 80),
     "RESIDENTIAL: +1.5% income", "", "residential"),

    ("Harbor View",
     "Old money neighborhood. Premium returns.",
     35, 0.015, 0.0, 0.0, "harborview", (70, 160, 140),
     "RESIDENTIAL: +1.5% income", "", "residential"),

    # ── Industrial districts (+op rewards, heat resistance) ───────────────────
    ("Rail Yards",
     "Freight hub. Product moves undetected through here.",
     10, 0.0, 0.0, 0.03, "railyards", (150, 110, 60),
     "INDUSTRIAL: +2% op rewards, -3% heat", "", "industrial"),

    ("Machine Quarter",
     "Chop shops and auto yards. Lucrative rackets.",
     25, 0.0, 0.0, 0.04, "machinequarter", (170, 125, 45),
     "INDUSTRIAL: +2% op rewards, -4% heat", "", "industrial"),

    ("Warehouse Row",
     "Storage and logistics. Operations run smoothly.",
     45, 0.0, 0.0, 0.06, "warehouserow", (185, 135, 50),
     "INDUSTRIAL: +2% op rewards, -6% heat", "", "industrial"),

    # ── Commercial districts (+income & clicks stacking) ──────────────────────
    ("Shopping District",
     "Storefronts and buzz. Reputation spreads fast here.",
     5, 0.01, 0.02, 0.0, "shopping", (200, 140, 80),
     "COMMERCIAL: +1% income, +2% clicks", "", "commercial"),

    ("Entertainment Row",
     "Bars and clubs. Everyone talks, everyone pays.",
     18, 0.01, 0.02, 0.0, "entertainment", (210, 120, 100),
     "COMMERCIAL: +1% income, +2% clicks", "", "commercial"),

    ("Market Square",
     "Street vendors and merchants under your wing.",
     30, 0.01, 0.02, 0.0, "marketsquare", (195, 155, 75),
     "COMMERCIAL: +1% income, +2% clicks", "", "commercial"),

    ("Hotel Quarter",
     "Business travelers bring money and opportunity.",
     50, 0.015, 0.03, 0.0, "hotelquarter", (210, 165, 95),
     "COMMERCIAL: +1.5% income, +3% clicks", "", "commercial"),

    # ── Government districts (+heat resistance, respect gain) ─────────────────
    ("Civic Center",
     "City officials on the payroll. Fewer problems.",
     15, 0.0, 0.0, 0.04, "civiccenter", (140, 140, 220),
     "GOVERNMENT: -4% heat rise, +2% respect gain", "", "government"),

    ("Police Precinct",
     "Compromised cops. Raids hit softer.",
     28, 0.0, 0.0, 0.06, "precinct", (120, 120, 210),
     "GOVERNMENT: -6% heat rise, +2% respect gain", "", "government"),

    ("Federal Building",
     "Influence at the federal level. Near-untouchable.",
     60, 0.0, 0.0, 0.08, "federal", (100, 100, 200),
     "GOVERNMENT: -8% heat rise, +2% respect gain", "", "government"),

    ("City Courts",
     "Judges and clerks in your pocket. Legal immunity.",
     80, 0.0, 0.0, 0.10, "citycourts", (90, 90, 200),
     "GOVERNMENT: -10% heat rise, +2% respect gain", "", "government"),
]

# Total districts (used for milestone % calculations)
TOTAL_DISTRICTS = len(_TERRITORY_DEFS)  # 20

# Milestone thresholds and their reward descriptions
MILESTONE_DEFS = [
    ('25',  0.25, "+10% Influence Gain",    (180, 220, 120)),
    ('50',  0.50, "+25% Respect Gain",      (220, 180, 100)),
    ('75',  0.75, "-15% Heat Generation",   (120, 200, 220)),
    ('100', 1.00, "+50% Global Income",     (220, 180, 255)),
]


def make_territories() -> List[Territory]:
    territories = []
    for i, tdef in enumerate(_TERRITORY_DEFS):
        name, desc, cost, ib, cb, hr, tag, col, perk, perk_key, district_type = tdef
        t = Territory(name=name, description=desc, unlock_cost=cost,
                      income_bonus=ib, click_bonus=cb, heat_resistance=hr,
                      news_tag=tag, color=col, perk=perk, perk_key=perk_key,
                      district_type=district_type)
        if i == 0:
            t.unlocked = True
            t.owner = 'player'
        territories.append(t)
    return territories


_STRATEGIC_NAMES = frozenset({
    "South Side", "Downtown", "Industrial District", "Waterfront", "City Hall",
})


def partial_territory_reset(territories: List[Territory], state=None) -> int:
    """Reset generic districts on prestige; preserve the 5 named strategic districts.

    Clears city-control milestones so they're earnable again each cycle.
    Returns the count of districts reset.
    """
    count = 0
    for t in territories:
        if t.name not in _STRATEGIC_NAMES:
            t.unlocked = False
            t.owner = 'unclaimed'
            t.contested = False
            count += 1
    if state is not None:
        state._city_control_milestones = set()
    return count


def assign_rival_territories(territories: List[Territory], rivals: list) -> None:
    """Assign initial rival ownership to unclaimed territories."""
    unclaimed = [t for t in territories if t.owner == 'unclaimed']
    if not rivals or not unclaimed:
        return
    ordered = sorted(
        [r for r in rivals if r is not None and r.status != 'Eliminated'],
        key=lambda r: getattr(r, 'turf', 0), reverse=True
    )
    for i, t in enumerate(unclaimed):
        if i < len(ordered):
            t.owner = ordered[i].name


def release_rival_territories(territories: List[Territory], rival_name: str) -> int:
    """Free every map district owned by a (defeated) rival back to 'unclaimed'.

    Part 4 — rival/territory integration: when a rival is eliminated their turf on
    the city map should visibly open up for the player to capture. Returns the
    number of districts released.
    """
    freed = 0
    for t in territories:
        if getattr(t, 'owner', None) == rival_name and not t.unlocked:
            t.owner = 'unclaimed'
            t.contested = False
            freed += 1
    return freed


def rival_claim_unclaimed(territories: List[Territory], rival_name: str) -> str | None:
    """Let a growing rival claim one unclaimed map district. Returns its name or None.

    Makes rival expansion visible on the map instead of only bumping an abstract
    turf counter.
    """
    for t in territories:
        if getattr(t, 'owner', 'unclaimed') == 'unclaimed' and not t.unlocked:
            t.owner = rival_name
            return t.name
    return None


def rival_claim_preferred(territories: List[Territory], rival_name: str,
                          preferred_names: list = None,
                          preferred_types: list = None) -> str | None:
    """Like rival_claim_unclaimed but tries faction-preferred districts first.

    preferred_names: specific district names to prioritise (e.g. ['Waterfront'])
    preferred_types: district_type values to prioritise (e.g. ['industrial'])
    Falls back to any unclaimed district if none of the preferred are available.
    """
    unclaimed = [t for t in territories
                 if getattr(t, 'owner', 'unclaimed') == 'unclaimed' and not t.unlocked]
    if not unclaimed:
        return None

    # Priority 1: exact name match
    if preferred_names:
        for t in unclaimed:
            if t.name in preferred_names:
                t.owner = rival_name
                return t.name

    # Priority 2: district_type match
    if preferred_types:
        for t in unclaimed:
            if getattr(t, 'district_type', '') in preferred_types:
                t.owner = rival_name
                return t.name

    # Fallback: first available
    unclaimed[0].owner = rival_name
    return unclaimed[0].name


def get_city_control(territories: List[Territory], rivals: list) -> list[tuple[str, float]]:
    """Return list of (name, share) sorted by share descending."""
    total = max(1, len(territories))
    counts: dict[str, int] = {}
    for t in territories:
        owner = t.owner or 'unclaimed'
        counts[owner] = counts.get(owner, 0) + 1
    result = [(name, count / total) for name, count in counts.items() if name != 'unclaimed']
    result.sort(key=lambda x: x[1], reverse=True)
    return result


# ─── Income / click / heat multipliers ───────────────────────────────────────

def territory_income_mult(territories: List[Territory]) -> float:
    """Per-district income_bonus from owned territories (existing strategic bonuses)."""
    bonus = sum(t.income_bonus for t in territories if t.unlocked)
    return 1.0 + bonus


def territory_click_mult(territories: List[Territory]) -> float:
    bonus = sum(t.click_bonus for t in territories if t.unlocked)
    return 1.0 + bonus


def territory_heat_resistance(territories: List[Territory]) -> float:
    return sum(t.heat_resistance for t in territories if t.unlocked)


# ─── Phase 10: Territory Count Bonus (2% per district) ───────────────────────

def territory_district_count_bonus(territories: List[Territory]) -> float:
    """Global income bonus: 2% per player-controlled district.

    Calculated separately from per-district income_bonus values so both are
    visible and additive rather than hidden inside a single multiplier.
    """
    count = sum(1 for t in territories if t.unlocked)
    return count * 0.02


# ─── Phase 10: District Type Bonuses (stacking per type owned) ───────────────

def district_type_operation_mult(territories: List[Territory]) -> float:
    """Each industrial-type district: +2% operation rewards."""
    count = sum(1 for t in territories
                if t.district_type == 'industrial' and t.unlocked)
    return 1.0 + count * 0.02


def district_type_respect_mult(territories: List[Territory]) -> float:
    """Each government-type district: +2% respect (influence) gain."""
    count = sum(1 for t in territories
                if t.district_type == 'government' and t.unlocked)
    return 1.0 + count * 0.02


# ─── Phase 10: City Control Milestone Rewards ────────────────────────────────

def milestone_income_mult(state) -> float:
    """100% city control milestone: +50% global income."""
    return 1.50 if '100' in getattr(state, '_city_control_milestones', set()) else 1.0


def milestone_heat_mult(state) -> float:
    """75% city control milestone: -15% heat generation."""
    return 0.85 if '75' in getattr(state, '_city_control_milestones', set()) else 1.0


def milestone_influence_mult(state) -> float:
    """25% city control milestone: +10% influence gain."""
    return 1.10 if '25' in getattr(state, '_city_control_milestones', set()) else 1.0


def milestone_respect_mult(state) -> float:
    """50% city control milestone: +25% respect gain."""
    return 1.25 if '50' in getattr(state, '_city_control_milestones', set()) else 1.0


# ─── District identity queries (read by other systems) ───────────────────────

def _owns_perk(state, key: str) -> bool:
    return any(getattr(t, 'perk_key', '') == key and t.unlocked
               for t in getattr(state, 'territories', []))


def operation_reward_mult(state) -> float:
    """Industrial District (+25%), Waterfront (+15%), and industrial-type (+2% each)."""
    mult = 1.0
    if _owns_perk(state, 'operations'):
        mult *= 1.25
    if _owns_perk(state, 'smuggling'):
        mult *= 1.15
    territories = getattr(state, 'territories', [])
    mult *= district_type_operation_mult(territories)
    return mult


def prestige_influence_mult(state) -> float:
    """City Hall (+15%), commercial-type districts, and 25% milestone (+10%)."""
    mult = 1.15 if _owns_perk(state, 'politics') else 1.0
    # Commercial districts each give +2% influence gain (stacks)
    territories = getattr(state, 'territories', [])
    commercial_count = sum(1 for t in territories
                           if t.district_type == 'commercial' and t.unlocked)
    mult *= 1.0 + commercial_count * 0.02
    # 25% milestone permanent reward
    mult *= milestone_influence_mult(state)
    return mult


def _apply_respect_gain(state, amount: int) -> int:
    """Scale a respect gain by government-type districts and 50% milestone."""
    territories = getattr(state, 'territories', [])
    mult = district_type_respect_mult(territories) * milestone_respect_mult(state)
    return max(1, int(round(amount * mult)))


# ─── Action system ───────────────────────────────────────────────────────────

_ACTIONS = [
    ('attack',    'Attack',    (200, 60,  60)),
    ('bribe',     'Bribe',     (200, 160, 40)),
    ('negotiate', 'Negotiate', (60,  160, 200)),
    ('sabotage',  'Sabotage',  (140, 60,  200)),
]


def _success_chance(state, territory: Territory, action: str) -> float:
    from src.crew import territory_action_bonus
    from src.rivals import get_empire_impact
    ca = getattr(state, 'crew', None)
    crew_bonus = territory_action_bonus(ca) if ca else 0.0

    try:
        import src.managers as _mgr
        crew_bonus += _mgr.territory_success_bonus(state)
    except Exception:
        pass

    # Cartel Expansion: prestige-branch territory success bonus.
    try:
        import src.prestige_tree as _ptree
        crew_bonus += _ptree.territory_action_bonus(state)
    except Exception:
        pass

    # Dragon Patron: Red boosts attack/sabotage; Jade boosts negotiate/bribe; Black penalises all.
    try:
        import src.dragon as _dragon
        crew_bonus += _dragon.territory_action_modifier(state, action)
    except Exception:
        pass

    inf = getattr(state, 'prestige_tokens', 0)
    inf_bonus = min(inf * 0.01, 0.25)

    try:
        import src.prestige as _prestige
        inf_bonus += _prestige.rank_territory_bonus(inf)
    except Exception:
        pass

    base = {
        'attack':    0.55,
        'bribe':     0.60,
        'negotiate': 0.70,
        'sabotage':  0.50,
    }.get(action, 0.5)

    try:
        impact = get_empire_impact(state)
        rival_penalty = impact.get('territory_penalty', 0.0)
    except Exception:
        rival_penalty = 0.0

    return min(0.90, max(0.10, base + crew_bonus + inf_bonus - rival_penalty))


def perform_action(state, idx: int, action: str) -> str:
    territories: List[Territory] = getattr(state, 'territories', [])
    if idx >= len(territories):
        return "Invalid territory."
    t = territories[idx]

    if t.unlocked:
        return f"{t.name} is already yours."

    if state.prestige_tokens < t.unlock_cost:
        return f"Need {t.unlock_cost:.0f} Influence to act here."

    if getattr(state, '_dragon_guaranteed_territory', False):
        success = True
        state._dragon_guaranteed_territory = False
    else:
        success = random.random() < _success_chance(state, t, action)
        if (not success and action in ('attack', 'bribe', 'negotiate', 'sabotage')):
            try:
                import src.managers as _mgr
                if _mgr.broker_retry_ready(state):
                    state._broker_retry_cd = _mgr._BROKER_RETRY_CD
                    if random.random() < _success_chance(state, t, action):
                        success = True
                        state._broker_retries = getattr(state, '_broker_retries', 0) + 1
            except Exception:
                pass
    ips = state.income_per_second

    def _seize(territory: Territory) -> None:
        territory.unlocked = True
        territory.owner = 'player'
        territory.contested = False
        was_first = getattr(state, '_total_territories_captured', 0) == 0
        state._total_territories_captured = getattr(state, '_total_territories_captured', 0) + 1
        try:
            import src.analytics as _an
            _an.territory_captured(territory.name, getattr(territory, 'perk_key', ''))
            if was_first:
                _an.first_territory()
        except Exception:
            pass
        try:
            import src.dragon as _dragon
            _dragon.on_territory_captured(state)
        except Exception:
            pass

    if action == 'attack':
        if success:
            _seize(t)
            state.prestige_tokens += 1
            gain = _apply_respect_gain(state, 8)
            state.influence = getattr(state, 'influence', 0) + gain
            state.heat = min(100.0, getattr(state, 'heat', 0.0) + 15.0)
            return f"Seized {t.name} by force! +1 Influence, +{gain} Respect, +15 heat"
        else:
            state.heat = min(100.0, getattr(state, 'heat', 0.0) + 12.0)
            loss = state.balance * 0.04
            state.balance = max(0.0, state.balance - loss)
            return f"Attack failed. +12 heat, lost ${theme.format_number(loss)}"

    elif action == 'bribe':
        cost = max(500.0, ips * 90)
        if state.balance < cost:
            return f"Need ${theme.format_number(cost)} to bribe officials."
        state.balance = max(0.0, state.balance - cost)
        if success:
            _seize(t)
            state.heat = max(0.0, getattr(state, 'heat', 0.0) - 5.0)
            state.prestige_tokens += 1
            return f"Bribed your way into {t.name}! +1 Influence, -5 heat"
        else:
            state.heat = min(100.0, getattr(state, 'heat', 0.0) + 6.0)
            return f"Bribe rejected. +6 heat, lost {theme.format_money(cost)}"

    elif action == 'negotiate':
        if success:
            _seize(t)
            state.prestige_tokens += 1
            gain = _apply_respect_gain(state, 5)
            state.influence = getattr(state, 'influence', 0) + gain
            state.heat = max(0.0, getattr(state, 'heat', 0.0) - 3.0)
            return f"Negotiated control of {t.name}. +1 Influence, +{gain} Respect, -3 heat"
        else:
            state.heat = min(100.0, getattr(state, 'heat', 0.0) + 3.0)
            return f"Negotiations failed. +3 heat"

    elif action == 'sabotage':
        cost = max(200.0, ips * 30)
        if state.balance < cost:
            return f"Need ${theme.format_number(cost)} for sabotage supplies."
        state.balance = max(0.0, state.balance - cost)
        if success:
            _seize(t)
            state.heat = min(100.0, getattr(state, 'heat', 0.0) + 8.0)
            state.prestige_tokens += 1
            gain = _apply_respect_gain(state, 6)
            state.influence = getattr(state, 'influence', 0) + gain
            return f"Sabotaged them out of {t.name}! +1 Influence, +{gain} Respect, +8 heat"
        else:
            state.heat = min(100.0, getattr(state, 'heat', 0.0) + 10.0)
            return f"Sabotage discovered. +10 heat, lost ${theme.format_number(cost)}"

    return "Unknown action."


# ─── UI ──────────────────────────────────────────────────────────────────────

_ROW_H   = 92   # fallback only — real height computed by _card_height()
_GAP     = 6
_TOP_PAD = 6
_BOT_PAD = 8
_ROW_GAP = 4

# Type colors for district badges
_TYPE_COLORS = {
    'residential': (100, 180, 100),
    'industrial':  (180, 140, 60),
    'commercial':  (200, 160, 80),
    'government':  (120, 140, 220),
}

# Fallback list-top offset used by handle_click() before the first draw frame
_HEADER_H = 182


def _terr_btn_metrics(fonts: dict) -> tuple[int, int, int]:
    """Action button width/height/gap — width fits the widest label
    (Attack/Bribe/Negotiate/Sabotage), height fits the glyph. Shared by
    _card_height, draw_panel and handle_click so all three agree."""
    if not fonts or not fonts.get('xs'):
        return scale.sd(72), scale.sd(22), scale.sd(4)
    xs_h = fonts['xs'].get_height()
    bh = xs_h + scale.sd(8)
    bw = max(scale.sd(56),
             max(fonts['xs'].size(lbl)[0] for _, lbl, _ in _ACTIONS) + scale.sd(14))
    return bw, bh, scale.sd(4)


def _card_height(terr: Territory, fonts: dict, can_act: bool) -> int:
    """Derive card height from actual content rows. Falls back to _ROW_H if fonts absent."""
    if not fonts or 'sm' not in fonts or 'xs' not in fonts:
        return _ROW_H
    sm_h = fonts['sm'].get_height()
    xs_h = fonts['xs'].get_height()
    g = _ROW_GAP
    h = _TOP_PAD
    h += sm_h + g                    # name row
    h += xs_h + g                    # description row
    if getattr(terr, 'perk', ''):
        h += xs_h + g                # perk row (optional)
    owner = getattr(terr, 'owner', 'unclaimed')
    if terr.unlocked:
        h += xs_h + g                # active bonus row
    elif owner not in ('player', 'unclaimed'):
        h += xs_h + g                # held-by row
    else:
        h += xs_h + g                # requirements row
        has_reward = terr.income_bonus > 0 or terr.click_bonus > 0 or terr.heat_resistance > 0
        if has_reward:
            h += xs_h + g            # reward preview row
        if can_act:
            _, btn_h, _ = _terr_btn_metrics(fonts)
            h += btn_h + g           # action buttons
        else:
            h += xs_h + g            # LOCKED badge row
    h += _BOT_PAD
    return h


def _compute_card_layout(rr: pygame.Rect, terr: Territory, fonts: dict) -> dict:
    """Single source of truth for card row Y positions.

    Both draw_panel and handle_click consume this output, so reordering rows here
    automatically propagates to both draw positions and click targets.
    """
    xs_h = fonts['xs'].get_height()
    sm_h = fonts['sm'].get_height()
    layout: dict = {}
    cy = rr.y + _TOP_PAD

    layout['name'] = cy
    cy += sm_h + _ROW_GAP

    layout['desc'] = cy
    cy += xs_h + _ROW_GAP

    if getattr(terr, 'perk', ''):
        layout['perk'] = cy
        cy += xs_h + _ROW_GAP

    owner = getattr(terr, 'owner', 'unclaimed')

    if terr.unlocked:
        layout['bonus'] = cy
    elif owner not in ('player', 'unclaimed'):
        layout['held'] = cy
    else:
        layout['req'] = cy
        cy += xs_h + _ROW_GAP
        has_reward = (terr.income_bonus > 0 or
                      terr.click_bonus > 0 or
                      terr.heat_resistance > 0)
        if has_reward:
            layout['reward'] = cy
            cy += xs_h + _ROW_GAP
        layout['buttons'] = cy

    return layout


def _draw_header(surface: pygame.Surface, state, fonts: dict,
                 panel_rect: pygame.Rect) -> int:
    """Draw the Territory Bonus + Milestones + Faction Breakdown header.

    Returns the y-coordinate where the scrollable district list should start.
    """
    territories: List[Territory] = getattr(state, 'territories', [])
    mx, my = pygame.mouse.get_pos()
    t_anim = getattr(state, '_time', 0.0)

    # Phase 90: every vertical step below derives from the live (scaled) font
    # heights + shared spacing, so the header can't pile up when fonts grow.
    xs_h = fonts['xs'].get_height()
    sm_h = fonts['sm'].get_height()
    g = scale.sd(4)
    pad = scale.sd(4)

    x0 = panel_rect.x + scale.sd(8)
    pw = panel_rect.width - scale.sd(16)
    y = panel_rect.y + scale.sd(6)

    total = max(1, len(territories))
    player_count = sum(1 for t in territories if t.unlocked)
    ctrl_pct = player_count / total
    count_bonus_pct = int(player_count * 2)   # 2% per district
    milestones_earned = getattr(state, '_city_control_milestones', set())

    # ── TERRITORY BONUS section ──────────────────────────────────────────────
    # Districts-controlled (left) and global-income (right) share one row when
    # they fit; on a narrow panel they stack so they can never collide.
    bonus_col = theme.GREEN if count_bonus_pct > 0 else theme.TEXT_MUTED
    dist_s = fonts['sm'].render(
        f"{player_count} Districts Controlled", True, theme.TEXT_GOLD)
    bonus_s = fonts['sm'].render(
        f"+{count_bonus_pct}% Global Income", True, bonus_col)
    same_row = dist_s.get_width() + bonus_s.get_width() + scale.sd(24) <= pw

    if same_row:
        box_h = pad + xs_h + g + sm_h + pad
    else:
        box_h = pad + xs_h + g + sm_h + g + sm_h + pad
    bg = pygame.Surface((pw, box_h), pygame.SRCALPHA)
    pygame.draw.rect(bg, (30, 60, 40, 180), bg.get_rect(), border_radius=6)
    surface.blit(bg, (x0, y))

    hdr_s = fonts['xs'].render("TERRITORY BONUS", True, theme.GREEN)
    surface.blit(hdr_s, (x0 + scale.sd(8), y + pad))

    dist_y = y + pad + xs_h + g
    surface.blit(dist_s, (x0 + scale.sd(8), dist_y))
    if same_row:
        surface.blit(bonus_s, bonus_s.get_rect(
            midright=(x0 + pw - scale.sd(6), dist_y + sm_h // 2)))
    else:
        surface.blit(bonus_s, bonus_s.get_rect(
            midright=(x0 + pw - scale.sd(6), dist_y + sm_h + g + sm_h // 2)))

    y += box_h + scale.sd(6)

    # ── MILESTONES section ───────────────────────────────────────────────────
    ms_hdr = fonts['xs'].render("CITY MILESTONES", True, theme.TEXT_MUTED)
    surface.blit(ms_hdr, (x0, y))
    y += xs_h + g

    row_h = xs_h + scale.sd(6)
    for m_key, m_thresh, m_desc, m_col in MILESTONE_DEFS:
        earned = m_key in milestones_earned
        need_count = max(0, int(math.ceil(m_thresh * total)) - player_count)

        row_bg = pygame.Surface((pw, row_h - scale.sd(2)), pygame.SRCALPHA)
        bg_alpha = 80 if earned else 30
        row_col = (*m_col, bg_alpha) if earned else (40, 40, 50, bg_alpha)
        pygame.draw.rect(row_bg, row_col, row_bg.get_rect(), border_radius=4)
        surface.blit(row_bg, (x0, y))

        ty = y + scale.sd(2)
        check_col = theme.GREEN if earned else theme.TEXT_MUTED
        check_s = fonts['xs'].render("v" if earned else "○", True, check_col)
        surface.blit(check_s, (x0 + scale.sd(4), ty))

        label_col = m_col if earned else theme.TEXT_MUTED
        pct_s = fonts['xs'].render(f"{int(m_thresh*100)}%", True, label_col)
        surface.blit(pct_s, (x0 + scale.sd(18), ty))

        desc_s = fonts['xs'].render(m_desc, True, label_col)
        surface.blit(desc_s, (x0 + scale.sd(46), ty))

        if earned:
            tail_s = fonts['xs'].render("EARNED", True, theme.GREEN)
        else:
            tail_s = fonts['xs'].render(f"need {need_count} more", True, (120, 120, 120))
        surface.blit(tail_s, tail_s.get_rect(midright=(x0 + pw - scale.sd(4), y + row_h // 2)))

        y += row_h

    y += scale.sd(2)

    # ── FACTION BREAKDOWN section ────────────────────────────────────────────
    ctrl = get_city_control(territories, getattr(state, 'rivals', []))
    unclaimed_count = sum(1 for t in territories if t.owner == 'unclaimed')

    # Progress bar (full width)
    bar_h = scale.sd(10)
    bar_w = pw
    pygame.draw.rect(surface, (30, 30, 40), (x0, y, bar_w, bar_h), border_radius=4)

    bar_x = x0
    bar_segments: list[tuple] = []
    for name, share in ctrl:
        if name == 'player':
            col = (80, 200, 120)
        else:
            # Look up rival color
            col = (180, 80, 60)
            try:
                rivals = getattr(state, 'rivals', [])
                for r in rivals:
                    if r and r.name == name:
                        col = getattr(r, 'color', col)
                        break
            except Exception:
                pass
        seg_w = int(share * bar_w)
        bar_segments.append((bar_x, seg_w, col))
        bar_x += seg_w

    for bx, bw, bc in bar_segments:
        if bw > 0:
            pygame.draw.rect(surface, bc, (bx, y, bw, bar_h), border_radius=3)

    y += bar_h + scale.sd(3)

    # Faction rows (player first, then top 2 rivals, then unclaimed)
    faction_rows: list[tuple[str, int, tuple]] = []
    for name, share in ctrl[:3]:
        count = int(round(share * total))
        if name == 'player':
            faction_rows.insert(0, ("YOU", count, (80, 200, 120)))
        else:
            col = (180, 80, 60)
            try:
                for r in getattr(state, 'rivals', []):
                    if r and r.name == name:
                        col = getattr(r, 'color', col)
                        break
            except Exception:
                pass
            faction_rows.append((name[:12], count, col))

    if unclaimed_count > 0:
        faction_rows.append(("Unclaimed", unclaimed_count, (80, 80, 80)))

    # 2-column layout for faction rows
    col_w = pw // 2
    frow_h = xs_h + scale.sd(2)
    for i, (fname, fcount, fcol) in enumerate(faction_rows[:4]):
        col_x = x0 + (i % 2) * col_w
        row_y_f = y + (i // 2) * frow_h
        pct_val = int(round(fcount / total * 100))
        fs = fonts['xs'].render(
            f"{fname}: {fcount}/{total} ({pct_val}%)", True, fcol)
        surface.blit(fs, (col_x, row_y_f))

    faction_rows_count = min(4, len(faction_rows))
    y += ((faction_rows_count + 1) // 2) * frow_h + scale.sd(2)

    # Next milestone hint
    next_thresh = None
    for m_key, m_thresh, _, m_col in MILESTONE_DEFS:
        if m_key not in milestones_earned:
            next_thresh = (m_thresh, m_col, m_key)
            break

    if next_thresh:
        needed = max(0, int(math.ceil(next_thresh[0] * total)) - player_count)
        if needed > 0:
            hint_s = fonts['xs'].render(
                f"Next milestone: {int(next_thresh[0]*100)}% control — {needed} more district{'s' if needed != 1 else ''}",
                True, next_thresh[1])
            surface.blit(hint_s, (x0, y))
        else:
            hint_s = fonts['xs'].render(
                "All milestones claimed!", True, theme.GREEN)
            surface.blit(hint_s, (x0, y))
        y += xs_h + scale.sd(2)

    # Divider
    sep = pygame.Surface((pw, 1), pygame.SRCALPHA)
    sep.fill((255, 255, 255, 40))
    surface.blit(sep, (x0, y))
    y += scale.sd(5)

    return y


def draw_panel(surface: pygame.Surface, state, fonts: dict,
               panel_rect: pygame.Rect) -> None:
    territories: List[Territory] = getattr(state, 'territories', [])
    mx, my = pygame.mouse.get_pos()
    t_anim = getattr(state, '_time', 0.0)

    # Static header (territory bonus + milestones + faction breakdown)
    list_top = _draw_header(surface, state, fonts, panel_rect)
    state._terr_list_top = list_top

    # Outcome popup
    outcome = getattr(state, '_territory_outcome', None)
    if outcome:
        timer = getattr(state, '_territory_outcome_timer', 0.0)
        if timer > 0:
            alpha = min(255, int(255 * min(1.0, timer / 0.4)))
            os_s = fonts['sm'].render(outcome, True, theme.TEXT_GOLD)
            os_s.set_alpha(alpha)
            surface.blit(os_s, os_s.get_rect(
                centerx=panel_rect.centerx, y=list_top))

    # Scroll offset (item count)
    scroll = getattr(state, '_terr_scroll', 0)
    scroll = max(0, min(scroll, max(0, len(territories) - 1)))

    row_y = list_top + 4
    visible_count = 0

    for idx in range(scroll, len(territories)):
        terr = territories[idx]
        can_act = (not terr.unlocked and
                   state.prestige_tokens >= terr.unlock_cost)
        card_h = _card_height(terr, fonts, can_act)
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, card_h)
        if row_y + card_h > panel_rect.bottom:
            break

        hover = rr.collidepoint(mx, my)

        if terr.unlocked:
            bg = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
            pygame.draw.rect(bg, (*terr.color, 40), bg.get_rect(), border_radius=10)
            surface.blit(bg, rr.topleft)
            ab = pygame.Surface((3, card_h - 16), pygame.SRCALPHA)
            ab.fill((*terr.color, 200))
            surface.blit(ab, (rr.x, rr.y + 8))
        else:
            pygame.draw.rect(surface, theme.BG_CARD_HOVER if hover else theme.BG_CARD,
                             rr, border_radius=10)
            if can_act:
                pulse_a = int(80 + 60 * math.sin(t_anim * 2.5))
                ps = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
                pygame.draw.rect(ps, (*terr.color, pulse_a), ps.get_rect(),
                                 border_radius=10, width=2)
                surface.blit(ps, rr.topleft)

        # District dot
        dot_c = (rr.x + scale.sd(22), rr.y + scale.sd(22))
        dot_r = scale.sd(10)
        pygame.draw.circle(surface, terr.color, dot_c, dot_r)
        if terr.unlocked:
            pygame.draw.circle(surface, (255, 255, 255), dot_c, dot_r, scale.sd(2))

        # District type badge (small tag for generic districts), sized to its text
        dtype = getattr(terr, 'district_type', '')
        badge_w = 0
        if dtype:
            type_col = _TYPE_COLORS.get(dtype, theme.TEXT_MUTED)
            ts = fonts['xs'].render(dtype.upper(), True, type_col)
            badge_w = ts.get_width() + scale.sd(8)
            badge_h = fonts['xs'].get_height() + scale.sd(2)
            badge_x = rr.x + scale.sd(36)
            type_bg = pygame.Surface((badge_w, badge_h), pygame.SRCALPHA)
            pygame.draw.rect(type_bg, (*type_col, 60), type_bg.get_rect(), border_radius=3)
            surface.blit(type_bg, (badge_x, rr.y + scale.sd(4)))
            surface.blit(ts, ts.get_rect(
                center=(badge_x + badge_w // 2, rr.y + scale.sd(4) + badge_h // 2)))

        tx = rr.x + scale.sd(40)
        name_col = (theme.TEXT_PRIMARY if terr.unlocked else
                    (theme.TEXT_GOLD if can_act else theme.TEXT_MUTED))
        name_x = tx + (badge_w + scale.sd(6) if dtype else 0)

        # Owner badge (right side, anchored to card top)
        owner = getattr(terr, 'owner', 'unclaimed')
        if owner == 'player':
            owner_txt, owner_col = "YOU", theme.GREEN
        elif owner == 'unclaimed':
            owner_txt, owner_col = "UNCLAIMED", theme.TEXT_MUTED
        else:
            owner_txt, owner_col = owner[:14], (220, 100, 80)
        ow_s = fonts['xs'].render(owner_txt, True, owner_col)
        surface.blit(ow_s, ow_s.get_rect(midright=(rr.right - 8, rr.y + 16)))

        # ── Content stack — positions driven by _compute_card_layout ──────────
        layout = _compute_card_layout(rr, terr, fonts)

        # Name
        ns = fonts['sm'].render(terr.name, True, name_col)
        surface.blit(ns, (name_x, layout['name']))

        # Description
        ds = fonts['xs'].render(terr.description, True, theme.TEXT_MUTED)
        surface.blit(ds, (tx, layout['desc']))

        # Perk (optional — only consumes space when present)
        if getattr(terr, 'perk', ''):
            perk_col = terr.color if (terr.unlocked or can_act) else theme.TEXT_MUTED
            perk_s = fonts['xs'].render(terr.perk, True, perk_col)
            surface.blit(perk_s, (tx, layout['perk']))

        # State-dependent lower rows
        if terr.unlocked:
            bonuses = []
            if terr.income_bonus > 0:
                bonuses.append(f"+{terr.income_bonus*100:.0f}% income")
            if terr.click_bonus > 0:
                bonuses.append(f"+{terr.click_bonus*100:.0f}% clicks")
            if terr.heat_resistance > 0:
                bonuses.append(f"-{terr.heat_resistance*100:.0f}% heat rise")
            bonus_txt = "  |  ".join(bonuses) if bonuses else "Home turf"
            bs = fonts['xs'].render(bonus_txt, True, theme.GREEN)
            surface.blit(bs, (tx, layout['bonus']))

        elif owner not in ('player', 'unclaimed'):
            held_s = fonts['xs'].render(
                f"Held by {owner} — Attack to contest!", True, (220, 100, 80))
            surface.blit(held_s, (tx, layout['held']))

        else:
            inf_col = theme.TEXT_GOLD if can_act else theme.TEXT_MUTED
            if terr.unlock_cost > 0:
                cur_inf = getattr(state, 'prestige_tokens', 0)
                need = int(terr.unlock_cost)
                pct = int(min(100, cur_inf / need * 100))
                req_txt = f"Requires {need} Influence  (You: {cur_inf}, {pct}%)"
            else:
                req_txt = "Accessible — use Attack, Bribe, Negotiate, or Sabotage"
            req_s = fonts['xs'].render(req_txt, True, inf_col)
            surface.blit(req_s, (tx, layout['req']))

            reward_parts = []
            if terr.income_bonus > 0:
                reward_parts.append(f"+{terr.income_bonus*100:.0f}% income")
            if terr.click_bonus > 0:
                reward_parts.append(f"+{terr.click_bonus*100:.0f}% clicks")
            if terr.heat_resistance > 0:
                reward_parts.append(f"-{terr.heat_resistance*100:.0f}% heat rise")
            if reward_parts:
                rew_s = fonts['xs'].render("Reward: " + "  |  ".join(reward_parts),
                                           True, theme.TEXT_MUTED)
                surface.blit(rew_s, (tx, layout['reward']))

            if can_act:
                btn_w, btn_h, btn_gap = _terr_btn_metrics(fonts)
                bx_start = rr.right - len(_ACTIONS) * (btn_w + btn_gap) - scale.sd(6)
                by = layout['buttons']

                for (act_key, lbl, col) in _ACTIONS:
                    btn = pygame.Rect(bx_start, by, btn_w, btn_h)
                    hov = btn.collidepoint(mx, my)
                    draw_col = tuple(min(255, v + 30) for v in col) if hov else col
                    try:
                        import src.managers as _mgr
                        if _mgr.broker_best_action(state, idx) == act_key:
                            pulse = int(120 + 80 * math.sin(t_anim * 3.0))
                            glow = pygame.Surface((btn_w, btn_h), pygame.SRCALPHA)
                            pygame.draw.rect(glow, (120, 220, 120, pulse),
                                             glow.get_rect(), border_radius=4, width=2)
                            surface.blit(glow, btn.topleft)
                            intel = fonts['xs'].render("BROKER", True, theme.GREEN)
                            surface.blit(intel, (btn.x + 2, btn.y - fonts['xs'].get_height()))
                    except Exception:
                        pass
                    pygame.draw.rect(surface, draw_col, btn, border_radius=4)
                    ls = fonts['xs'].render(lbl, True, (230, 230, 230))
                    surface.blit(ls, ls.get_rect(center=btn.center))
                    bx_start += btn_w + btn_gap
            else:
                lock_s = fonts['xs'].render("LOCKED", True, theme.TEXT_MUTED)
                surface.blit(lock_s, lock_s.get_rect(
                    midright=(rr.right - 10,
                               layout['buttons'] + fonts['xs'].get_height() // 2)))

        sep = pygame.Surface((rr.width, 1), pygame.SRCALPHA)
        sep.fill((255, 255, 255, 25))
        surface.blit(sep, (rr.x, rr.bottom + _GAP // 2))
        row_y += card_h + _GAP
        visible_count += 1

    # Scroll indicators
    if scroll > 0:
        up_s = fonts['xs'].render(
            f"▲ scroll up ({scroll} more above)", True, theme.TEXT_MUTED)
        surface.blit(up_s, up_s.get_rect(centerx=panel_rect.centerx, y=list_top + 2))

    remaining = len(territories) - scroll - visible_count
    if remaining > 0:
        dn_s = fonts['xs'].render(
            f"▼ scroll down ({remaining} more below)", True, theme.TEXT_MUTED)
        surface.blit(dn_s, dn_s.get_rect(
            centerx=panel_rect.centerx, y=panel_rect.bottom - 14))


def handle_click(state, pos: tuple, panel_rect: pygame.Rect) -> bool:
    territories: List[Territory] = getattr(state, 'territories', [])
    fonts = getattr(state, '_fonts', {})

    list_top = getattr(state, '_terr_list_top', panel_rect.y + _HEADER_H)
    scroll = getattr(state, '_terr_scroll', 0)
    scroll = max(0, min(scroll, max(0, len(territories) - 1)))

    row_y = list_top + 4

    for idx in range(scroll, len(territories)):
        terr = territories[idx]
        can_act = (not terr.unlocked and
                   state.prestige_tokens >= terr.unlock_cost)
        card_h = _card_height(terr, fonts, can_act)
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, card_h)
        if row_y + card_h > panel_rect.bottom:
            break

        # Action buttons only exist for unclaimed/player districts — rival-held
        # ones render "Held by … — Attack to contest!" with no buttons, so their
        # layout has no 'buttons' key. Guard to match the draw side (fixes a
        # KeyError crash on clicking when an affordable rival-held district shows).
        if can_act:
            layout = _compute_card_layout(rr, terr, fonts)
            if 'buttons' in layout:
                btn_w, btn_h, btn_gap = _terr_btn_metrics(fonts)
                bx = rr.right - len(_ACTIONS) * (btn_w + btn_gap) - scale.sd(6)
                by = layout['buttons']

                for (action_key, _, _) in _ACTIONS:
                    btn = pygame.Rect(bx, by, btn_w, btn_h)
                    if btn.collidepoint(pos):
                        outcome = perform_action(state, idx, action_key)
                        state._territory_outcome = outcome
                        state._territory_outcome_timer = 3.5
                        import src.sound as sound
                        # _seize() flips .unlocked on a win — only then is it a victory.
                        sound.play('territory' if terr.unlocked else 'purchase')
                        return True
                    bx += btn_w + btn_gap

        row_y += card_h + _GAP

    return False
