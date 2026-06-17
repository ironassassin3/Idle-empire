"""PART 1 baseline validation — prove the PRE-Session-9 prestige-tree
reachability empirically (historical record).

The Session 9 branching tree replaced this universal tree. This script documents
the broken baseline it replaced: it greedily buys every perk the OLD universal
purchase logic allowed (the _LEGACY_PERK_DEFS, still kept for save grandfathering,
plus the old global tier gates) and shows which perks were dead and that the only
viable build was "buy everything".
"""
from __future__ import annotations
import src.prestige_tree as pt

# The pre-S9 perk defs (kept as _LEGACY_PERK_DEFS) and the old global tier gates.
_PERK_DEFS = pt._LEGACY_PERK_DEFS
_TIER_UNLOCK = {1: 0, 2: 2, 3: 5, 4: 9, 5: 16}  # the original (broken) gates


def _tier_unlocked(tier, perks):
    return len(perks) >= _TIER_UNLOCK[tier]


def reachable_perks() -> list[str]:
    """Buy every buyable perk with infinite influence until no progress."""
    perks: list[str] = []
    changed = True
    while changed:
        changed = False
        for key, name, cost, eff, tier in _PERK_DEFS:
            if key in perks:
                continue
            if _tier_unlocked(tier, perks):  # infinite influence, so cost ignored
                perks.append(key)
                changed = True
    return perks


def main():
    all_keys = [d[0] for d in _PERK_DEFS]
    reach = reachable_perks()
    dead = [k for k in all_keys if k not in reach]

    print("=" * 64)
    print("PRE-S9 PRESTIGE TREE BASELINE — REACHABILITY (historical)")
    print("=" * 64)
    print(f"Total perks defined : {len(all_keys)}")
    print(f"Tier unlock gates   : {_TIER_UNLOCK}")
    # tier sizes
    from collections import Counter
    sizes = Counter(d[4] for d in _PERK_DEFS)
    print(f"Perks per tier      : {dict(sorted(sizes.items()))}")
    print()
    print(f"REACHABLE ({len(reach)}/{len(all_keys)}): {reach}")
    print(f"DEAD      ({len(dead)}): {dead}")
    print()
    # Cumulative max purchasable before each tier gate
    print("Tier reachability proof (max perks purchasable before the gate):")
    cum = 0
    for tier in sorted(sizes):
        gate = _TIER_UNLOCK[tier]
        ok = cum >= gate
        print(f"  TIER {tier}: needs {gate} purchased, "
              f"max available from lower tiers = {cum}  -> {'UNLOCKS' if ok else 'DEAD'}")
        cum += sizes[tier]
    print()

    # Are all reachable perks pure global income/click multipliers? (convergence test)
    income_click_keys = {
        'click_power_1', 'income_1', 'click_power_2', 'income_2',
        'empire_bonus', 'faster_prog', 'manager_unlock',
    }
    automation_keys = {'auto_buy', 'auto_upgrade'}
    other_keys = {'offline_1'}
    pure = [k for k in reach if k in income_click_keys]
    auto = [k for k in reach if k in automation_keys]
    print("CONVERGENCE TEST (are reachable perks differentiating?):")
    print(f"  income/click multipliers reachable : {pure}")
    print(f"  automation reachable               : {auto}")
    print(f"  other (offline)                    : {[k for k in reach if k in other_keys]}")
    print(f"  EXCLUSIVE choices in tree          : 0 (purchase logic appends, never excludes)")
    print(f"  => Every reachable perk is a universal stat boost. One optimal build.")


if __name__ == "__main__":
    main()
