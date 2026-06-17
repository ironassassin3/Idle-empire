"""PART 7 — branching prestige tree validation.

Covers: new save init, branch selection + cycle lock, sequential tier gating,
branch-exclusive effect activation, save/load round-trip, legacy-save migration,
multi-prestige branch reset, and branch switching across prestiges.

Run: python sim_branch_validation.py
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
from src.state_base import StateManager
from src.states import PlayingState
from src.save_load import save_game, load_game, apply_save_data, delete_save, _migrate

PASS, FAIL = [], []
def check(name, cond):
    (PASS if cond else FAIL).append(name)
    print(f"  [{'OK' if cond else 'FAIL'}] {name}")

def fresh():
    # on_enter() may load an existing save from a prior section; force a clean
    # slate so each test controls its own branch/perk state. Load/apply tests
    # override these immediately afterwards.
    sm = StateManager(); ps = PlayingState(sm); ps.on_enter()
    ps.perks_purchased = []
    ps.prestige_branch = None
    pt.apply_perks(ps)
    return ps

print("=" * 64)
print("SESSION 9 — BRANCHING PRESTIGE TREE VALIDATION")
print("=" * 64)

# ── 1. New save init ──
print("\n[1] NEW SAVE INIT")
ps = fresh()
check("fresh: prestige_branch is None", ps.prestige_branch is None)
check("fresh: no perks", ps.perks_purchased == [])
ps.prestige_tokens = 50
# With no branch chosen, no branch perk is buyable.
ok, reason = pt.can_buy_perk(ps, 'kp_cashflow')
check("no branch -> cannot buy any perk", (not ok) and reason == "Choose a path first")
pt.apply_perks(ps)
check("no branch -> income mult neutral", abs(getattr(ps, '_perk_income_mult', 1.0) - 1.0) < 1e-9)

# ── 2. Branch selection + cycle lock ──
print("\n[2] BRANCH SELECTION + CYCLE LOCK")
check("select Kingpin succeeds", pt.select_branch(ps, pt.KINGPIN))
check("branch now Kingpin", ps.prestige_branch == pt.KINGPIN)
check("cannot switch to Warlord mid-cycle", not pt.select_branch(ps, pt.WARLORD))
check("branch still Kingpin", ps.prestige_branch == pt.KINGPIN)

# ── 3. Sequential tier gating ──
print("\n[3] SEQUENTIAL TIER GATING (within Kingpin)")
# Tier 1 buyable; tier 2 locked until tier-1 owned.
ok1, _ = pt.can_buy_perk(ps, 'kp_cashflow')   # tier 1
ok2, r2 = pt.can_buy_perk(ps, 'kp_ledger')    # tier 2
check("tier 1 buyable immediately", ok1)
check("tier 2 locked before tier 1 owned", (not ok2))
# Buy tier 1, then tier 2 unlocks.
ps.prestige_tokens -= pt.PERK_COST['kp_cashflow']; ps.perks_purchased.append('kp_cashflow'); pt.apply_perks(ps)
ok2b, _ = pt.can_buy_perk(ps, 'kp_ledger')
ok3, _ = pt.can_buy_perk(ps, 'kp_payroll')    # tier 3 still locked
check("tier 2 unlocks after tier 1", ok2b)
check("tier 3 still locked (needs 2 owned)", not ok3)
# Cannot buy a perk from a different branch even if influence allows.
okx, rx = pt.can_buy_perk(ps, 'wl_knuckles')
check("other-branch perk locked", (not okx) and rx == "Locked (other path)")

# ── 4. Branch-exclusive effect activation ──
print("\n[4] BRANCH-EXCLUSIVE EFFECTS")
# Kingpin cashflow active -> income +15%.
check("Kingpin Cash Flow active (+15% income)", abs(ps._perk_income_mult - 1.15) < 1e-6)
# Consigliere/Cartel/Warlord accessors neutral while Kingpin active.
check("combat bonus 0 (not Warlord)", pt.combat_success_bonus(ps) == 0.0)
check("op reward 1.0 (not Cartel)", pt.operation_reward_mult(ps) == 1.0)
check("influence mult 1.0 (not Consigliere)", pt.influence_gain_mult(ps) == 1.0)

# ── 5. Save / load round-trip ──
print("\n[5] SAVE / LOAD ROUND-TRIP")
delete_save(); save_game(ps)
ps2 = fresh(); apply_save_data(ps2, load_game())
check("loaded branch == Kingpin", ps2.prestige_branch == pt.KINGPIN)
check("loaded perks preserved", 'kp_cashflow' in ps2.perks_purchased)
check("loaded income mult reapplied", abs(ps2._perk_income_mult - 1.15) < 1e-6)

# ── 6. Legacy-save migration ──
print("\n[6] LEGACY-SAVE MIGRATION (old universal perks, no branch field)")
legacy = {
    'balance': 0, 'lifetime_earnings': 1e7, 'prestige_tokens': 30,
    'perks_purchased': ['income_1', 'income_2', 'auto_buy', 'manager_unlock'],
    # intentionally no 'prestige_branch'
}
ps3 = fresh()
apply_save_data(ps3, dict(legacy))
check("legacy: branch defaults None", ps3.prestige_branch is None)
check("legacy: perks retained", set(['income_1', 'income_2']).issubset(set(ps3.perks_purchased)))
# Grandfathered effects still apply (income_1 *1.10 * income_2 *1.25 = 1.375).
check("legacy: grandfathered income (1.375x)", abs(ps3._perk_income_mult - 1.375) < 1e-6)
check("legacy: grandfathered manager 2.0x", abs(pt.manager_income_mult(ps3) - 2.0) < 1e-6)
# A migrated very-old key maps and never offers empire_bonus as buyable.
mig = _migrate({'perks_purchased': ['crime_lord'], 'prestige_tokens': 0})
check("legacy key 'crime_lord' migrates to empire_bonus", 'empire_bonus' in mig['perks_purchased'])
check("empire_bonus not in any branch (not revived as buyable)", 'empire_bonus' not in pt.BRANCH_OF)

# ── 7. Multi-prestige: branch resets, perks persist ──
print("\n[7] MULTI-PRESTIGE RESET + PERSISTENCE")
ps4 = fresh()
ps4.prestige_tokens = 60
pt.select_branch(ps4, pt.CARTEL)
for k in ['ct_supply', 'ct_fast']:
    ps4.prestige_tokens -= pt.PERK_COST[k]; ps4.perks_purchased.append(k)
pt.apply_perks(ps4)
check("Cartel op reward active (x1.30)", abs(pt.operation_reward_mult(ps4) - 1.30) < 1e-6)
# Force prestige eligibility and execute.
ps4.lifetime_earnings = max(ps4.lifetime_earnings, prestige.prestige_earnings_required(ps4) + 1)
ps4.buildings[0].owned = 25; ps4.buildings[1].owned = 10; ps4.buildings[2].owned = 5
ps4.prestige_tokens = max(ps4.prestige_tokens, 12)  # Made Man rank gate
ok_p = prestige.PrestigeManager.execute(ps4)
check("prestige executed", ok_p)
check("branch reset to None after prestige", ps4.prestige_branch is None)
check("owned perks persist across prestige", 'ct_supply' in ps4.perks_purchased)
# Owned-but-inactive: Cartel perks no longer active (no branch committed).
check("Cartel effect inactive post-prestige (no branch)", pt.operation_reward_mult(ps4) == 1.0)

# ── 8. Branch switching across prestiges + exclusivity ──
print("\n[8] BRANCH SWITCH ACROSS PRESTIGE + EXCLUSIVITY")
# New cycle: pick Warlord this time.
check("can pick a DIFFERENT branch next cycle", pt.select_branch(ps4, pt.WARLORD))
ps4.prestige_tokens = max(ps4.prestige_tokens, 20)
ps4.perks_purchased.append('wl_knuckles')  # owns a Warlord perk now
pt.apply_perks(ps4)
# Now player owns perks in BOTH Cartel and Warlord, but only Warlord is active.
check("owns perks in 2 branches", pt.branch_perk_count(ps4, pt.CARTEL) >= 1
      and pt.branch_perk_count(ps4, pt.WARLORD) >= 1)
check("only Warlord active: click +40%", abs(ps4._perk_click_mult - 1.40) < 1e-6)
check("Cartel still inactive (exclusivity)", pt.operation_reward_mult(ps4) == 1.0)
# Re-selecting Cartel later reactivates its already-owned perks for free.
pt.reset_branch(ps4)
pt.select_branch(ps4, pt.CARTEL)
pt.apply_perks(ps4)
check("re-picking Cartel reactivates owned perks", abs(pt.operation_reward_mult(ps4) - 1.30) < 1e-6)
check("Warlord now inactive", abs(ps4._perk_click_mult - 1.0) < 1e-6)

print("\n" + "=" * 64)
print(f"RESULT: {len(PASS)} passed, {len(FAIL)} failed")
if FAIL:
    print("FAILED:", FAIL)
    raise SystemExit(1)
print("ALL BRANCH VALIDATION TESTS PASSED")
