"""Save / load system with corruption protection and version migration."""
from __future__ import annotations
import json
import os
import shutil
import time

SAVE_PATH   = "save.json"
BACKUP_PATH = "save.json.bak"

def _env_float(key: str, default: float) -> float:
    try:
        return float(os.environ[key])
    except (KeyError, ValueError):
        return default

# A/B-tunable offline economy constants:
#   IDLE_OFFLINE_CAP_H=8 python main.py    ← shorter cap to encourage daily returns
#   IDLE_OFFLINE_EFF=0.8 python main.py    ← more generous offline efficiency
_OFFLINE_CAP_SECONDS = _env_float("IDLE_OFFLINE_CAP_H", 12.0) * 3600.0
_OFFLINE_EFFICIENCY  = _env_float("IDLE_OFFLINE_EFF", 0.6)

# ─── Migration ────────────────────────────────────────────────────────────────

def _simulate_offline_rivals(state, elapsed_secs: float) -> list[str]:
    """Lightweight offline rival activity simulation.

    Only adjusts rival turf/power (never steals player territories) and returns
    narrative event strings for display in the return overlay. Deterministic via
    a seed derived from elapsed time so multiple calls return the same result.
    """
    import random as _rng
    rivals = getattr(state, 'rivals', []) or []
    if not rivals or elapsed_secs < 60:
        return []

    rng = _rng.Random(int(elapsed_secs * 37) & 0xFFFFFFFF)
    active = [r for r in rivals if getattr(r, 'status', '') != 'Eliminated']
    if not active:
        return []

    # Tick count: one AI round every ~135 s on average, cap at 30 to stay fast
    ticks = min(30, max(1, int(elapsed_secs / 135)))
    events: list[str] = []

    for _ in range(ticks):
        for rival in active:
            roll = rng.random()
            aggression = float(getattr(rival, 'aggression', 0.5))
            if roll > aggression * 0.25:
                continue

            action = rng.choices(
                ['expand', 'rival_war', 'weaken', 'weaken'],
                weights=[3, 2, 2, 2],
            )[0]

            if action == 'expand':
                max_turf = 8
                if getattr(rival, 'turf', 0) < max_turf:
                    rival.turf = min(max_turf, getattr(rival, 'turf', 0) + 1)
                    if len(events) < 3:
                        events.append(f"{rival.name} captured a district")

            elif action == 'rival_war' and len(active) > 1:
                others = [r for r in active if r is not rival]
                target = rng.choice(others)
                loser_power_loss = rng.randint(2, 6)
                target.power = max(0, getattr(target, 'power', 0) - loser_power_loss)
                if target.power < 10:
                    target.status = 'Weakened'
                if len(events) < 3:
                    events.append(f"{rival.name} clashed with {target.name}")

            elif action == 'weaken':
                rival.power = max(0, getattr(rival, 'power', 0) - rng.randint(1, 4))
                if rival.power < 10:
                    rival.status = 'Weakened'
                if rng.random() < 0.25 and len(events) < 3:
                    events.append(f"{rival.name} lost ground in street conflict")

    return events


def _migrate(data: dict) -> dict:
    """Forward-migrate old save data to current schema. Non-destructive."""
    data.setdefault('influence', 0)
    data.setdefault('heat', 0.0)
    data.setdefault('territories', [])
    data.setdefault('rivals', [])
    data.setdefault('crew', {})
    data.setdefault('operations', [])
    mgr_list = data.get('managers', [])
    if len(mgr_list) < 13:
        mgr_list.extend([False] * (13 - len(mgr_list)))
        data['managers'] = mgr_list
    if 'prestige_count' not in data and 'prestige_tokens' in data:
        data['prestige_count'] = 0
    # v2→v3: prestige_tokens now stores cumulative influence (same field, same meaning)
    # Old perk names migrated to new perk key names
    old_perk_map = {
        'iron_fist':        'click_power_1',
        'street_smarts':    'income_1',
        'fast_hands':       'click_power_2',
        'crew_loyalty':     None,
        'money_laundering': 'income_2',
        'the_network':      None,
        'enforcer':         'click_power_2',
        'crime_lord':       'empire_bonus',
        'untouchable':      'offline_1',
    }
    old_perks = data.get('perks_purchased', [])
    if old_perks and any(k in old_perk_map for k in old_perks):
        new_perks = []
        seen = set()
        for k in old_perks:
            mapped = old_perk_map.get(k, k)
            if mapped and mapped not in seen:
                new_perks.append(mapped)
                seen.add(mapped)
        data['perks_purchased'] = new_perks
    return data


# ─── Apply ────────────────────────────────────────────────────────────────────

def apply_save_data(state, data: dict) -> None:
    """Populate state from a loaded save dict. Handles offline earnings and daily reward."""
    data = _migrate(data)

    state.balance            = float(data.get('balance', 0))
    state.lifetime_earnings  = float(data.get('lifetime_earnings', 0))
    state._prestige_route_earnings = float(
        data.get('prestige_route_earnings', state.lifetime_earnings)
    )
    state.prestige_tokens    = int(data.get('prestige_tokens', 0))
    state.influence          = int(data.get('influence', 0))
    state._click_count       = int(data.get('click_count', 0))
    state._play_time         = float(data.get('play_time', 0.0))
    state._coins_caught      = int(data.get('coins_caught', 0))
    state._prestige_count    = int(data.get('prestige_count', 0))
    import src.prestige as _prestige_mod
    state._next_prestige_earnings = float(data.get('next_prestige_earnings',
                                                   _prestige_mod.FIRST_PRESTIGE_EARNINGS))
    state._daily_streak      = int(data.get('daily_streak', 1))
    state.perks_purchased    = list(data.get('perks_purchased', []))
    # Session 9 branching tree: committed branch for the current cycle. Old saves
    # default to None (unchosen) — their grandfathered legacy perks still apply
    # via apply_perks regardless of branch, so they lose nothing.
    _branch = data.get('prestige_branch', None)
    import src.prestige_tree as _ptree_mod
    state.prestige_branch = _branch if _branch in _ptree_mod.BRANCH_PERKS else None
    # Dragon Patron: persists across runs. Old saves default to None (no patron yet).
    import src.dragon as _dragon_mod
    _dkey = data.get('dragon_patron', None)
    state.dragon_patron = _dkey if _dkey in _dragon_mod.DRAGON_META else None
    state._dragon_red_elim_count = int(data.get('dragon_red_elim_count', 0))
    state._dragon_black_last_op_time = None  # not persisted; resets on load
    # Dragon lifecycle (Session 11). Existing saves with a patron get Hatchling XP immediately.
    _raw_xp = data.get('dragon_xp', None)
    if _raw_xp is None:
        # Migration: if they already had a patron, skip the egg phase
        state.dragon_xp = _dragon_mod.STAGE_XP[_dragon_mod.HATCHLING] if state.dragon_patron else 0
    else:
        state.dragon_xp = max(0, int(_raw_xp))
    _raw_cds = data.get('dragon_ability_cooldowns', {})
    state.dragon_ability_cooldowns = {k: float(v) for k, v in _raw_cds.items()
                                      if k in _dragon_mod.ABILITIES}
    # Non-persisted request state — fresh request issues on first dragon_update()
    state._dragon_request_key = None
    state._dragon_req_snapshot = {}
    state._dragon_request_cooldown = 15.0
    state._dragon_recent_requests = []
    state._dragon_mood_timer = 0.0
    state._dragon_rage_timer = 0.0
    state._dragon_logistics_timer = 0.0
    state._dragon_guaranteed_territory = False
    state._dragon_ability_btn_rects = {}
    state._arms_influence_frac = float(data.get('arms_influence_frac', 0.0))
    state._tutorial_step     = int(data.get('tutorial_step', 0))
    state._tutorial_age      = 0.0
    state._tutorial_age_step4 = 0.0
    state._shown_milestones  = set(data.get('shown_milestones', []))
    state._shown_raid_tutorial = bool(data.get('shown_raid_tutorial', False))
    state._shown_ops_tutorial       = bool(data.get('shown_ops_tutorial', False))
    state._shown_influence_tutorial = bool(data.get('shown_influence_tutorial', False))
    state._shown_heat_warning           = bool(data.get('shown_heat_warning', False))
    state._shown_prestige_tree_tutorial = bool(data.get('shown_prestige_tree_tutorial', False))
    state._shown_syndicate_tutorial     = bool(data.get('shown_syndicate_tutorial', False))
    state._shown_influence_intro        = bool(data.get('shown_influence_intro', False))
    state._shown_crew_tutorial          = bool(data.get('shown_crew_tutorial', False))
    state._shown_territory_tutorial     = bool(data.get('shown_territory_tutorial', False))
    state._shown_rivals_tutorial        = bool(data.get('shown_rivals_tutorial', False))
    state._post_prestige_notif          = bool(data.get('post_prestige_notif', False))
    state._notif_near_prestige_80       = bool(data.get('notif_near_prestige_80', False))
    state._push_near_prestige_fired     = bool(data.get('push_near_prestige_fired', False))
    state._peak_income       = float(data.get('peak_income', 0.0))
    state._longest_streak    = int(data.get('longest_streak', 1))
    # Lifetime statistics
    state._total_buildings_purchased  = int(data.get('total_buildings_purchased', 0))
    state._total_territories_captured = int(data.get('total_territories_captured', 0))
    state._total_rivals_defeated      = int(data.get('total_rivals_defeated', 0))
    state._total_ops_completed        = int(data.get('total_ops_completed', 0))
    state._total_heat_generated       = float(data.get('total_heat_generated', 0.0))
    state._total_respect_earned       = int(data.get('total_respect_earned', 0))
    state._total_influence_earned     = int(data.get('total_influence_earned', 0))
    state._highest_cash_held          = float(data.get('highest_cash_held', 0.0))
    state._highest_city_control       = float(data.get('highest_city_control', 0.0))
    state._city_control_milestones    = set(data.get('city_control_milestones', []))

    # Heat
    state.heat = float(data.get('heat', 0.0))

    # Audio / display settings
    state._sfx_volume    = float(data.get('sfx_volume', 1.0))
    state._fps_cap       = int(data.get('fps_cap', 60))
    state._music_volume  = float(data.get('music_volume', 0.5))
    state._master_volume = float(data.get('master_volume', 1.0))
    state._mute_all      = bool(data.get('mute_all', False))

    # Analytics opt-in (default True; respects player choice across sessions)
    import src.analytics as _analytics_mod
    _analytics_mod.set_enabled(bool(data.get('analytics_enabled', True)))

    # Apply loaded SFX volume immediately
    import src.sound as _sound
    effective = 0.0 if state._mute_all else state._sfx_volume * state._master_volume
    _sound.set_volume(effective)

    # Territories — restore unlocked flags and owner by index
    # Supports both old format (list of bools) and new format (list of dicts)
    territory_data = data.get('territories', [])
    territories = getattr(state, 'territories', [])
    for i, td in enumerate(territory_data):
        if i < len(territories):
            if isinstance(td, dict):
                territories[i].unlocked = bool(td.get('unlocked', False))
                territories[i].owner    = td.get('owner', 'unclaimed')
            else:
                territories[i].unlocked = bool(td)
                territories[i].owner    = 'player' if bool(td) else 'unclaimed'

    # Restore rank for change detection
    import src.prestige as _prestige
    state._last_rank = _prestige.get_rank(state.prestige_tokens)

    # Managers (11-slot)
    mgr_list = data.get('managers', [])
    for i, m in enumerate(state.managers):
        m.hired = bool(mgr_list[i]) if i < len(mgr_list) else False

    # Buildings (variable length)
    owned_list = data.get('buildings', [])
    for i, b in enumerate(state.buildings):
        b.owned = int(owned_list[i]) if i < len(owned_list) else 0
        b.income_multiplier = 1.0  # always reset; upgrades re-apply below

    # Upgrades
    purchased_list = data.get('upgrades', [])
    for i, u in enumerate(state.upgrades):
        if i < len(purchased_list) and purchased_list[i]:
            u.purchased = True
            u.apply(state)

    # Achievements
    earned_list = data.get('achievements', [])
    for i, a in enumerate(state.achievements):
        if i < len(earned_list) and earned_list[i]:
            a.earned = True

    # Goals — restore completed flags
    import src.goals as _goals_mod
    completed_keys = set(data.get('goals_completed', []))
    goals = getattr(state, 'goals', _goals_mod.make_goals())
    for g in goals:
        if g.key in completed_keys:
            g.completed = True
    state.goals = goals

    # Rivals — restore per-faction state
    import src.rivals as rivals_mod
    rival_data = data.get('rivals', [])
    rivals = getattr(state, 'rivals', rivals_mod.make_rivals())
    for i, rd in enumerate(rival_data):
        if i < len(rivals):
            # Support both old field name ('territory') and new ('turf')
            rivals[i].turf          = int(rd.get('turf', rd.get('territory', rivals[i].turf)))
            rivals[i].wealth        = float(rd.get('wealth', rivals[i].wealth))
            rivals[i].power         = int(rd.get('power', rivals[i].power))
            rivals[i].aggression    = float(rd.get('aggression', rivals[i].aggression))
            rivals[i].at_war        = bool(rd.get('at_war', False))
            rivals[i].status        = rd.get('status', 'Active')
            rivals[i]._last_action  = rd.get('last_action', 'Watching...')
    state.rivals = rivals

    # Crew assignments
    import src.crew as crew_mod
    crew_data = data.get('crew', {})
    state.crew = crew_mod.CrewAssignment.from_dict(crew_data) if crew_data else crew_mod.CrewAssignment()
    # Legacy saves (or saves written before the prestige rebalance) may hold
    # crew assignments exceeding the building-derived capacity; fit them now so
    # effects and operations behave consistently.
    try:
        state.crew.clamp_to_capacity(sum(b.owned for b in getattr(state, 'buildings', [])))
    except Exception:
        pass

    # Operations — restore active timers
    import src.operations as ops_mod
    ops_data = data.get('operations', [])
    ops = getattr(state, 'operations', ops_mod.make_operations())
    for i, od in enumerate(ops_data):
        if i < len(ops):
            ops[i].active     = bool(od.get('active', False))
            ops[i].start_time = float(od.get('start_time', 0.0))
            ops[i].reward     = float(od.get('reward', 0.0))
            ops[i].completed  = bool(od.get('completed', False))
            ops[i].collected  = bool(od.get('collected', False))
            ops[i].speed_mult = float(od.get('speed_mult', 1.0))
    state.operations = ops

    # Prestige perks
    from src.prestige_tree import apply_perks
    apply_perks(state)

    # ── Return summary snapshot (used by offline overlay) ────────────────────
    # Compute before offline earnings so values reflect what the player left behind.
    _territories = getattr(state, 'territories', [])
    state._return_territory_player = sum(1 for t in _territories if t.unlocked)
    state._return_territory_total  = len(_territories)
    _rivals = getattr(state, 'rivals', []) or []
    state._return_rival_active  = sum(1 for r in _rivals
                                      if getattr(r, 'status', '') != 'Eliminated')
    state._return_rival_at_war  = sum(1 for r in _rivals
                                      if getattr(r, 'at_war', False))

    # Count operations that completed while the player was offline (active + elapsed >= duration)
    state._return_ops_ready = sum(
        1 for op in getattr(state, 'operations', [])
        if op.is_ready
    )

    # Offline earnings. Mobile-tuned for daily check-ins: a 12h cap covers an
    # overnight return, and base efficiency is 60% (75% with the Night Shift
    # perk). The longer cap + higher efficiency make returning the next day feel
    # rewarding (D1->D7 retention) rather than punishing a player for sleeping.
    saved_ts = data.get('save_timestamp')
    if saved_ts is not None:
        raw_away = max(0.0, time.time() - saved_ts)
        elapsed = min(raw_away, _OFFLINE_CAP_SECONDS)
        # Night Shift perk (offline_1) boosts offline efficiency by +25%. The old
        # code checked a 'untouchable' key that no longer exists after migration
        # (untouchable -> offline_1), so the perk silently did nothing — fixed here.
        from src.prestige_tree import offline_earnings_mult
        eff = min(1.0, _OFFLINE_EFFICIENCY * offline_earnings_mult(state))
        offline = state.income_per_second * elapsed * eff
        if offline > 0:
            state.balance          += offline
            state.lifetime_earnings += offline
            import src.money_debug as _md
            _md.credit(state, offline, 'money_from_other')
            state._offline_gain    = offline
            state._offline_secs_away = elapsed
            state._offline_capped  = raw_away > _OFFLINE_CAP_SECONDS
            state._show_offline_overlay = True

        # Simulate rival activity during offline period (always, even if no cash)
        if raw_away >= 60:
            state._offline_rival_events = _simulate_offline_rivals(state, min(raw_away, _OFFLINE_CAP_SECONDS))
        else:
            state._offline_rival_events = []

    # Daily reward — once per calendar day
    last_login = data.get('last_login_date', '')
    today = time.strftime('%Y-%m-%d')
    if last_login != today:
        yesterday = time.strftime('%Y-%m-%d', time.localtime(time.time() - 86400))
        if last_login == yesterday:
            state._daily_streak = min(7, state._daily_streak + 1)
        else:
            state._daily_streak = 1
        # Floor: at minimum worth 3× the cheapest building so day-1 return feels real.
        # Scale: 5 minutes of income × streak (generous for engaged players).
        cheapest = state.buildings[0].current_cost if getattr(state, 'buildings', None) else 30.0
        reward = max(cheapest * 3, state.income_per_second * 300 * state._daily_streak)
        state._daily_reward = reward
        state.balance          += reward
        state.lifetime_earnings += reward
        state._show_daily_overlay = not state._show_offline_overlay


# ─── Save ────────────────────────────────────────────────────────────────────

def save_game(state) -> None:
    data = {
        'balance':           state.balance,
        'lifetime_earnings': state.lifetime_earnings,
        'prestige_route_earnings': float(getattr(state, '_prestige_route_earnings', 0.0)),
        'prestige_tokens':   state.prestige_tokens,
        'influence':         getattr(state, 'influence', 0),
        'click_count':       state._click_count,
        'play_time':         getattr(state, '_play_time', 0.0),
        'coins_caught':      getattr(state, '_coins_caught', 0),
        'prestige_count':    getattr(state, '_prestige_count', 0),
        'next_prestige_earnings': getattr(state, '_next_prestige_earnings', 0.0),
        'daily_streak':      getattr(state, '_daily_streak', 1),
        'last_login_date':   time.strftime('%Y-%m-%d'),
        'perks_purchased':   getattr(state, 'perks_purchased', []),
        'prestige_branch':   getattr(state, 'prestige_branch', None),
        'dragon_patron':     getattr(state, 'dragon_patron', None),
        'dragon_xp':         getattr(state, 'dragon_xp', 0),
        'dragon_ability_cooldowns': getattr(state, 'dragon_ability_cooldowns', {}),
        'dragon_red_elim_count': getattr(state, '_dragon_red_elim_count', 0),
        'arms_influence_frac': getattr(state, '_arms_influence_frac', 0.0),
        'managers':          [m.hired for m in getattr(state, 'managers', [])],
        'buildings':         [b.owned for b in state.buildings],
        'upgrades':          [u.purchased for u in state.upgrades],
        'achievements':      [a.earned for a in state.achievements],
        'save_timestamp':    time.time(),
        'tutorial_step':     getattr(state, '_tutorial_step', 0),
        'shown_milestones':  list(getattr(state, '_shown_milestones', set())),
        'shown_raid_tutorial': getattr(state, '_shown_raid_tutorial', False),
        'shown_ops_tutorial':       getattr(state, '_shown_ops_tutorial', False),
        'shown_influence_tutorial': getattr(state, '_shown_influence_tutorial', False),
        'shown_heat_warning':           getattr(state, '_shown_heat_warning', False),
        'shown_prestige_tree_tutorial': getattr(state, '_shown_prestige_tree_tutorial', False),
        'shown_syndicate_tutorial':     getattr(state, '_shown_syndicate_tutorial', False),
        'shown_influence_intro':        getattr(state, '_shown_influence_intro', False),
        'shown_crew_tutorial':          getattr(state, '_shown_crew_tutorial', False),
        'shown_territory_tutorial':     getattr(state, '_shown_territory_tutorial', False),
        'shown_rivals_tutorial':        getattr(state, '_shown_rivals_tutorial', False),
        'post_prestige_notif':          getattr(state, '_post_prestige_notif', False),
        'notif_near_prestige_80':       getattr(state, '_notif_near_prestige_80', False),
        'push_near_prestige_fired':     getattr(state, '_push_near_prestige_fired', False),
        'peak_income':       getattr(state, '_peak_income', 0.0),
        'longest_streak':    getattr(state, '_longest_streak', 1),
        'total_buildings_purchased':  getattr(state, '_total_buildings_purchased', 0),
        'total_territories_captured': getattr(state, '_total_territories_captured', 0),
        'total_rivals_defeated':      getattr(state, '_total_rivals_defeated', 0),
        'total_ops_completed':        getattr(state, '_total_ops_completed', 0),
        'total_heat_generated':       getattr(state, '_total_heat_generated', 0.0),
        'total_respect_earned':       getattr(state, '_total_respect_earned', 0),
        'total_influence_earned':     getattr(state, '_total_influence_earned', 0),
        'highest_cash_held':          getattr(state, '_highest_cash_held', 0.0),
        'highest_city_control':       getattr(state, '_highest_city_control', 0.0),
        'city_control_milestones':    list(getattr(state, '_city_control_milestones', set())),
        'heat':              getattr(state, 'heat', 0.0),
        'goals_completed':   [g.key for g in getattr(state, 'goals', []) if g.completed],
        'sfx_volume':        getattr(state, '_sfx_volume', 1.0),
        'fps_cap':           getattr(state, '_fps_cap', 60),
        'music_volume':      getattr(state, '_music_volume', 0.5),
        'master_volume':     getattr(state, '_master_volume', 1.0),
        'mute_all':          getattr(state, '_mute_all', False),
        'analytics_enabled': __import__('src.analytics', fromlist=['is_enabled']).is_enabled(),
        'territories':       [
            {'unlocked': t.unlocked, 'owner': getattr(t, 'owner', 'unclaimed')}
            for t in getattr(state, 'territories', [])
        ],
        'rivals':            [
            {
                'turf':        r.turf,
                'wealth':      r.wealth,
                'power':       r.power,
                'aggression':  r.aggression,
                'at_war':      r.at_war,
                'status':      r.status,
                'last_action': r._last_action,
            }
            for r in getattr(state, 'rivals', [])
        ],
        'crew':              getattr(state, 'crew', None).as_dict()
                             if getattr(state, 'crew', None) else {},
        'operations':        [
            {
                'active':     op.active,
                'start_time': op.start_time,
                'reward':     op.reward,
                'completed':  op.completed,
                'collected':  op.collected,
                'speed_mult': op.speed_mult,
            }
            for op in getattr(state, 'operations', [])
        ],
    }
    try:
        # Write to temp file first, then rename — atomic on most OSes
        tmp_path = SAVE_PATH + '.tmp'
        with open(tmp_path, 'w') as f:
            json.dump(data, f, indent=2)
        # Back up old save
        if os.path.exists(SAVE_PATH):
            shutil.copy2(SAVE_PATH, BACKUP_PATH)
        os.replace(tmp_path, SAVE_PATH)
    except OSError:
        pass


# ─── Load ────────────────────────────────────────────────────────────────────

def load_game() -> dict | None:
    for path in (SAVE_PATH, BACKUP_PATH):
        if not os.path.exists(path):
            continue
        try:
            with open(path, 'r') as f:
                data = json.load(f)
            # Basic validation
            if isinstance(data, dict) and 'balance' in data:
                return data
        except (json.JSONDecodeError, OSError, KeyError):
            continue
    return None


def delete_save() -> None:
    for path in (SAVE_PATH, BACKUP_PATH, SAVE_PATH + '.tmp'):
        try:
            os.remove(path)
        except OSError:
            pass


def load_game_preview() -> dict | None:
    """Return lightweight save summary for the title screen. No game state needed."""
    for path in (SAVE_PATH, BACKUP_PATH):
        if not os.path.exists(path):
            continue
        try:
            with open(path, 'r') as f:
                data = json.load(f)
            if isinstance(data, dict) and 'balance' in data:
                return {
                    'prestige_count':  int(data.get('prestige_count', 0)),
                    'prestige_tokens': int(data.get('prestige_tokens', 0)),
                    'play_time':       float(data.get('play_time', 0.0)),
                    'daily_streak':    int(data.get('daily_streak', 1)),
                }
        except (json.JSONDecodeError, OSError, KeyError):
            continue
    return None
