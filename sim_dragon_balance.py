"""Dragon Patron balance simulation.

Answers the primary question: "Does choosing a Dragon change how the player
approaches the game, and is one Dragon obviously best?"

Methodology:
  - Simulate a 2-prestige run for each of the 4 playstyle archetypes
    × each Dragon, measuring income uplift, ops output, territory pressure,
    heat exposure, and rival count.
  - "Archetype-Dragon" pair = the player's dual identity.
  - Compare integrated utility (combined income+ops+territory) across all 12
    combinations.
  - Flag any pair that is more than 30% ahead of the group mean (dominance
    risk) or more than 40% behind (unviable risk).
"""
from __future__ import annotations
import math
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

# --- Lightweight mock state ----------------------------------------------------

class _MockRival:
    def __init__(self, at_war=False, status='Active', trait=''):
        self.at_war = at_war
        self.status = status
        self.trait  = trait
        self.power  = 40

class _MockOp:
    def __init__(self, active=True, collected=False):
        self.active    = active
        self.collected = collected

class _MockTerritory:
    def __init__(self, owner='player'):
        self.owner = owner

class MockState:
    def __init__(self, dragon=None, prestige_count=1, prestige_branch=None,
                 n_rivals_active=5, n_rivals_eliminated=0, n_ops_running=3,
                 n_territories=8, heat=50.0, crew_collection=20):
        self.dragon_patron                = dragon
        self._prestige_count              = prestige_count
        self.prestige_branch              = prestige_branch
        self._dragon_red_elim_count       = n_rivals_eliminated
        self._dragon_black_last_op_time   = None
        self.heat                         = heat
        self.perks_purchased: list        = []
        self._perk_income_mult            = 1.0
        self._perk_bld_mults: list        = []

        self.rivals = (
            [_MockRival(status='Active') for _ in range(n_rivals_active)] +
            [_MockRival(status='Eliminated') for _ in range(n_rivals_eliminated)]
        )
        self.operations = [_MockOp(active=i < n_ops_running) for i in range(5)]
        self.territories = [_MockTerritory('player') for _ in range(n_territories)]
        self.buildings = []

        class _Crew:
            collection = crew_collection
        self.crew = _Crew()


# --- Import dragon accessors --------------------------------------------------

import src.dragon as dragon

# --- Simulation helpers -------------------------------------------------------

def simulate_pair(dragon_key: str, prestige_branch: str, n_ticks=1000) -> dict:
    """Run a simplified empire simulation for the given Dragon + branch combo.

    Returns a dict of normalised metrics (all relative to a neutral baseline).
    """
    # Base IPS = 1.0 (everything else is a multiplier relative to this)
    base_ips = 1.0

    # -- Territory configuration --
    # Red players push territory offensively; Jade controls through negotiation;
    # Black focuses inward; Warlord/Cartel branches expand.
    territory_focus = {
        'red':   {'n_territories': 12, 'n_rivals_active': 3, 'n_rivals_elim': 2},
        'jade':  {'n_territories': 15, 'n_rivals_active': 5, 'n_rivals_elim': 0},
        'black': {'n_territories':  8, 'n_rivals_active': 5, 'n_rivals_elim': 0},
        None:    {'n_territories': 10, 'n_rivals_active': 5, 'n_rivals_elim': 0},
    }
    tf = territory_focus.get(dragon_key, territory_focus[None])

    # -- Operations configuration --
    # Black players run ops heavily; Jade runs fewer but consistent.
    ops_config = {
        'black': {'n_ops_running': 4, 'crew_collection': 30},
        'jade':  {'n_ops_running': 2, 'crew_collection': 15},
        'red':   {'n_ops_running': 2, 'crew_collection': 20},
        None:    {'n_ops_running': 2, 'crew_collection': 20},
    }
    oc = ops_config.get(dragon_key, ops_config[None])

    state = MockState(
        dragon=dragon_key,
        prestige_count=2,
        prestige_branch=prestige_branch,
        n_rivals_active=tf['n_rivals_active'],
        n_rivals_eliminated=tf['n_rivals_elim'],
        n_ops_running=oc['n_ops_running'],
        n_territories=tf['n_territories'],
        heat=55.0 if dragon_key == 'red' else 40.0,
        crew_collection=oc['crew_collection'],
    )

    # -- Compute income multipliers --
    income_mult = 1.0
    income_mult *= dragon.rival_presence_income_mult(state)
    income_mult *= dragon.eliminated_rival_income_mult(state)
    income_mult *= 1.0 + dragon.active_ops_income_bonus(state)

    # Crew collection (with Black Dragon efficiency)
    per_unit = 0.008 * dragon.collection_efficiency_mult(state)
    crew_coll_bonus = 1.0 + min(oc['crew_collection'] * per_unit, 0.60)
    income_mult *= crew_coll_bonus

    # Territory count bonus (2% per district, standard)
    income_mult *= 1.0 + tf['n_territories'] * 0.02

    # -- Heat penalty to effective income --
    # Heat at steady-state with this Dragon
    heat_ss = 55.0 + (10.0 if dragon_key == 'red' else 0.0) - (
        tf['n_territories'] * 0.02 * (30.0 if dragon_key == 'jade' else 0.0))
    heat_ss = max(20.0, min(100.0, heat_ss))
    heat_bonus = 1.0 + max(0.0, heat_ss - 50.0) * 0.008
    income_mult *= heat_bonus

    total_ips = base_ips * income_mult

    # -- Operations output --
    # Base reward per op = 300× IPS. Modifiers:
    op_mult = dragon.op_reward_mult(state)
    ops_per_run = oc['n_ops_running'] * 4.0   # average ops completed per hour
    ops_output = ops_per_run * base_ips * 300.0 * op_mult

    # -- Crew capacity (ops can use more crew → more ops possible) --
    cap_mult = dragon.crew_capacity_mult(state)

    # -- Territory acquisition rate --
    # Base chance 60%; Red +15% attack; Jade +40% negotiate; Black -15%.
    terr_attack_bonus  = dragon.territory_action_modifier(state, 'attack')
    terr_nego_bonus    = dragon.territory_action_modifier(state, 'negotiate')
    avg_terr_bonus = (terr_attack_bonus + terr_nego_bonus) / 2.0

    # -- Heat steadiness --
    jade_decay = dragon.heat_decay_bonus(state) - dragon.heat_decay_penalty(state)
    heat_risk = max(0.0, heat_ss - 60.0) / 40.0   # 0.0 = safe, 1.0 = max risk

    # -- Influence gain per prestige --
    inf_mult = dragon.prestige_influence_mult(state)

    # -- Rival pressure --
    aggression_mult = dragon.rival_aggression_mult(state)
    growth_mult     = dragon.rival_growth_mult(state)

    return {
        'ips':           total_ips,
        'ops':           ops_output,
        'cap':           cap_mult,
        'terr':          avg_terr_bonus,
        'heat_risk':     heat_risk,
        'inf_mult':      inf_mult,
        'rival_agg':     aggression_mult,
        'rival_growth':  growth_mult,
        'jade_decay':    jade_decay,
    }


# --- Run all 12 archetype-dragon combos ---------------------------------------

def run_balance_sim():
    BRANCHES = ['kingpin', 'warlord', 'cartel', 'consigliere']
    DRAGONS  = ['red', 'jade', 'black']

    print("=" * 70)
    print("DRAGON PATRON BALANCE SIMULATION")
    print("=" * 70)
    print(f"{'Combo':<28} {'IPS':>8} {'Ops':>8} {'Cap':>6} {'Terr':>7} "
          f"{'Heat%':>6} {'InfMx':>6} {'AggMx':>6}")
    print("-" * 70)

    results: list[dict] = []
    for branch in BRANCHES:
        for d in DRAGONS:
            r = simulate_pair(d, branch)
            r['branch'] = branch
            r['dragon'] = d
            results.append(r)

    # Compute utility = IPS × (1 + ops_normalised) — captures the main tradeoff
    # between raw income and ops output without double-counting territory.
    max_ips  = max(r['ips'] for r in results)
    max_ops  = max(r['ops'] for r in results)

    for r in results:
        combo = f"{r['branch'][:10]:>10} + {r['dragon']}"
        util = r['ips'] / max_ips * 0.6 + (r['ops'] / max_ops) * 0.25 + r['cap'] * 0.15
        r['utility'] = util
        print(f"{combo:<28} {r['ips']:>8.3f} {r['ops']:>8.0f} {r['cap']:>6.2f} "
              f"{r['terr']:>+7.2f} {r['heat_risk']:>6.2f} {r['inf_mult']:>6.2f} "
              f"{r['rival_agg']:>6.2f}")

    print()
    print("- Utility scores (60% IPS + 25% Ops + 15% Crew cap) -")
    sorted_r = sorted(results, key=lambda x: -x['utility'])
    mean_u = sum(r['utility'] for r in results) / len(results)
    for r in sorted_r:
        flag = ""
        if r['utility'] > mean_u * 1.30:
            flag = " WARN DOMINANCE RISK (>+30% mean)"
        elif r['utility'] < mean_u * 0.60:
            flag = " WARN UNVIABLE (<-40% mean)"
        print(f"  {r['branch']:>12} + {r['dragon']:<6}: {r['utility']:.3f}{flag}")

    print()
    best   = sorted_r[0]
    worst  = sorted_r[-1]
    spread = (best['utility'] - worst['utility']) / mean_u * 100
    print(f"Mean utility:  {mean_u:.3f}")
    print(f"Utility spread (best-worst / mean): {spread:.1f}%")
    if spread < 30:
        print("OK All combos within 30% spread — balanced.")
    elif spread < 50:
        print("WARN Moderate spread — review top 2 combos.")
    else:
        print("FAIL High spread — rebalance required.")

    print()
    print("- Identity check: do dragons create distinct behaviours? -")
    for d in DRAGONS:
        drs = [r for r in results if r['dragon'] == d]
        avg_ips   = sum(r['ips']  for r in drs) / len(drs)
        avg_terr  = sum(r['terr'] for r in drs) / len(drs)
        avg_ops   = sum(r['ops']  for r in drs) / len(drs)
        avg_heat  = sum(r['heat_risk'] for r in drs) / len(drs)
        print(f"  {d.upper():<6}  IPS={avg_ips:.3f}  Terr={avg_terr:+.2f}  "
              f"Ops={avg_ops:.0f}  HeatRisk={avg_heat:.2f}")

    print()
    print("- Kingpin dominance check (Session 9 concern + dragon interaction) -")
    kp_combos = [r for r in results if r['branch'] == 'kingpin']
    kp_max = max(r['ips'] for r in kp_combos)
    others_max = max(r['ips'] for r in results if r['branch'] != 'kingpin')
    ratio = kp_max / others_max if others_max > 0 else 0
    print(f"  Kingpin max IPS: {kp_max:.3f}")
    print(f"  Other branch max IPS: {others_max:.3f}")
    print(f"  Ratio: {ratio:.2f}×  ({'OK' if ratio < 1.5 else 'WARNING: Kingpin dominates'})")

    return results


if __name__ == '__main__':
    run_balance_sim()
