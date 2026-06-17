"""Dynamic Goals system — tracks player objectives and grants rewards on completion."""
from __future__ import annotations
from dataclasses import dataclass, field
from typing import Callable, List
import src.theme as theme


@dataclass
class Goal:
    key:        str
    label:      str
    desc:       str
    phase:      str          # 'early' | 'mid' | 'late'
    progress:   Callable     # (state) -> (current, target) both numeric
    reward_cash:      float = 0.0
    reward_respect:   int   = 0
    reward_influence: int   = 0
    completed:  bool  = False
    notified:   bool  = False
    color:      tuple = (255, 200, 50)
    narrative:  str   = ""   # Narrative title shown in place of label when non-empty


def _buildings_of_type(state, idx: int) -> int:
    blds = getattr(state, 'buildings', [])
    return blds[idx].owned if idx < len(blds) else 0


def _crew_total(state) -> int:
    crew = getattr(state, 'crew', None)
    if crew is None:
        return 0
    return int(sum([
        getattr(crew, 'protection', 0),
        getattr(crew, 'collection', 0),
        getattr(crew, 'smuggling', 0),
        getattr(crew, 'territory', 0),
        getattr(crew, 'heat_reduction', 0),
    ]))


def _rivals_eliminated(state) -> int:
    rivals = getattr(state, 'rivals', []) or []
    return sum(1 for r in rivals if r is not None and r.status == 'Eliminated')


def _territories_owned(state) -> int:
    return sum(1 for t in getattr(state, 'territories', []) if t.unlocked)


def _territories_total(state) -> int:
    return len(getattr(state, 'territories', []))


def make_goals() -> List[Goal]:
    """Return the full ordered goal list. Completed state is set externally."""
    return [
        # ── Starter Influence faucet ───────────────────────────────────
        # These grant the FIRST 12 Influence (= Made Man) from pure economic
        # play, with NO dependency on territory/rivals — breaking the circular
        # deadlock (see AUDIT.md). Thresholds are LIFETIME-earnings based so they
        # require idle TIME to reach (not just instant tapping/buying), pacing
        # the road to first prestige into the ~30-45 min window.
        Goal(
            key='start_cash_5k', label='First Real Money ($5K)', phase='early',
            desc='Reach $5,000 lifetime earnings. Earns your first Influence.',
            progress=lambda s: (s.lifetime_earnings, 5_000),
            reward_cash=500, reward_influence=1,
            color=theme.PRESTIGE_LABEL,
        ),
        Goal(
            key='start_cash_25k', label='Getting Noticed ($25K)', phase='early',
            desc='Reach $25,000 lifetime earnings. +1 Influence.',
            progress=lambda s: (s.lifetime_earnings, 25_000),
            reward_cash=2_000, reward_influence=1,
            color=theme.PRESTIGE_LABEL,
        ),
        Goal(
            key='start_cash_100k', label='Six Figures ($100K)', phase='early',
            desc='Reach $100,000 lifetime earnings. +2 Influence.',
            progress=lambda s: (s.lifetime_earnings, 100_000),
            reward_cash=8_000, reward_influence=2,
            color=theme.PRESTIGE_LABEL,
        ),
        Goal(
            key='start_cash_250k', label='Connected ($250K)', phase='early',
            desc='Reach $250,000 lifetime earnings. +2 Influence.',
            progress=lambda s: (s.lifetime_earnings, 250_000),
            reward_cash=20_000, reward_influence=2,
            color=theme.PRESTIGE_LABEL,
        ),
        Goal(
            key='start_cash_500k', label='Respected ($500K)', phase='early',
            desc='Reach $500,000 lifetime earnings. +3 Influence.',
            progress=lambda s: (s.lifetime_earnings, 500_000),
            reward_cash=40_000, reward_influence=3,
            color=theme.PRESTIGE_LABEL,
        ),
        Goal(
            key='start_cash_1m_inf', label='Made (lifetime $1M)', phase='early',
            desc='Reach $1,000,000 lifetime earnings. +3 Influence — you are Made.',
            progress=lambda s: (s.lifetime_earnings, 1_000_000),
            reward_cash=80_000, reward_influence=3,
            color=theme.PRESTIGE_LABEL,
        ),
        # ── Early game ─────────────────────────────────────────────────
        Goal(
            key='cash_1m', label='Reach $1M', phase='early',
            desc='Accumulate $1,000,000 in cash.',
            progress=lambda s: (s.balance, 1_000_000),
            reward_cash=5_000, reward_respect=5,
            color=theme.TEXT_GOLD,
        ),
        Goal(
            key='buy_pawn', label='Own a Pawn Shop', phase='early',
            desc='Purchase your first Pawn Shop building.',
            progress=lambda s: (_buildings_of_type(s, 4), 1),
            reward_cash=3_000, reward_respect=3,
            color=theme.BLUE_BRIGHT,
        ),
        Goal(
            key='crew_50', label='Hire 50 Crew', phase='early',
            desc='Assign at least 50 crew members across all roles.',
            reward_cash=15_000, reward_respect=8,
            progress=lambda s: (_crew_total(s), 50),
            color=theme.GREEN,
        ),
        Goal(
            key='heat_60', label='Survive 60% Heat', phase='early',
            desc='Reach 60% heat and survive without being wiped out.',
            progress=lambda s: (min(s.heat, 60.0), 60.0),
            reward_cash=10_000, reward_respect=6,
            color=(255, 120, 60),
        ),
        Goal(
            key='first_territory', label='Capture First District', phase='early',
            desc='Seize any territory beyond South Side.',
            progress=lambda s: (max(0, _territories_owned(s) - 1), 1),
            reward_cash=30_000, reward_respect=12,
            color=theme.BLUE_BRIGHT,
        ),
        # ── Mid game ───────────────────────────────────────────────────
        Goal(
            key='cash_100m', label='Reach $100M', phase='mid',
            narrative='Fortune Built in Blood',
            desc='Accumulate $100,000,000 in cash.',
            progress=lambda s: (s.balance, 100_000_000),
            reward_cash=500_000, reward_respect=20, reward_influence=1,
            color=theme.TEXT_GOLD,
        ),
        Goal(
            key='downtown', label='Capture Downtown', phase='mid',
            narrative='Own the Heart of the City',
            desc='Seize control of the Downtown district.',
            progress=lambda s: (
                1 if any(t.name == 'Downtown' and t.unlocked
                         for t in getattr(s, 'territories', [])) else 0,
                1
            ),
            reward_cash=200_000, reward_respect=25, reward_influence=2,
            color=theme.BLUE_BRIGHT,
        ),
        Goal(
            key='defeat_rival', label='Defeat a Rival', phase='mid',
            narrative='Send a Message',
            desc='Eliminate any rival syndicate. Fear is currency.',
            progress=lambda s: (_rivals_eliminated(s), 1),
            reward_cash=500_000, reward_respect=40, reward_influence=3,
            color=(220, 80, 60),
        ),
        Goal(
            key='capo_rank', label='Reach Capo Rank', phase='mid',
            narrative='Earn Your Stripes',
            desc='Earn enough Influence to achieve Capo status.',
            progress=lambda s: (s.prestige_tokens, 25),
            reward_cash=300_000, reward_respect=20, reward_influence=2,
            color=theme.PRESTIGE_LABEL,
        ),
        Goal(
            key='crew_200', label='Command 200 Crew', phase='mid',
            narrative='Build an Army',
            desc='Assign at least 200 crew members.',
            progress=lambda s: (_crew_total(s), 200),
            reward_cash=1_000_000, reward_respect=30,
            color=theme.GREEN,
        ),
        # ── Late game ──────────────────────────────────────────────────
        Goal(
            key='cash_1t', label='Reach $1T', phase='late',
            narrative='Build a Financial Empire',
            desc='Accumulate $1,000,000,000,000 in cash. Legitimate empires are built on money.',
            progress=lambda s: (s.balance, 1_000_000_000_000),
            reward_cash=2_000_000_000, reward_respect=80, reward_influence=5,
            color=theme.TEXT_GOLD,
        ),
        Goal(
            key='all_territories', label='Own All Territories', phase='late',
            narrative='Become the Shadow Government',
            desc='Control every district in the city. The streets answer to you.',
            progress=lambda s: (_territories_owned(s), _territories_total(s)),
            reward_cash=500_000_000, reward_respect=120, reward_influence=8,
            color=theme.GREEN,
        ),
        Goal(
            key='rivals_3', label='Eliminate 3 Rivals', phase='late',
            narrative='Eliminate the Competition',
            desc='Destroy three competing syndicates. There can only be one criminal empire.',
            progress=lambda s: (_rivals_eliminated(s), 3),
            reward_cash=1_000_000_000, reward_respect=150, reward_influence=10,
            color=(220, 80, 60),
        ),
        Goal(
            key='boss_rank', label='Reach Boss Rank', phase='late',
            narrative='Rise to the Throne',
            desc='Rise to the rank of Boss. The city will know your name.',
            progress=lambda s: (s.prestige_tokens, 75),
            reward_cash=0, reward_respect=300, reward_influence=20,
            color=theme.PRESTIGE_LABEL,
        ),
        Goal(
            key='cash_1qa', label='Reach $1Qa', phase='late',
            narrative='Untouchable Wealth',
            desc='Accumulate $1 Quadrillion. Numbers that make governments nervous.',
            progress=lambda s: (s.balance, 1e15),
            reward_cash=5e11, reward_respect=200, reward_influence=15,
            color=theme.TEXT_GOLD,
        ),
    ]


def check_goals(state) -> list[str]:
    """
    Check each incomplete goal. Complete any that are met, apply rewards,
    and return list of completion messages for notifications.
    """
    goals: List[Goal] = getattr(state, 'goals', []) or []
    completed_msgs = []

    for g in goals:
        if g.completed:
            continue
        try:
            cur, target = g.progress(state)
            cur    = float(cur)
            target = float(target)
        except Exception:
            continue

        if target > 0 and cur >= target:
            g.completed = True
            # Apply rewards
            if g.reward_cash > 0:
                state.balance = float(getattr(state, 'balance', 0.0)) + g.reward_cash
                state.lifetime_earnings = float(getattr(state, 'lifetime_earnings', 0.0)) + g.reward_cash
                import src.money_debug as _md
                _md.credit(state, g.reward_cash, 'money_from_other')
            if g.reward_respect > 0:
                state.influence = int(getattr(state, 'influence', 0)) + g.reward_respect
            if g.reward_influence > 0:
                state.prestige_tokens = int(getattr(state, 'prestige_tokens', 0)) + g.reward_influence

            # Identity first (Phase 59/60): the narrative title leads, mechanics
            # follow on a second line. Reward labels are abbreviated so the line
            # fits the notification without clipping any reward value.
            parts = []
            if g.reward_cash > 0:
                parts.append(f"+{theme.format_money(g.reward_cash)}")
            if g.reward_respect > 0:
                parts.append(f"+{g.reward_respect} Resp")
            if g.reward_influence > 0:
                parts.append(f"+{g.reward_influence} Inf")
            reward_str = " ".join(parts)
            title = getattr(g, 'narrative', '') or g.label
            completed_msgs.append(f"{title}\n{reward_str}")

    return completed_msgs


def current_goals(state, max_count: int = 4) -> List[Goal]:
    """Return up to max_count incomplete goals ordered by phase."""
    goals: List[Goal] = getattr(state, 'goals', []) or []
    phase_order = {'early': 0, 'mid': 1, 'late': 2}
    incomplete = [g for g in goals if not g.completed]
    incomplete.sort(key=lambda g: phase_order.get(g.phase, 9))
    return incomplete[:max_count]


def next_focus_hint(state) -> str:
    """Return a short, context-sensitive 'what to do right now' hint.

    Designed to answer the question a new player always has: 'What should I
    be doing?' without being heavy-handed. Returns an empty string when
    the answer is already obvious from visible goals/UI.
    """
    try:
        influence = int(getattr(state, 'prestige_tokens', 0) or 0)
        lifetime  = float(getattr(state, 'lifetime_earnings', 0.0) or 0.0)
        balance   = float(getattr(state, 'balance', 0.0) or 0.0)
        heat      = float(getattr(state, 'heat', 0.0) or 0.0)
        territories = getattr(state, 'territories', []) or []
        player_t  = sum(1 for t in territories if t.unlocked)
        buildings = getattr(state, 'buildings', []) or []
        total_bld = sum(b.owned for b in buildings)
        upgrades  = getattr(state, 'upgrades', []) or []
        any_bought = any(u.purchased for u in upgrades)
        managers  = getattr(state, 'managers', []) or []
        any_hired = any(m.hired for m in managers)

        import src.prestige as _p
        can_prestige = _p.can_prestige(state)
        near_prestige = lifetime >= _p.FIRST_PRESTIGE_EARNINGS * 0.7 if influence == 0 else False

        # Priority order: unblock the next gate first
        if can_prestige:
            return "Ready to PRESTIGE — open Prestige panel now"
        if near_prestige:
            return "Almost at prestige — keep buying buildings"
        if influence == 0 and lifetime < 1_000_000:
            # Forward-looking: each hint names the NEXT system and why it matters,
            # so the player always sees what they're working toward (Phase 102).
            if total_bld < 5:
                return "Buy buildings — reach 5 to unlock Crew"
            if not any_bought:
                return "Open Upgrades — multiply your income"
            if not any_hired:
                return "Hire a Manager — automates a building, no clicking"
            if total_bld < 10:
                return "Keep expanding → income earns Influence to Prestige"
            return "Grow income → earn Influence, then capture Turf"
        if influence > 0 and player_t == 0:
            return "Capture a district in Turf — opens Operations & Rivals"
        if heat >= 60:
            return "Heat critical — lower it before raids seize cash"
        if influence >= 12 and player_t == 0:
            return "You're Made Man — capture your first district"
    except Exception:
        pass
    return ""
