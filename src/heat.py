"""Heat system — risk/reward mechanic. Higher heat = more income, but raids happen."""
from __future__ import annotations
import random
import math

# Heat clamps between 0 and 100 (percent)
HEAT_MIN = 0.0
HEAT_MAX = 100.0

# How fast heat naturally rises per building owned (per second), and decay rate
_HEAT_RISE_PER_BLD   = 0.0003   # each building pushes heat up slowly
_HEAT_PASSIVE_RISE   = 0.01     # baseline rise per second while running
_HEAT_NATURAL_DECAY  = 0.004    # natural slow cooldown per second

# Income bonus per heat point above 50 (additive multiplier, e.g. 0.008 per point)
_HEAT_INCOME_BONUS_PER_PT = 0.008   # heat 100 → +40% income bonus above base

# Click bonus per heat point above 30
_HEAT_CLICK_BONUS_PER_PT  = 0.005

# Raid thresholds
_RAID_HEAT_THRESHOLD = 60.0      # raids can start at 60+
_RAID_CHANCE_PER_SEC = 0.0012    # base probability per second at threshold
_RAID_HEAT_SCALE     = 0.004     # additional probability per heat point above threshold
_RAID_BALANCE_PENALTY = 0.08     # fraction of balance lost in a raid
_RAID_HEAT_REDUCTION  = 15.0     # heat drop after a successful raid

# Reduction from spending (lawyer / bribe upgrades applied via reduce_heat)
_LAWYER_REDUCTION    = 8.0
_BRIBE_REDUCTION     = 12.0


def heat_income_mult(heat: float) -> float:
    """Multiplicative income bonus from heat (additive over 1.0)."""
    bonus = max(0.0, heat - 50.0) * _HEAT_INCOME_BONUS_PER_PT
    return 1.0 + bonus


def heat_click_bonus(heat: float) -> float:
    """Extra click value multiplier from heat."""
    bonus = max(0.0, heat - 30.0) * _HEAT_CLICK_BONUS_PER_PT
    return 1.0 + bonus


def update_heat(state, dt: float) -> list[str]:
    """
    Tick heat, check for raids. Returns a list of event strings that occurred.
    Modifies state.heat in place.
    """
    events: list[str] = []

    heat: float = getattr(state, 'heat', 0.0)

    # Natural rise from operations
    total_bld = sum(b.owned for b in state.buildings)
    rise = (_HEAT_PASSIVE_RISE + total_bld * _HEAT_RISE_PER_BLD) * dt

    # Territory heat resistance reduces rise
    from src.territory import territory_heat_resistance, milestone_heat_mult
    territories = getattr(state, 'territories', [])
    resistance = territory_heat_resistance(territories)
    rise *= max(0.0, 1.0 - resistance)
    # 75% city-control milestone: -15% heat generation (Phase 10)
    rise *= milestone_heat_mult(state)

    # Clean Carl manager (the "Lawyer"): -30% heat gain rate.
    try:
        import src.managers as _mgr
        rise *= _mgr.heat_gain_mult(state)
    except Exception:
        pass

    # Decay: base + rank perk bonus heat decay + Consigliere branch perk
    rank_decay_bonus = 0.0
    try:
        import src.prestige as _prestige
        rank_decay_bonus = _prestige.rank_heat_decay_bonus(
            getattr(state, 'prestige_tokens', 0))
    except Exception:
        pass
    try:
        import src.prestige_tree as _ptree
        rank_decay_bonus += _ptree.heat_decay_bonus(state)
    except Exception:
        pass
    # Dragon Jade: per-territory heat decay bonus; Red: decay penalty.
    try:
        import src.dragon as _dragon
        rank_decay_bonus += _dragon.heat_decay_bonus(state)
        rank_decay_bonus -= _dragon.heat_decay_penalty(state)
    except Exception:
        pass
    decay = (_HEAT_NATURAL_DECAY + rank_decay_bonus) * dt

    heat_before = heat
    heat = max(HEAT_MIN, min(HEAT_MAX, heat + rise - decay))

    try:
        import src.managers as _mgr
        if _mgr.tick_carl_emergency(state, heat_before, heat):
            heat = float(getattr(state, 'heat', heat))
    except Exception:
        pass

    # Raid check (only above threshold)
    if heat >= _RAID_HEAT_THRESHOLD:
        excess = heat - _RAID_HEAT_THRESHOLD
        raid_prob = (_RAID_CHANCE_PER_SEC + excess * _RAID_HEAT_SCALE) * dt
        if random.random() < raid_prob:
            penalty = state.balance * _RAID_BALANCE_PENALTY
            try:
                import src.managers as _mgr
                actual, absorbed = _mgr.apply_raid_penalty(state, penalty, 'police')
                if absorbed:
                    events.append('raid:0:absorbed')
                else:
                    events.append(f'raid:{actual:.0f}')
            except Exception:
                state.balance = max(0.0, state.balance - penalty)
                events.append(f'raid:{penalty:.0f}')
            heat = max(HEAT_MIN, heat - _RAID_HEAT_REDUCTION)

    state.heat = heat
    return events


def heat_breakdown(state) -> dict:
    """Return a per-second breakdown of what's pushing heat up and down right now.

    Visibility helper (Part 6) — lets the UI show exactly why heat is rising or
    falling. Keys: 'rise' (list of (label, +/sec)), 'decay' (list of (label, -/sec)),
    'net' (float/sec), 'raid_risk' (bool).
    """
    rise_sources: list[tuple[str, float]] = []
    decay_sources: list[tuple[str, float]] = []

    total_bld = sum(b.owned for b in getattr(state, 'buildings', []))
    base_rise = _HEAT_PASSIVE_RISE + total_bld * _HEAT_RISE_PER_BLD

    # Resistance / milestone / manager multipliers applied to the rise
    from src.territory import territory_heat_resistance, milestone_heat_mult
    territories = getattr(state, 'territories', [])
    resistance = territory_heat_resistance(territories)
    mult = max(0.0, 1.0 - resistance) * milestone_heat_mult(state)
    try:
        import src.managers as _mgr
        mult *= _mgr.heat_gain_mult(state)
    except Exception:
        pass
    effective_rise = base_rise * mult
    rise_sources.append(("Operations (buildings)", effective_rise))
    if resistance > 0:
        rise_sources.append((f"  territory resistance -{resistance*100:.0f}%", 0.0))

    # Investigative rival passive heat (Federal Informants: +2 per growth tick ≈ avg)
    try:
        rivals = getattr(state, 'rivals', []) or []
        if any(r.trait == 'Investigative' and r.status != 'Eliminated' for r in rivals if r):
            rise_sources.append(("Federal Informants (rival)", 2.0 / 45.0))
    except Exception:
        pass

    # Decay sources
    base_decay = _HEAT_NATURAL_DECAY
    decay_sources.append(("Natural cooldown", base_decay))
    try:
        import src.prestige as _prestige
        rb = _prestige.rank_heat_decay_bonus(getattr(state, 'prestige_tokens', 0))
        if rb > 0:
            decay_sources.append(("Rank perk decay", rb))
    except Exception:
        pass
    try:
        import src.prestige_tree as _ptree
        cb = _ptree.heat_decay_bonus(state)
        if cb > 0:
            decay_sources.append(("Corruption (Clean Money)", cb))
    except Exception:
        pass
    try:
        import src.crew as _crew
        ca = getattr(state, 'crew', None)
        hr = _crew.heat_reduction_per_sec(ca) if ca else 0.0
        if hr > 0:
            decay_sources.append(("Crew (heat reduction)", hr))
    except Exception:
        pass
    try:
        import src.managers as _mgr
        if _mgr.manager_active(state, "The Promoter"):
            tgt = int(_mgr.promoter_heat_target(state))
            decay_sources.append((f"The Promoter (autopilot ≤{tgt}%)", 0.6))
    except Exception:
        pass
    # Nightclub launder
    try:
        club = state.buildings[7]
        if club.owned > 0:
            decay_sources.append(("Nightclubs (launder)", 0.5 * club.owned))
    except Exception:
        pass

    total_rise = sum(v for _, v in rise_sources)
    total_decay = sum(v for _, v in decay_sources)
    return {
        'rise': rise_sources,
        'decay': decay_sources,
        'net': total_rise - total_decay,
        'raid_risk': getattr(state, 'heat', 0.0) >= _RAID_HEAT_THRESHOLD,
        'raid_threshold': _RAID_HEAT_THRESHOLD,
    }


def reduce_heat(state, method: str = 'lawyer') -> None:
    """Instantly reduce heat via a lawyer or bribe."""
    amount = _LAWYER_REDUCTION if method == 'lawyer' else _BRIBE_REDUCTION
    state.heat = max(HEAT_MIN, getattr(state, 'heat', 0.0) - amount)


def heat_label(heat: float) -> str:
    if heat < 20:
        return "Low"
    if heat < 40:
        return "Moderate"
    if heat < 60:
        return "Elevated"
    if heat < 80:
        return "High"
    return "Critical"


def heat_color(heat: float) -> tuple:
    """RGB color for heat display — green → yellow → red."""
    if heat < 40:
        t = heat / 40.0
        r = int(60 + 195 * t)
        g = int(200 - 60 * t)
        return (r, g, 60)
    else:
        t = (heat - 40.0) / 60.0
        r = 255
        g = int(140 - 140 * t)
        return (r, g, 40)
