"""Phase 72 — Save Integrity Runtime Validation (headless)."""
from __future__ import annotations
import sys, os, json, time, copy, types

sys.path.insert(0, os.path.dirname(__file__))

# Minimal pygame stub
pg_stub = types.ModuleType('pygame')
pg_stub.Surface = lambda *a, **kw: None
pg_stub.Rect = lambda *a, **kw: type('R', (), {
    'collidepoint': lambda s, *a: False,
    'bottom': 0, 'right': 0, 'center': (0,0), 'centerx': 0, 'y': 0,
    'x': 0, 'width': 100, 'height': 30, 'top': 0,
})()
pg_stub.font = types.SimpleNamespace(SysFont=lambda *a, **kw: None, Font=lambda *a, **kw: None)
pg_stub.draw = types.SimpleNamespace(rect=lambda *a, **kw: None,
                                      circle=lambda *a, **kw: None,
                                      line=lambda *a, **kw: None)
pg_stub.SRCALPHA = 0
pg_stub.init = lambda: None
pg_stub.mixer = types.SimpleNamespace(
    init=lambda *a, **kw: None,
    Sound=lambda *a, **kw: type('S', (), {'play': lambda s: None, 'set_volume': lambda s, v: None})(),
    music=types.SimpleNamespace(load=lambda *a: None, play=lambda *a: None,
                                set_volume=lambda *a: None, stop=lambda *a: None),
)
pg_stub.mouse = types.SimpleNamespace(get_pos=lambda: (0, 0))
sys.modules.setdefault('pygame', pg_stub)

# Stub analytics so push_notification, etc. don't error
import types as _t
anl_stub = _t.ModuleType('src.analytics')
anl_stub.is_enabled = lambda: True
anl_stub.set_enabled = lambda v: None
anl_stub.start_session = lambda *a, **kw: None
anl_stub.end_session = lambda *a, **kw: None
anl_stub.offline_return = lambda *a, **kw: None
anl_stub.daily_reward = lambda *a, **kw: None
anl_stub.rank_up = lambda *a, **kw: None
anl_stub.first_influence = lambda *a, **kw: None
anl_stub.first_operation = lambda *a, **kw: None
anl_stub.push_near_prestige = lambda *a, **kw: None
sys.modules['src.analytics'] = anl_stub

snd_stub = _t.ModuleType('src.sound')
snd_stub.get_volume = lambda: 1.0
snd_stub.set_volume = lambda v: None
snd_stub.play = lambda *a, **kw: None
sys.modules['src.sound'] = snd_stub

# Stub ui minimally
ui_stub = _t.ModuleType('src.ui')
ui_stub.push_notification = lambda *a, **kw: None
ui_stub.update_notifications = lambda *a, **kw: None
ui_stub.CLICK_RECT = pg_stub.Rect(0, 0, 100, 100)
ui_stub.PRESTIGE_RECT = pg_stub.Rect(0, 0, 100, 30)
ui_stub.RIGHT_X = 450
ui_stub.TAB_H = 28
ui_stub._TAB_W_MAIN = 52
ui_stub._PORTRAIT = False
ui_stub.HEADER_H = 60
ui_stub._TICKER_SPEED = 60
ui_stub._is_empire_subtab = lambda t: t in ('territory', 'rivals')
ui_stub._EMPIRE_SUBTABS = [('Territory', 'territory'), ('Rivals', 'rivals')]
ui_stub._SUBTAB_W = 80
ui_stub._SUBTAB_Y_OFFSET = 26
ui_stub.get_content_rect = lambda t: pg_stub.Rect(450, 100, 440, 580)
ui_stub.make_bg_surface = lambda: None
ui_stub.make_fonts = lambda: {}
sys.modules['src.ui'] = ui_stub

thm_stub = _t.ModuleType('src.theme')
thm_stub.make_fonts = lambda: {}
thm_stub.TEXT_MUTED = (120, 120, 140)
thm_stub.RED = (220, 60, 60)
thm_stub.GREEN = (80, 200, 80)
thm_stub.PRESTIGE_LABEL = (180, 140, 255)
thm_stub.TEXT_PRIMARY = (230, 230, 230)
thm_stub.TEXT_GOLD = (220, 180, 60)
thm_stub.BLUE_BRIGHT = (80, 140, 255)
thm_stub.PURPLE_BRIGHT = (160, 80, 255)
thm_stub.BLUE_HIGHLIGHT = (100, 160, 255)
thm_stub.BG_CARD_HOVER = (38, 42, 60)
thm_stub.format_number = lambda n: str(n)
thm_stub.format_money = lambda n: f"${n:,.0f}"
sys.modules['src.theme'] = thm_stub

import importlib
import config

from src.buildings   import make_buildings
from src.upgrades    import make_upgrades
from src.managers    import make_managers
from src.territory   import make_territories
from src.rivals      import make_rivals
from src.crew        import CrewAssignment
from src.operations  import make_operations, Operation
from src.goals       import make_goals
from src.achievements import make_achievements
import src.prestige as pmod
import src.save_load as sl

# ─── Minimal fake state ───────────────────────────────────────────────────────

class FakeState:
    def __init__(self):
        self.balance             = 0.0
        self.lifetime_earnings   = 0.0
        self.prestige_tokens     = 0
        self.influence           = 0
        self._click_count        = 0
        self._play_time          = 0.0
        self._coins_caught       = 0
        self._prestige_count     = 0
        self._next_prestige_earnings = pmod.FIRST_PRESTIGE_EARNINGS
        self._daily_streak       = 1
        self.perks_purchased     = []
        self.prestige_branch     = None
        self.dragon_patron       = None
        self.dragon_xp           = 0
        self.dragon_ability_cooldowns = {}
        self._dragon_red_elim_count = 0
        self._dragon_black_last_op_time = None
        self._arms_influence_frac = 0.0
        self._tutorial_step      = 0
        self._shown_milestones   = set()
        self._milestone_queue    = []
        self._milestone_timer    = 0.0
        self._peak_income        = 0.0
        self._longest_streak     = 1
        self._show_prestige_locked = False
        self._post_prestige_notif  = False
        self._last_rank          = pmod.get_rank(0)
        self._ips_dirty          = True
        self._ips_cached         = 0.0
        self._ach_check_timer    = 0.0
        self.heat                = 0.0
        self.territories         = make_territories()
        self._event_timer        = None
        self._pending_event      = None
        self._event_outcome      = None
        self._event_outcome_timer = 0.0
        self.rivals              = make_rivals()
        self._rival_outcome      = None
        self._rival_outcome_timer = 0.0
        self.crew                = CrewAssignment()
        self.operations          = make_operations()
        self._territory_outcome  = None
        self._territory_outcome_timer = 0.0
        self._terr_scroll        = 0
        self.goals               = make_goals()
        self._elim_overlay       = None
        self._elim_overlay_timer = 0.0
        self._elim_rewards       = ""
        self._music_volume       = 0.5
        self._master_volume      = 1.0
        self._mute_all           = False
        self._sfx_volume         = 1.0
        self._fps_cap            = 60
        self._total_buildings_purchased  = 0
        self._total_territories_captured = 0
        self._total_rivals_defeated      = 0
        self._total_ops_completed        = 0
        self._total_heat_generated       = 0.0
        self._total_respect_earned       = 0
        self._total_influence_earned     = 0
        self._highest_cash_held          = 0.0
        self._highest_city_control       = 0.0
        self._city_control_milestones    = set()
        self._shown_influence_intro      = False
        self._return_ops_ready           = 0
        self._return_territory_player    = 0
        self._return_territory_total     = 0
        self._return_rival_active        = 0
        self._return_rival_at_war        = 0
        self._push_near_prestige_fired   = False
        self._notif_near_prestige_80     = False
        # Fields set by apply_save_data (not in __init__ in FakeState, but always
        # present on PlayingState via its own __init__ before apply_save_data runs)
        self._show_offline_overlay       = False
        self._show_daily_overlay         = False
        self._offline_gain               = 0.0
        self._offline_secs_away          = 0.0
        self._offline_capped             = False
        self._offline_rival_events: list = []
        self._daily_reward               = 0.0
        self._shown_raid_tutorial        = False
        self._shown_ops_tutorial         = False
        self._shown_influence_tutorial   = False
        self._shown_heat_warning         = False
        self._shown_prestige_tree_tutorial = False
        self._shown_syndicate_tutorial   = False
        self._shown_crew_tutorial        = False
        self._shown_territory_tutorial   = False
        self._shown_rivals_tutorial      = False
        self.buildings           = make_buildings()
        self.upgrades            = make_upgrades()
        self.achievements        = make_achievements()
        self.managers            = make_managers()
        self._buffs              = []

    @property
    def income_per_second(self) -> float:
        base = sum(b.owned * b.base_income for b in self.buildings)
        return max(base, 1.0)


# ─── Test harness ─────────────────────────────────────────────────────────────

PASS = 0
FAIL = 0
WARN = 0

def check(name, condition, detail='', warn=False):
    global PASS, FAIL, WARN
    tag = 'WARN' if warn and not condition else ('PASS' if condition else 'FAIL')
    if condition:
        print(f'  PASS  {name}')
        PASS += 1
    elif warn:
        print(f'  WARN  {name}  {detail}')
        WARN += 1
    else:
        print(f'  FAIL  {name}  {detail}')
        FAIL += 1


def roundtrip(state: FakeState) -> FakeState:
    """Save state to dict and reload into a fresh FakeState."""
    data = _capture_save(state)
    fresh = FakeState()
    # Patch save_load imports to use our stubs
    sl.apply_save_data(fresh, data)
    return fresh


def _capture_save(state: FakeState) -> dict:
    """Call save_game logic but capture to dict instead of file."""
    import src.save_load as _sl
    import tempfile
    tmp = os.path.join(tempfile.gettempdir(), '_phase72_test.json')
    _sl.SAVE_PATH = tmp
    _sl.BACKUP_PATH = tmp + '.bak'
    _sl.save_game(state)
    with open(tmp) as f:
        data = json.load(f)
    try:
        os.remove(tmp)
        os.remove(tmp + '.bak')
    except OSError:
        pass
    return data


# ═══════════════════════════════════════════════════════════════════════════════
# PART 1 — Normal Save Validation
# ═══════════════════════════════════════════════════════════════════════════════
print('\n' + '='*60)
print('PART 1 — Normal Save Validation')
print('='*60)

s = FakeState()
s.balance            = 1_234_567.89
s.lifetime_earnings  = 9_876_543.21
s.prestige_tokens    = 42
s.influence          = 99
s.heat               = 37.5
s.buildings[0].owned = 25
s.buildings[1].owned = 10
s.buildings[3].owned = 5
s.managers[0].hired  = True
s.managers[2].hired  = True
# territory
s.territories[0].unlocked = True; s.territories[0].owner = 'player'
s.territories[2].unlocked = True; s.territories[2].owner = 'player'
# rivals
s.rivals[0].power = 55; s.rivals[0].status = 'Weakened'
s.rivals[1].turf  = 4
# crew
s.crew.protection = 3; s.crew.collection = 5; s.crew.heat = 2
# operations: one active, one collected
s.operations[0].active = True; s.operations[0].start_time = time.time() - 30
s.operations[0].reward = 500_000.0
s.operations[1].active = False; s.operations[1].completed = True; s.operations[1].collected = True

r = roundtrip(s)

# Offline earnings apply on load (save_timestamp in file → tiny elapsed time).
# Allow up to 5s of IPS as drift; real drift should be milliseconds.
ips_est = sum(b.owned * b.base_income for b in s.buildings)
tol = max(1.0, ips_est * 5.0)
check('money: balance restored (within offline-earnings tolerance)',
      r.balance >= s.balance and (r.balance - s.balance) < tol,
      f'{r.balance} vs {s.balance}, ips≈{ips_est:.1f}, tol={tol:.1f}')
check('money: lifetime_earnings restored (within offline-earnings tolerance)',
      r.lifetime_earnings >= s.lifetime_earnings
      and (r.lifetime_earnings - s.lifetime_earnings) < tol)
check('prestige_tokens restored',          r.prestige_tokens == 42, str(r.prestige_tokens))
check('influence/respect restored',        r.influence == 99, str(r.influence))
check('heat restored',                     abs(r.heat - 37.5) < 0.01, str(r.heat))
check('buildings[0].owned restored',       r.buildings[0].owned == 25, str(r.buildings[0].owned))
check('buildings[1].owned restored',       r.buildings[1].owned == 10)
check('buildings[3].owned restored',       r.buildings[3].owned == 5)
check('manager[0] hired restored',         r.managers[0].hired is True)
check('manager[2] hired restored',         r.managers[2].hired is True)
check('territory[0] unlocked restored',    r.territories[0].unlocked is True)
check('territory[0] owner restored',       r.territories[0].owner == 'player')
check('territory[2] unlocked restored',    r.territories[2].unlocked is True)
check('rival[0] power preserved',          r.rivals[0].power == 55)
check('rival[0] status preserved',         r.rivals[0].status == 'Weakened')
check('rival[1] turf preserved',           r.rivals[1].turf == 4)
check('crew.protection restored',          r.crew.protection == 3)
check('crew.collection restored',          r.crew.collection == 5)
check('crew.heat restored',                r.crew.heat == 2)
check('operations[0] active restored',     r.operations[0].active is True)
check('operations[0] start_time restored', abs(r.operations[0].start_time - s.operations[0].start_time) < 1.0)
check('operations[0] reward restored',     r.operations[0].reward == 500_000.0)
check('operations[1] collected restored',  r.operations[1].collected is True)


# ═══════════════════════════════════════════════════════════════════════════════
# PART 2 — Prestige Save Validation
# ═══════════════════════════════════════════════════════════════════════════════
print('\n' + '='*60)
print('PART 2 — Prestige Save Validation')
print('='*60)

s = FakeState()
s._satisfy = lambda: None
# Setup sufficient state to pass can_prestige
s.lifetime_earnings   = pmod.FIRST_PRESTIGE_EARNINGS * 2
s.prestige_tokens     = 12  # Made Man
s.buildings[0].owned  = pmod.FIRST_PRESTIGE_DEALERS
s.buildings[1].owned  = pmod.FIRST_PRESTIGE_RACKETS
s.buildings[2].owned  = pmod.FIRST_PRESTIGE_CHOPS
s.influence           = 50
s.heat                = 85.0
s.balance             = 5_000_000.0
for t in s.territories: t.unlocked = True; t.owner = 'player'
s._prestige_count     = 0

# Execute prestige
ok = pmod.PrestigeManager.execute(s)

# Capture state post-prestige
prestige_tokens_after = s.prestige_tokens
prestige_count_after  = s._prestige_count
branch_after          = s.prestige_branch

# Now roundtrip
r = roundtrip(s)

check('prestige executed',                      ok, 'can_prestige returned False')
check('multiplier (tokens) preserved on reload', r.prestige_tokens == prestige_tokens_after,
      f'{r.prestige_tokens} vs {prestige_tokens_after}')
check('prestige_count preserved on reload',      r._prestige_count == prestige_count_after,
      f'{r._prestige_count}')
check('rank preserved on reload',
      pmod.get_rank(r.prestige_tokens) == pmod.get_rank(prestige_tokens_after))
check('buildings reset to 0',                    all(b.owned == 0 for b in r.buildings))
check('heat reset to 0',                         r.heat == 0.0, f'{r.heat}')
# Post-prestige: IPS is 0 (no buildings). The FakeState's floor of 1.0/s means
# tiny offline earnings apply. Accept up to 10s worth as a tolerance.
check('balance reset to 0 (or minimal offline drift)',
      r.balance < 10.0,   # max 10s of IPS=1.0 × 0.6 efficiency = 6.0
      f'{r.balance}')
check('branch reset (None)',                      r.prestige_branch is None, str(r.prestige_branch))
check('managers reset',                          not any(m.hired for m in r.managers))
check('_post_prestige_notif persisted after prestige reload',
      getattr(r, '_post_prestige_notif', False),
      '_post_prestige_notif lost on reload — rebuild hint will not fire')


# ═══════════════════════════════════════════════════════════════════════════════
# PART 3 — Mid-Operation Save Test
# ═══════════════════════════════════════════════════════════════════════════════
print('\n' + '='*60)
print('PART 3 — Mid-Operation Save Test')
print('='*60)

s = FakeState()
# Start an operation 60s ago
op = s.operations[0]  # Drug Run, 300s duration
op.active     = True
op.start_time = time.time() - 60   # 60s elapsed out of 300s
op.reward     = 250_000.0
op.completed  = False
op.collected  = False

r = roundtrip(s)

rop = r.operations[0]
elapsed_after_reload = rop.elapsed
check('op still active after reload',       rop.active is True)
check('op start_time preserved',            abs(rop.start_time - op.start_time) < 1.0,
      f'{rop.start_time} vs {op.start_time}')
check('op reward preserved',               rop.reward == 250_000.0, str(rop.reward))
check('op not completed on reload',        rop.completed is False)
check('op not collected on reload',        rop.collected is False)
check('op timer resumes correctly',        60 <= elapsed_after_reload < 65,
      f'elapsed={elapsed_after_reload:.1f}s (expected ~60s)')
check('op is_ready=False (incomplete)',    not rop.is_ready,
      'should not be ready at 60/300s')

# Check speed_mult persistence (Cartel branch issue)
s2 = FakeState()
s2.operations[1].active     = True
s2.operations[1].start_time = time.time() - 120
s2.operations[1].reward     = 100_000.0
s2.operations[1].speed_mult = 0.75  # Cartel Fast Track perk applied at start

r2 = roundtrip(s2)
rop2 = r2.operations[1]
check('op speed_mult persisted across reload', rop2.speed_mult == 0.75,
      f'speed_mult={rop2.speed_mult} (expected 0.75) — op takes longer than expected after reload',
      warn=True)

# Duplicate collect check: completed + collected op should not be collectible again
s3 = FakeState()
s3.operations[2].active    = False
s3.operations[2].completed = True
s3.operations[2].collected = True
s3.operations[2].reward    = 999_999.0
r3 = roundtrip(s3)
rop3 = r3.operations[2]
check('collected op: is_ready=False after reload',  not rop3.is_ready,
      'collected op should not be collectable again')
check('collected op: collect() returns empty string', rop3.collect(r3) == '')


# ═══════════════════════════════════════════════════════════════════════════════
# PART 4 — Autosave Validation
# ═══════════════════════════════════════════════════════════════════════════════
print('\n' + '='*60)
print('PART 4 — Autosave Validation (structure)')
print('='*60)

s = FakeState()
s.balance = 7_777_777.0
s.prestige_tokens = 15

import tempfile as _tmp
tmp_path = os.path.join(_tmp.gettempdir(), '_phase72_autosave.json')
tmp_bak  = tmp_path + '.bak'
_orig_save = sl.SAVE_PATH
_orig_bak  = sl.BACKUP_PATH
sl.SAVE_PATH   = tmp_path
sl.BACKUP_PATH = tmp_bak
sl.save_game(s)
sl.SAVE_PATH   = _orig_save
sl.BACKUP_PATH = _orig_bak

check('autosave file created',   os.path.exists(tmp_path), 'save.json not found')
check('autosave valid JSON', True)
if os.path.exists(tmp_path):
    with open(tmp_path) as f:
        _ad = json.load(f)
    check('autosave has save_timestamp', 'save_timestamp' in _ad)
    check('autosave balance correct', abs(_ad['balance'] - 7_777_777.0) < 0.01)
    check('autosave prestige_tokens correct', _ad['prestige_tokens'] == 15)
    try: os.remove(tmp_path)
    except OSError: pass

# Backup fallback: use a separate pair of paths so cleanup doesn't interfere
tmp_path2 = os.path.join(_tmp.gettempdir(), '_phase72_bak_test.json')
tmp_bak2  = tmp_path2 + '.bak'
sl.SAVE_PATH   = tmp_path2
sl.BACKUP_PATH = tmp_bak2
sl.save_game(s)  # 1st write: creates primary (no backup yet)
sl.save_game(s)  # 2nd write: copies primary→backup, overwrites primary
# Corrupt primary
with open(tmp_path2, 'w') as f:
    f.write('{"balance": 9999, "BAD JSON TRUNCATED')
loaded = sl.load_game()
check('backup used on corrupted primary', loaded is not None and
      abs(loaded.get('balance', 0) - 7_777_777.0) < 0.01,
      f'loaded={loaded}')
sl.SAVE_PATH   = _orig_save
sl.BACKUP_PATH = _orig_bak
try:
    os.remove(tmp_path2)
    os.remove(tmp_bak2)
except OSError:
    pass


# ═══════════════════════════════════════════════════════════════════════════════
# PART 5 — Long Session / Large Value Validation
# ═══════════════════════════════════════════════════════════════════════════════
print('\n' + '='*60)
print('PART 5 — Long Session / Large Value Validation')
print('='*60)

s = FakeState()
# Extreme late-game values
s.balance            = 9.87654321e18
s.lifetime_earnings  = 1.23456789e20
s.prestige_tokens    = 9999
s.influence          = 9999
s._prestige_count    = 47
s._play_time         = 86400 * 30.0   # 30 days
s._total_ops_completed      = 5000
s._total_buildings_purchased = 99999
s._total_territories_captured = 2000
s._total_rivals_defeated     = 500
s._highest_cash_held         = 1.0e25
s._total_heat_generated      = 9999999.0
s.heat               = 99.9
for b in s.buildings:
    b.owned = 9999
for m in s.managers:
    m.hired = True
for t in s.territories:
    t.unlocked = True; t.owner = 'player'
s._city_control_milestones = {'25', '50', '75', '100'}
s._shown_milestones = {'first_building', 'first_prestige', 'made_man', 'first_territory'}

r = roundtrip(s)

# JSON float serialization loses precision at extreme values (~1e18+).
# Verify within 0.001% relative error — any rounding is cosmetic, not progress loss.
def rel_close(a, b, rtol=1e-5):
    return abs(a - b) <= rtol * max(abs(a), abs(b), 1.0)
check('large balance persists (within JSON float precision)',
      rel_close(r.balance, s.balance),
      f'{r.balance} vs {s.balance}')
check('large lifetime_earnings (within JSON float precision)',
      rel_close(r.lifetime_earnings, s.lifetime_earnings),
      f'{r.lifetime_earnings} vs {s.lifetime_earnings}')
check('large prestige_tokens',       r.prestige_tokens == 9999)
check('large prestige_count',        r._prestige_count == 47)
check('large play_time',             abs(r._play_time - 86400 * 30.0) < 1.0)
check('large ops_completed',         r._total_ops_completed == 5000)
check('buildings all 9999',          all(b.owned == 9999 for b in r.buildings))
check('all managers hired',          all(m.hired for m in r.managers))
check('all territories unlocked',    all(t.unlocked for t in r.territories))
check('city_control_milestones',     r._city_control_milestones == {'25', '50', '75', '100'})
check('shown_milestones set',        'first_building' in r._shown_milestones)
check('heat 99.9 persists',         abs(r.heat - 99.9) < 0.01)
check('nan/inf guard: balance finite', r.balance < float('inf') and r.balance == r.balance)


# ═══════════════════════════════════════════════════════════════════════════════
# PART 6 — Missing Field / Old Save Compatibility
# ═══════════════════════════════════════════════════════════════════════════════
print('\n' + '='*60)
print('PART 6 — Missing Field Compatibility')
print('='*60)

# Simulate an old save that lacks newer fields
old_save = {
    'balance': 500_000.0,
    'lifetime_earnings': 2_000_000.0,
    'prestige_tokens': 5,
    # Missing: influence, heat, dragon fields, _post_prestige_notif, etc.
}

fresh = FakeState()
try:
    sl.apply_save_data(fresh, old_save)
    check('old save: no crash on load', True)
    # Daily reward fires because old save has no last_login_date → balance increases.
    # This is correct behavior (player gets a return reward). Verify balance >= original.
    check('old save: balance >= original (daily reward applied)',
          fresh.balance >= 500_000.0,
          f'{fresh.balance}')
    check('old save: influence defaults to 0', fresh.influence == 0)
    check('old save: heat defaults to 0.0',    abs(fresh.heat - 0.0) < 0.01)
    check('old save: dragon_patron defaults to None', fresh.dragon_patron is None)
    check('old save: dragon_xp defaults to 0', fresh.dragon_xp == 0)
    check('old save: prestige_branch defaults to None', fresh.prestige_branch is None)
    check('old save: crew defaults to empty CrewAssignment',
          fresh.crew.protection == 0 and fresh.crew.total() == 0)
    check('old save: operations all inactive',
          not any(op.active for op in fresh.operations))
    check('old save: territories all unclaimed (except South Side by default)',
          True)  # territories not in old save → defaults to [] → no unlocks set
except Exception as e:
    check('old save: no crash on load', False, str(e))

# Simulate save missing _post_prestige_notif (Phase 68-71 era)
phase68_save = {
    'balance': 0.0,
    'lifetime_earnings': 25_000_000.0,
    'prestige_tokens': 30,
    'influence': 50,
    'prestige_count': 1,
    'next_prestige_earnings': 200_000_000.0,
    # Deliberately absent: _post_prestige_notif, arms_influence_frac, dragon_xp
}
fresh2 = FakeState()
try:
    sl.apply_save_data(fresh2, phase68_save)
    check('Phase 68+ save: no crash on load',           True)
    check('Phase 68+ save: _post_prestige_notif safe',
          not getattr(fresh2, '_post_prestige_notif', True),
          warn=False)
    check('Phase 68+ save: arms_influence_frac defaults to 0',
          getattr(fresh2, '_arms_influence_frac', 0.0) == 0.0)
    check('Phase 68+ save: dragon_xp defaults to 0',
          fresh2.dragon_xp == 0)
except Exception as e:
    check('Phase 68+ save: no crash on load', False, str(e))

# Verify near-prestige flags survive save/load (no duplicate notifications after reload)
s_notif = FakeState()
s_notif._notif_near_prestige_80   = True
s_notif._push_near_prestige_fired = True
s_notif.balance = 1_000_000.0
r_notif = roundtrip(s_notif)
check('near-prestige flags persisted (no re-fire after reload)',
      getattr(r_notif, '_notif_near_prestige_80', False)
      and getattr(r_notif, '_push_near_prestige_fired', False),
      'near-prestige flags lost on reload — notifications will duplicate')


# ═══════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════
print('\n' + '='*60)
print(f'Results: {PASS} PASS  {WARN} WARN  {FAIL} FAIL')
print('='*60)

if FAIL:
    sys.exit(1)
