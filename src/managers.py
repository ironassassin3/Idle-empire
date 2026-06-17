"""Manager system — themed characters that automate buildings and boost income."""
from __future__ import annotations
import math
from dataclasses import dataclass, field
from typing import List
import pygame
import config
import src.theme as theme

_BTN_W, _BTN_H = 80, 36
_ROW_H = 92
_GAP   = 8
_ICON_SIZE = 40


@dataclass
class Manager:
    name: str
    building_index: int
    flavor: str
    cost: float
    title: str     = ""    # short role label
    bonus_desc: str = ""   # what bonus they give
    specialty: str = ""    # preferred strategy label
    hired: bool = False


# 13 managers — 11 buildings + Rudy & Rob on HQ. Save order is load-critical
# (hired[] by index in save_load.py) — never reorder.
#
# Phase 111 — acquisition: early tier payroll fees + milestone unlocks; late
# tier premium costs + rank gates. Fees tuned in _measure_p111.py for ENGAGED
# windows (Pete/Sal ~11m, Mechanic ~18m, Accountant ~25m) without reserving.
_EARLY_TIER_MAX = 5

# Payroll fees (early tier) — Phase 110 tuned
_PAYROLL_FEES = {
    0: 3_000.0,
    1: 10_000.0,
    2: 8_000.0,
    3: 4_000.0,
    4: 50_000.0,
    5: 65_000.0,
}

# Late-tier minimum rank (prestige_tokens → get_rank)
# Phase 117: Smuggler → Underboss (runway); Consigliere → Crime Lord (reachable P2)
_LATE_RANK_GATES: dict[int, str] = {
    6: "Capo",
    7: "Underboss",
    8: "Underboss",
    9: "Boss",
    10: "Crime Lord",
    11: "Kingpin",
    12: "Kingpin",
}

_LATE_TIER_START = 6
_LATE_VISIBILITY_RANK = "Made Man"
_TEASER_ROW_H = 36

MANAGERS: List[Manager] = [
    Manager("Sticky Pete",      0,
            "Runs the corner crew hands-off. Loyal to a fault.",
            3_000.0, "Street Boss",    "PETE'S PICK on Buildings + 1.5x Dealer",
            specialty="* Street Boss — marks your best buy"),
    Manager("The Collector",    1,
            "Nobody skips a payment. Nobody.",
            10_000.0, "Enforcer",    "SHIELD absorbs 1st raid / 5m + 1.5x Racket",
            specialty="* Protection — first raid bounces off"),
    Manager("The Mechanic",     2,
            "Chop shop runs itself. He only shows up to count the money.",
            8_000.0, "Night Shift", "AUTO-BUYS Chop Shop at 2× cost buffer",
            specialty="* Night Shift — Chop Shops run themselves"),
    Manager("Lucky Sal",        3,
            "He's never lost a bet. The house just doesn't know that.",
            4_000.0, "Bookmaker", "AUTO-COLLECTS golden coins + 1.5x Betting",
            specialty="* Bookmaker — coins find you"),
    Manager("Clean Carl",       4,
            "Everything's legitimate. He has the receipts to prove it.",
            50_000.0, "Front Man", "HEAT forecast + 1 free 60% rescue",
            specialty="* The Lawyer — heat forecast & emergency dump"),
    Manager("The Accountant",   5,
            "Makes debts disappear. Legally, most of the time.",
            65_000.0, "Fixer",  "AUTO-BUYS buildings + 1.5x Loan Shark",
            specialty="* Automation — buys the best building for you"),
    Manager("Maxine the Dealer",6,
            "House always wins. She makes sure the house is yours.",
            500_000_000.0, "Pit Boss", "BOOSTS manager behaviors per casino",
            specialty="* Pit Boss — +10% behaviors per casino"),
    Manager("The Promoter",     7,
            "VIP list: anyone with enough cash and no questions.",
            4_000_000_000.0, "Club King", "HEAT autopilot to your target",
            specialty="* Club King — heat autopilot (click to set target)"),
    Manager("The Smuggler",     8,
            "Containers arrive. Questions don't. Customs doesn't exist.",
            30_000_000_000.0, "Dock Master", "AUTO-STARTS ops + ready alerts",
            specialty="* Dock Master — ops queue runs in background"),
    Manager("The Broker",       9,
            "Supply chain optimization. Untraceable. Discreet.",
            250_000_000_000.0, "Arms Dealer", "TURF intel + 1 free retry / 5m",
            specialty="* Arms Dealer — intel highlights best district action"),
    Manager("The Consigliere",  10,
            "The whole operation, optimized. He sees everything.",
            2_000_000_000_000.0, "Underboss", "PRESTIGE advisory dashboard",
            specialty="* Underboss — reset timing intel on Prestige button"),
    Manager("Rudy Riches",      10,
            "The money guy. He knows exactly when to walk away and cash out.",
            8_000_000_000_000.0, "Money Guy", "PRESTIGE strategist — now vs wait intel",
            specialty="* Money Guy — full prestige window comparison"),
    Manager("Rob Revenue",      10,
            "The numbers guy. Every dollar has a story and Rob reads them all.",
            12_000_000_000_000.0, "Numbers Guy", "EMPIRE dashboard — income source breakdown",
            specialty="* Numbers Guy — see where your money comes from"),
]


def make_managers() -> List[Manager]:
    return [Manager(m.name, m.building_index, m.flavor, m.cost,
                    m.title, m.bonus_desc, m.specialty) for m in MANAGERS]


def hire_fee(idx: int) -> float:
    """Cash cost to hire manager idx (payroll early tier, premium late)."""
    if 0 <= idx < len(MANAGERS):
        return MANAGERS[idx].cost
    return 0.0


def _building_owned(state, idx: int) -> int:
    blds = getattr(state, 'buildings', [])
    return blds[idx].owned if idx < len(blds) else 0


def _rank_meets(state, required: str) -> bool:
    from src.prestige import get_rank, _rank_index
    return _rank_index(get_rank(getattr(state, 'prestige_tokens', 0))) >= _rank_index(required)


def manager_unlocked(state, idx: int) -> bool:
    """Phase 111 — computed from existing save state only."""
    if idx < 0 or idx >= len(MANAGERS):
        return False
    managers = getattr(state, 'managers', [])
    if idx < len(managers) and managers[idx].hired:
        return True
    if idx <= _EARLY_TIER_MAX:
        le = float(getattr(state, 'lifetime_earnings', 0))
        heat = float(getattr(state, 'heat', 0))
        heat_total = float(getattr(state, '_total_heat_generated', 0))
        if idx == 0:
            return le >= 25_000.0
        if idx == 1:
            return _building_owned(state, 1) >= 3
        if idx == 2:
            return _building_owned(state, 2) >= 2
        if idx == 3:
            return _building_owned(state, 3) >= 1 or le >= 25_000.0
        if idx == 4:
            return heat >= 40.0 or heat_total >= 80.0
        if idx == 5:
            blds = getattr(state, 'buildings', [])
            types = sum(1 for b in blds if b.owned > 0)
            return types >= 4 or le >= 200_000.0
    else:
        gate = _LATE_RANK_GATES.get(idx)
        if gate:
            return _rank_meets(state, gate)
    return False


def unlock_requirement_text(idx: int) -> str:
    if idx == 0:
        return "Reach $25K lifetime earnings"
    if idx == 1:
        return "Own 3 Protection Rackets"
    if idx == 2:
        return "Own 2 Chop Shops"
    if idx == 3:
        return "Reach $25K lifetime OR own 1 Betting Ring"
    if idx == 4:
        return "Heat reaches 40% (lawyer on retainer)"
    if idx == 5:
        return "Reach $200K lifetime OR own 4 building types"
    gate = _LATE_RANK_GATES.get(idx)
    if gate:
        return f"Reach rank {gate}"
    return "Unknown requirement"


def late_roster_expanded(state) -> bool:
    """Phase 117 — executive team hidden until Made Man / post-prestige path."""
    if getattr(state, '_prestige_count', 0) >= 1:
        return True
    if _rank_meets(state, _LATE_VISIBILITY_RANK):
        return True
    managers = getattr(state, 'managers', [])
    for idx in range(_LATE_TIER_START, len(managers)):
        if managers[idx].hired or manager_unlocked(state, idx):
            return True
    return False


def collapsed_late_count(state) -> int:
    managers = getattr(state, 'managers', [])
    return sum(1 for i in range(_LATE_TIER_START, len(managers)) if not managers[i].hired)


def rank_gate_progress(state, idx: int) -> tuple[str, int, int, int] | None:
    """Return (rank_name, tokens, threshold, pct) for a late manager gate."""
    gate = _LATE_RANK_GATES.get(idx)
    if not gate:
        return None
    from src.prestige import HIERARCHY
    tokens = int(getattr(state, 'prestige_tokens', 0))
    thresh = 0
    for t, name in HIERARCHY:
        if name == gate:
            thresh = t
            break
    if thresh <= 0:
        return gate, tokens, 0, 100
    pct = min(100, int(tokens / thresh * 100))
    return gate, tokens, thresh, pct


def display_hire_fee(state, idx: int, *, unlocked: bool) -> str:
    """Phase 117 — hide trillion sticker shock until rank gate opens."""
    fee = hire_fee(idx)
    if idx <= _EARLY_TIER_MAX:
        return _fmt(fee)
    if not unlocked:
        return "Premium payroll (affordable when unlocked)"
    return _fmt(fee)


_SECTION_H = 24

_SECTION_STYLES = {
    'active':    ("ACTIVE EMPLOYEES",     theme.GREEN),
    'available': ("AVAILABLE FOR HIRE",   theme.NOIR_GOLD),
    'locked':    ("LOCKED EMPLOYEES",     theme.TEXT_MUTED),
}


def _categorize_indices(state, indices: list[int]) -> tuple[list[int], list[int], list[int]]:
    managers = getattr(state, 'managers', [])
    hired, avail, locked = [], [], []
    for i in indices:
        if i >= len(managers):
            continue
        if managers[i].hired:
            hired.append(i)
        elif manager_unlocked(state, i):
            avail.append(i)
        else:
            locked.append(i)
    return hired, avail, locked


def _panel_row_plan(state) -> list[tuple[str, int | None | str]]:
    """Phase 123 — roster sections: active / available / locked + exec collapse."""
    managers = getattr(state, 'managers', [])
    n = len(managers)
    plan: list[tuple[str, int | None | str]] = []
    street_end = min(_EARLY_TIER_MAX + 1, n)
    street_idx = list(range(street_end))

    exec_indices: list[int] = []
    if late_roster_expanded(state) and not getattr(state, '_mgr_late_collapsed', True):
        exec_indices = list(range(_LATE_TIER_START, n))
    else:
        for i in range(_LATE_TIER_START, n):
            if i < len(managers) and managers[i].hired:
                exec_indices.append(i)

    all_idx = street_idx + exec_indices
    hired, avail, locked = _categorize_indices(state, all_idx)

    if hired:
        plan.append(('section', 'active'))
        for i in sorted(hired):
            plan.append(('mgr', i))
    if avail:
        plan.append(('section', 'available'))
        for i in sorted(avail):
            plan.append(('mgr', i))
    if locked:
        plan.append(('section', 'locked'))
        for i in sorted(locked):
            plan.append(('mgr', i))

    if not late_roster_expanded(state):
        plan.append(('teaser', None))
    else:
        plan.append(('collapse', None))

    return plan


def manager_panel_scroll_max(state) -> int:
    return max(0, len(_panel_row_plan(state)) - 1)


def count_visible_locked_late(state) -> int:
    """Metric helper — locked late cards shown in panel (Phase 117)."""
    if not late_roster_expanded(state):
        return 0
    if getattr(state, '_mgr_late_collapsed', False):
        return 0
    managers = getattr(state, 'managers', [])
    return sum(
        1 for i in range(_LATE_TIER_START, len(managers))
        if not managers[i].hired and not manager_unlocked(state, i)
    )


def next_executive_preview(state) -> str:
    """One-line anticipation hook for collapsed executive section."""
    managers = getattr(state, 'managers', [])
    for idx in range(_LATE_TIER_START, len(managers)):
        if managers[idx].hired:
            continue
        if manager_unlocked(state, idx):
            return f"{managers[idx].name} ready to hire"
        prog = rank_gate_progress(state, idx)
        if prog:
            gate, tokens, thresh, pct = prog
            return f"Next: {gate} ({tokens}/{thresh} Inf, {pct}%)"
    return "Expand turf & ops to climb ranks"


def can_hire_manager(state, idx: int) -> bool:
    managers = getattr(state, 'managers', [])
    if idx < 0 or idx >= len(managers):
        return False
    mgr = managers[idx]
    if mgr.hired:
        return False
    if not manager_unlocked(state, idx):
        return False
    return state.balance >= hire_fee(idx)


def tick_unlock_milestones(state) -> None:
    """One-shot milestone when a manager first becomes unlockable (runtime flags)."""
    shown = getattr(state, '_mgr_unlock_toast', None)
    if shown is None:
        shown = set()
        state._mgr_unlock_toast = shown
    queue = getattr(state, '_milestone_queue', None)
    if queue is None:
        return
    labels = {
        0: ("STICKY PETE AVAILABLE\n"
            "Your empire hit $25K lifetime — Pete can mark your best buys.\n"
            "Open Managers and pay his payroll fee."),
        1: ("THE COLLECTOR AVAILABLE\n"
            "Three rackets on the books — hire The Collector for raid shield.\n"
            "First hit each 5 minutes bounces completely."),
        2: ("THE MECHANIC AVAILABLE\n"
            "Two chop shops running — The Mechanic auto-buys Chop Shops.\n"
            "Your first slice of building automation."),
        4: ("CLEAN CARL AVAILABLE\n"
            "Heat is climbing — Carl shows a forecast and one free emergency dump.\n"
            "Hire before the police raid your cash."),
        3: ("LUCKY SAL AVAILABLE\n"
            "The betting ring is open — Sal auto-collects golden coins.\n"
            "Hire him from the Managers tab."),
        5: ("THE ACCOUNTANT AVAILABLE\n"
            "Four building lines running — hire The Accountant for auto-buy.\n"
            "Payroll is a fraction of what buildings cost."),
        11: ("RUDY RICHES AVAILABLE\n"
             "Kingpin rank unlocked — Rudy compares prestige now vs 5m vs 10m.\n"
             "Stop guessing when to reset; hire the money guy."),
        12: ("ROB REVENUE AVAILABLE\n"
             "Kingpin rank — Rob breaks down buildings, ops, turf, and clicks.\n"
             "Open Stats for the empire dashboard."),
    }
    for idx, msg in labels.items():
        key = f"unlock_{idx}"
        if key in shown:
            continue
        managers = getattr(state, 'managers', [])
        if idx >= len(managers) or managers[idx].hired:
            shown.add(key)
            continue
        if manager_unlocked(state, idx):
            shown.add(key)
            queue.insert(0, msg)
            if getattr(state, '_milestone_timer', 0) <= 0:
                state._milestone_timer = 6.0
    if 'exec_team' not in shown and late_roster_expanded(state):
        shown.add('exec_team')
        queue.insert(0, (
            "EXECUTIVE TEAM UNLOCKED\n"
            "Five rank-gated specialists join your roster — Maxine through Consigliere.\n"
            "Open Managers to track rank progress toward each hire."
        ))
        if getattr(state, '_milestone_timer', 0) <= 0:
            state._milestone_timer = 6.0


def manager_active(state, name: str) -> bool:
    return any(m.hired and m.name == name for m in getattr(state, 'managers', []))


# ─── Unique manager effects ──────────────────────────────────────────────────
# Sessions 2-3: managers were a flat +1.5x income (no gameplay). Each now has a
# UNIQUE identity — a reason to actively pursue THAT manager — instead of being
# interchangeable percentages. Effects are keyed by manager name so the set is
# easy to extend. Two kinds:
#   • ACTIVE ticks (automation, heat laundering) — run in tick_manager_effects.
#   • PASSIVE modifiers (click boost, raid shield, op/territory/prestige bonuses,
#     heat-gain reduction, luckier coins) — queried by the relevant system.
#
# Identity summary (the "why hire this one" hook):
#   Sticky Pete    — Corner Dealer: PETE'S PICK highlights best building buy (Phase 109)
#   The Collector  — Racket: shield absorbs first raid / 5m (Phase 113)
#   The Mechanic   — Chop Shop: auto-buys Chop Shop only (Phase 113)
#   Lucky Sal      — Betting: AUTO-COLLECT golden coins (Phase 109)
#   Clean Carl     — Pawn: heat forecast + one 60% emergency dump (Phase 113)
#   The Accountant — Loan: AUTO-BUYS buildings (automation)
#   Maxine         — Casino: +10% behavioral speed per casino owned (Phase 114)
#   The Promoter   — Nightclub: heat autopilot to player target (Phase 114)
#   The Smuggler   — Dock: auto-starts ops + ready alerts (Phase 114)
#   The Broker     — Arms: turf intel + free retry on failed capture (Phase 114)
#   The Consigliere— HQ: prestige timing advisory (Phase 114)
#   Rudy Riches    — HQ: expanded prestige strategist dashboard (Phase 118)
#   Rob Revenue    — HQ: empire efficiency analyst dashboard (Phase 119)

# ── Passive modifier queries (read by other systems) ─────────────────────────

def pete_recommends_index(state) -> int | None:
    """Sticky Pete (Phase 109): best income/$ building the player can afford."""
    if not manager_active(state, "Sticky Pete"):
        return None
    best_idx: int | None = None
    best_ratio = 0.0
    for i, b in enumerate(state.buildings):
        cost = b.current_cost
        if cost <= 0 or state.balance < cost:
            continue
        ratio = (b.base_income * b.income_multiplier) / cost
        if ratio > best_ratio:
            best_ratio = ratio
            best_idx = i
    return best_idx


def raid_damage_mult(state) -> float:
    """The Collector: -35% raid damage on non-shield hits."""
    return 0.65 if manager_active(state, "The Collector") else 1.0


_COLLECTOR_SHIELD_CD = 300.0
_MECHANIC_BUILDING_IDX = 2
_MECHANIC_AUTOBUY_INTERVAL = 3.0
_MECHANIC_BALANCE_MULT = 2.0
_CARL_RAID_THRESHOLD = 60.0
_CARL_EMERGENCY_TARGET = 55.0
_CARL_EMERGENCY_DROP = 20.0


def tick_collector_shield(state, dt: float) -> None:
    cd = getattr(state, '_collector_shield_cd', 0.0)
    if cd > 0:
        state._collector_shield_cd = max(0.0, cd - dt * maxine_behavior_mult(state))


def collector_shield_ready(state) -> bool:
    return (manager_active(state, "The Collector")
            and getattr(state, '_collector_shield_cd', 0.0) <= 0.0)


def collector_shield_fraction(state) -> float:
    if not manager_active(state, "The Collector"):
        return 0.0
    cd = getattr(state, '_collector_shield_cd', 0.0)
    if cd <= 0:
        return 1.0
    return max(0.0, 1.0 - cd / _COLLECTOR_SHIELD_CD)


def apply_raid_penalty(state, penalty: float, source: str = 'police') -> tuple[float, bool]:
    """Apply raid cash loss. Returns (actual_penalty, fully_absorbed)."""
    if penalty <= 0:
        return 0.0, False
    actual = penalty
    absorbed = False
    if manager_active(state, "The Collector"):
        if collector_shield_ready(state):
            actual = 0.0
            absorbed = True
            state._collector_shield_cd = _COLLECTOR_SHIELD_CD
            state._collector_absorbs = getattr(state, '_collector_absorbs', 0) + 1
        else:
            actual = penalty * raid_damage_mult(state)
    state.balance = max(0.0, state.balance - actual)
    state._last_raid_absorbed = absorbed
    state._last_raid_source = source
    return actual, absorbed


def heat_forecast_delta(state, horizon_sec: float = 120.0) -> float:
    """Projected heat change over horizon (for Carl UI)."""
    try:
        import src.heat as _heat
        bd = _heat.heat_breakdown(state)
        current = float(getattr(state, 'heat', 0.0))
        end = max(_heat.HEAT_MIN, min(_heat.HEAT_MAX, current + bd['net'] * horizon_sec))
        return end - current
    except Exception:
        return 0.0


def tick_carl_emergency(state, heat_before: float, heat_after: float) -> bool:
    """One free auto-dump when crossing 60% upward per prestige run."""
    if not manager_active(state, "Clean Carl"):
        return False
    if getattr(state, '_carl_emergency_used', False):
        return False
    if heat_before < _CARL_RAID_THRESHOLD and heat_after >= _CARL_RAID_THRESHOLD:
        state._carl_emergency_used = True
        state.heat = max(0.0, min(_CARL_EMERGENCY_TARGET,
                                   heat_after - _CARL_EMERGENCY_DROP))
        state._carl_emergency_fired = getattr(state, '_carl_emergency_fired', 0) + 1
        return True
    return False


def heat_gain_mult(state) -> float:
    """Clean Carl (the 'Lawyer'): -30% heat gain rate."""
    return 0.70 if manager_active(state, "Clean Carl") else 1.0


def operation_reward_mult(state) -> float:
    """The Smuggler: +30% operation rewards."""
    return 1.30 if manager_active(state, "The Smuggler") else 1.0


def territory_success_bonus(state) -> float:
    """The Broker: +15% additive territory action success chance."""
    return 0.15 if manager_active(state, "The Broker") else 0.0


def influence_gain_mult(state) -> float:
    """The Consigliere: +20% Influence gained on prestige."""
    return 1.20 if manager_active(state, "The Consigliere") else 1.0


# ── Phase 114 — late manager behaviors ─────────────────────────────────────

_PROMOTER_TARGETS = (40.0, 50.0, 60.0)
_BROKER_RETRY_CD = 300.0
_SMUGGLER_CHECK_INTERVAL = 2.0


def maxine_behavior_mult(state) -> float:
    """Maxine: +10% behavioral effect speed per owned casino."""
    if not manager_active(state, "Maxine the Dealer"):
        return 1.0
    blds = getattr(state, 'buildings', [])
    casinos = blds[6].owned if len(blds) > 6 else 0
    return 1.0 + 0.10 * casinos


def sal_autocollect_delay(state) -> float:
    return 0.75 / maxine_behavior_mult(state)


def _behavior_interval(base: float, state) -> float:
    m = maxine_behavior_mult(state)
    return base / m if m > 0 else base


def promoter_heat_target(state) -> float:
    return float(getattr(state, '_promoter_heat_target', 50.0))


def cycle_promoter_target(state) -> float:
    if not manager_active(state, "The Promoter"):
        return promoter_heat_target(state)
    cur = promoter_heat_target(state)
    opts = _PROMOTER_TARGETS
    try:
        nxt = opts[(opts.index(cur) + 1) % len(opts)]
    except ValueError:
        nxt = opts[1]
    state._promoter_heat_target = nxt
    return nxt


def tick_promoter_heat(state, dt: float) -> None:
    """Heat autopilot — launder toward player target (Phase 114)."""
    if not manager_active(state, "The Promoter"):
        return
    try:
        import src.heat as _heat
    except Exception:
        return
    target = promoter_heat_target(state)
    heat = float(getattr(state, 'heat', 0.0))
    decay = 0.35 * dt
    try:
        club = state.buildings[7]
        decay += 0.5 * club.owned * dt
    except Exception:
        pass
    if heat > target:
        decay += min(heat - target, 20.0) * 0.06 * dt
    state.heat = max(_heat.HEAT_MIN, heat - decay)


def tick_broker_retry_cd(state, dt: float) -> None:
    cd = getattr(state, '_broker_retry_cd', 0.0)
    if cd > 0:
        state._broker_retry_cd = max(0.0, cd - dt)


def broker_retry_ready(state) -> bool:
    return (manager_active(state, "The Broker")
            and getattr(state, '_broker_retry_cd', 0.0) <= 0.0)


def broker_best_action(state, terr_idx: int) -> str | None:
    """Best territory action by success chance (Broker intel)."""
    if not manager_active(state, "The Broker"):
        return None
    territories = getattr(state, 'territories', [])
    if terr_idx < 0 or terr_idx >= len(territories):
        return None
    t = territories[terr_idx]
    if t.unlocked:
        return None
    try:
        import src.territory as _terr
        best_a, best_c = None, 0.0
        for action, _, _ in _terr._ACTIONS:
            c = _terr._success_chance(state, t, action)
            if c > best_c:
                best_c, best_a = c, action
        return best_a
    except Exception:
        return None


def tick_smuggler_ops(state, dt: float) -> None:
    """Auto-start next affordable op; notify when one is ready (Phase 114)."""
    if not manager_active(state, "The Smuggler"):
        return
    state._smuggler_timer = getattr(state, '_smuggler_timer', 0.0) + dt
    if state._smuggler_timer < _SMUGGLER_CHECK_INTERVAL:
        return
    state._smuggler_timer = 0.0
    ops = getattr(state, 'operations', [])
    notified: set = getattr(state, '_smuggler_notified', set())
    for i, op in enumerate(ops):
        if op.collected:
            notified.discard(i)
        elif op.is_ready and i not in notified:
            notified.add(i)
            state._smuggler_ready_notifs = getattr(state, '_smuggler_ready_notifs', 0) + 1
            try:
                import src.ui as _ui
                _ui.push_notification(f"Smuggler: {op.name} ready to collect!",
                                      theme.TEXT_GOLD)
            except Exception:
                pass
    state._smuggler_notified = notified
    if any(o.active and not o.collected for o in ops):
        return
    for op in ops:
        can, _ = op.can_start(state)
        if can:
            op.start(state)
            state._smuggler_op_starts = getattr(state, '_smuggler_op_starts', 0) + 1
            try:
                import src.ui as _ui
                _ui.push_notification(f"Smuggler launched {op.name}", theme.GREEN)
            except Exception:
                pass
            break


def consigliere_advice(state) -> dict | None:
    """Backward-compatible alias — use prestige_advice() for full intel."""
    return prestige_advice(state)


def prestige_advice(state) -> dict | None:
    """Prestige timing intel — Consigliere base, Rudy expands (Phase 114/118)."""
    has_consig = manager_active(state, "The Consigliere")
    has_rudy = manager_active(state, "Rudy Riches")
    if not has_consig and not has_rudy:
        return None
    try:
        import src.prestige as _prestige
        ips = float(getattr(state, 'income_per_second', 0.0))
        le = float(getattr(state, 'lifetime_earnings', 0.0))
        tokens = int(getattr(state, 'prestige_tokens', 0))
        gain_now = _prestige.calc_influence_gain(le)
        gain_5 = _prestige.calc_influence_gain(le + ips * 300)
        gain_10 = _prestige.calc_influence_gain(le + ips * 600)
        can_now = _prestige.can_prestige(state)
        d5 = gain_5 - gain_now
        d10 = gain_10 - gain_now
        rank_after = _prestige.get_rank(tokens + gain_now)
        income_pct = gain_now * 2
        need = _prestige.prestige_earnings_required(state)
        pct = int(min(100, le / need * 100)) if need > 0 else 0

        if can_now:
            if has_rudy:
                if d10 >= 2 and gain_10 > gain_now * 1.20:
                    window, rec = "WAIT_10", f"wait 10m (+{d10} Influence)"
                elif d5 >= 1 and gain_5 > gain_now * 1.10:
                    window, rec = "WAIT_5", f"wait 5m (+{d5} Influence)"
                else:
                    window, rec = "NOW", "prestige now — peak window"
            elif gain_5 > gain_now * 1.12:
                window, rec = "WAIT_5", "wait 5m (+Influence)"
            elif gain_10 > gain_now * 1.20:
                window, rec = "WAIT_10", "wait 10m (+Influence)"
            else:
                window, rec = "NOW", "prestige now"
        else:
            window, rec = "BUILD", f"{pct}% to prestige gate"

        summary = (
            f"+{gain_now} Influence, +{income_pct}% run income, rank → {rank_after}"
        )
        out = {
            'ips': ips,
            'gain_now': gain_now,
            'gain_5m': gain_5,
            'gain_10m': gain_10,
            'delta_5m': d5,
            'delta_10m': d10,
            'recommend': rec,
            'window': window,
            'summary': summary,
            'rank_after': rank_after,
            'income_pct': income_pct,
            'enhanced': has_rudy,
            'source': 'Rudy' if has_rudy else 'Consigliere',
        }
        if has_rudy and can_now and window == "NOW":
            out['confidence'] = min(100, 70 + d5 * 5 + (10 if d10 <= d5 else 0))
        elif has_rudy and can_now:
            out['confidence'] = min(95, 55 + max(d5, d10) * 4)
        elif has_rudy:
            out['confidence'] = pct
        return out
    except Exception:
        return None


def _territory_income_mult(state) -> float:
    territories = getattr(state, 'territories', [])
    try:
        import src.territory as _terr
        import src.prestige_tree as _ptree
        return (
            _terr.territory_income_mult(territories)
            * (1.0 + _terr.territory_district_count_bonus(territories))
            * _terr.milestone_income_mult(state)
            * _ptree.district_income_mult(state)
        )
    except Exception:
        return 1.0


def _estimate_click_rate(state) -> float:
    import time as _time
    recent = getattr(state, '_recent_clicks', [])
    now = _time.time()
    window = [t for t in recent if now - t <= 10.0]
    cps = len(window) / 10.0 if window else 0.0
    if cps < 0.05:
        play = max(1.0, float(getattr(state, '_play_time', getattr(state, '_time', 1.0))))
        clicks = float(getattr(state, '_click_count', 0))
        cps = clicks / play
    try:
        cv = float(state.click_value)
    except Exception:
        cv = 0.0
    return cv * cps


def _estimate_operations_rate(state) -> float:
    ips = float(getattr(state, 'income_per_second', 0.0) or 0.0)
    total = 0.0
    for op in getattr(state, 'operations', []):
        dur = op._eff_duration if op.active else op.duration
        if dur <= 0:
            continue
        if op.active and not op.collected and op.reward > 0:
            total += op.reward / dur
        elif not op.active and not op.collected:
            can, _ = op.can_start(state)
            if can and ips > 0:
                total += ips * op.reward_mult / dur * 0.35
    return total


def _rob_recommendations(state, shares: dict[str, float]) -> list[str]:
    recs: list[str] = []
    ops = getattr(state, 'operations', [])
    can_op = any(op.can_start(state)[0] for op in ops)
    if shares.get('operations', 0) < 8.0 and can_op:
        recs.append("Operations are underperforming.")
    if shares.get('territory', 0) >= 20.0:
        b = shares.get('buildings', 0)
        t = shares.get('territory', 0)
        if t >= b * 0.85:
            recs.append("Territories now generate most revenue.")
    clk = shares.get('clicks', 0)
    if clk < 8.0:
        recs.append(f"Clicks are only {clk:.0f}% of income.")
    try:
        import src.prestige as _prestige
        if _prestige.can_prestige(state):
            adv = prestige_advice(state)
            if adv and adv.get('window') == 'NOW':
                recs.append("Consider another prestige.")
            elif adv and adv.get('window') in ('WAIT_5', 'WAIT_10'):
                recs.append("Hold prestige — income still climbing.")
    except Exception:
        pass
    if not recs:
        ranked = sorted(shares.items(), key=lambda x: x[1])
        if ranked and ranked[0][1] < 5.0:
            labels = {
                'buildings': 'Building income',
                'territory': 'Territory bonuses',
                'operations': 'Operations',
                'clicks': 'Clicks',
            }
            recs.append(f"{labels.get(ranked[0][0], ranked[0][0])} need attention.")
    return recs[:4]


def empire_efficiency_report(state) -> dict | None:
    """Phase 119 — Rob Revenue income breakdown and recommendations."""
    if not manager_active(state, "Rob Revenue"):
        return None
    ips = float(getattr(state, 'income_per_second', 0.0) or 0.0)
    terr_mult = max(1.0, _territory_income_mult(state))
    building_rate = ips / terr_mult if ips > 0 else 0.0
    territory_rate = max(0.0, ips - building_rate)
    ops_rate = _estimate_operations_rate(state)
    click_rate = _estimate_click_rate(state)
    total = building_rate + territory_rate + ops_rate + click_rate
    if total <= 0:
        total = 1.0

    shares = {
        'buildings': building_rate / total * 100.0,
        'territory': territory_rate / total * 100.0,
        'operations': ops_rate / total * 100.0,
        'clicks': click_rate / total * 100.0,
    }
    labels = {
        'buildings': 'Buildings',
        'territory': 'Territories',
        'operations': 'Operations',
        'clicks': 'Clicks',
    }
    ranked = sorted(shares.items(), key=lambda x: x[1], reverse=True)
    strongest = (labels[ranked[0][0]], ranked[0][1])
    weakest = (labels[ranked[-1][0]], ranked[-1][1])
    recs = _rob_recommendations(state, shares)
    headline = recs[0] if recs else f"{strongest[0]} lead at {strongest[1]:.0f}%"
    return {
        'rates': {
            'buildings': building_rate,
            'territory': territory_rate,
            'operations': ops_rate,
            'clicks': click_rate,
            'total': total,
        },
        'shares': shares,
        'strongest': strongest,
        'weakest': weakest,
        'recommendations': recs,
        'headline': headline,
    }


_AUTOBUY_INTERVAL = 3.0  # seconds between Accountant auto-purchases


def _auto_buy_chop_shop(state) -> bool:
    """Mechanic (Phase 113): auto-buy Chop Shop when balance >= 2× next cost."""
    if not manager_active(state, "The Mechanic"):
        return False
    blds = getattr(state, 'buildings', [])
    if _MECHANIC_BUILDING_IDX >= len(blds):
        return False
    b = blds[_MECHANIC_BUILDING_IDX]
    cost = b.current_cost
    if cost <= 0 or state.balance < cost * _MECHANIC_BALANCE_MULT:
        return False
    state.balance -= cost
    b.owned += 1
    state._mechanic_autobuys = getattr(state, '_mechanic_autobuys', 0) + 1
    return True


def tick_manager_effects(state, dt: float) -> None:
    """Tick unique, hired-manager active effects. Modifies state in place.

    Called once per frame from PlayingState.update.
    """
    managers = getattr(state, 'managers', [])
    if not managers:
        return

    tick_collector_shield(state, dt)
    tick_broker_retry_cd(state, dt)

    beh_iv = lambda base: _behavior_interval(base, state)

    # ── The Mechanic (idx 2): partial automation — Chop Shop only (Phase 113)
    if manager_active(state, "The Mechanic"):
        state._mechanic_timer = getattr(state, '_mechanic_timer', 0.0) + dt
        if state._mechanic_timer >= beh_iv(_MECHANIC_AUTOBUY_INTERVAL):
            state._mechanic_timer = 0.0
            if _auto_buy_chop_shop(state):
                n = getattr(state, '_mechanic_autobuys', 0)
                if n == 1 or n % 3 == 0:
                    try:
                        import src.ui as _ui
                        _ui.push_notification(
                            "Mechanic ordered another Chop Shop", theme.GREEN)
                    except Exception:
                        pass

    # ── The Accountant (idx 5): AUTOMATION — auto-buys the best-value building
    if manager_active(state, "The Accountant"):
        state._autobuy_timer = getattr(state, '_autobuy_timer', 0.0) + dt
        if state._autobuy_timer >= beh_iv(_AUTOBUY_INTERVAL):
            state._autobuy_timer = 0.0
            _auto_buy_best(state)

    tick_promoter_heat(state, dt)
    tick_smuggler_ops(state, dt)


def _auto_buy_best(state) -> None:
    """Buy the single best income/$ building the player can afford (Accountant)."""
    best, best_ratio = None, 0.0
    for b in state.buildings:
        cost = b.current_cost
        if cost <= 0 or state.balance < cost:
            continue
        ratio = (b.base_income * b.income_multiplier) / cost
        if ratio > best_ratio:
            best_ratio, best = ratio, b
    if best is not None:
        state.balance -= best.current_cost
        best.owned += 1


def compute_base_income(state) -> float:
    """Total base income/sec, applying perk multipliers, manager bonuses, and building specials."""
    from src.buildings import global_special_mult, casino_manager_bonus
    perk_blds = getattr(state, '_perk_bld_mults', [])
    managers  = getattr(state, 'managers', [])
    global_mult = global_special_mult(state.buildings)
    mgr_bonus   = casino_manager_bonus(state.buildings)
    # Crew Network perk (manager_unlock): managers grant 2.0× instead of 1.5×.
    from src.prestige_tree import manager_income_mult
    mgr_mult = manager_income_mult(state)
    total = 0.0
    for i, b in enumerate(state.buildings):
        base = b.base_income * b.owned * b.income_multiplier
        if perk_blds and i < len(perk_blds):
            base *= perk_blds[i]
        if any(m.hired and m.building_index == i for m in managers):
            base *= mgr_mult * mgr_bonus
        total += base
    return total * global_mult


# ─── Icon cache ────────────────────────────────────────────────────────────────
_ICON_CACHE: dict[int, pygame.Surface] = {}


def _make_icon(idx: int) -> pygame.Surface:
    s = pygame.Surface((_ICON_SIZE, _ICON_SIZE), pygame.SRCALPHA)
    c = _ICON_SIZE // 2

    hues = [
        (180, 100, 40), (80, 60, 180), (60, 140, 80), (180, 50, 50),
        (100, 80, 160), (60, 160, 140), (160, 50, 120), (80, 130, 180),
        (140, 100, 40), (100, 40, 160), (160, 130, 50), (200, 170, 60), (90, 150, 120),
    ]
    bg_col = hues[idx % len(hues)]
    pygame.draw.circle(s, bg_col, (c, c), c - 2)
    pygame.draw.circle(s, tuple(min(255, v + 60) for v in bg_col), (c, c), c - 2, 2)

    name = MANAGERS[idx].name if idx < len(MANAGERS) else "?"
    initial = name.replace("The ", "").split()[-1][0].upper()
    try:
        glyph = pygame.font.SysFont("serif", max(14, _ICON_SIZE // 2), bold=True).render(
            initial, True, theme.NOIR_INK)
        s.blit(glyph, glyph.get_rect(center=(c, c + 1)))
    except Exception:
        pygame.draw.circle(s, theme.TEXT_PRIMARY, (c, c - 7), 7)
        pygame.draw.ellipse(s, theme.TEXT_PRIMARY, pygame.Rect(c - 9, c + 2, 18, 12))

    return s


def _get_icon(idx: int) -> pygame.Surface:
    if idx not in _ICON_CACHE:
        _ICON_CACHE[idx] = _make_icon(idx)
    return _ICON_CACHE[idx]


def _icon_initial(name: str) -> str:
    return name.replace("The ", "").split()[-1][0].upper()


def _department_label(mgr: Manager) -> str:
    """Short department / role line for roster identity."""
    return mgr.title or "Staff"


def _employee_status(state, idx: int) -> tuple[str, tuple, str]:
    """Phase 123 — (status line, color, badge kind) for roster cards."""
    managers = getattr(state, 'managers', [])
    if idx >= len(managers):
        return "", theme.TEXT_MUTED, "idle"
    mgr = managers[idx]

    if mgr.hired:
        name = mgr.name
        if name == "Lucky Sal":
            return "Collecting coins", theme.NOIR_GOLD_BRIGHT, "auto"
        if name == "The Mechanic":
            return "Managing Chop Shops", theme.GREEN, "auto"
        if name == "The Collector":
            shield = collector_shield_fraction(state)
            if shield >= 1.0:
                return "Shield ready", theme.BLUE_BRIGHT, "ready"
            return f"Shield charging ({int(shield * 100)}%)", theme.BLUE_BRIGHT, "working"
        if name == "Clean Carl":
            delta = heat_forecast_delta(state, 120.0)
            if abs(delta) >= 0.5:
                sign = '+' if delta >= 0 else ''
                return f"Forecast {sign}{delta:.0f}% / 2m", theme.NOIR_GOLD, "working"
            return "Monitoring heat", theme.NOIR_GOLD, "working"
        if name == "The Accountant":
            return "Empire automation active", theme.GREEN, "auto"
        if name == "The Promoter":
            tgt = int(promoter_heat_target(state))
            return f"Maintaining heat ≤ {tgt}%", theme.CRIT_COLOR, "auto"
        if name == "The Smuggler":
            ops = getattr(state, 'operations', []) or []
            ready = sum(1 for op in ops if op.is_ready)
            active = sum(1 for op in ops if op.active and not op.collected and not op.is_ready)
            if ready:
                return f"Operation ready ({ready})", theme.GREEN, "ready"
            if active:
                return "Monitoring operations", theme.PARTICLE_IDLE, "working"
            return "Monitoring operations", theme.PARTICLE_IDLE, "working"
        if name == "The Broker":
            return "Turf intel active", theme.BLUE_BRIGHT, "working"
        if name == "The Consigliere":
            return "Prestige advisory active", theme.PRESTIGE_LABEL, "working"
        if name == "Rudy Riches":
            adv = prestige_advice(state)
            if adv:
                return f"Prestige analysis — {adv['recommend']}", theme.NOIR_GOLD, "working"
            return "Prestige analysis active", theme.NOIR_GOLD, "working"
        if name == "Rob Revenue":
            rep = empire_efficiency_report(state)
            if rep:
                return f"Reviewing finances — {rep['headline']}", theme.NOIR_GOLD_BRIGHT, "working"
            return "Reviewing finances", theme.NOIR_GOLD_BRIGHT, "working"
        if name == "Maxine the Dealer":
            syn = maxine_behavior_mult(state)
            if syn > 1.0:
                return f"Coordinating staff (+{int((syn - 1) * 100)}%)", theme.GREEN, "working"
            return "Coordinating employees", theme.GREEN, "working"
        if name == "Sticky Pete":
            if pete_recommends_index(state) is not None:
                return "Marking best building buy", theme.NOIR_GOLD, "working"
            return "Scouting street deals", theme.NOIR_GOLD, "working"
        return "On payroll", theme.GREEN, "working"

    if not manager_unlocked(state, idx):
        if idx >= _LATE_TIER_START:
            gate = _LATE_RANK_GATES.get(idx, "?")
            return f"Requires rank {gate}", theme.TEXT_MUTED, "locked"
        return unlock_requirement_text(idx), theme.TEXT_MUTED, "locked"

    return "Payroll open — ready to hire", theme.NOIR_GOLD_BRIGHT, "ready"


def _draw_pill(surface, fonts, text: str, x: int, y: int, color: tuple,
               bg_alpha: int = 200) -> pygame.Rect:
    ls = fonts['xs'].render(text, True, color)
    pad_x, pad_y = 6, 2
    rect = pygame.Rect(x, y, ls.get_width() + pad_x * 2, ls.get_height() + pad_y * 2)
    pill = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
    fill = tuple(int(c * 0.25) for c in color)
    pygame.draw.rect(pill, (*fill, bg_alpha), pill.get_rect(), border_radius=4)
    pygame.draw.rect(pill, (*color, min(255, bg_alpha + 30)), pill.get_rect(), border_radius=4, width=1)
    pill.blit(ls, ls.get_rect(center=(rect.width // 2, rect.height // 2)))
    surface.blit(pill, rect.topleft)
    return rect


def _draw_section_header(surface, fonts, panel_rect: pygame.Rect, y: int,
                         section_key: str, count: int) -> int:
    label, col = _SECTION_STYLES.get(section_key, ("SECTION", theme.TEXT_MUTED))
    disp = fonts.get('disp_xs', fonts['xs'])
    txt = f"{label}  ({count})"
    ls = disp.render(txt, True, col)
    surface.blit(ls, (panel_rect.x + 8, y))
    sep_x = panel_rect.x + 8 + ls.get_width() + 8
    sep_w = max(20, panel_rect.width - sep_x - 12)
    sep = pygame.Surface((sep_w, 1), pygame.SRCALPHA)
    sep.fill((*col, 70))
    surface.blit(sep, (sep_x, y + ls.get_height() // 2))
    return y + _SECTION_H


def _draw_manager_card(surface, state, fonts, idx: int, rr: pygame.Rect,
                       t: float, mx: int, my: int) -> None:
    """Phase 123 employee roster card."""
    mgr = state.managers[idx]
    unlocked = manager_unlocked(state, idx)
    fee = hire_fee(idx)
    can = unlocked and not mgr.hired and state.balance >= fee
    hover = rr.collidepoint(mx, my)
    card_h = rr.height
    status_txt, status_col, badge_kind = _employee_status(state, idx)

    if mgr.hired:
        bg_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
        pygame.draw.rect(bg_surf, (16, 32, 22, 235), bg_surf.get_rect(), border_radius=10)
        surface.blit(bg_surf, rr.topleft)
        pygame.draw.rect(surface, (*theme.GREEN, 90), rr, border_radius=10, width=1)
        bar = pygame.Surface((3, card_h - 14), pygame.SRCALPHA)
        bar.fill((*theme.GREEN, 220))
        surface.blit(bar, (rr.x + 4, rr.y + 7))
    elif not unlocked:
        bg_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
        pygame.draw.rect(bg_surf, (22, 22, 30, 210), bg_surf.get_rect(), border_radius=10)
        surface.blit(bg_surf, rr.topleft)
        pygame.draw.rect(surface, (55, 55, 70), rr, border_radius=10, width=1)
    else:
        bg = (38, 36, 28, 240) if can else (theme.BG_CARD_HOVER if hover else theme.BG_CARD)
        if isinstance(bg, tuple) and len(bg) == 4:
            bg_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
            pygame.draw.rect(bg_surf, bg, bg_surf.get_rect(), border_radius=10)
            surface.blit(bg_surf, rr.topleft)
        else:
            pygame.draw.rect(surface, bg, rr, border_radius=10)
        if can:
            pulse_a = int(80 + 70 * math.sin(t * 2.8))
            pulse_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
            pygame.draw.rect(pulse_surf, (*theme.NOIR_GOLD, pulse_a),
                             pulse_surf.get_rect(), border_radius=10, width=2)
            surface.blit(pulse_surf, rr.topleft)
        elif hover:
            pygame.draw.rect(surface, theme.NOIR_GOLD_DEEP, rr, border_radius=10, width=1)

    icon = _get_icon(idx)
    icon_x = rr.x + 10
    icon_y = rr.y + (card_h - _ICON_SIZE) // 2
    if not unlocked and not mgr.hired:
        icon_copy = icon.copy()
        icon_copy.set_alpha(90)
        surface.blit(icon_copy, (icon_x, icon_y))
    else:
        surface.blit(icon, (icon_x, icon_y))

    text_x = icon_x + _ICON_SIZE + 10
    name_col = theme.TEXT_MUTED if not unlocked and not mgr.hired else theme.TEXT_PRIMARY
    name_font = fonts.get('disp_sm', fonts['sm'])
    ns = name_font.render(mgr.name, True, name_col)
    surface.blit(ns, (text_x, rr.y + 6))

    dept = _department_label(mgr)
    _draw_pill(surface, fonts, dept, text_x + ns.get_width() + 8, rr.y + 8,
               theme.NOIR_GOLD if mgr.hired else theme.NOIR_BONE_DIM)

    if mgr.hired:
        _draw_pill(surface, fonts, "ON PAYROLL", rr.right - 78, rr.y + 6, theme.GREEN)
    elif unlocked:
        _draw_pill(surface, fonts, "OPEN", rr.right - 52, rr.y + 6, theme.NOIR_GOLD_BRIGHT)
    else:
        _draw_pill(surface, fonts, "LOCKED", rr.right - 58, rr.y + 6, theme.TEXT_MUTED, 140)

    st_y = rr.y + 30
    st_s = fonts['xs'].render(status_txt, True, status_col)
    surface.blit(st_s, (text_x, st_y))

    if badge_kind in ('auto', 'ready', 'working') and mgr.hired:
        badge_lbl = "AUTO" if badge_kind == 'auto' else ("READY" if badge_kind == 'ready' else "ACTIVE")
        _draw_pill(surface, fonts, badge_lbl, rr.right - 58, st_y - 2, status_col)

    if not mgr.hired and not unlocked:
        if idx >= _LATE_TIER_START:
            prog = rank_gate_progress(state, idx)
            if prog:
                gate, tokens, thresh, pct = prog
                prog_s = fonts['xs'].render(
                    f"{gate}: {tokens}/{thresh} Inf ({pct}%)", True, theme.BLUE_BRIGHT)
                surface.blit(prog_s, (text_x, rr.y + 46))
        elif hover:
            fs = fonts['xs'].render(mgr.flavor[:48] + ("…" if len(mgr.flavor) > 48 else ""),
                                    True, theme.TEXT_MUTED)
            fs.set_alpha(140)
            surface.blit(fs, (text_x, rr.y + 46))
    elif not mgr.hired and unlocked:
        fee_lbl = "Payroll" if idx <= _EARLY_TIER_MAX else "Premium payroll"
        pay_txt = display_hire_fee(state, idx, unlocked=True)
        pay_line = fonts['xs'].render(f"{fee_lbl}: {pay_txt}", True, theme.NOIR_GOLD)
        surface.blit(pay_line, (text_x, rr.y + 46))

        btn = pygame.Rect(rr.right - _BTN_W - 6,
                          rr.y + (card_h - _BTN_H) // 2, _BTN_W, _BTN_H)
        hover_btn = btn.collidepoint(mx, my)
        if can:
            col = tuple(min(255, v + 20) for v in theme.NOIR_GOLD) if hover_btn else theme.NOIR_GOLD
            pygame.draw.rect(surface, col, btn, border_radius=6)
            pygame.draw.rect(surface, theme.NOIR_GOLD_BRIGHT, btn, border_radius=6, width=1)
            bl_col = theme.NOIR_INK
        else:
            pygame.draw.rect(surface, (40, 43, 60), btn, border_radius=6)
            bl_col = theme.TEXT_MUTED
        hl = fonts['sm'].render("HIRE", True, bl_col)
        surface.blit(hl, hl.get_rect(center=btn.center))
    elif mgr.hired:
        b = state.buildings[mgr.building_index] if mgr.building_index < len(state.buildings) else None
        if b and b.owned > 0 and mgr.building_index >= 0:
            from src.prestige import income_mult
            from src.prestige_tree import manager_income_mult
            inc = b.base_income * b.owned * b.income_multiplier * manager_income_mult(state)
            inc *= income_mult(state.prestige_tokens)
            inc_s = fonts['xs'].render(f"+{_fmt(inc)}/s", True, theme.GREEN)
            inc_s.set_alpha(180)
            surface.blit(inc_s, inc_s.get_rect(midright=(rr.right - 10, rr.y + 58)))


# ─── Panel drawing ─────────────────────────────────────────────────────────────

def draw_panel(surface: pygame.Surface, state, fonts: dict,
               panel_rect: pygame.Rect) -> None:
    t = getattr(state, '_time', 0.0)
    mx, my = pygame.mouse.get_pos()
    managers = state.managers
    plan = _panel_row_plan(state)
    n_rows = len(plan)
    scroll = max(0, min(getattr(state, '_mgr_scroll', 0), max(0, n_rows - 1)))
    state._mgr_scroll = scroll
    list_bottom = panel_rect.bottom - 16
    row_y = panel_rect.y + 34
    visible_count = 0

    disp = fonts.get('disp_xs', fonts['xs'])
    hdr = disp.render("EMPLOYEE ROSTER", True, theme.NOIR_GOLD)
    surface.blit(hdr, (panel_rect.x + 8, panel_rect.y + 8))
    sub = fonts['xs'].render("Payroll · departments · live status", True, theme.TEXT_MUTED)
    surface.blit(sub, (panel_rect.x + 8, panel_rect.y + 22))

    section_counts: dict[str, int] = {'active': 0, 'available': 0, 'locked': 0}
    _sec: str | None = None
    for kind, payload in plan:
        if kind == 'section':
            _sec = payload
        elif kind == 'mgr' and _sec:
            section_counts[_sec] = section_counts.get(_sec, 0) + 1

    def _row_h(kind: str, payload=None) -> int:
        if kind == 'section':
            return _SECTION_H
        if kind in ('teaser', 'collapse'):
            return _TEASER_ROW_H + _GAP
        return _ROW_H + _GAP

    current_section = None
    for row_i in range(scroll, n_rows):
        kind, payload = plan[row_i]
        idx = payload if kind == 'mgr' else None
        rh = _row_h(kind, payload)
        card_h = _ROW_H - 4

        if kind == 'section':
            if row_y + _SECTION_H > list_bottom:
                break
            current_section = payload
            row_y = _draw_section_header(
                surface, fonts, panel_rect, row_y, payload,
                section_counts.get(payload, 0))
            visible_count += 1
            continue

        if kind == 'teaser':
            if row_y + _TEASER_ROW_H > list_bottom:
                break
            rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, _TEASER_ROW_H)
            hover = rr.collidepoint(mx, my)
            bg = (35, 32, 48, 230) if hover else (28, 28, 38, 220)
            bg_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
            pygame.draw.rect(bg_surf, bg, bg_surf.get_rect(), border_radius=8)
            surface.blit(bg_surf, rr.topleft)
            left = disp.render("EXECUTIVE STAFF (LOCKED)", True, theme.PRESTIGE_LABEL)
            surface.blit(left, (rr.x + 10, rr.y + 4))
            sub2 = fonts['xs'].render(
                "Unlocks at Made Man — expand when ready", True, theme.TEXT_MUTED)
            surface.blit(sub2, (rr.x + 10, rr.y + 20))
            row_y += _TEASER_ROW_H + _GAP
            visible_count += 1
            continue

        if kind == 'collapse':
            if row_y + _TEASER_ROW_H > list_bottom:
                break
            rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, _TEASER_ROW_H)
            hover = rr.collidepoint(mx, my)
            bg = (35, 32, 48, 230) if hover else (28, 28, 38, 220)
            bg_surf = pygame.Surface((rr.width, rr.height), pygame.SRCALPHA)
            pygame.draw.rect(bg_surf, bg, bg_surf.get_rect(), border_radius=8)
            surface.blit(bg_surf, rr.topleft)
            collapsed = getattr(state, '_mgr_late_collapsed', True)
            cnt = collapsed_late_count(state)
            if collapsed:
                left = disp.render(
                    f"EXECUTIVE STAFF ({cnt} LOCKED)  ▼ Expand", True, theme.PRESTIGE_LABEL)
                surface.blit(left, (rr.x + 10, rr.y + 4))
                sub2 = fonts['xs'].render(next_executive_preview(state), True, theme.NOIR_GOLD)
            else:
                left = disp.render("EXECUTIVE STAFF  ▲ Collapse", True, theme.PRESTIGE_LABEL)
                surface.blit(left, (rr.x + 10, rr.y + 4))
                sub2 = fonts['xs'].render(
                    "Premium specialists — rank-gated payroll", True, theme.TEXT_MUTED)
            surface.blit(sub2, (rr.x + 10, rr.y + 20))
            row_y += _TEASER_ROW_H + _GAP
            visible_count += 1
            continue

        assert idx is not None
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, card_h)
        if row_y + card_h > list_bottom:
            break
        _draw_manager_card(surface, state, fonts, idx, rr, t, mx, my)
        row_y += _ROW_H + _GAP
        visible_count += 1

    if scroll > 0:
        up_s = fonts['xs'].render(f"▲ {scroll} more above", True, theme.TEXT_MUTED)
        surface.blit(up_s, up_s.get_rect(midright=(panel_rect.right - 10, panel_rect.y + 18)))
    remaining = n_rows - scroll - visible_count
    if remaining > 0:
        dn_s = fonts['xs'].render(
            f"▼ scroll down ({remaining} more below)", True, theme.TEXT_MUTED)
        surface.blit(dn_s, dn_s.get_rect(
            centerx=panel_rect.centerx, y=panel_rect.bottom - 14))


def handle_click(state, pos: tuple, panel_rect: pygame.Rect) -> bool:
    plan = _panel_row_plan(state)
    n_rows = len(plan)
    scroll = max(0, min(getattr(state, '_mgr_scroll', 0), max(0, n_rows - 1)))
    list_bottom = panel_rect.bottom - 16
    row_y = panel_rect.y + 34
    card_h = _ROW_H - 4

    def _row_h(kind: str) -> int:
        if kind == 'section':
            return _SECTION_H
        if kind in ('teaser', 'collapse'):
            return _TEASER_ROW_H + _GAP
        return _ROW_H + _GAP

    for row_i in range(scroll, n_rows):
        kind, payload = plan[row_i]
        idx = payload if kind == 'mgr' else None

        if kind == 'section':
            row_y += _SECTION_H
            continue
        if kind == 'collapse':
            rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, _TEASER_ROW_H)
            if rr.collidepoint(pos):
                state._mgr_late_collapsed = not getattr(state, '_mgr_late_collapsed', True)
                return True
            row_y += _TEASER_ROW_H + _GAP
            continue
        if kind == 'teaser':
            row_y += _TEASER_ROW_H + _GAP
            continue

        assert idx is not None
        mgr = state.managers[idx]
        rr = pygame.Rect(panel_rect.x + 4, row_y, panel_rect.width - 8, card_h)
        if row_y + card_h > list_bottom:
            break
        if not mgr.hired and manager_unlocked(state, idx):
            btn = pygame.Rect(rr.right - _BTN_W - 6,
                              rr.y + (card_h - _BTN_H) // 2, _BTN_W, _BTN_H)
            if btn.collidepoint(pos):
                if can_hire_manager(state, idx):
                    fee = hire_fee(idx)
                    state.balance -= fee
                    was_first = not any(m.hired for m in getattr(state, 'managers', []))
                    mgr.hired = True
                    import src.sound as sound
                    sound.play('manager')
                    try:
                        import src.analytics as _an
                        _an.manager_hired(mgr.name)
                        if was_first:
                            _an.first_manager(mgr.name)
                    except Exception:
                        pass
                    import src.ui as _ui
                    if mgr.name == "Sticky Pete":
                        _ui.push_notification(
                            "Pete's on the block — check Buildings for his pick",
                            theme.TEXT_GOLD)
                    elif mgr.name == "Lucky Sal":
                        _ui.push_notification(
                            "Sal's collecting — golden coins auto-grab",
                            theme.TEXT_GOLD)
                    elif mgr.name == "The Collector":
                        _ui.push_notification(
                            "Collector's shield is up — first raid bounces",
                            theme.TEXT_GOLD)
                    elif mgr.name == "The Mechanic":
                        _ui.push_notification(
                            "Mechanic's on night shift — Chop Shops auto-buy",
                            theme.TEXT_GOLD)
                    elif mgr.name == "Clean Carl":
                        _ui.push_notification(
                            "Carl's watching heat — forecast + one emergency dump",
                            theme.TEXT_GOLD)
                    elif mgr.name == "The Accountant":
                        _ui.push_notification(
                            "The Accountant is on payroll — auto-buy active",
                            theme.TEXT_GOLD)
                    elif mgr.name == "Maxine the Dealer":
                        _ui.push_notification(
                            "Maxine boosts the family — behaviors scale with casinos",
                            theme.TEXT_GOLD)
                    elif mgr.name == "The Promoter":
                        _ui.push_notification(
                            f"Promoter autopilot — heat target ≤{int(promoter_heat_target(state))}%",
                            theme.TEXT_GOLD)
                    elif mgr.name == "The Smuggler":
                        _ui.push_notification(
                            "Smuggler's queue running — ops auto-start",
                            theme.TEXT_GOLD)
                    elif mgr.name == "The Broker":
                        _ui.push_notification(
                            "Broker intel live — best turf action highlighted",
                            theme.TEXT_GOLD)
                    elif mgr.name == "The Consigliere":
                        _ui.push_notification(
                            "Consigliere sees the board — check Prestige advisory",
                            theme.TEXT_GOLD)
                    elif mgr.name == "Rudy Riches":
                        _ui.push_notification(
                            "Rudy says it's time to make some real money.",
                            theme.TEXT_GOLD)
                    elif mgr.name == "Rob Revenue":
                        _ui.push_notification(
                            "Rob's balancing the books.",
                            theme.TEXT_GOLD)
                return True
        elif mgr.hired and mgr.name == "The Promoter":
            card_body = pygame.Rect(rr.x, rr.y, rr.width - _BTN_W - 20, card_h)
            if card_body.collidepoint(pos):
                tgt = int(cycle_promoter_target(state))
                import src.ui as _ui
                _ui.push_notification(f"Promoter target: keep heat ≤{tgt}%", theme.TEXT_GOLD)
                return True
        row_y += _ROW_H + _GAP
    return False


def _fmt(n: float) -> str:
    import src.theme as _t
    return _t.format_number(n)
