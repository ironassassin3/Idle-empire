"""Rival Syndicates — 5 AI factions that expand, raid, and compete for territory."""
from __future__ import annotations
import math
import random
import traceback
from dataclasses import dataclass, field
from typing import List

import pygame
import src.theme as theme
import src.sound as sound
import src.scale as scale
import config

# ─── AI tick rates ────────────────────────────────────────────────────────────
_ACTION_INTERVAL_MIN = 90.0    # seconds between AI actions (min)
_ACTION_INTERVAL_MAX = 180.0   # seconds between AI actions (max)
_GROWTH_INTERVAL     = 45.0    # seconds between passive growth ticks

# Max activity log entries displayed
_LOG_MAX = 10

_FACTIONS: list[dict] = [
    {
        'name':          'Crimson Kings',
        'leader_name':   'Marco "The Inferno" Reyes',
        'leader_title':  'The Inferno',
        'color':         (200, 60,  40),
        'trait':         'Violent',
        'trait_desc':    'Raids relentlessly. First to strike, last to stop.',
        'aggression':    0.75,
        'flavor':        'Street-level muscle. Block by block, they burn the city to take it.',
        'theme':         'Street warfare. Numbers and fire. Territory is respect.',
        'personality':   'Violent and expansionist. Raids everything. Pride before strategy.',
        'symbol':        '♦',   # ♦
        'faction_key':   'crimson_kings',
        'preferred_district_types': ['residential', 'commercial'],
        'start_turf':    2,
        'start_wealth':  2_000_000.0,
        'start_power':   35,
    },
    {
        'name':          'Silver Hand',
        'leader_name':   'Marcus "The Architect" Kane',
        'leader_title':  'The Architect',
        'color':         (40,  110, 175),
        'trait':         'Corrupt',
        'trait_desc':    'Generates money faster. Judges and police are on the payroll.',
        'aggression':    0.40,
        'flavor':        "Old money criminal machine. They buy what they can't beat.",
        'theme':         'Political corruption. Old money. They own the courthouses.',
        'personality':   'Political manipulators. Avoid direct conflict. Buy everything.',
        'symbol':        '◊',   # ◊ lozenge (❖ unsupported by Consolas)
        'faction_key':   'silver_hand',
        'preferred_district_types': ['government', 'commercial'],
        'start_turf':    3,
        'start_wealth':  20_000_000.0,
        'start_power':   55,
    },
    {
        'name':          'Iron Union',
        'leader_name':   'Viktor "The Slab" Orlov',
        'leader_title':  'The Slab',
        'color':         (155, 118, 48),
        'trait':         'Territorial',
        'trait_desc':    'Expands industrial territory faster than any other faction.',
        'aggression':    0.60,
        'flavor':        'Industrial machine. Chop shops and rail yards. Efficient and relentless.',
        'theme':         'Industrial dominance. They control freight, fabs, and the workforce.',
        'personality':   'Industrial and efficient. Territory through force of organization.',
        'symbol':        '●',   # ● filled circle — iron (⚙ gear unsupported by Consolas)
        'faction_key':   'iron_union',
        'preferred_district_types': ['industrial', 'residential'],
        'start_turf':    1,
        'start_wealth':  1_000_000.0,
        'start_power':   45,
    },
    {
        'name':          'The Network',
        'leader_name':   'Agent Clara "The Ghost" Voss',
        'leader_title':  'The Ghost',
        'color':         (155, 55,  175),
        'trait':         'Surveillance',
        'trait_desc':    'Not a gang. A web of informants draining your heat away.',
        'aggression':    0.45,
        'flavor':        'Not criminals — shadows. They see everything you do.',
        'theme':         'Intelligence apparatus. Heat is their only weapon.',
        'personality':   'Cold and methodical. Never expand. Just watch — and make you bleed.',
        'symbol':        '○',   # ○ ring/eye — surveillance (◎ bullseye unsupported by Consolas)
        'faction_key':   'network',
        'preferred_district_types': ['government'],
        'start_turf':    0,
        'start_wealth':  50_000_000.0,
        'start_power':   70,
    },
    {
        'name':          'Blackwater Mob',
        'leader_name':   'Captain Leon "Claw" Deveraux',
        'leader_title':  'The Claw',
        'color':         (28,  105, 135),
        'trait':         'Smuggler',
        'trait_desc':    'Controls shipping routes. Fights indirectly through the supply chain.',
        'aggression':    0.35,
        'flavor':        'Harbor crime, patience, and the smell of the sea. The tide is always theirs.',
        'theme':         'Harbor crime. Dockyards and shipping routes. Patient as the tide.',
        'personality':   'Patient and opportunistic. They fight indirectly — through supply chains.',
        'symbol':        '≈',   # ≈ waves — harbor/tide (⚓ anchor unsupported by Consolas)
        'faction_key':   'blackwater',
        'preferred_district_types': ['industrial'],
        'preferred_district_names': ['Waterfront', 'Rail Yards', 'Machine Quarter', 'Warehouse Row'],
        'start_turf':    4,
        'start_wealth':  10_000_000.0,
        'start_power':   50,
    },
]

# Shared activity log — module-level so it persists across draws
_activity_log: list[str] = []


def _log(msg: str) -> None:
    _activity_log.append(msg)
    if len(_activity_log) > _LOG_MAX:
        _activity_log.pop(0)


@dataclass
class Rival:
    name:         str
    color:        tuple
    trait:        str
    trait_desc:   str
    aggression:   float
    flavor:       str
    turf:         int          # formerly 'territory'
    wealth:       float
    power:        int
    leader_name:  str  = ""
    leader_title: str  = ""
    at_war:       bool = False
    status:       str  = "Active"      # Active | Weakened | Eliminated
    _action_timer:  float = 0.0
    _growth_timer:  float = 0.0
    _last_action:   str   = "Watching..."
    # ── Faction identity (added Session 12) ─────────────────────────────────
    symbol:       str  = "●"
    faction_key:  str  = ""
    theme:        str  = ""
    personality:  str  = ""
    preferred_district_types: list = field(default_factory=list)
    preferred_district_names: list = field(default_factory=list)

    # ── Passive growth ──────────────────────────────────────────────────────
    def _grow(self, state) -> None:
        """Rivals get stronger over time. Trait/faction_key affects growth vector."""
        try:
            player_balance = float(getattr(state, 'balance', 0.0) or 0.0)
        except Exception:
            player_balance = 0.0
        base_wealth_gain = self.turf * 200_000.0
        catch_up_factor  = max(1.0, player_balance / max(1.0, self.wealth * 10.0))
        wealth_gain = base_wealth_gain * min(catch_up_factor, 5.0)
        power_gain  = 1

        trait = self.trait
        # New trait names + legacy names both handled
        if trait in ('Wealthy', 'Corrupt'):
            wealth_gain *= 2.5
        elif trait == 'Territorial':
            if self.turf < 8 and random.random() < 0.30:
                self.turf += 1
                symbol = getattr(self, 'symbol', '')
                _log(f"{symbol} {self.name} captured a new district.".strip())
        elif trait in ('Investigative', 'Surveillance'):
            try:
                state.heat = min(100.0, state.heat + 2.0)
            except Exception:
                pass
        elif trait == 'Smuggler':
            # Blackwater grows via shipping wealth, not turf bashing
            wealth_gain *= 1.8

        # Dragon Black: rivals grow 15% faster (cost of ignoring them)
        try:
            import src.dragon as _dragon
            wealth_gain *= _dragon.rival_growth_mult(state)
        except Exception:
            pass
        self.wealth = min(self.wealth + wealth_gain, 5_000_000_000.0)
        self.power  = min(self.power + power_gain, 300)

    # ── AI action tick ──────────────────────────────────────────────────────
    def tick(self, dt: float, state) -> list[str]:
        if self.status == 'Eliminated':
            return []

        # Growth tick
        self._growth_timer -= dt
        if self._growth_timer <= 0:
            self._growth_timer = _GROWTH_INTERVAL + random.uniform(-10, 10)
            self._grow(state)

        # Action tick
        self._action_timer -= dt
        if self._action_timer > 0:
            return []
        self._action_timer = random.uniform(_ACTION_INTERVAL_MIN, _ACTION_INTERVAL_MAX)
        try:
            return self._take_action(state)
        except Exception as e:
            print(f"[rivals] AI tick error for {self.name!r}: {e}")
            return []

    # ── Blackwater-specific AI ──────────────────────────────────────────────
    def _blackwater_action(self, state) -> list[str]:
        """Blackwater fights indirectly: harbor control, economic pressure, rival
        undercutting. They never directly raid the player."""
        events = []
        roll = random.random()

        if roll < 0.40 and self.wealth > 1_000_000:
            # Claim preferred harbor district on the city map
            claimed = None
            try:
                import src.territory as _terr
                claimed = _terr.rival_claim_preferred(
                    getattr(state, 'territories', []), self.name,
                    preferred_names=getattr(self, 'preferred_district_names', []),
                    preferred_types=getattr(self, 'preferred_district_types', []))
            except Exception:
                pass
            self.turf   = min(8, self.turf + 1)
            self.wealth = max(0.0, self.wealth - 500_000.0)
            self.power  = min(300, self.power + 2)
            if claimed:
                msg = f"~ {self.name} seized {claimed}."
            else:
                msg = f"~ {self.name} expanded along the waterfront."
            _log(msg)
            events.append(msg)
            self._last_action = "Secured a harbor district"

        elif roll < 0.62:
            # Smuggling consolidation — grow wealthy, stay quiet
            self.wealth = min(self.wealth + self.turf * 300_000.0, 5_000_000_000.0)
            self._last_action = "Running smuggling routes"
            self.at_war = False

        elif roll < 0.80 and self.turf > 0:
            # Economic pressure: tighten the shipping lane grip
            self.wealth = min(self.wealth + 200_000.0, 5_000_000_000.0)
            msg = f"~ {self.name} tightened its grip on the shipping lanes."
            _log(msg)
            events.append(msg)
            self._last_action = "Pressuring shipping routes"

        else:
            # Undercut a rival's trade — weaken their wealth without direct war
            rivals: list[Rival] = getattr(state, 'rivals', []) or []
            others = [r for r in rivals if r is not None and r is not self
                      and r.status != 'Eliminated' and r.turf > 0]
            if others:
                victim = random.choice(others)
                victim.wealth = max(0.0, victim.wealth - 500_000.0)
                victim.power  = max(0, victim.power - 2)
                self.wealth   = min(self.wealth + 300_000.0, 5_000_000_000.0)
                msg = f"~ {self.name} undercut {victim.name}'s trade routes."
                _log(msg)
            self._last_action = "Cutting deals in the dark"

        if self.turf == 0 and self.wealth < 100_000.0 and self.power < 10:
            self.status = 'Weakened'
        return events

    def _take_action(self, state) -> list[str]:
        # Blackwater has its own AI — no direct player raids
        if getattr(self, 'faction_key', '') == 'blackwater':
            return self._blackwater_action(state)

        events = []
        roll = random.random()

        try:
            player_turf = sum(
                1 for t in getattr(state, 'territories', [])
                if t is not None and getattr(t, 'unlocked', False)
            )
        except Exception:
            player_turf = 0

        # Opportunistic (legacy trait): target weakened rivals
        if self.trait == 'Opportunistic':
            rivals: list[Rival] = getattr(state, 'rivals', []) or []
            targets = [r for r in rivals if r is not None and r is not self
                       and r.status == 'Weakened' and r.turf > 0]
            if targets and roll < 0.45:
                victim = random.choice(targets)
                stolen = max(1, victim.turf // 2)
                victim.turf  = max(0, victim.turf - stolen)
                victim.power = max(0, victim.power - 5)
                self.turf    = min(8, self.turf + stolen)
                self.wealth  = min(self.wealth + victim.wealth * 0.3, 500_000_000.0)
                msg = f"{self.name} seized {stolen} district(s) from {victim.name}."
                _log(msg)
                events.append(msg)
                self._last_action = "Exploited a weakened rival"
                return events

        # Violent / Aggressive: raid player more often
        raid_threshold = 0.55
        if self.trait in ('Aggressive', 'Violent'):
            raid_threshold = 0.70

        # Dragon Red: rivals are 20% more aggressive; Black: rivals grow faster (growth tick).
        effective_aggression = self.aggression
        try:
            import src.dragon as _dragon
            effective_aggression = min(1.0, effective_aggression
                                       * _dragon.rival_aggression_mult(state))
        except Exception:
            _dragon = None

        symbol = getattr(self, 'symbol', '')
        if self.wealth > 500_000 and roll < 0.25:
            # Expand territory — claim a preferred district type on the city map
            self.turf   = min(8, self.turf + 1)
            self.wealth = max(0.0, self.wealth - 250_000.0)
            self.power  = min(300, self.power + 2)
            self._last_action = "Expanded into new territory"
            claimed = None
            try:
                import src.territory as _terr
                claimed = _terr.rival_claim_preferred(
                    getattr(state, 'territories', []), self.name,
                    preferred_names=getattr(self, 'preferred_district_names', []),
                    preferred_types=getattr(self, 'preferred_district_types', []))
            except Exception:
                pass
            prefix = f"{symbol} " if symbol else ""
            msg = (f"{prefix}{self.name} captured {claimed}." if claimed
                   else f"{prefix}{self.name} captured a new district.")
            _log(msg)
            events.append(msg)

        elif effective_aggression > random.random() and player_turf > 0 and roll < raid_threshold:
            # Raid player
            self.at_war = True
            try:
                ips = float(state.income_per_second)
            except Exception:
                ips = 0.0
            balance = float(getattr(state, 'balance', 0.0) or 0.0)
            raw_penalty = min(balance * 0.06, max(500.0, ips * 45))
            counterattacked = False
            absorbed = False
            try:
                import src.dragon as _dragon
                raw_penalty *= _dragon.raid_damage_mult(state)
                counterattacked = _dragon.try_counterattack(state, self)
            except Exception:
                pass
            try:
                import src.managers as _mgr
                penalty, absorbed = _mgr.apply_raid_penalty(state, raw_penalty, 'rival')
            except Exception:
                penalty = raw_penalty
                try:
                    import src.managers as _mgr
                    penalty *= _mgr.raid_damage_mult(state)
                except Exception:
                    pass
                state.balance = max(0.0, balance - penalty)
            try:
                heat_gain = 10.0 if self.trait == 'Aggressive' else 8.0
                state.heat = min(100.0, getattr(state, 'heat', 0.0) + heat_gain)
            except Exception as e:
                print(f"[rivals] raid state-update error: {e}")
            self.wealth = min(self.wealth + penalty, 500_000_000.0)
            self._last_action = "Raided your operation"
            if absorbed:
                msg = f"RAID: {symbol} {self.name} struck — Collector handled it!".strip()
            else:
                wealth_fmt = theme.format_number(penalty)
                msg = f"RAID: {symbol} {self.name} hit you for ${wealth_fmt}!".strip()
            if counterattacked:
                msg += f" Counterattack weakened {self.name}!"
            _log(f"{self.name} raided your operations.")
            events.append(msg)

        elif roll < 0.12 and self.turf > 0:
            self.turf   = max(0, self.turf - 1)
            self.wealth = max(0.0, self.wealth - 50_000.0)
            self.power  = max(0, self.power - 3)
            self._last_action = "Lost territory to infighting"
            msg = f"{self.name} lost influence from internal conflict."
            _log(msg)
            events.append(msg)

        else:
            self.wealth = min(self.wealth + self.turf * 150_000.0, 5_000_000_000.0)
            self._last_action = "Consolidating power"
            self.at_war = False

        # Rival vs rival: occasionally fight each other
        if roll > 0.80:
            rivals: list[Rival] = getattr(state, 'rivals', []) or []
            others = [r for r in rivals if r is not None and r is not self
                      and r.status != 'Eliminated' and r.turf > 0]
            if others:
                victim = random.choice(others)
                victim.turf   = max(0, victim.turf - 1)
                victim.power  = max(0, victim.power - 4)
                victim.wealth = max(0.0, victim.wealth - 200_000.0)
                self.turf     = min(8, self.turf + 1)
                v_symbol = getattr(victim, 'symbol', '')
                msg = f"{symbol} {self.name} seized turf from {v_symbol} {victim.name}.".strip()
                _log(msg)

        # Weakness check
        if self.turf == 0 and self.wealth < 100_000.0 and self.power < 10:
            self.status = 'Weakened'

        return events


def make_rivals() -> List[Rival]:
    rivals = []
    for d in _FACTIONS:
        r = Rival(
            name=d['name'], color=d['color'],
            trait=d['trait'], trait_desc=d['trait_desc'],
            aggression=d['aggression'], flavor=d['flavor'],
            turf=d['start_turf'], wealth=d['start_wealth'],
            power=d['start_power'],
            leader_name=d.get('leader_name', ''),
            leader_title=d.get('leader_title', ''),
            symbol=d.get('symbol', '●'),
            faction_key=d.get('faction_key', ''),
            theme=d.get('theme', ''),
            personality=d.get('personality', ''),
            preferred_district_types=list(d.get('preferred_district_types', [])),
            preferred_district_names=list(d.get('preferred_district_names', [])),
        )
        r._action_timer = random.uniform(30.0, _ACTION_INTERVAL_MIN)
        r._growth_timer = random.uniform(10.0, _GROWTH_INTERVAL)
        rivals.append(r)
    return rivals


_FACTION_DEFAULTS = {d['faction_key']: d for d in _FACTIONS}


def reconstitute_eliminated_rivals(rivals: List[Rival],
                                    restore_fraction: float = 0.30) -> int:
    """Restore eliminated rivals on prestige with reduced stats.

    Preserves faction identity, name, symbol, trait, and faction_key.
    Only revives Eliminated rivals; Active and Weakened rivals are untouched.
    Returns the count of rivals revived.
    """
    count = 0
    for rival in rivals:
        if rival is None or rival.status != 'Eliminated':
            continue
        defaults = _FACTION_DEFAULTS.get(getattr(rival, 'faction_key', ''))
        if defaults:
            turf   = int(defaults['start_turf']   * restore_fraction)
            wealth = defaults['start_wealth'] * restore_fraction
            power  = int(defaults['start_power']  * restore_fraction)
        else:
            turf   = 1
            wealth = 500_000.0
            power  = 10
        rival.status       = 'Active'
        rival.turf         = max(1, turf)
        rival.wealth       = max(100_000.0, wealth)
        rival.power        = max(5, power)
        rival.at_war       = False
        rival._action_timer = random.uniform(120.0, 180.0)
        rival._last_action  = 'Regrouping...'
        count += 1
    return count


# ─── Player actions against rivals ────────────────────────────────────────────

def _base_success(rival: Rival, action: str) -> float:
    aggression = float(rival.aggression) if rival.aggression is not None else 0.5
    power      = int(rival.power)        if rival.power      is not None else 0
    wealth     = float(rival.wealth)     if rival.wealth     is not None else 0.0

    # High power and wealth make the rival harder to hit
    power_penalty  = min(0.25, power / 800.0)
    wealth_penalty = min(0.15, wealth / 100_000_000.0)

    table = {
        'attack':    0.60 - aggression * 0.2 - power_penalty,
        'bribe':     0.65 - wealth_penalty * 2,
        'negotiate': 0.70 - aggression * 0.3,
        'sabotage':  0.55 - power_penalty,
    }
    return max(0.10, min(0.90, table.get(action, 0.5)))


def perform_action(state, rival_idx: int, action: str) -> str:
    """
    Perform player action against rival at rival_idx.
    Returns outcome description. Modifies state and rival in place.
    Never raises.
    """
    try:
        rivals: List[Rival] = getattr(state, 'rivals', None) or []
        if not rivals:
            return "Action unavailable"
        if not isinstance(rival_idx, int) or rival_idx < 0 or rival_idx >= len(rivals):
            return "Action unavailable"

        rival = rivals[rival_idx]
        if rival is None:
            return "Action unavailable"

        status = getattr(rival, 'status', 'Active') or 'Active'
        if status == 'Eliminated':
            return f"{rival.name} is already eliminated."

        r_turf       = int(rival.turf)         if rival.turf       is not None else 0
        r_wealth     = float(rival.wealth)     if rival.wealth     is not None else 0.0
        r_power      = int(rival.power)        if rival.power      is not None else 0
        r_aggression = float(rival.aggression) if rival.aggression is not None else 0.5

        # Warlord Show of Force boosts success against rivals.
        _combat_bonus = 0.0
        try:
            import src.prestige_tree as _ptree
            _combat_bonus = _ptree.combat_success_bonus(state)
        except Exception:
            pass
        success = random.random() < min(0.95, _base_success(rival, action) + _combat_bonus)

        def _ips() -> float:
            try:
                return float(state.income_per_second)
            except Exception:
                return 0.0

        balance  = float(getattr(state, 'balance', 0.0) or 0.0)
        heat     = float(getattr(state, 'heat',    0.0) or 0.0)
        influence = int(getattr(state, 'prestige_tokens', 0) or 0)
        respect   = int(getattr(state, 'influence', 0) or 0)

        # ── Attack ─────────────────────────────────────────────────────────
        # Warlord Spoils of War: more cash from aggressive actions.
        _spoils = 1.0
        try:
            import src.prestige_tree as _ptree
            _spoils = _ptree.combat_reward_mult(state)
        except Exception:
            pass

        if action == 'attack':
            if success:
                cash_reward = max(25_000.0, r_wealth * 0.12) * _spoils
                inf_reward  = 1
                resp_reward = 10

                rival.turf    = max(0, r_turf - 1)
                rival.wealth  = max(0.0, r_wealth - cash_reward)
                rival.power   = max(0, r_power - 8)
                rival.heat    = min(100.0, getattr(rival, 'heat', 0.0) + 15.0)

                state.balance         = balance + cash_reward
                state.prestige_tokens = influence + inf_reward
                state.influence       = respect + resp_reward

                # Check for defeat
                if rival.turf == 0 and rival.wealth < 100_000.0 and rival.power < 5:
                    rival.status = 'Eliminated'
                    return _defeat_rival(state, rival, r_wealth, balance, influence, respect)

                rival.status       = 'Weakened' if rival.turf == 0 else 'Active'
                cash_fmt           = theme.format_number(cash_reward)
                _log(f"{rival.name} lost a district to your forces.")
                return (f"Victory! Seized ${cash_fmt} cash  +{inf_reward} Influence"
                        f"  +{resp_reward} Respect")
            else:
                heat_penalty    = 14.0
                balance_penalty = balance * 0.05
                state.heat    = min(100.0, heat + heat_penalty)
                state.balance = max(0.0, balance - balance_penalty)
                rival.wealth  = min(rival.wealth + balance_penalty, 500_000_000.0)
                _log(f"{rival.name} repelled your attack.")
                return (f"Repelled! +{heat_penalty:.0f} heat,"
                        f" lost ${theme.format_number(balance_penalty)}")

        # ── Bribe ──────────────────────────────────────────────────────────
        elif action == 'bribe':
            cost = max(1_000_000.0, _ips() * 120)
            if balance < cost:
                return f"Need ${theme.format_number(cost)} to bribe."
            state.balance = max(0.0, balance - cost)
            if success:
                rival.power   = max(0, r_power - 10)
                rival.wealth  = max(0.0, r_wealth * 0.75)
                state.heat    = max(0.0, heat - 10.0)
                state.prestige_tokens = influence + 1
                state.influence       = respect + 8
                _log(f"{rival.name} was bribed into inaction.")
                return "Bribed! -10 heat, +1 Influence, +8 Respect"
            else:
                state.heat = min(100.0, heat + 8.0)
                return f"Bribe rejected! +8 heat, lost ${theme.format_number(cost)}"

        # ── Negotiate ──────────────────────────────────────────────────────
        elif action == 'negotiate':
            if heat < 5.0:
                return "Not enough heat leverage to negotiate."
            if success:
                rival.at_war     = False
                rival.aggression = max(0.10, r_aggression - 0.12)
                state.heat       = max(0.0, heat - 15.0)
                state.prestige_tokens = influence + 1
                state.influence       = respect + 6
                _log(f"Peace deal struck with {rival.name}.")
                return f"Peace deal with {rival.name}. -15 heat, +1 Influence, +6 Respect"
            else:
                state.heat = min(100.0, heat + 5.0)
                _log(f"{rival.name} rejected negotiations.")
                return "Negotiations collapsed. +5 heat"

        # ── Sabotage ──────────────────────────────────────────────────────
        elif action == 'sabotage':
            cost = max(500_000.0, _ips() * 60)
            if balance < cost:
                return f"Need ${theme.format_number(cost)} for a sabotage op."
            state.balance = max(0.0, balance - cost)
            if success:
                cash_reward = r_wealth * 0.20
                rival.wealth = max(0.0, r_wealth * 0.55)
                rival.power  = max(0, r_power - 12)
                rival.heat   = min(100.0, getattr(rival, 'heat', 0.0) + 25.0)
                state.prestige_tokens = influence + 1
                state.influence       = respect + 10

                if rival.turf == 0 and rival.wealth < 100_000.0 and rival.power < 5:
                    rival.status = 'Eliminated'
                    return _defeat_rival(state, rival, r_wealth, balance, influence, respect)

                _log(f"{rival.name}'s operations were sabotaged.")
                return f"Sabotage succeeded! {rival.name} lost half their wealth. +1 Influence, +12 Respect"
            else:
                state.heat = min(100.0, heat + 10.0)
                return f"Sabotage blown! +10 heat, lost ${theme.format_number(cost)}"

        return "Action unavailable"

    except Exception as e:
        print(f"[rivals] perform_action error (rival={rival_idx}, action={action}): {e}")
        traceback.print_exc()
        return "Action unavailable"


# Faction-specific elimination epitaphs (Phase 58). Keyed by faction_key so old
# saves and legacy traits fall back gracefully to the generic line. Phrasing is
# deliberately timeless (not present-tense) so it still reads naturally when a
# faction is eliminated again after reviving on prestige.
_ELIMINATION_LINES: dict[str, str] = {
    'crimson_kings': "The Inferno is ash. The streets go quiet.",
    'silver_hand':   "Old money runs dry. The courts are yours.",
    'iron_union':    "The machine is scrap. The yards go still.",
    'network':       "The Network goes dark. Nobody is watching.",
    'blackwater':    "The tide goes out. The harbor is yours.",
}


def _elimination_line(rival: Rival) -> str:
    """Return the faction's elimination epitaph, or the generic line as fallback."""
    key = getattr(rival, 'faction_key', '') or ''
    return _ELIMINATION_LINES.get(key, "has collapsed.")


def _defeat_rival(state, rival: Rival, pre_wealth: float,
                  balance: float, influence: int, respect: int) -> str:
    """Handle rival elimination — grant defeat rewards and trigger overlay."""
    cash_bonus = max(500_000.0, pre_wealth * 0.35)
    state.balance         = balance + cash_bonus
    state.prestige_tokens = influence + 3
    state.influence       = respect + 30

    heat_bonus = ""
    if rival.trait == 'Investigative':
        h = float(getattr(state, 'heat', 0.0) or 0.0)
        state.heat = max(0.0, h - 30.0)
        heat_bonus = "-30 heat!"

    # Part 4 — free the rival's districts on the city map so defeating them
    # visibly opens up territory for the player to capture.
    freed = 0
    try:
        import src.territory as _terr
        freed = _terr.release_rival_territories(
            getattr(state, 'territories', []), rival.name)
    except Exception:
        pass

    # Dragon Red: track eliminated count for income bonus
    try:
        import src.dragon as _dragon
        _dragon.on_rival_eliminated(state, rival)
    except Exception:
        pass

    _log(f"{rival.name} has been eliminated.")
    cash_fmt = theme.format_number(cash_bonus)
    reward_str = f"+${cash_fmt}  +5 Influence  +50 Respect"
    if freed > 0:
        reward_str += f"  {freed} district{'s' if freed != 1 else ''} freed"
    if heat_bonus:
        reward_str += f"  {heat_bonus}"

    # Single point of truth for every player rival elimination — the cue lives
    # here so both the attack and sabotage paths fire it exactly once.
    sound.play('rival')

    # Trigger full-screen elimination overlay in state
    try:
        state._elim_overlay       = rival.name
        state._elim_overlay_timer = 5.0
        state._elim_rewards       = reward_str
        state._elim_flavor        = _elimination_line(rival)
        was_first = getattr(state, '_total_rivals_defeated', 0) == 0
        state._total_rivals_defeated = getattr(state, '_total_rivals_defeated', 0) + 1
        if was_first:
            try:
                import src.analytics as _an
                _an.first_rival_defeat()
            except Exception:
                pass
    except Exception:
        pass

    return f"ELIMINATED {rival.name}!  {reward_str}"


def update_rivals(state, dt: float) -> list[str]:
    rivals: List[Rival] = getattr(state, 'rivals', None) or []
    events = []
    for r in rivals:
        if r is None:
            continue
        try:
            events.extend(r.tick(dt, state))
        except Exception as e:
            print(f"[rivals] update error for rival: {e}")
    # Dragon Jade: chance to de-escalate at-war rivals each AI tick
    try:
        import src.dragon as _dragon
        events.extend(_dragon.try_jade_de_escalate(state))
    except Exception:
        pass
    return events


def get_empire_impact(state) -> dict:
    """
    Summarise how living rivals are currently affecting the player.
    Returns a dict of modifier names -> float delta.
    Called by states.py / territory.py to apply mechanical penalties.
    """
    rivals: List[Rival] = getattr(state, 'rivals', None) or []
    total_power  = 0
    total_wealth = 0.0
    high_agg     = 0.0
    investig_active = False

    for r in rivals:
        if r is None or r.status == 'Eliminated':
            continue
        total_power  += r.power
        total_wealth += r.wealth
        if r.aggression > high_agg:
            high_agg = r.aggression
        if r.trait == 'Investigative':
            investig_active = True

    # Territory success penalty from combined rival power (caps at -30%)
    territory_penalty = min(0.30, total_power / 1000.0)
    # Raid frequency modifier from highest aggression
    raid_mult         = 1.0 + high_agg * 0.4
    # Investigator heat-drain rate
    heat_drain_rate   = 1.5 if investig_active else 0.0

    return {
        'territory_penalty': territory_penalty,
        'raid_mult':          raid_mult,
        'heat_drain_rate':    heat_drain_rate,
        'total_power':        total_power,
        'total_wealth':       total_wealth,
    }


# ─── UI ───────────────────────────────────────────────────────────────────────

_GAP    = 8
_LOG_H  = 130    # height of the activity feed at the bottom
_BTN_H  = 26     # fallback only — real height from _rival_btn_h(fonts)
_BTN_GAP = 8


def _rival_btn_h(fonts: dict) -> int:
    """Action button height — fits the xs glyph at any font scale."""
    if not fonts or not fonts.get('xs'):
        return _BTN_H
    return fonts['xs'].get_height() + scale.sd(8)


def _rival_card_height(rival, fonts: dict) -> int:
    """Minimum card height: all content rows + bottom-anchored button zone, no overlap."""
    if rival is None:
        return 60
    eliminated = getattr(rival, 'status', 'Active') == 'Eliminated'
    xs_h = fonts['xs'].get_height() if fonts.get('xs') else 14
    sm_h = fonts['sm'].get_height() if fonts.get('sm') else 18

    cy = 10                                                   # top padding
    cy += sm_h + 2                                            # name row
    if not eliminated and getattr(rival, 'leader_name', ''):
        cy += xs_h + 2                                        # leader row
    cy += (xs_h + 4) if (not eliminated and getattr(rival, 'theme', '')) else 4
    cy += (xs_h + 6) if (not eliminated and getattr(rival, 'trait', '')) else 4
    cy += xs_h + 6                                            # stats row
    cy += xs_h + 6                                            # flavor row
    if not eliminated:
        cy += _rival_btn_h(fonts) + 16   # 8px gap + buttons + 8px bottom padding
    else:
        cy += 8
    return max(60, cy)


def _rival_btn_widths(fonts: dict) -> list:
    """Per-button widths from rendered label text + horizontal padding."""
    if not fonts.get('xs'):
        return [82] * len(_ACTION_LABELS)
    pad = 20
    return [max(72, fonts['xs'].size(lbl)[0] + pad) for lbl, _ in _ACTION_LABELS]

_ACTION_LABELS = [("Attack", "attack"), ("Bribe", "bribe"),
                  ("Negotiate", "negotiate"), ("Sabotage", "sabotage")]
_ACTION_COLORS = [
    (200, 60,  60),    # attack  — red
    (200, 160, 40),    # bribe   — gold
    (60,  160, 200),   # negotiate — blue
    (140, 60,  200),   # sabotage  — purple
]

# Trait badge colors — new names first, legacy names kept for old saves
_TRAIT_COLORS: dict[str, tuple] = {
    'Violent':       (220, 70,  50),   # Crimson Kings
    'Corrupt':       (50,  130, 200),  # Silver Hand
    'Territorial':   (140, 180, 80),   # Iron Union
    'Surveillance':  (170, 70,  210),  # The Network
    'Smuggler':      (28,  160, 190),  # Blackwater Mob
    # Legacy trait names (preserved for saves written before Session 12)
    'Aggressive':    (220, 80,  60),
    'Wealthy':       (200, 175, 40),
    'Investigative': (180, 80,  200),
    'Opportunistic': (80,  180, 180),
}


# Short faction identity line shown on the rival card (Phase 61). Each value is a
# verbatim clause of that faction's `flavor` (crimson's first letter capitalized
# for display), trimmed to fit the card width at every resolution — no new prose.
# Replaces the low-identity dynamic `last_action` line; the live action feed still
# lives in the RECENT ACTIVITY log below the cards.
_CARD_FLAVOR: dict[str, str] = {
    'crimson_kings': "They burn the city to take it.",
    'silver_hand':   "They buy what they can't beat.",
    'iron_union':    "Chop shops and rail yards.",
    'network':       "They see everything you do.",
    'blackwater':    "The tide is always theirs.",
}


def _fmt_wealth(w: float) -> str:
    if w >= 1_000_000:
        return f"${theme.format_number(w)}"
    return f"${w:,.0f}"


def draw_panel(surface: pygame.Surface, state, fonts: dict,
               panel_rect: pygame.Rect) -> None:
    try:
        rivals: List[Rival] = getattr(state, 'rivals', None) or []
        mx, my = pygame.mouse.get_pos()
        t = float(getattr(state, '_time', 0.0) or 0.0)

        # Header
        hdr = fonts['xs'].render(
            "RIVAL SYNDICATES  —  strategic threats to your empire", True, theme.TEXT_MUTED)
        surface.blit(hdr, (panel_rect.x + 8, panel_rect.y + 4))

        # Determine card area vs log area
        log_area_top = panel_rect.bottom - _LOG_H
        cards_area = pygame.Rect(panel_rect.x, panel_rect.y + 22,
                                 panel_rect.width, log_area_top - (panel_rect.y + 22) - 4)

        # Clamp scroll to valid range
        total_content_h = sum(_rival_card_height(r, fonts) + _GAP for r in rivals)
        max_scroll = max(0, total_content_h - cards_area.height)
        scroll = max(0, min(getattr(state, '_rivals_scroll', 0), max_scroll))
        try:
            state._rivals_scroll = scroll
        except Exception:
            pass

        heat = float(getattr(state, 'heat', 0.0) or 0.0)

        old_clip = surface.get_clip()
        surface.set_clip(cards_area)

        row_y = cards_area.top - scroll
        for idx, rival in enumerate(rivals):
            card_h = _rival_card_height(rival, fonts)
            if rival is None:
                row_y += card_h + _GAP
                continue
            if row_y + card_h <= cards_area.top:
                row_y += card_h + _GAP
                continue
            if row_y >= cards_area.bottom:
                break
            _draw_card(surface, rival, idx, row_y, panel_rect, fonts, mx, my, t, heat, card_h)
            row_y += card_h + _GAP

        surface.set_clip(old_clip)

        if max_scroll > 0:
            _draw_rivals_scrollbar(surface, cards_area, scroll, max_scroll, fonts)

        # Activity log
        _draw_activity_log(surface, fonts, panel_rect, log_area_top)

    except Exception as e:
        print(f"[rivals] draw_panel error: {e}")
        traceback.print_exc()

    # Outcome overlay
    try:
        outcome = getattr(state, '_rival_outcome', None)
        if outcome:
            timer = float(getattr(state, '_rival_outcome_timer', 0.0) or 0.0)
            if timer > 0:
                alpha = min(255, int(255 * min(1.0, timer / 0.4)))
                os_ = fonts['sm'].render(str(outcome), True, theme.TEXT_GOLD)
                os_.set_alpha(alpha)
                surface.blit(os_, os_.get_rect(
                    centerx=panel_rect.centerx, y=panel_rect.bottom - _LOG_H - 30))
    except Exception as e:
        print(f"[rivals] outcome overlay error: {e}")


_NEGOTIATE_HEAT_MIN = 5.0  # rivals.perform_action requires heat >= this to negotiate


def _draw_card(surface: pygame.Surface, rival: Rival, idx: int,
               row_y: int, panel_rect: pygame.Rect, fonts: dict,
               mx: int, my: int, t: float, heat: float = 0.0,
               card_h: int = 0) -> None:
    """Draw a single rival card — tall, vertical layout, buttons on own row."""
    if card_h <= 0:
        card_h = _rival_card_height(rival, fonts)
    rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, card_h)

    status      = rival.status or 'Active'
    at_war      = bool(rival.at_war)
    color       = rival.color or (120, 120, 120)
    name        = rival.name or '???'
    turf        = int(rival.turf)    if rival.turf    is not None else 0
    wealth      = float(rival.wealth) if rival.wealth is not None else 0.0
    power       = int(rival.power)   if rival.power   is not None else 0
    trait       = rival.trait or ''
    last_action = str(rival._last_action or 'Watching...')
    eliminated  = (status == 'Eliminated')

    # ── Background ──────────────────────────────────────────────────────────
    if eliminated:
        bg_col = (18, 18, 24, 200)
    elif at_war:
        pulse_a = int(50 + 35 * math.sin(t * 3.0))
        bg_col  = (*color, pulse_a)
    else:
        bg_col = (*color, 22)

    bg_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
    pygame.draw.rect(bg_surf, bg_col, bg_surf.get_rect(), border_radius=10)
    surface.blit(bg_surf, rr.topleft)

    # Left accent bar
    bar = pygame.Surface((3, card_h - 16), pygame.SRCALPHA)
    bar.fill((*color, 200 if not eliminated else 50))
    surface.blit(bar, (rr.x, rr.y + 8))

    pad_x = rr.x + 14
    cy    = rr.y + 10

    # ── Row 1: Symbol + Name + WAR badge ───────────────────────────────────
    name_col = theme.TEXT_MUTED if eliminated else (
        (255, 80, 80) if at_war else theme.TEXT_PRIMARY)
    symbol   = getattr(rival, 'symbol', '')
    display_name = f"{symbol} {name}" if symbol else name
    ns = fonts['sm'].render(display_name, True, name_col)
    surface.blit(ns, (pad_x, cy))

    if at_war and not eliminated:
        tag_surf = fonts['xs'].render(" WAR ", True, (255, 60, 60))
        tag_x    = pad_x + ns.get_width() + 10
        pygame.draw.rect(surface, (80, 20, 20),
                         pygame.Rect(tag_x - 2, cy + 1, tag_surf.get_width() + 4, tag_surf.get_height() + 2),
                         border_radius=3)
        surface.blit(tag_surf, (tag_x, cy + 1))
    elif eliminated:
        tag_surf = fonts['xs'].render(" ELIMINATED ", True, (120, 120, 120))
        surface.blit(tag_surf, (pad_x + ns.get_width() + 8, cy + 2))

    cy += ns.get_height() + 2

    # ── Row 1b: Leader name / title ─────────────────────────────────────────
    leader_name  = rival.leader_name  or ''
    leader_title = rival.leader_title or ''
    if leader_name and not eliminated:
        leader_txt = f"{leader_name}  \"{leader_title}\""
        ls = fonts['xs'].render(leader_txt, True, theme.TEXT_MUTED)
        ls.set_alpha(180)
        surface.blit(ls, (pad_x, cy))
        cy += ls.get_height() + 2
    # ── Row 1c: Theme tagline ───────────────────────────────────────────────
    faction_theme = getattr(rival, 'theme', '') or ''
    if faction_theme and not eliminated:
        ts = fonts['xs'].render(faction_theme, True, color)
        ts.set_alpha(130)
        surface.blit(ts, (pad_x, cy))
        cy += ts.get_height() + 4
    else:
        cy += 4

    # ── Row 2: Trait badge ─────────────────────────────────────────────────
    if not eliminated and trait:
        tcol = _TRAIT_COLORS.get(trait, theme.TEXT_MUTED)
        tsurf = fonts['xs'].render(f"  {trait}  ", True, tcol)
        tbg   = pygame.Surface((tsurf.get_width() + 4, tsurf.get_height() + 2), pygame.SRCALPHA)
        pygame.draw.rect(tbg, (*tcol, 35), tbg.get_rect(), border_radius=4)
        pygame.draw.rect(tbg, (*tcol, 120), tbg.get_rect(), width=1, border_radius=4)
        surface.blit(tbg, (pad_x - 2, cy))
        surface.blit(tsurf, (pad_x, cy))
        cy += tsurf.get_height() + 6
    else:
        cy += 4

    # ── Row 3: Stats — Turf / Wealth / Power ───────────────────────────────
    wealth_str = _fmt_wealth(wealth)
    stats = [
        (f"Turf: {turf}",         theme.TEXT_PRIMARY),
        (f"Wealth: {wealth_str}", theme.TEXT_GOLD),
        (f"Power: {power}",       (255, 120, 60) if power > 80 else theme.TEXT_PRIMARY),
    ]
    sx = pad_x
    for txt, col in stats:
        ss = fonts['xs'].render(txt, True, col)
        surface.blit(ss, (sx, cy))
        sx += ss.get_width() + 20

    cy += fonts['xs'].get_height() + 6

    # ── Row 4: faction identity line (falls back to live action text) ──────
    # Active rivals show their faction flavor so each card reads distinctly;
    # eliminated rivals keep the status/action text. Unknown/legacy factions
    # fall back to last_action, preserving prior behavior.
    if eliminated:
        flavor_txt = f"[{status}] {last_action}"
    else:
        flavor_txt = _CARD_FLAVOR.get(getattr(rival, 'faction_key', ''), '') or last_action
    la_s = fonts['xs'].render(flavor_txt, True, theme.TEXT_MUTED)
    la_s.set_alpha(160)
    surface.blit(la_s, (pad_x, cy))

    cy += la_s.get_height() + 6

    # ── Row 5: Action buttons — centered, own dedicated row ────────────────
    if not eliminated:
        btn_ws   = _rival_btn_widths(fonts)
        btn_h    = _rival_btn_h(fonts)
        total_w  = sum(btn_ws) + (len(btn_ws) - 1) * _BTN_GAP
        start_bx = rr.centerx - total_w // 2
        by       = rr.bottom - btn_h - 8

        for (lbl, akey), col, bw in zip(_ACTION_LABELS, _ACTION_COLORS, btn_ws):
            btn = pygame.Rect(start_bx, by, bw, btn_h)
            # Negotiate needs heat leverage — show the requirement instead of
            # letting the click silently fail (Part 6 visibility).
            heat_blocked = (akey == 'negotiate' and heat < _NEGOTIATE_HEAT_MIN)
            hov = btn.collidepoint(mx, my)
            if heat_blocked:
                pygame.draw.rect(surface, (50, 52, 64), btn, border_radius=5)
                ls = fonts['xs'].render(f"Needs {int(_NEGOTIATE_HEAT_MIN)} heat", True, (150, 150, 160))
            else:
                draw_col = tuple(min(255, v + 35) for v in col) if hov else col
                pygame.draw.rect(surface, draw_col, btn, border_radius=5)
                if hov:
                    pygame.draw.rect(surface, (255, 255, 255, 40), btn, width=1, border_radius=5)
                ls = fonts['xs'].render(lbl, True, (235, 235, 235))
            surface.blit(ls, ls.get_rect(center=btn.center))
            start_bx += bw + _BTN_GAP

    # Separator
    sep = pygame.Surface((rr.width, 1), pygame.SRCALPHA)
    sep.fill((255, 255, 255, 18))
    surface.blit(sep, (rr.x, rr.bottom + _GAP // 2))


def _draw_rivals_scrollbar(surface: pygame.Surface, cards_area: pygame.Rect,
                            scroll: int, max_scroll: int, fonts: dict) -> None:
    """Minimal track + thumb on the right edge of the cards area."""
    track_w  = 4
    track_x  = cards_area.right - track_w - 3
    track_r  = pygame.Rect(track_x, cards_area.top + 4, track_w, cards_area.height - 8)
    pygame.draw.rect(surface, (35, 38, 50), track_r, border_radius=2)

    total_h      = cards_area.height + max_scroll
    visible_frac = cards_area.height / total_h
    thumb_h      = max(18, int(track_r.height * visible_frac))
    thumb_pct    = scroll / max_scroll
    thumb_y      = track_r.top + int((track_r.height - thumb_h) * thumb_pct)
    pygame.draw.rect(surface, (90, 100, 130),
                     pygame.Rect(track_x, thumb_y, track_w, thumb_h), border_radius=2)

    if max_scroll - scroll > 0 and fonts.get('xs'):
        hint = fonts['xs'].render("▼ scroll", True, (90, 95, 115))
        hint.set_alpha(110)
        surface.blit(hint, hint.get_rect(
            right=track_x - 4, y=cards_area.bottom - hint.get_height() - 2))


def _draw_activity_log(surface: pygame.Surface, fonts: dict,
                       panel_rect: pygame.Rect, top_y: int) -> None:
    """Draw recent rival activity feed at the bottom of the panel."""
    log_rect = pygame.Rect(panel_rect.x + 4, top_y + 4,
                           panel_rect.width - 8, _LOG_H - 8)

    # Background
    bg = pygame.Surface((log_rect.width, log_rect.height), pygame.SRCALPHA)
    pygame.draw.rect(bg, (20, 22, 34, 200), bg.get_rect(), border_radius=8)
    surface.blit(bg, log_rect.topleft)

    lbl = fonts['xs'].render("RECENT ACTIVITY", True, theme.TEXT_MUTED)
    surface.blit(lbl, (log_rect.x + 8, log_rect.y + 5))

    line_h = fonts['xs'].get_height() + 2
    ey = log_rect.y + 5 + lbl.get_height() + 4

    entries = _activity_log[-8:]  # show last 8 within the box
    if not entries:
        ph = fonts['xs'].render("No rival activity yet.", True, theme.TEXT_MUTED)
        ph.set_alpha(90)
        surface.blit(ph, (log_rect.x + 8, ey))
    else:
        for i, entry in enumerate(reversed(entries)):
            if ey + line_h > log_rect.bottom - 4:
                break
            alpha = max(80, 220 - i * 20)
            es = fonts['xs'].render(entry, True, theme.TEXT_PRIMARY)
            es.set_alpha(alpha)
            surface.blit(es, (log_rect.x + 8, ey))
            ey += line_h


def handle_click(state, pos: tuple, panel_rect: pygame.Rect) -> bool:
    try:
        rivals: List[Rival] = getattr(state, 'rivals', None) or []
        if not rivals:
            return False
        fonts  = getattr(state, '_fonts', {})
        scroll = getattr(state, '_rivals_scroll', 0)

        log_area_top = panel_rect.bottom - _LOG_H
        cards_area = pygame.Rect(panel_rect.x, panel_rect.y + 22,
                                 panel_rect.width, log_area_top - (panel_rect.y + 22) - 4)

        row_y = cards_area.top - scroll

        for idx, rival in enumerate(rivals):
            card_h = _rival_card_height(rival, fonts)
            if rival is None:
                row_y += card_h + _GAP
                continue
            if row_y + card_h <= cards_area.top:
                row_y += card_h + _GAP
                continue
            if row_y >= cards_area.bottom:
                break

            rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, card_h)
            if not rr.collidepoint(pos):
                row_y += card_h + _GAP
                continue

            status = getattr(rival, 'status', 'Active') or 'Active'
            if status == 'Eliminated':
                row_y += card_h + _GAP
                continue

            # Button positions — must match _draw_card exactly
            btn_ws   = _rival_btn_widths(fonts)
            btn_h    = _rival_btn_h(fonts)
            total_w  = sum(btn_ws) + (len(btn_ws) - 1) * _BTN_GAP
            start_bx = rr.centerx - total_w // 2
            by       = rr.bottom - btn_h - 8

            for (_, action_key), bw in zip(_ACTION_LABELS, btn_ws):
                btn = pygame.Rect(start_bx, by, bw, btn_h)
                if btn.collidepoint(pos):
                    outcome = perform_action(state, idx, action_key)
                    state._rival_outcome       = outcome or "Action unavailable"
                    state._rival_outcome_timer = 3.5
                    # _defeat_rival() owns the elimination cue; avoid doubling it.
                    if getattr(rival, 'status', 'Active') != 'Eliminated':
                        sound.play('purchase')
                    return True
                start_bx += bw + _BTN_GAP

            row_y += card_h + _GAP

    except Exception as e:
        print(f"[rivals] handle_click error: {e}")
        traceback.print_exc()

    return False
