"""Dragon Patron system — long-term criminal companion and identity layer.

Players unlock Dragon Patrons after the first prestige. Unlike prestige branches
(which reset each cycle), a Dragon Patron persists across ALL runs forever.

Session 11 redesign: dragons are companions, not perk cards.
  - Lifecycle: Egg → Hatchling → Young Dragon → Adult Dragon → Ancient Dragon
  - Dragon XP accrues from prestiges, requests, rival eliminations, ops, territory
  - Active abilities unlock as the dragon evolves (with cooldowns)
  - Requests give the dragon personality and drive behavior
  - Visible HUD widget keeps the dragon present during normal play

Three Dragons:
  RED   (Crimson Tide)   — aggression, territory, rival dominance
  JADE  (Jade Serpent)   — patience, corruption, diplomatic control
  BLACK (Iron Scale)     — efficiency, operations, logistical supremacy
"""
from __future__ import annotations
import time
import random
import pygame
import config
import src.theme as theme

RED, JADE, BLACK = 'red', 'jade', 'black'
DRAGON_ORDER = [RED, JADE, BLACK]
DRAGON_CHANGE_COST = 25  # Influence tokens to switch patron

# ─── Lifecycle stages ──────────────────────────────────────────────────────────
EGG, HATCHLING, YOUNG, ADULT, ANCIENT = 'egg', 'hatchling', 'young', 'adult', 'ancient'
STAGE_ORDER = [EGG, HATCHLING, YOUNG, ADULT, ANCIENT]
STAGE_XP = {EGG: 0, HATCHLING: 25, YOUNG: 100, ADULT: 300, ANCIENT: 750}
STAGE_LABELS = {
    EGG:      'Egg',
    HATCHLING:'Hatchling',
    YOUNG:    'Young Dragon',
    ADULT:    'Adult Dragon',
    ANCIENT:  'Ancient Dragon',
}
_STAGE_PASSIVE_MULT = {EGG: 1.0, HATCHLING: 1.0, YOUNG: 1.0, ADULT: 1.10, ANCIENT: 1.25}

DRAGON_META: dict[str, dict] = {
    RED: {
        'name':    'Crimson Tide',
        'title':   'Red Dragon',
        'color':   (220, 80, 60),
        'tag':     'Aggression & Territory',
        'blurb':   'Rival pressure drives your empire. More enemies means more power.',
        'strengths': [
            'Each active rival: +3% income (max +15%)',
            'Territory attack/sabotage: +15% success',
            '+4% income per rival eliminated this run',
            'Heat ≥75: raids may counterattack the rival',
        ],
        'costs': [
            'Heat decay: −0.04/s slower',
            'All rival aggression: +20%',
            'Raid damage: +10% worse',
        ],
    },
    JADE: {
        'name':    'Jade Serpent',
        'title':   'Jade Dragon',
        'color':   (80, 200, 140),
        'tag':     'Patience & Corruption',
        'blurb':   'You own the system. Stability is your weapon.',
        'strengths': [
            '+30% Influence gained at every prestige',
            'Negotiate/Bribe in territory: +40% success',
            'Each district owned: −0.025/s heat',
            '8% chance per AI tick rivals de-escalate',
        ],
        'costs': [
            'Territory attack/sabotage: −20% success',
            'Operations rewards: −15%',
            'Raid cash loss: +20% worse',
        ],
    },
    BLACK: {
        'name':    'Iron Scale',
        'title':   'Black Dragon',
        'color':   (120, 140, 200),
        'tag':     'Efficiency & Operations',
        'blurb':   'Every resource is optimized. The machine never sleeps.',
        'strengths': [
            'Crew capacity: +25% more slots',
            'Collection crew: ×1.5 income per unit',
            'Each running operation: +0.5% income',
            'Ops within 90s of last: +35% reward',
        ],
        'costs': [
            'All territory actions: −15% success',
            'Rival growth rate: +15% faster',
            'Operations heat gain: +25% more',
        ],
    },
}

# ─── Evolution dialogue ────────────────────────────────────────────────────────
_EVOLUTION_LINES: dict[str, dict[str, str]] = {
    RED: {
        HATCHLING: "The flame kindles. It is hungry.",
        YOUNG:     "Growing teeth. Growing hunger. You will feed it well.",
        ADULT:     "The Crimson Tide rises. Your enemies will break.",
        ANCIENT:   "Ancient fire. Ancient rage. All who stand against you shall burn.",
    },
    JADE: {
        HATCHLING: "The serpent stirs. It watches everything.",
        YOUNG:     "It learns. It remembers. It waits.",
        ADULT:     "The Jade Serpent coils through your empire. None see it coming.",
        ANCIENT:   "Ancient patience. Ancient power. The board was yours before they sat down.",
    },
    BLACK: {
        HATCHLING: "The forge ignites. Precision takes shape.",
        YOUNG:     "Efficiency compounds. The machine learns its master.",
        ADULT:     "Iron will. Iron scale. Nothing is wasted, nothing undone.",
        ANCIENT:   "The Ancient Forge. Your empire runs like clockwork. Like fate.",
    },
}

# ─── Request pool ─────────────────────────────────────────────────────────────
# Each entry: (key, dragon, title, goal_text, condition_fn(state, snapshot), xp, reaction)
def _terr_owned(st) -> int:
    return sum(1 for t in getattr(st, 'territories', []) if getattr(t, 'owner', '') == 'player')

_REQUEST_POOL: list[tuple] = [
    # ── RED DRAGON ────────────────────────────────────────────────────────────
    ('red_blood',    RED,
     "I hunger. Show me blood.",
     "Eliminate 1 rival",
     lambda st, sn: st._total_rivals_defeated > sn.get('rivals_elim', 0),
     15, "The Crimson Tide swells. More."),

    ('red_expand',   RED,
     "Expand. Every inch is mine to burn.",
     "Capture 2 territories",
     lambda st, sn: _terr_owned(st) >= sn.get('territories', 0) + 2,
     12, "Good. The map bleeds red."),

    ('red_edge',     RED,
     "Push them to the edge. Push yourself.",
     "Reach Heat 70+",
     lambda st, sn: getattr(st, 'heat', 0.0) >= 70.0,
     10, "Yes. Let them fear what you become."),

    ('red_dominate', RED,
     "Five districts. Show me your reach.",
     "Own 5+ territories simultaneously",
     lambda st, sn: _terr_owned(st) >= 5,
     14, "This is how empires are born."),

    ('red_war',      RED,
     "Two rivals must fall. Show no mercy.",
     "Eliminate 2 rivals",
     lambda st, sn: st._total_rivals_defeated >= sn.get('rivals_elim', 0) + 2,
     20, "The Crimson Tide is satisfied. For now."),

    # ── JADE DRAGON ───────────────────────────────────────────────────────────
    ('jade_web',     JADE,
     "Tighten the web. Control more.",
     "Own 4 territories",
     lambda st, sn: _terr_owned(st) >= 4,
     12, "Good. Control is earned, not seized."),

    ('jade_influence', JADE,
     "Gain me influence. Corrupt the system.",
     "Gain 15 Respect",
     lambda st, sn: getattr(st, 'influence', 0) >= sn.get('influence', 0) + 15,
     15, "The system bends. As it always does."),

    ('jade_cool',    JADE,
     "Stay cold. Control your heat. Show restraint.",
     "Keep Heat below 30",
     lambda st, sn: getattr(st, 'heat', 0.0) < 30.0,
     10, "Restraint is its own weapon."),

    ('jade_thread',  JADE,
     "Expand through guile. Capture three districts.",
     "Capture 3 territories",
     lambda st, sn: _terr_owned(st) >= sn.get('territories', 0) + 3,
     18, "Silk is stronger than steel."),

    ('jade_elder',   JADE,
     "You must prestige. Show me your growth.",
     "Prestige 3 times total",
     lambda st, sn: getattr(st, '_prestige_count', 0) >= 3,
     25, "Now you see what patience builds."),

    # ── BLACK (IRON) DRAGON ───────────────────────────────────────────────────
    ('iron_ops',     BLACK,
     "Run three operations. Show me efficiency.",
     "Complete 3 operations",
     lambda st, sn: st._total_ops_completed > sn.get('ops_completed', 0) + 2,
     15, "The machine does not sleep."),

    ('iron_chain',   BLACK,
     "Link your operations. Chain two completions.",
     "Collect 2 ops within 90 seconds of each other",
     lambda st, sn: op_combo_mult(st) > 1.0,
     18, "That is the rhythm I demand."),

    ('iron_deploy',  BLACK,
     "Deploy everything. Maximum efficiency.",
     "Have all 5 ops active simultaneously",
     lambda st, sn: sum(
         1 for op in getattr(st, 'operations', [])
         if getattr(op, 'active', False) and not getattr(op, 'collected', False)
     ) >= 5,
     20, "Full deployment. As it should be."),

    ('iron_crew',    BLACK,
     "Staff your collection crews. Maximize output.",
     "Have 5+ crew in Collection",
     lambda st, sn: getattr(getattr(st, 'crew', None), 'collection', 0) >= 5,
     12, "Every hand employed. Good."),

    ('iron_grind',   BLACK,
     "Complete five operations without pause.",
     "Complete 5 operations",
     lambda st, sn: st._total_ops_completed >= sn.get('ops_completed', 0) + 5,
     22, "Iron will. Iron results."),

    # ── FACTION-AWARE REQUESTS (only issued when faction is active) ───────────
    # Red Dragon + Blackwater Mob
    ('red_blackwater', RED,
     "The Blackwater Mob guards the harbor. Crush them and take the docks.",
     "Eliminate the Blackwater Mob",
     lambda st, sn: _rival_elim_by_key(st, 'blackwater'),
     22, "The harbor runs red. Good."),

    # Red Dragon + Crimson Kings — faction mirror (two infernos cannot share one city)
    ('red_crimson', RED,
     "The Crimson Kings think they own the streets. Prove them wrong.",
     "Eliminate the Crimson Kings",
     lambda st, sn: _rival_elim_by_key(st, 'crimson_kings'),
     20, "One fire burns in this city. Yours."),

    # Jade Dragon + Blackwater Mob — use them
    ('jade_blackwater', JADE,
     "The Blackwater Mob values loyalty over war. Negotiate — they can be useful.",
     "Negotiate with 2 rivals",
     lambda st, sn: st._total_rivals_defeated <= sn.get('rivals_elim', 0),
     18, "Patience and sea-craft. Both serve the Jade Serpent."),

    # Jade Dragon + Silver Hand — political mirror
    ('jade_silver', JADE,
     "The Silver Hand understands power. Thread carefully through their web.",
     "Keep Heat below 25",
     lambda st, sn: getattr(st, 'heat', 0.0) < 25.0,
     15, "Silk moves through water unseen. As do you."),

    # Black Dragon + Iron Union — logistics rivalry
    ('iron_ironunion', BLACK,
     "The Iron Union controls your freight lanes. Dominate their industrial districts.",
     "Own 3 industrial territories",
     lambda st, sn: _industrial_owned(st) >= 3,
     20, "Their machine yields to a better one."),

    # Black Dragon + Blackwater Mob — shipping route takeover
    ('iron_blackwater', BLACK,
     "The Blackwater Mob runs your shipping lanes. Take their routes. Take their docks.",
     "Own 2 waterfront/industrial districts",
     lambda st, sn: _harbor_owned(st) >= 2,
     18, "The freight is ours. The sea bows to iron."),
]


def _rival_elim_by_key(state, faction_key: str) -> bool:
    """True if the named faction is eliminated."""
    try:
        rivals = getattr(state, 'rivals', []) or []
        r = next((x for x in rivals if getattr(x, 'faction_key', '') == faction_key), None)
        return r is not None and r.status == 'Eliminated'
    except Exception:
        return False


def _industrial_owned(state) -> int:
    """Count player-owned industrial-type territories."""
    try:
        return sum(
            1 for t in getattr(state, 'territories', [])
            if getattr(t, 'owner', '') == 'player' and t.unlocked
            and getattr(t, 'district_type', '') == 'industrial'
        )
    except Exception:
        return 0


def _harbor_owned(state) -> int:
    """Count player-owned harbor/waterfront districts (industrial + Waterfront)."""
    _harbor_names = {'Waterfront', 'Rail Yards', 'Machine Quarter', 'Warehouse Row'}
    try:
        return sum(
            1 for t in getattr(state, 'territories', [])
            if getattr(t, 'owner', '') == 'player' and t.unlocked
            and (getattr(t, 'district_type', '') == 'industrial' or t.name in _harbor_names)
        )
    except Exception:
        return 0


# Key lookup for fast access
_REQ_BY_KEY = {r[0]: r for r in _REQUEST_POOL}

# ─── Active abilities ──────────────────────────────────────────────────────────
# key: (dragon, min_stage, name, desc, cooldown_seconds)
ABILITIES: dict[str, tuple] = {
    'red_strike':  (RED,   HATCHLING, 'Dragon Strike',
                    'Weaken the strongest rival by 20 power.',  120.0),
    'red_rage':    (RED,   YOUNG,     'Dragon Rage',
                    '+50% territory attack success for 30s.',   600.0),
    'jade_press':  (JADE,  HATCHLING, 'Political Pressure',
                    'Next territory action guaranteed to succeed.', 300.0),
    'jade_couns':  (JADE,  YOUNG,     "Dragon's Counsel",
                    'Instantly gain +5 Respect.',                900.0),
    'iron_drop':   (BLACK, HATCHLING, 'Supply Drop',
                    'Complete the longest-running operation instantly.', 480.0),
    'iron_logis':  (BLACK, YOUNG,     'Dragon Logistics',
                    'All active ops run at 2× speed for 60s.',  720.0),
}

# ─── Mood system ──────────────────────────────────────────────────────────────
MOOD_PLEASED   = 'pleased'
MOOD_HUNGRY    = 'hungry'
MOOD_RESTLESS  = 'restless'
MOOD_AWAKENING = 'awakening'

MOOD_COLORS = {
    MOOD_PLEASED:   (80, 200, 120),
    MOOD_HUNGRY:    (220, 150, 60),
    MOOD_RESTLESS:  (160, 130, 180),
    MOOD_AWAKENING: (240, 210, 80),
}

MOOD_LABELS = {
    MOOD_PLEASED:   'Pleased',
    MOOD_HUNGRY:    'Waiting',
    MOOD_RESTLESS:  'Restless',
    MOOD_AWAKENING: 'Awakening',
}


# ─── Lifecycle helpers ─────────────────────────────────────────────────────────

def get_stage(state) -> str:
    xp = getattr(state, 'dragon_xp', 0)
    stage = EGG
    for s in STAGE_ORDER:
        if xp >= STAGE_XP[s]:
            stage = s
    return stage


def stage_xp_progress(state) -> tuple[int, int, str]:
    """Returns (progress_xp, needed_xp, next_stage_key). next_stage_key=ANCIENT when maxed."""
    xp   = getattr(state, 'dragon_xp', 0)
    stg  = get_stage(state)
    idx  = STAGE_ORDER.index(stg)
    if idx >= len(STAGE_ORDER) - 1:
        return (xp - STAGE_XP[ANCIENT], 0, ANCIENT)
    curr_req = STAGE_XP[stg]
    next_req = STAGE_XP[STAGE_ORDER[idx + 1]]
    return (xp - curr_req, next_req - curr_req, STAGE_ORDER[idx + 1])


def _passive_mult(state) -> float:
    return _STAGE_PASSIVE_MULT.get(get_stage(state), 1.0)


def get_mood(state) -> str:
    if not active_dragon(state):
        return MOOD_PLEASED
    prog, total, _ = stage_xp_progress(state)
    if total > 0 and total > 0 and prog / total >= 0.90:
        return MOOD_AWAKENING
    if getattr(state, '_dragon_request_key', None) is not None:
        return MOOD_HUNGRY
    if getattr(state, '_dragon_mood_timer', 0.0) > 300.0:
        return MOOD_RESTLESS
    return MOOD_PLEASED


def add_dragon_xp(state, amount: int) -> None:
    """Add XP, check for evolution, queue milestone if stage advanced."""
    if not active_dragon(state):
        return
    old_stage = get_stage(state)
    state.dragon_xp = getattr(state, 'dragon_xp', 0) + max(0, amount)
    new_stage = get_stage(state)
    if new_stage != old_stage:
        _on_evolution(state, old_stage, new_stage)


def _on_evolution(state, old_stage: str, new_stage: str) -> None:
    patron = active_dragon(state)
    if not patron:
        return
    meta   = DRAGON_META[patron]
    line   = _EVOLUTION_LINES.get(patron, {}).get(new_stage, "Your dragon has grown.")
    label  = STAGE_LABELS[new_stage]
    abilities = get_available_abilities(state)
    new_ab = [ABILITIES[k] for k in abilities
              if STAGE_ORDER.index(ABILITIES[k][1]) == STAGE_ORDER.index(new_stage)]
    ab_line = (f"Ability unlocked: {new_ab[0][2]}." if new_ab
               else "Passive bonuses enhanced.")
    state._milestone_queue.append(
        f"{meta['title'].upper()}: {label.upper()}\n"
        f"{line}\n"
        f"{ab_line}"
    )
    if getattr(state, '_milestone_timer', 0.0) <= 0:
        state._milestone_timer = 8.0
    state._dragon_mood_timer = 0.0
    try:
        import src.ui as _ui
        import src.sound as _snd
        _ui.push_notification(f"Dragon evolved: {label}!", meta['color'])
        _snd.play('achievement')
    except Exception:
        pass


# ─── Request system ────────────────────────────────────────────────────────────

def get_active_request(state) -> tuple | None:
    """Return the active request tuple or None."""
    key = getattr(state, '_dragon_request_key', None)
    return _REQ_BY_KEY.get(key) if key else None


def _make_snapshot(state) -> dict:
    return {
        'territories':  _terr_owned(state),
        'rivals_elim':  getattr(state, '_total_rivals_defeated', 0),
        'ops_completed': getattr(state, '_total_ops_completed', 0),
        'influence':    getattr(state, 'influence', 0),
    }


def _active_rival_faction_keys(state) -> set:
    """Return faction_key values for all non-eliminated rivals."""
    try:
        rivals = getattr(state, 'rivals', []) or []
        return {getattr(r, 'faction_key', '') for r in rivals
                if getattr(r, 'status', '') != 'Eliminated'}
    except Exception:
        return set()


# Faction-specific request keys and the faction they require to be active
_FACTION_REQ_KEYS: dict[str, str] = {
    'red_blackwater':  'blackwater',
    'red_crimson':     'crimson_kings',
    'jade_blackwater': 'blackwater',
    'jade_silver':     'silver_hand',
    'iron_ironunion':  'iron_union',
    'iron_blackwater': 'blackwater',
}


def _issue_new_request(state) -> None:
    patron = active_dragon(state)
    if not patron:
        return
    active_factions = _active_rival_faction_keys(state)
    # Include faction-specific requests only when their faction is active
    pool = [r for r in _REQUEST_POOL
            if r[1] == patron
            and (_FACTION_REQ_KEYS.get(r[0], '') in active_factions
                 or r[0] not in _FACTION_REQ_KEYS)]
    if not pool:
        pool = [r for r in _REQUEST_POOL if r[1] == patron and r[0] not in _FACTION_REQ_KEYS]
    recent: list = getattr(state, '_dragon_recent_requests', [])
    available = [r for r in pool if r[0] not in recent[-2:]]
    if not available:
        available = pool
    chosen = random.choice(available)
    state._dragon_request_key = chosen[0]
    state._dragon_req_snapshot = _make_snapshot(state)
    try:
        import src.ui as _ui
        # Full title — push_notification word-wraps it (Phase 60); no hard cut.
        _ui.push_notification(
            f'{DRAGON_META[patron]["title"]}: {chosen[2]}',
            DRAGON_META[patron]['color']
        )
    except Exception:
        pass


def _complete_request(state, req: tuple) -> None:
    key, dragon, title, goal, _, xp, reaction = req
    add_dragon_xp(state, xp)
    # Track recently completed
    recent = getattr(state, '_dragon_recent_requests', [])
    recent.append(key)
    state._dragon_recent_requests = recent[-6:]
    state._dragon_request_key = None
    state._dragon_req_snapshot = {}
    state._dragon_request_cooldown = 90.0  # seconds before next request
    state._dragon_mood_timer = 0.0         # reset to pleased
    try:
        import src.ui as _ui
        _ui.push_notification(reaction, DRAGON_META[dragon]['color'])
    except Exception:
        pass


# ─── Ability system ────────────────────────────────────────────────────────────

def get_available_abilities(state) -> list[str]:
    patron = active_dragon(state)
    if not patron:
        return []
    stage_idx = STAGE_ORDER.index(get_stage(state))
    return [k for k, (d, min_s, *_rest) in ABILITIES.items()
            if d == patron and STAGE_ORDER.index(min_s) <= stage_idx]


def ability_cooldown_remaining(state, key: str) -> float:
    return getattr(state, 'dragon_ability_cooldowns', {}).get(key, 0.0)


def activate_ability(state, key: str) -> bool:
    """Activate an ability; returns True on success."""
    if key not in ABILITIES:
        return False
    ab = ABILITIES[key]
    dragon_key, min_stage, name, desc, cooldown = ab
    if not has_dragon(state, dragon_key):
        return False
    if key not in get_available_abilities(state):
        return False
    if ability_cooldown_remaining(state, key) > 0:
        return False

    # Apply effect
    if key == 'red_strike':
        _fx_red_strike(state)
    elif key == 'red_rage':
        state._dragon_rage_timer = 30.0
    elif key == 'jade_press':
        state._dragon_guaranteed_territory = True
    elif key == 'jade_couns':
        state.influence = getattr(state, 'influence', 0) + 5
        state.prestige_tokens = getattr(state, 'prestige_tokens', 0) + 5
        state._ips_dirty = True
    elif key == 'iron_drop':
        _fx_iron_drop(state)
    elif key == 'iron_logis':
        _fx_iron_logistics(state)

    if not hasattr(state, 'dragon_ability_cooldowns'):
        state.dragon_ability_cooldowns = {}
    state.dragon_ability_cooldowns[key] = cooldown
    state._dragon_mood_timer = 0.0

    try:
        import src.ui as _ui
        patron = active_dragon(state)
        _ui.push_notification(f"{name}!", DRAGON_META[patron]['color'])
    except Exception:
        pass
    try:
        import src.sound as _snd
        _snd.play('purchase')
    except Exception:
        pass
    return True


def _fx_red_strike(state) -> None:
    rivals = getattr(state, 'rivals', []) or []
    active = [r for r in rivals if getattr(r, 'status', '') != 'Eliminated']
    if not active:
        return
    target = max(active, key=lambda r: getattr(r, 'power', 0))
    target.power = max(0, target.power - 20)
    if target.power < 10:
        target.status = 'Weakened'
    try:
        import src.ui as _ui
        _ui.push_notification(f"Dragon Strike hit {target.name}! (-20 power)", (220, 80, 60))
    except Exception:
        pass


def _fx_iron_drop(state) -> None:
    ops = getattr(state, 'operations', []) or []
    running = [op for op in ops
               if getattr(op, 'active', False)
               and not getattr(op, 'collected', False)
               and not getattr(op, 'completed', False)]
    if not running:
        return
    target = min(running, key=lambda op: getattr(op, 'start_time', 0.0))
    target.completed = True
    try:
        import src.ui as _ui
        _ui.push_notification(f"Supply Drop: {target.name} complete!", (120, 140, 200))
    except Exception:
        pass


def _fx_iron_logistics(state) -> None:
    state._dragon_logistics_timer = 60.0
    ops = getattr(state, 'operations', []) or []
    for op in ops:
        if (getattr(op, 'active', False)
                and not getattr(op, 'collected', False)
                and not getattr(op, 'completed', False)):
            remaining = op.time_remaining
            if remaining > 0:
                op.start_time -= remaining * 0.5  # halve remaining time
    try:
        import src.ui as _ui
        _ui.push_notification("Dragon Logistics: all ops at 2× speed!", (120, 140, 200))
    except Exception:
        pass


def dragon_logistics_active(state) -> bool:
    return getattr(state, '_dragon_logistics_timer', 0.0) > 0


# ─── Dragon rage active query (used by territory) ─────────────────────────────

def dragon_rage_active(state) -> bool:
    return has_dragon(state, RED) and getattr(state, '_dragon_rage_timer', 0.0) > 0


# ─── dragon_update: called every frame from PlayingState.update() ──────────────

def dragon_update(state, dt: float) -> None:
    patron = active_dragon(state)
    if not patron:
        return

    # Tick ability cooldowns
    cds = getattr(state, 'dragon_ability_cooldowns', {})
    for k in list(cds.keys()):
        cds[k] = max(0.0, cds[k] - dt)
    state.dragon_ability_cooldowns = cds

    # Tick active ability timers
    if getattr(state, '_dragon_rage_timer', 0.0) > 0:
        state._dragon_rage_timer = max(0.0, state._dragon_rage_timer - dt)
    if getattr(state, '_dragon_logistics_timer', 0.0) > 0:
        state._dragon_logistics_timer = max(0.0, state._dragon_logistics_timer - dt)

    # Tick mood timer (counts up; > 300s = restless)
    state._dragon_mood_timer = getattr(state, '_dragon_mood_timer', 0.0) + dt

    # Tick request cooldown
    cd = getattr(state, '_dragon_request_cooldown', 0.0)
    if cd > 0:
        state._dragon_request_cooldown = max(0.0, cd - dt)

    # Check if active request is complete
    req = get_active_request(state)
    if req:
        snap = getattr(state, '_dragon_req_snapshot', {})
        try:
            if req[4](state, snap):  # condition_fn(state, snapshot)
                _complete_request(state, req)
        except Exception:
            pass

    # Issue new request when idle and cooldown expired
    if (not get_active_request(state)
            and getattr(state, '_dragon_request_cooldown', 0.0) <= 0
            and getattr(state, '_dragon_request_key', None) is None):
        _issue_new_request(state)
        state._dragon_request_cooldown = 999.0  # prevent re-issue until completed or cooldown


# ─── Unlock / identity accessors ──────────────────────────────────────────────

def active_dragon(state) -> str | None:
    return getattr(state, 'dragon_patron', None)


def has_dragon(state, key: str) -> bool:
    return active_dragon(state) == key


def dragon_unlocked(state) -> bool:
    return getattr(state, '_prestige_count', 0) >= 1


# ─── Income-side effect accessors (stage-scaled) ──────────────────────────────

def rival_presence_income_mult(state) -> float:
    """Red Dragon: +3% per active rival, max +15%."""
    if not has_dragon(state, RED):
        return 1.0
    rivals = getattr(state, 'rivals', []) or []
    active = sum(1 for r in rivals if getattr(r, 'status', '') != 'Eliminated')
    base = 1.0 + min(0.15, active * 0.03)
    return 1.0 + (base - 1.0) * _passive_mult(state)


def eliminated_rival_income_mult(state) -> float:
    """Red Dragon: +4% per rival eliminated this run, max +20%."""
    if not has_dragon(state, RED):
        return 1.0
    count = getattr(state, '_dragon_red_elim_count', 0)
    base = 1.0 + min(0.20, count * 0.04)
    return 1.0 + (base - 1.0) * _passive_mult(state)


def active_ops_income_bonus(state) -> float:
    """Black Dragon: +0.5% income per currently running operation, max +2.5%."""
    if not has_dragon(state, BLACK):
        return 0.0
    ops = getattr(state, 'operations', []) or []
    running = sum(1 for op in ops
                  if getattr(op, 'active', False) and not getattr(op, 'collected', False))
    return min(0.025, running * 0.005) * _passive_mult(state)


# ─── Combat / rival effect accessors ──────────────────────────────────────────

def rival_aggression_mult(state) -> float:
    return 1.20 if has_dragon(state, RED) else 1.0


def raid_damage_mult(state) -> float:
    if has_dragon(state, RED):
        return 1.10
    if has_dragon(state, JADE):
        return 1.20
    return 1.0


def rival_growth_mult(state) -> float:
    return 1.15 if has_dragon(state, BLACK) else 1.0


# ─── Territory effect accessors ───────────────────────────────────────────────

def territory_action_modifier(state, action_type: str) -> float:
    """Additive success modifier for the given territory action type."""
    bonus = 0.0
    if action_type in ('attack', 'sabotage'):
        if has_dragon(state, RED):
            bonus += 0.15
            if dragon_rage_active(state):
                bonus += 0.50  # Dragon Rage: +50% extra
        if has_dragon(state, JADE):
            bonus -= 0.20
    elif action_type in ('negotiate', 'bribe'):
        if has_dragon(state, JADE):
            bonus += 0.40 * _passive_mult(state)
    if has_dragon(state, BLACK):
        bonus -= 0.15
    return bonus


# ─── Heat effect accessors ────────────────────────────────────────────────────

def heat_decay_bonus(state) -> float:
    """Jade Dragon: per-territory extra decay /s."""
    if not has_dragon(state, JADE):
        return 0.0
    territories = getattr(state, 'territories', []) or []
    owned = sum(1 for t in territories if getattr(t, 'owner', '') == 'player')
    return min(0.25, owned * 0.025) * _passive_mult(state)


def heat_decay_penalty(state) -> float:
    """Red Dragon COST: heat decays 0.04/s slower."""
    return 0.04 if has_dragon(state, RED) else 0.0


# ─── Operations effect accessors ─────────────────────────────────────────────

def op_reward_mult(state) -> float:
    """Jade Dragon COST: −15% op rewards.  Black Dragon combo: +35% if active."""
    m = 1.0
    if has_dragon(state, JADE):
        m *= 0.85
    if has_dragon(state, BLACK):
        m *= op_combo_mult(state)
    return m


def op_combo_mult(state) -> float:
    """Black Dragon: +35% if an op was collected within the last 90 seconds."""
    if not has_dragon(state, BLACK):
        return 1.0
    last = getattr(state, '_dragon_black_last_op_time', None)
    if last is None:
        return 1.0
    return 1.35 if (time.time() - last) <= 90.0 else 1.0


def op_heat_gain_mult(state) -> float:
    return 1.25 if has_dragon(state, BLACK) else 1.0


# ─── Crew effect accessors ────────────────────────────────────────────────────

def crew_capacity_mult(state) -> float:
    return 1.25 if has_dragon(state, BLACK) else 1.0


def collection_efficiency_mult(state) -> float:
    return 1.50 * _passive_mult(state) if has_dragon(state, BLACK) else 1.0


# ─── Prestige effect accessor ─────────────────────────────────────────────────

def prestige_influence_mult(state) -> float:
    """Jade Dragon: +30% Influence gained at every prestige."""
    if not has_dragon(state, JADE):
        return 1.0
    return 1.30 * _passive_mult(state)


# ─── Event hooks ──────────────────────────────────────────────────────────────

def on_rival_eliminated(state, rival) -> None:
    if not active_dragon(state):
        return
    if has_dragon(state, RED):
        state._dragon_red_elim_count = getattr(state, '_dragon_red_elim_count', 0) + 1
    add_dragon_xp(state, 3 if has_dragon(state, RED) else 1)
    state._ips_dirty = True


def on_op_collected(state) -> None:
    if has_dragon(state, BLACK):
        state._dragon_black_last_op_time = time.time()
    add_dragon_xp(state, 2 if has_dragon(state, BLACK) else 1)


def on_territory_captured(state) -> None:
    add_dragon_xp(state, 2 if has_dragon(state, JADE) else 1)


def on_prestige(state) -> None:
    """Called at prestige: grant XP, never reset XP."""
    add_dragon_xp(state, 25)


def reset_for_prestige(state) -> None:
    """Clear per-run Dragon counters at prestige. XP is never reset."""
    state._dragon_red_elim_count = 0
    state._dragon_black_last_op_time = None
    # Clear active request so a fresh one issues next cycle
    state._dragon_request_key = None
    state._dragon_req_snapshot = {}
    state._dragon_request_cooldown = 30.0


# ─── Selection ────────────────────────────────────────────────────────────────

def select_dragon(state, key: str) -> tuple[bool, str]:
    if key not in DRAGON_META:
        return False, "Unknown patron"
    if not dragon_unlocked(state):
        return False, "Complete your first prestige first"
    current = active_dragon(state)
    if current == key:
        return False, "Already your patron"
    if current is not None:
        if getattr(state, 'prestige_tokens', 0) < DRAGON_CHANGE_COST:
            return False, f"Switching costs {DRAGON_CHANGE_COST} Influence"
        state.prestige_tokens -= DRAGON_CHANGE_COST
    state.dragon_patron = key
    # Migrate: existing patron sets XP to at least Hatchling threshold
    if getattr(state, 'dragon_xp', 0) == 0 and current is None:
        state.dragon_xp = 0  # fresh start — egg
    state._ips_dirty = True
    state._dragon_request_key = None
    state._dragon_req_snapshot = {}
    state._dragon_request_cooldown = 10.0  # first request soon
    return True, ""


# ─── DragonPatronState (full-screen overlay UI) ───────────────────────────────

_CARD_W = 230
_CARD_H = 295
_GAP    = 18


class DragonPatronState:
    """Full-screen overlay for Dragon Patron selection and display."""

    _PANEL = pygame.Rect(50, 50, config.SCREEN_WIDTH - 100, config.SCREEN_HEIGHT - 100)

    def __init__(self, state_manager, playing):
        self.state_manager = state_manager
        self._playing = playing
        self._fonts = playing._fonts
        self._pending = None
        self._confirm_change = False
        self._hovered: str | None = None

        cx = self._PANEL.centerx
        bot = self._PANEL.bottom - 18
        self._back_r = pygame.Rect(cx - 80, bot - 38, 140, 38)

    def on_enter(self): pass
    def on_exit(self):  pass

    def handle_events(self, events):
        for ev in events:
            if ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE:
                if self._pending:
                    self._pending = None
                    self._confirm_change = False
                else:
                    self.state_manager.pop()
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                self._handle_click(ev.pos)

    def update(self, dt): pass

    def _handle_click(self, pos):
        if self._pending:
            cx = self._PANEL.centerx
            cy = config.SCREEN_HEIGHT // 2
            yes_r = pygame.Rect(cx - 110, cy + 50, 100, 42)
            no_r  = pygame.Rect(cx + 10,  cy + 50, 100, 42)
            if yes_r.collidepoint(pos):
                ok, msg = select_dragon(self._playing, self._pending)
                if ok:
                    try:
                        import src.sound as sound
                        sound.play('purchase')
                    except Exception:
                        pass
                    try:
                        import src.ui as _ui
                        meta = DRAGON_META[self._pending]
                        _ui.push_notification(
                            f"Dragon Patron: {meta['title']}", meta['color'])
                    except Exception:
                        pass
                self._pending = None
                self._confirm_change = False
            elif no_r.collidepoint(pos):
                self._pending = None
                self._confirm_change = False
            return

        if self._back_r.collidepoint(pos):
            self.state_manager.pop()
            return

        if not dragon_unlocked(self._playing):
            return

        total_w = len(DRAGON_ORDER) * _CARD_W + (len(DRAGON_ORDER) - 1) * _GAP
        start_x = self._PANEL.centerx - total_w // 2
        card_y = self._PANEL.top + 140
        for i, key in enumerate(DRAGON_ORDER):
            r = pygame.Rect(start_x + i * (_CARD_W + _GAP), card_y, _CARD_W, _CARD_H)
            if r.collidepoint(pos):
                current = active_dragon(self._playing)
                if key == current:
                    return
                self._pending = key
                self._confirm_change = (current is not None)
                return

    def draw(self, surface):
        self._playing.draw(surface)

        ov = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
        ov.fill((*theme.OVERLAY_DARK, 215))
        surface.blit(ov, (0, 0))

        p = self._PANEL
        pygame.draw.rect(surface, theme.BG_PANEL, p, border_radius=14)

        current = active_dragon(self._playing)
        border_col = DRAGON_META[current]['color'] if current else theme.ACCENT_DIM
        pygame.draw.rect(surface, border_col, p, border_radius=14, width=2)

        ts = self._fonts['lg'].render("DRAGON PATRON", True, theme.TEXT_GOLD)
        surface.blit(ts, ts.get_rect(center=(p.centerx, p.top + 24)))

        # If a dragon is active, show current stage + XP below title
        if current:
            stage_lbl = STAGE_LABELS[get_stage(self._playing)]
            xp = getattr(self._playing, 'dragon_xp', 0)
            prog, total, _ = stage_xp_progress(self._playing)
            xp_text = (f"{stage_lbl}  •  {prog}/{total} XP" if total > 0
                       else f"{stage_lbl}  •  ANCIENT (maxed)")
            xs = self._fonts['xs'].render(xp_text, True, DRAGON_META[current]['color'])
            surface.blit(xs, xs.get_rect(center=(p.centerx, p.top + 46)))

        if not dragon_unlocked(self._playing):
            self._draw_locked(surface)
        else:
            self._draw_cards(surface)

        mx, my = pygame.mouse.get_pos()
        hover = self._back_r.collidepoint(mx, my)
        bc = tuple(min(255, v + 30) for v in theme.BG_CARD) if hover else theme.BG_CARD
        pygame.draw.rect(surface, bc, self._back_r, border_radius=8)
        pygame.draw.rect(surface, theme.ACCENT_DIM, self._back_r, border_radius=8, width=1)
        bl = self._fonts['sm'].render("Back", True, theme.TEXT_PRIMARY)
        surface.blit(bl, bl.get_rect(center=self._back_r.center))

        hint = self._fonts['xs'].render("ESC: back", True, theme.TEXT_MUTED)
        surface.blit(hint, hint.get_rect(center=(p.centerx, p.bottom - 8)))

        if self._pending:
            self._draw_confirm(surface)

    def _draw_locked(self, surface):
        p = self._PANEL
        msg = self._fonts['md'].render(
            "Complete your first prestige to unlock Dragon Patrons.",
            True, theme.TEXT_MUTED)
        surface.blit(msg, msg.get_rect(center=(p.centerx, p.centery - 20)))
        sub = self._fonts['xs'].render(
            "Dragon Patrons grow with you across every run — a permanent companion.",
            True, (80, 76, 100))
        surface.blit(sub, sub.get_rect(center=(p.centerx, p.centery + 10)))

    def _draw_cards(self, surface):
        p = self._PANEL
        mx, my = pygame.mouse.get_pos()
        current = active_dragon(self._playing)

        sub_label = (f"Active patron: {DRAGON_META[current]['title']}" if current
                     else "Choose your patron — grows with you across all runs")
        sub_col = DRAGON_META[current]['color'] if current else theme.TEXT_MUTED
        ss = self._fonts['xs'].render(sub_label, True, sub_col)
        surface.blit(ss, ss.get_rect(center=(p.centerx, p.top + 64)))

        total_w = len(DRAGON_ORDER) * _CARD_W + (len(DRAGON_ORDER) - 1) * _GAP
        start_x = p.centerx - total_w // 2
        card_y = p.top + 82

        self._hovered = None
        for i, key in enumerate(DRAGON_ORDER):
            meta = DRAGON_META[key]
            r = pygame.Rect(start_x + i * (_CARD_W + _GAP), card_y, _CARD_W, _CARD_H)
            is_current = (key == current)
            hover = r.collidepoint(mx, my)
            if hover:
                self._hovered = key

            if is_current:
                bg = tuple(int(v * 0.35) for v in meta['color'])
                border = meta['color']
                border_w = 2
            elif hover:
                bg = tuple(int(v * 0.20) for v in meta['color'])
                border = meta['color']
                border_w = 1
            else:
                bg = theme.BG_CARD
                border = theme.ACCENT_DIM
                border_w = 1

            pygame.draw.rect(surface, bg, r, border_radius=12)
            pygame.draw.rect(surface, border, r, border_radius=12, width=border_w)

            title_s = self._fonts['md'].render(meta['title'], True, meta['color'])
            surface.blit(title_s, title_s.get_rect(centerx=r.centerx, y=r.y + 10))

            tag_s = self._fonts['xs'].render(meta['tag'], True, theme.TEXT_MUTED)
            surface.blit(tag_s, tag_s.get_rect(centerx=r.centerx, y=r.y + 30))

            # Stage badge if this is the active patron
            if is_current:
                slbl = STAGE_LABELS[get_stage(self._playing)]
                prog, total, _ = stage_xp_progress(self._playing)
                xp_str = f"{slbl} · {prog}/{total} XP" if total > 0 else f"{slbl}"
                xps = self._fonts['xs'].render(xp_str, True, meta['color'])
                surface.blit(xps, xps.get_rect(centerx=r.centerx, y=r.y + 46))
                start_y = r.y + 64
            else:
                self._draw_wrapped(surface, meta['blurb'], self._fonts['xs'],
                                   theme.TEXT_PRIMARY, r.x + 10, r.y + 46, r.width - 20)
                start_y = r.y + 78

            y = start_y
            surface.blit(self._fonts['xs'].render("STRENGTHS", True, theme.GREEN), (r.x + 10, y))
            y += 16
            for line in meta['strengths']:
                s = self._fonts['xs'].render(f"+ {line}", True, theme.GREEN)
                if s.get_width() > r.width - 20:
                    s = self._fonts['xs'].render(f"+ {line[:36]}…", True, theme.GREEN)
                surface.blit(s, (r.x + 10, y))
                y += 15

            y += 4
            surface.blit(self._fonts['xs'].render("COSTS", True, (200, 100, 80)), (r.x + 10, y))
            y += 16
            for line in meta['costs']:
                s = self._fonts['xs'].render(f"− {line}", True, (200, 100, 80))
                if s.get_width() > r.width - 20:
                    s = self._fonts['xs'].render(f"− {line[:36]}…", True, (200, 100, 80))
                surface.blit(s, (r.x + 10, y))
                y += 15

            btn = pygame.Rect(r.x + 10, r.bottom - 38, r.width - 20, 28)
            if is_current:
                pygame.draw.rect(surface, tuple(int(v * 0.5) for v in meta['color']),
                                 btn, border_radius=6)
                bl = self._fonts['xs'].render("ACTIVE PATRON", True, meta['color'])
            elif current is None:
                pygame.draw.rect(surface, theme.ACCENT, btn, border_radius=6)
                bl = self._fonts['xs'].render("Choose", True, theme.BG_DARK)
            else:
                pygame.draw.rect(surface, theme.BG_DARK, btn, border_radius=6)
                pygame.draw.rect(surface, theme.ACCENT_DIM, btn, border_radius=6, width=1)
                bl = self._fonts['xs'].render(
                    f"Switch (−{DRAGON_CHANGE_COST} Inf)", True, theme.TEXT_MUTED)
            surface.blit(bl, bl.get_rect(center=btn.center))

    def _draw_wrapped(self, surface, text, font, color, x, y, max_w) -> int:
        words = text.split()
        line = ""
        for w in words:
            test = (line + " " + w).strip()
            if font.size(test)[0] <= max_w:
                line = test
            else:
                if line:
                    surface.blit(font.render(line, True, color), (x, y))
                    y += font.get_height() + 2
                line = w
        if line:
            surface.blit(font.render(line, True, color), (x, y))
        return y

    def _draw_confirm(self, surface):
        from src.ui import draw_overlay
        draw_overlay(surface, 210)
        meta = DRAGON_META[self._pending]
        cx = self._PANEL.centerx
        cy = config.SCREEN_HEIGHT // 2
        current = active_dragon(self._playing)
        w, h = 460, 230
        panel = pygame.Rect(cx - w // 2, cy - h // 2, w, h)
        pygame.draw.rect(surface, theme.BG_PANEL, panel, border_radius=14)
        pygame.draw.rect(surface, meta['color'], panel, border_radius=14, width=2)

        if self._confirm_change:
            title = f"Switch to {meta['title']}?"
            cost_line = f"Costs {DRAGON_CHANGE_COST} Influence to switch."
        else:
            title = f"Choose {meta['title']}?"
            cost_line = "Free — you have no current patron."

        ts = self._fonts['lg'].render(title, True, meta['color'])
        surface.blit(ts, ts.get_rect(center=(cx, cy - 76)))
        lines = [meta['tag'], meta['blurb'], cost_line,
                 "This patron grows with you across all runs.",
                 "Dragon XP persists forever."]
        for i, ln in enumerate(lines):
            col = theme.TEXT_PRIMARY if i < 2 else theme.TEXT_MUTED
            s = self._fonts['xs'].render(ln, True, col)
            surface.blit(s, s.get_rect(center=(cx, cy - 30 + i * 18)))

        yes_r = pygame.Rect(cx - 110, cy + 60, 100, 42)
        no_r  = pygame.Rect(cx + 10,  cy + 60, 100, 42)
        mx2, my2 = pygame.mouse.get_pos()
        yc = tuple(min(255, v + 20) for v in theme.BTN_YES) if yes_r.collidepoint(mx2, my2) else theme.BTN_YES
        nc = tuple(min(255, v + 20) for v in theme.BTN_NO)  if no_r.collidepoint(mx2, my2)  else theme.BTN_NO
        pygame.draw.rect(surface, yc, yes_r, border_radius=8)
        pygame.draw.rect(surface, nc, no_r,  border_radius=8)
        for rect, label in ((yes_r, "Confirm"), (no_r, "Cancel")):
            s = self._fonts['sm'].render(label, True, theme.TEXT_PRIMARY)
            surface.blit(s, s.get_rect(center=rect.center))
