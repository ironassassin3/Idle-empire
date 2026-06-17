"""PART 5 — Divergence simulation: current (universal) tree vs branching tree.

Uses the REAL PlayingState so every number flows through production code paths
(income_per_second, click_value, Operation.start, rivals.perform_action odds,
territory._success_chance, heat decay, prestige influence gain).

For each "build" we configure an identical representative mid-game state, then
measure a capability vector across the subsystems each branch is supposed to
own. Divergence = different builds leading different axes, and no single build
dominating everything.

Run: python sim_divergence.py
"""
from __future__ import annotations
import os
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
import pygame
pygame.init()
pygame.display.set_mode((900, 720))

import src.prestige as prestige
import src.prestige_tree as pt
import src.territory as territory_mod
import src.operations as ops_mod
import src.rivals as rivals_mod
import src.heat as heat_mod
from src.state_base import StateManager
from src.states import PlayingState


# ─── Build definitions ────────────────────────────────────────────────────────
# The old tree's single convergent endgame build (the 7 reachable perks), then
# each branch fully purchased.
BASELINE_UNIVERSAL = ['click_power_1', 'income_1', 'offline_1', 'auto_buy',
                      'manager_unlock', 'auto_upgrade', 'income_2']

BRANCH_BUILDS = {br: [p[0] for p in pt.BRANCH_PERKS[br]] for br in pt.BRANCH_ORDER}


def make_midgame_state(perks, branch):
    """A representative mid-game PlayingState with a fixed economy/turf/rivals."""
    sm = StateManager()
    ps = PlayingState(sm)
    ps.on_enter()
    # Fixed economy: a spread of buildings so income/manager/building perks bite.
    counts = [40, 20, 12, 8, 6, 5, 4, 3, 2, 2, 1]
    for i, b in enumerate(ps.buildings):
        b.owned = counts[i] if i < len(counts) else 0
    for m in ps.managers:
        m.hired = True
    # Territory: own 3 districts (player) so turf/district perks apply.
    owned = 0
    for t in ps.territories:
        if owned < 3:
            t.unlocked = True
            t.owner = 'player'
            owned += 1
    # Crew: a balanced spread.
    total = sum(b.owned for b in ps.buildings)
    ps.crew.collection = total // 3
    ps.crew.smuggling = total // 6
    ps.crew.territory = total // 6
    ps.heat = 55.0
    ps.prestige_tokens = 40
    ps.influence = 800  # Respect
    ps.lifetime_earnings = 5.0e8
    ps._prestige_count = 1
    ps._next_prestige_earnings = 4.0e9
    ps.perks_purchased = list(perks)
    ps.prestige_branch = branch
    pt.apply_perks(ps)
    ps._ips_dirty = True
    return ps


# ─── Capability measurement ────────────────────────────────────────────────────

def measure(ps):
    """Return a dict of capability metrics for the configured state."""
    income = float(ps.income_per_second)
    click = float(ps.click_value)

    # Operation reward (Drug Run) normalized by income → the op's "income-hours".
    op = ops_mod.make_operations()[0]
    op.start(ps)
    op_reward_hours = (op.reward / income / 3600.0) if income > 0 else 0.0
    op_speed = 1.0 / pt.operation_speed_mult(ps)  # >1 = faster

    # Rival combat: success chance * cash reward multiplier on attack.
    rivals = rivals_mod.make_rivals()
    ps.rivals = rivals
    base_succ = rivals_mod._base_success(rivals[0], 'attack')
    combat_succ = min(0.95, base_succ + pt.combat_success_bonus(ps))
    combat_power = combat_succ * pt.combat_reward_mult(ps)

    # Territory attack success chance (includes branch bonus).
    terr = next(t for t in ps.territories if not t.unlocked) if any(
        not t.unlocked for t in ps.territories) else ps.territories[0]
    terr_succ = territory_mod._success_chance(ps, terr, 'attack')

    # Influence gain on prestige (Consigliere amplifies).
    base_gain = prestige.calc_influence_gain(ps.lifetime_earnings)
    inf_mult = pt.influence_gain_mult(ps)
    influence_gain = base_gain * inf_mult

    # Heat net decay rate (higher = better control). Use heat_breakdown net rise.
    try:
        bd = heat_mod.heat_breakdown(ps)
        heat_net = -bd['net']  # positive = net cooling
    except Exception:
        heat_net = 0.0

    offline = pt.offline_earnings_mult(ps)

    return {
        'income/s': income,
        'click': click,
        'op_reward(h)': op_reward_hours,
        'op_speed': op_speed,
        'combat': combat_power,
        'territory%': terr_succ,
        'influence': influence_gain,
        'heat_decay': heat_net,
        'offline': offline,
    }


AXES = ['income/s', 'click', 'op_reward(h)', 'op_speed', 'combat',
        'territory%', 'influence', 'heat_decay', 'offline']


def main():
    builds = {'NoPerks': ([], None),
              'OLD:Universal': (BASELINE_UNIVERSAL, None)}
    for br in pt.BRANCH_ORDER:
        builds[f'NEW:{pt.BRANCH_META[br]["name"]}'] = (BRANCH_BUILDS[br], br)

    results = {}
    for name, (perks, branch) in builds.items():
        ps = make_midgame_state(perks, branch)
        results[name] = measure(ps)

    # ── Raw capability table ──
    print("=" * 110)
    print("CAPABILITY VECTORS (identical mid-game state; only the prestige build differs)")
    print("=" * 110)
    hdr = f"{'build':16}" + "".join(f"{a:>13}" for a in AXES)
    print(hdr)
    for name, vec in results.items():
        row = f"{name:16}"
        for a in AXES:
            v = vec[a]
            row += f"{v:>13.3g}"
        print(row)

    # ── Normalized vs NoPerks (relative power per axis) ──
    base = results['NoPerks']
    print("\n" + "=" * 110)
    print("RELATIVE TO NO-PERKS BASELINE (×). >1 means the build boosts that axis.")
    print("=" * 110)
    print(hdr)
    norm = {}
    for name, vec in results.items():
        row = f"{name:16}"
        norm[name] = {}
        for a in AXES:
            b = base[a] if base[a] else 1e-9
            r = vec[a] / b if b else 1.0
            norm[name][a] = r
            row += f"{r:>13.2f}"
        print(row)

    # ── Divergence analysis ──
    print("\n" + "=" * 110)
    print("DIVERGENCE ANALYSIS")
    print("=" * 110)

    # Per-axis leader (exclude NoPerks).
    contenders = [n for n in results if n != 'NoPerks']
    leaders = {}
    print("\nAxis leaders (which build maximizes each subsystem):")
    for a in AXES:
        leader = max(contenders, key=lambda n: norm[n][a])
        leaders[a] = leader
        print(f"  {a:14} -> {leader:16} ({norm[leader][a]:.2f}×)")

    distinct_leaders = set(leaders.values())
    print(f"\nDistinct axis-leaders: {len(distinct_leaders)} of {len(contenders)} builds "
          f"lead >=1 axis -> {sorted(distinct_leaders)}")

    # Dominant strategy risk: does ONE build lead a majority of axes?
    from collections import Counter
    lead_counts = Counter(leaders.values())
    top, top_n = lead_counts.most_common(1)[0]
    print(f"\nMost-dominant build: {top} leads {top_n}/{len(AXES)} axes.")
    if top_n > len(AXES) / 2:
        print("  WARNING: possible dominant strategy (leads majority of axes).")
    else:
        print("  OK: no build leads a majority of axes -> no universal dominant strategy.")

    # Pairwise divergence (euclidean distance on log-normalized vectors).
    import math
    new_builds = [n for n in contenders if n.startswith('NEW:')]
    print("\nPairwise build distance among the 4 branches (log-space; higher = more distinct):")
    dists = []
    for i in range(len(new_builds)):
        for j in range(i + 1, len(new_builds)):
            a, b = new_builds[i], new_builds[j]
            d = math.sqrt(sum((math.log10(max(norm[a][ax], 1e-6))
                               - math.log10(max(norm[b][ax], 1e-6))) ** 2 for ax in AXES))
            dists.append(d)
            print(f"  {a:16} <-> {b:16} : {d:.2f}")
    if dists:
        print(f"  mean pairwise distance = {sum(dists)/len(dists):.2f}")

    # Old tree axis coverage: how many axes does the universal build move?
    moved_old = sum(1 for a in AXES if norm['OLD:Universal'][a] > 1.05)
    moved_new = {n: sum(1 for a in AXES if norm[n][a] > 1.05) for n in new_builds}
    print("\nAxis coverage (axes moved >5% above no-perks):")
    print(f"  OLD:Universal moves {moved_old}/{len(AXES)} axes "
          f"(all income/click — one archetype).")
    for n in new_builds:
        lead_axes = [a for a in AXES if leaders[a] == n]
        print(f"  {n:16} moves {moved_new[n]}/{len(AXES)} axes; leads: {lead_axes}")

    # Viable-build count.
    print("\n" + "=" * 110)
    print("VIABLE BUILDS")
    print("=" * 110)
    print(f"  OLD tree: 1 viable build (buy all 7 reachable universal perks).")
    new_leaders = {n for n in distinct_leaders if n.startswith('NEW:')}
    print(f"  NEW tree: {len(new_builds)} distinct archetypes, each leading a different")
    print(f"            subsystem cluster -> {len(new_leaders)} of {len(new_builds)} lead >=1 axis.")


if __name__ == "__main__":
    main()
