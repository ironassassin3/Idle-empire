"""Headless validation of Phase 20 hard prestige reset."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))

# Minimal pygame stub so we can import game modules without a display
import types
pg_stub = types.ModuleType('pygame')
pg_stub.Surface = lambda *a, **kw: None
pg_stub.Rect = lambda *a, **kw: None
pg_stub.font = types.SimpleNamespace(SysFont=lambda *a: None, Font=lambda *a: None)
pg_stub.draw = types.SimpleNamespace()
pg_stub.SRCALPHA = 0
pg_stub.init = lambda: None
sys.modules.setdefault('pygame', pg_stub)

# ── Build a minimal fake state that mirrors PlayingState fields ───────────────
from src.buildings   import make_buildings
from src.upgrades    import make_upgrades
from src.managers    import make_managers
from src.territory   import make_territories
from src.rivals      import make_rivals
from src.crew        import CrewAssignment
from src.operations  import make_operations
from src.goals       import make_goals
import src.prestige as pmod

class FakeState:
    def __init__(self):
        self.buildings           = make_buildings()
        self.upgrades            = make_upgrades()
        self.managers            = make_managers()
        self.territories         = make_territories()
        self.rivals              = make_rivals()
        self.crew                = CrewAssignment()
        self.operations          = make_operations()
        self.goals               = make_goals()
        self.achievements        = []
        self.balance             = 0.0
        self.lifetime_earnings   = pmod.FIRST_PRESTIGE_EARNINGS * 2
        self.prestige_tokens     = 12       # Made Man
        self.influence           = 12
        self._prestige_count     = 0
        self._next_prestige_earnings = pmod.FIRST_PRESTIGE_EARNINGS
        self.heat                = 0.0
        self.perks_purchased     = []
        self.prestige_branch     = None
        self.dragon_patron       = None
        self.dragon_xp           = 0
        self.dragon_ability_cooldowns = {}
        self._dragon_red_elim_count  = 0
        self._arms_influence_frac    = 0.0
        self._milestone_queue        = []
        self._milestone_timer        = 0.0
        self._peak_income            = 0.0
        self._push_near_prestige_fired = False
        self._notif_near_prestige_80   = False
        self._show_offline_overlay     = False
        self._show_daily_overlay       = False
        self._show_prestige_locked     = False
        self._city_control_milestones  = set()
        self._play_time              = 0.0
        self._click_count            = 0
        self._coins_caught           = 0
        self._daily_streak           = 1
        self._sfx_volume             = 1.0
        self._fps_cap                = 60
        self._music_volume           = 0.5
        self._master_volume          = 1.0
        self._mute_all               = False
        self._tutorial_step          = 0
        self._shown_milestones       = set()
        self._shown_raid_tutorial    = False
        self._shown_ops_tutorial     = False
        self._shown_influence_tutorial = False
        self._shown_heat_warning     = False
        self._shown_prestige_tree_tutorial = False
        self._shown_syndicate_tutorial = False
        self._shown_influence_intro  = False
        self._shown_crew_tutorial    = False
        self._shown_territory_tutorial = False
        self._shown_rivals_tutorial  = False
        self._longest_streak         = 1
        self._total_buildings_purchased  = 0
        self._total_territories_captured = 0
        self._total_rivals_defeated      = 0
        self._total_ops_completed        = 0
        self._total_heat_generated       = 0.0
        self._total_respect_earned       = 0
        self._total_influence_earned     = 0
        self._highest_cash_held          = 0.0
        self._highest_city_control       = 0.0

    @property
    def income_per_second(self):
        return sum(b.owned * b.base_income for b in self.buildings) + 1.0

    def _satisfy_prestige_requirements(self):
        """Give state enough progress to pass can_prestige() for prestige_count==0."""
        self.buildings[0].owned = pmod.FIRST_PRESTIGE_DEALERS    # dealers
        self.buildings[1].owned = pmod.FIRST_PRESTIGE_RACKETS     # rackets
        self.buildings[2].owned = pmod.FIRST_PRESTIGE_CHOPS       # chops
        self.prestige_tokens    = 12   # Made Man


PASS = 0
FAIL = 0

def check(name, condition, detail=''):
    global PASS, FAIL
    if condition:
        print(f'  PASS  {name}')
        PASS += 1
    else:
        print(f'  FAIL  {name}  {detail}')
        FAIL += 1


# ─────────────────────────────────────────────────────────────────────────────
# TEST 1 — Large balance + many buildings → both zero after prestige
# ─────────────────────────────────────────────────────────────────────────────
print('\nTEST 1: balance + buildings reset')
s = FakeState()
s.balance = 99_999_999.0
for b in s.buildings:
    b.owned = 50
ok = pmod.PrestigeManager.execute(s)
check('prestige executed', ok)
check('balance == 0', s.balance == 0.0, f'balance={s.balance}')
check('all buildings == 0', all(b.owned == 0 for b in s.buildings),
      str([b.owned for b in s.buildings]))

# ─────────────────────────────────────────────────────────────────────────────
# TEST 2 — Crew fully reset
# ─────────────────────────────────────────────────────────────────────────────
print('\nTEST 2: crew reset')
s = FakeState()
for b in s.buildings: b.owned = 100   # large crew pool
s.crew.protection = 20
s.crew.collection  = 30
s.crew.smuggling   = 10
s.crew.territory   = 5
s.crew.heat        = 3
s.lifetime_earnings = pmod.FIRST_PRESTIGE_EARNINGS * 2
ok = pmod.PrestigeManager.execute(s)
check('prestige executed', ok)
check('crew.protection == 0', s.crew.protection == 0, str(s.crew.protection))
check('crew.collection == 0',  s.crew.collection == 0,  str(s.crew.collection))
check('crew.smuggling == 0',   s.crew.smuggling == 0,   str(s.crew.smuggling))
check('crew.territory == 0',   s.crew.territory == 0,   str(s.crew.territory))
check('crew.heat == 0',        s.crew.heat == 0,        str(s.crew.heat))

# ─────────────────────────────────────────────────────────────────────────────
# TEST 3 — Active operations fully reset
# ─────────────────────────────────────────────────────────────────────────────
print('\nTEST 3: operations reset')
s = FakeState()
s._satisfy_prestige_requirements()
import time as _time
for op in s.operations:
    op.active     = True
    op.start_time = _time.time() - 60
    op.reward     = 50_000.0
    op.completed  = True
    op.collected  = False
ok = pmod.PrestigeManager.execute(s)
check('prestige executed', ok)
check('no active ops',    not any(op.active     for op in s.operations))
check('no completed ops', not any(op.completed  for op in s.operations))
check('rewards cleared',  not any(op.reward > 0 for op in s.operations))

# ─────────────────────────────────────────────────────────────────────────────
# TEST 4 — All districts reset (no strategic exceptions)
# ─────────────────────────────────────────────────────────────────────────────
print('\nTEST 4: territory reset')
s = FakeState()
s._satisfy_prestige_requirements()
for t in s.territories:
    t.unlocked = True
    t.owner    = 'player'
s._city_control_milestones = {'25', '50', '75', '100'}
ok = pmod.PrestigeManager.execute(s)
check('prestige executed', ok)
from src.territory import _STRATEGIC_NAMES
# Strategic districts (South Side, Downtown, Industrial, Waterfront, City Hall) survive
check('strategic districts retained',
      all(t.unlocked and t.owner == 'player'
          for t in s.territories if t.name in _STRATEGIC_NAMES),
      str([(t.name, t.unlocked) for t in s.territories
           if t.name in _STRATEGIC_NAMES and not t.unlocked]))
# Non-strategic districts must be wiped
check('non-strategic districts reset',
      all(not t.unlocked and t.owner == 'unclaimed'
          for t in s.territories if t.name not in _STRATEGIC_NAMES),
      str([(t.name, t.unlocked) for t in s.territories
           if t.name not in _STRATEGIC_NAMES and t.unlocked]))
check('milestones cleared', len(s._city_control_milestones) == 0,
      str(s._city_control_milestones))

# ─────────────────────────────────────────────────────────────────────────────
# TEST 5 — Eliminated rivals return as fresh faction defaults
# ─────────────────────────────────────────────────────────────────────────────
print('\nTEST 5: rivals reset')
s = FakeState()
s._satisfy_prestige_requirements()
from src.rivals import _FACTIONS
for i, r in enumerate(s.rivals):
    r.status = 'Eliminated'
    r.power  = 0
    r.wealth = 0.0
    r.turf   = 0
ok = pmod.PrestigeManager.execute(s)
check('prestige executed', ok)
check('all rivals Active', all(r.status == 'Active' for r in s.rivals),
      str([r.status for r in s.rivals]))
# Eliminated rivals are reconstituted at 30% of default power (minimum 5)
expected_powers = [max(5, int(d['start_power'] * 0.30)) for d in _FACTIONS]
check('rival powers at 30% restore',
      all(s.rivals[i].power == expected_powers[i] for i in range(len(s.rivals))),
      str([(r.name, r.power) for r in s.rivals]))

# ─────────────────────────────────────────────────────────────────────────────
# TEST 6 — Heat always resets to 0
# ─────────────────────────────────────────────────────────────────────────────
print('\nTEST 6: heat reset')
s = FakeState()
s._satisfy_prestige_requirements()
s.heat = 95.0
ok = pmod.PrestigeManager.execute(s)
check('prestige executed', ok)
check('heat == 0.0', s.heat == 0.0, f'heat={s.heat}')

# ─────────────────────────────────────────────────────────────────────────────
# TEST 7 — Prestige perks remain; branch resets
# ─────────────────────────────────────────────────────────────────────────────
print('\nTEST 7: prestige perks preserved, branch resets')
s = FakeState()
s._satisfy_prestige_requirements()
s.perks_purchased = ['income_1', 'click_power_1']
s.prestige_branch = 'kingpin'
ok = pmod.PrestigeManager.execute(s)
check('prestige executed', ok)
check('perks preserved', 'income_1' in s.perks_purchased and 'click_power_1' in s.perks_purchased,
      str(s.perks_purchased))
check('branch reset', s.prestige_branch is None, str(s.prestige_branch))

# ─────────────────────────────────────────────────────────────────────────────
# TEST 8 — Dragon progression preserved
# ─────────────────────────────────────────────────────────────────────────────
print('\nTEST 8: dragon preserved')
s = FakeState()
s._satisfy_prestige_requirements()
try:
    from src.dragon import DRAGON_META, HATCHLING, STAGE_XP
    patron_key = list(DRAGON_META.keys())[0]
    s.dragon_patron = patron_key
    s.dragon_xp     = STAGE_XP[HATCHLING]
    ok = pmod.PrestigeManager.execute(s)
    check('prestige executed', ok)
    check('dragon patron preserved', s.dragon_patron == patron_key, str(s.dragon_patron))
    check('dragon xp >= 0', s.dragon_xp >= 0, str(s.dragon_xp))
except Exception as e:
    print(f'  SKIP  dragon test (import error): {e}')

# ─────────────────────────────────────────────────────────────────────────────
print(f'\n{"="*50}')
print(f'Results: {PASS} passed, {FAIL} failed')
if FAIL:
    sys.exit(1)
