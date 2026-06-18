"""Prestige system — requirements, influence formula, reset/reward logic."""
from __future__ import annotations
import math
import traceback
import config

# ─── First-prestige requirements ──────────────────────────────────────────────
# Tuned (with the rebalanced economy + non-circular Influence goals) for a first
# prestige in the ~30-45 min window for both the optimal and casual player
# profiles (validated in sim_prestige_gate.py / sim_harness.py).
#
# Pacing model:
#   - Made Man (12 Influence) is reached at ~6-10 min purely from the starter
#     economic goals (goals.py) — NO rival/op grind required. This breaks the
#     old circular deadlock (see AUDIT.md).
#   - The $20M empire-route earnings gate is the actual pacing control; with the
#     rebalanced exponential economy it resolves at ~25-35 min (sim) depending on
#     whether the player engages territory early (~18 min) or focuses buildings (~25 min).
import os as _os

def _env_float(key: str, default: float) -> float:
    try:
        return float(_os.environ[key])
    except (KeyError, ValueError):
        return default

def _env_int(key: str, default: int) -> int:
    try:
        return int(_os.environ[key])
    except (KeyError, ValueError):
        return default

# ── Tuning constants (A/B-override via env vars) ──────────────────────────────
# Set any of these before launching to test a variant without changing code:
#   IDLE_PRESTIGE_EARNINGS=10000000 python main.py   ← easier first prestige
#   IDLE_PRESTIGE_GROWTH=6 python main.py            ← softer escalation
FIRST_PRESTIGE_EARNINGS  = _env_float("IDLE_PRESTIGE_EARNINGS", 20_000_000.0)
FIRST_PRESTIGE_DEALERS   = _env_int("IDLE_PRESTIGE_DEALERS",   20)
FIRST_PRESTIGE_RACKETS   = _env_int("IDLE_PRESTIGE_RACKETS",   8)
FIRST_PRESTIGE_CHOPS     = _env_int("IDLE_PRESTIGE_CHOPS",     4)
FIRST_PRESTIGE_RANK      = _os.environ.get("IDLE_PRESTIGE_RANK", "Made Man")

# Building indices in buildings list
_IDX_DEALER  = 0
_IDX_RACKET  = 1
_IDX_CHOP    = 2

PRESTIGE_EARNINGS_GROWTH = _env_float("IDLE_PRESTIGE_GROWTH", 8.0)


def prestige_earnings_required(state) -> float:
    """Lifetime-earnings threshold the player must reach for their NEXT prestige.

    First prestige: FIRST_PRESTIGE_EARNINGS. Each subsequent prestige stores
    `_next_prestige_earnings` = current lifetime * GROWTH, so the bar always sits
    a full run ahead of where the player is now.
    """
    n = getattr(state, '_prestige_count', 0)
    if n <= 0:
        return FIRST_PRESTIGE_EARNINGS
    return float(getattr(state, '_next_prestige_earnings', FIRST_PRESTIGE_EARNINGS))


def prestige_route_earnings(state) -> float:
    """Income that counts toward the prestige earnings gate.

    Only passive building income and manual clicks — not goal/territory bonus
    cash, jackpots, loan interest, operations, events, or offline payouts.
    """
    return float(getattr(state, '_prestige_route_earnings', 0.0))


def check_requirements(state) -> dict:
    """
    Return a dict describing whether each requirement is met.
    First prestige enforces building-count + rank gates (teaches the systems).
    Later prestiges are gated purely on the escalating lifetime-earnings bar.
    Keys: 'earnings', and (first prestige only) 'dealers'/'rackets'/'chops'/'rank'
    Values: (current, required, met: bool)
    """
    required = prestige_earnings_required(state)
    route = prestige_route_earnings(state)
    reqs = {
        'earnings': (route, required, route >= required),
    }
    if getattr(state, '_prestige_count', 0) <= 0:
        dealers = state.buildings[_IDX_DEALER].owned if len(state.buildings) > _IDX_DEALER else 0
        rackets = state.buildings[_IDX_RACKET].owned if len(state.buildings) > _IDX_RACKET else 0
        chops   = state.buildings[_IDX_CHOP].owned   if len(state.buildings) > _IDX_CHOP   else 0
        rank    = get_rank(state.prestige_tokens)
        reqs.update({
            'dealers':  (dealers, FIRST_PRESTIGE_DEALERS, dealers >= FIRST_PRESTIGE_DEALERS),
            'rackets':  (rackets, FIRST_PRESTIGE_RACKETS, rackets >= FIRST_PRESTIGE_RACKETS),
            'chops':    (chops, FIRST_PRESTIGE_CHOPS, chops >= FIRST_PRESTIGE_CHOPS),
            'rank':     (rank, FIRST_PRESTIGE_RANK,
                         _rank_index(rank) >= _rank_index(FIRST_PRESTIGE_RANK)),
        })
    return reqs


def can_prestige(state) -> bool:
    """All current-prestige requirements met."""
    reqs = check_requirements(state)
    return all(v[2] for v in reqs.values())


# ─── Influence formula ────────────────────────────────────────────────────────
# Influence gain scales with lifetime earnings so each prestige (which now
# requires ~8x more lifetime than the last) yields meaningfully MORE Influence
# than the previous one — the core "each prestige is bigger" escalation that
# motivates the 2nd, 3rd, Nth prestige. Tuned yields at the escalating gates:
#   Run 1 ($20M):   ~10 tokens   (Made Man -> Capo)
#   Run 2 (~$160M):  ~15 tokens
#   Run 3 (~$1.3B):  ~20 tokens
#   Run 4 (~$10B):   ~26 tokens
#   later runs:      keeps climbing, powering deeper ranks

def calc_influence_gain(lifetime_earnings: float) -> int:
    """Influence gain from lifetime earnings (super-logarithmic so deeper
    prestiges escalate)."""
    if lifetime_earnings < FIRST_PRESTIGE_EARNINGS:
        return 0
    log_val = math.log10(max(1.0, lifetime_earnings))
    # log^2 / 5.0 gives a gently accelerating curve; +1 keeps run 1 ~ 10 tokens.
    return max(1, round(log_val * log_val / 5.0))


def next_influence_threshold(current_influence: int) -> float:
    """Return the lifetime earnings needed to gain one more influence than now."""
    # Invert: influence = round(log10(e)^2 / 4.5) → solve for e
    target = current_influence + 1
    log_needed = math.sqrt(target * 4.5)
    return 10.0 ** log_needed


# ─── Criminal hierarchy ───────────────────────────────────────────────────────
# Threshold is prestige tokens (influence) earned cumulatively.
# Pacing targets (first run):
#   Street Hustler → Crew Member:  5-10 min  (1 token from early action)
#   → Associate:                  15-30 min  (5 tokens total)
#   → Made Man:                   30-60 min  (prestige gate, 3 rival/op actions)
#   → Capo:                       several hours of cumulative play
#   → Boss:                       long-term achievement
#   → Kingpin+:                   endgame / multi-prestige
HIERARCHY = [
    (0,   "Street Hustler"),
    (1,   "Crew Member"),
    (5,   "Associate"),
    (12,  "Made Man"),      # first prestige rank gate — requires multiple operations/attacks
    (25,  "Capo"),
    (45,  "Underboss"),
    (75,  "Boss"),
    (115, "Crime Lord"),
    (165, "Kingpin"),
    (230, "City Controller"),
    (310, "State Influence"),
    (410, "National Influence"),
    (540, "Shadow Government"),
]

# Rank-up unlock descriptions — these match actual game mechanics.
RANK_UNLOCKS = {
    "Street Hustler":     "Starting rank — build your first Corner Dealers to earn Influence",
    "Crew Member":        "+5% territory action success  •  Downtown accessible",
    "Associate":          "+5% operation rewards  •  Industrial District (5 Inf)",
    "Made Man":           "Operations tab open  •  Prestige available  •  Waterfront (15 Inf)",
    "Capo":               "+0.05/s heat decay  •  City Hall accessible at 40 Influence",
    "Underboss":          "+10% operation rewards  •  Syndicate grows stronger",
    "Boss":               "+10% territory action success  •  Veteran command",
    "Crime Lord":         "+5% all income  •  City bows to your legend",
    "Kingpin":            "+0.05/s heat decay  •  Untouchable reputation",
    "City Controller":    "+15% operation rewards  •  Downtown is your domain",
    "State Influence":    "+10% territory action success  •  State answers to you",
    "National Influence": "+5% all income  •  Your reach spans the nation",
    "Shadow Government":  "+20% operation rewards  •  Maximum rank — you own it all",
}

# Identity-first rank-up flavor (Phase 59). One short line that says what the
# player BECAME, shown above the mechanical unlocks on the rank-up overlay.
# Scoped deliberately to the early ranks the majority of players actually reach
# in their first session; later ranks fall back to mechanics-only (no over-
# authoring). Lines are kept short to fit the existing overlay without layout
# changes (verified against the 500px panel at the reference resolution).
RANK_FLAVOR = {
    "Crew Member": "You're in the crew now.",
    "Associate":   "The family knows your name.",
    "Made Man":    "You're a Made Man now. Untouchable.",
}

# Per-rank perk bonuses (cumulative — all ranks below current stack).
# Keys: territory_success (additive fraction), operation_reward (additive fraction),
#       heat_decay (/s added to base decay), income_bonus (additive fraction).
_RANK_PERK_TABLE: dict[str, dict[str, float]] = {
    "Crew Member":        {"territory_success": 0.05},
    "Associate":          {"operation_reward": 0.05},
    "Made Man":           {},
    "Capo":               {"heat_decay": 0.05},
    "Underboss":          {"operation_reward": 0.10},
    "Boss":               {"territory_success": 0.10},
    "Crime Lord":         {"income_bonus": 0.05},
    "Kingpin":            {"heat_decay": 0.05},
    "City Controller":    {"operation_reward": 0.15},
    "State Influence":    {"territory_success": 0.10},
    "National Influence": {"income_bonus": 0.05},
    "Shadow Government":  {"operation_reward": 0.20},
}


def get_cumulative_rank_perks(influence: int) -> dict:
    """Sum all perk bonuses for ranks at or below the current influence total."""
    totals: dict[str, float] = {}
    for threshold, label in HIERARCHY:
        if influence >= threshold and label in _RANK_PERK_TABLE:
            for k, v in _RANK_PERK_TABLE[label].items():
                totals[k] = totals.get(k, 0.0) + v
    return totals


def rank_territory_bonus(influence: int) -> float:
    """Cumulative additive territory action success bonus from rank perks."""
    return get_cumulative_rank_perks(influence).get("territory_success", 0.0)


def rank_operation_reward_bonus(influence: int) -> float:
    """Cumulative additive operation reward multiplier bonus from rank perks."""
    return get_cumulative_rank_perks(influence).get("operation_reward", 0.0)


def rank_heat_decay_bonus(influence: int) -> float:
    """Cumulative bonus heat decay rate (/s) from rank perks."""
    return get_cumulative_rank_perks(influence).get("heat_decay", 0.0)


def rank_income_bonus(influence: int) -> float:
    """Cumulative additive income multiplier bonus from rank perks."""
    return get_cumulative_rank_perks(influence).get("income_bonus", 0.0)

_RANK_ORDER = {label: i for i, (_, label) in enumerate(HIERARCHY)}


def _rank_index(label: str) -> int:
    return _RANK_ORDER.get(label, -1)


# ─── Tab visibility ────────────────────────────────────────────────────────────
# IMPORTANT: tab access is gated on ECONOMIC progress, never on Influence.
# Influence is what these systems EARN, so gating them behind Influence created a
# circular deadlock (see AUDIT.md).
#
# Phase 100 (information architecture): the abstract "Empire" tab hid the core
# progression behind one nameless container. The economy loop now lives in three
# concrete top-level tabs — Buildings, Upgrades, Managers — so a fresh player
# reads the path left-to-right without hunting. The city-conflict systems
# (Territory, Rivals, Crew, Operations) gather under one concrete "Turf" tab as
# sub-tabs; Crew/Operations keep their economic gates, applied at the sub-tab
# level. Five fixed main tabs fit the panel width at every resolution.

def _total_buildings(state) -> int:
    return sum(b.owned for b in getattr(state, 'buildings', []))


def _territories_owned(state) -> int:
    return sum(1 for t in getattr(state, 'territories', []) if getattr(t, 'unlocked', False))


def visible_tabs(state) -> list[tuple[str, str]]:
    """Single source of truth for which right-panel MAIN tabs are accessible.

    Returns [(label, key), ...]. Both the draw code (ui.py) and the click
    dispatch (states.py) call this so they never diverge. All five are always
    visible — none is Influence-gated, so there is no deadlock. The order is the
    progression itself: earn (Buildings) → boost (Upgrades) → automate
    (Managers) → expand (Turf) → review (Stats).
    """
    return [
        ("Buildings", "buildings"),
        ("Upgrades",  "upgrades"),
        ("Managers",  "managers"),
        ("Turf",      "turf"),
        ("Stats",     "stats"),
    ]


def visible_turf_subtabs(state) -> list[tuple[str, str, bool, str]]:
    """Sub-tabs under the Turf main tab as (label, key, locked, requirement).

    Phase 102: locked systems stay VISIBLE (greyed, with a live-progress
    requirement) instead of being hidden until unlocked — the player should
    always know a system exists and how to reach it. The economic GATES are
    unchanged from Phase 100; only their visibility changed.
    """
    bld  = _total_buildings(state)
    terr = _territories_owned(state)
    made_man = _rank_index(get_rank(state.prestige_tokens)) >= _rank_index("Made Man")
    crew_locked = bld < 5
    ops_locked  = not (terr >= 2 or made_man)
    return [
        ("Territory", "territory",  False, ""),
        ("Rivals",    "rivals",     False, ""),
        ("Crew",      "crew",       crew_locked,
         f"Own 5 buildings to unlock — assign crew for bonuses  ({bld}/5)"),
        ("Ops",       "operations", ops_locked,
         f"Capture 2 districts to unlock — timed heists pay big  ({terr}/2)"),
    ]


def get_rank(influence: int) -> str:
    rank = HIERARCHY[0][1]
    for threshold, label in HIERARCHY:
        if influence >= threshold:
            rank = label
    return rank


def get_next_rank(influence: int) -> tuple[str, int] | None:
    for threshold, label in HIERARCHY:
        if influence < threshold:
            return label, threshold
    return None


# ─── Income multiplier (from influence/tokens) ───────────────────────────────
# Phase 30 (root-cause R1): token→income is a DIMINISHING-RETURN curve, NOT the
# old 1.02^tokens exponential. The exponential let any token-multiplier
# (Consigliere, Jade, Prestige Mastery) snowball without bound and made every
# non-token system irrelevant past ~50 prestiges, while exploding toward the
# float cap in the deep endgame.
#
#   income_mult = (1 + tokens / TOKEN_SOFTCAP_D) ** TOKEN_SOFTCAP_A
#
# Properties: mult(0)=1 exactly · strictly monotonic · NO hard cap (more tokens
# always help) · marginal return diminishes because the exponent is < 1 · never
# overflows float for any reachable token count. Early game is preserved (and
# slightly enhanced) versus the old curve — the two cross near ~85 tokens — so
# the first several prestiges still feel punchy; only the runaway late tail is
# tamed. Tune these two constants to rebalance the entire prestige economy.
TOKEN_SOFTCAP_D = 14.0   # token "scale": larger = gentler early ramp
TOKEN_SOFTCAP_A = 0.90   # exponent (<1): smaller = stronger diminishing return


def income_mult(tokens: int) -> float:
    t = max(0, tokens)            # defensive: never raise a negative base to a fractional power
    return (1.0 + t / TOKEN_SOFTCAP_D) ** TOKEN_SOFTCAP_A


# ─── Prestige Mastery upgrade rider (Phase 31, completes root-cause R1) ───────
# The "Prestige Mastery" upgrade (upgrades.py, effect_key 'prestige_boost') used
# to multiply income by (1 + tokens*0.10) — a LINEAR-in-tokens factor that, once
# the base curve became sub-linear in Phase 30, out-grew the base and re-created
# a near-quadratic runaway (combined growth ~ t^1.9) that dominated the economy.
#
# Phase 31 makes it a BOUNDED, saturating rider (Michaelis-Menten form):
#
#   prestige_mastery_mult = 1 + MAX * tokens / (HALF + tokens)   ∈ [1, 1+MAX)
#
# It approaches +150% but never reaches it, so its multiplicative contribution is
# capped. That keeps the combined (base × mastery) growth in the SAME diminishing
# class as income_mult alone (empirically exponent ~0.95 vs base ~0.90), so it can
# never dominate, never becomes mandatory, and leaves headroom for the future
# Respect (Phase 32) and Branch-Legacy (Phase 33) systems to matter. Still scales
# with every token (monotonic) so it remains a worthwhile per-run purchase.
PRESTIGE_MASTERY_MAX  = 1.5     # asymptotic maximum bonus: +150% income
PRESTIGE_MASTERY_HALF = 120.0   # tokens at which half the bonus is reached


def prestige_mastery_mult(tokens: int) -> float:
    t = max(0, tokens)
    return 1.0 + PRESTIGE_MASTERY_MAX * t / (PRESTIGE_MASTERY_HALF + t)


# ─── Respect → income (Phase 12 resource clarity) ─────────────────────────────
# RESPECT (stored in state.influence) was previously earned everywhere but never
# spent or read — a dead currency. It now represents your street reputation and
# grants a capped passive global income bonus, giving active play (operations,
# territory, rivals) a permanent payoff distinct from Influence/Prestige Tokens
# (which power the prestige tree, ranks, and territory gates).
_RESPECT_INCOME_PER_POINT = 0.0004   # +1% income per 25 Respect
_RESPECT_INCOME_CAP       = 0.50     # capped at +50% (reached at 1250 Respect)


def respect_income_bonus(respect: int) -> float:
    """Additive global income bonus from accumulated Respect (0.0 – 0.50)."""
    return min(_RESPECT_INCOME_CAP, max(0, respect) * _RESPECT_INCOME_PER_POINT)


# ─── PrestigeManager ─────────────────────────────────────────────────────────

class PrestigeManager:
    """Full prestige cycle: validate, reward influence, reset run, save."""

    @staticmethod
    def execute(state) -> bool:
        try:
            return PrestigeManager._do_execute(state)
        except Exception:
            traceback.print_exc()
            PrestigeManager._clear_modals(state)
            return False

    @staticmethod
    def _do_execute(state) -> bool:
        if not can_prestige(state):
            return False

        influence_gain = calc_influence_gain(state.lifetime_earnings)

        # Prestige Influence bonuses: The Consigliere manager (+20%) and the
        # City Hall district (+15%) both reward investing toward bigger prestiges.
        try:
            import src.managers as _mgr
            import src.territory as _terr
            import src.prestige_tree as _ptree
            import src.dragon as _dragon
            mult = (_mgr.influence_gain_mult(state) * _terr.prestige_influence_mult(state)
                    * _ptree.influence_gain_mult(state) * _dragon.prestige_influence_mult(state))
            influence_gain = int(round(influence_gain * mult))
        except Exception:
            pass

        state.prestige_tokens    += influence_gain
        state.influence          = getattr(state, 'influence', 0) + influence_gain
        state._prestige_count    = getattr(state, '_prestige_count', 0) + 1

        # Analytics: prestige is the central retention event.
        try:
            import src.analytics as _an
            _an.prestige(state._prestige_count, influence_gain, state.prestige_tokens,
                         state.lifetime_earnings, getattr(state, '_play_time', 0.0))
        except Exception:
            pass

        # Set the escalating bar for the NEXT prestige: a full run ahead of where
        # the player is now. This paces prestiges apart and makes each a bigger
        # goal (the head start would otherwise allow instant re-prestige).
        state._next_prestige_earnings = prestige_route_earnings(state) * PRESTIGE_EARNINGS_GROWTH

        # Reset balance (lifetime_earnings keeps accumulating across prestiges)
        state.balance = 0.0

        # Reset buildings
        for b in state.buildings:
            b.owned = 0
            b.income_multiplier = 1.0

        # Reset upgrades
        for u in state.upgrades:
            u.purchased = False

        # Session 9: clear the cycle's branch commitment so the next run can
        # choose a different archetype. Owned perks persist; only the ACTIVE
        # branch resets. Done before apply_perks so no branch perks are active
        # on the fresh run until the player re-commits.
        from src.prestige_tree import apply_perks, reset_branch
        reset_branch(state)
        apply_perks(state)
        # Dragon Patron persists — grant XP for the cycle, then clear per-run counters.
        try:
            import src.dragon as _dragon
            _dragon.on_prestige(state)
            _dragon.reset_for_prestige(state)
        except Exception:
            pass

        PrestigeManager._clear_modals(state)

        # ── HARD RESET: heat ────────────────────────────────────────────────
        state.heat = 0.0
        state._carl_emergency_used = False
        state._collector_shield_cd = 0.0
        state._mechanic_timer = 0.0
        state._autobuy_timer = 0.0
        state._broker_retry_cd = 0.0
        state._smuggler_notified = set()
        state._promoter_heat_target = 50.0

        # ── HARD RESET: crew ────────────────────────────────────────────────
        try:
            from src.crew import CrewAssignment
            state.crew = CrewAssignment()
        except Exception:
            pass

        # ── MEMORY RESET: rivals (Phase 45) ──────────────────────────────────
        # Eliminated rivals return weakened; active/weakened rivals are untouched.
        # First prestige (or corrupted state): fall back to fresh initialization.
        try:
            from src.rivals import make_rivals, reconstitute_eliminated_rivals
            if not getattr(state, 'rivals', None):
                state.rivals = make_rivals()
            else:
                reconstitute_eliminated_rivals(state.rivals, restore_fraction=0.30)
        except Exception:
            pass

        # ── MEMORY RESET: territory (Phase 45) ────────────────────────────────
        # Strategic districts (South Side, Downtown, Industrial, Waterfront,
        # City Hall) retain ownership across prestiges. Generic districts wipe.
        # Milestones reset so they're earnable again each cycle.
        try:
            from src.territory import partial_territory_reset
            partial_territory_reset(getattr(state, 'territories', []), state)
        except Exception:
            pass

        # ── HARD RESET: operations ──────────────────────────────────────────
        for _op in getattr(state, "operations", []):
            _op.active     = False
            _op.start_time = 0.0
            _op.reward     = 0.0
            _op.completed  = False
            _op.collected  = False

        # ── HARD RESET: managers ────────────────────────────────────────────
        for _m in getattr(state, "managers", []):
            _m.hired = False

        # ── HARD RESET: goals ───────────────────────────────────────────────
        for _g in getattr(state, "goals", []):
            _g.completed = False
            _g.notified  = False

        state._peak_income = 0.0
        state._push_near_prestige_fired = False   # reset for next prestige run
        state._notif_near_prestige_80 = False     # reset so 80% notification fires again
        state._post_prestige_notif = True         # fires a rebuild reminder after the overlay clears

        # Prestige climax (Phase 101): a dedicated full-screen ceremony — distinct
        # from the routine milestone toast every building uses — marks the largest
        # event in the game. Reuses the timed-overlay pattern; no new mechanics and
        # no save fields (these attrs are runtime-only and recomputed each prestige).
        try:
            state._prestige_climax_count  = state._prestige_count
            state._prestige_climax_tokens = influence_gain
            state._prestige_climax_rank   = get_rank(state.prestige_tokens)
            state._prestige_climax_timer  = config.PRESTIGE_CLIMAX_DURATION
        except Exception:
            pass

        from src.save_load import save_game
        save_game(state)

        return True

    @staticmethod
    def _clear_modals(state) -> None:
        state._show_offline_overlay   = False
        state._show_daily_overlay     = False
        state._milestone_timer        = 0.0
        state._show_prestige_locked   = False


# Legacy compatibility
def execute(state) -> None:
    PrestigeManager.execute(state)


# Kept for any external callers that used old token formula
def new_tokens(state) -> int:
    return calc_influence_gain(state.lifetime_earnings)
