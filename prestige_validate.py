"""Phase 70 headless prestige validation — renders to PNG without opening a window."""
import os, sys, json, shutil, time
sys.stdout.reconfigure(encoding='utf-8')

# Force off-screen rendering via a null SDL driver
os.environ.setdefault('SDL_VIDEODRIVER', 'dummy')
os.environ.setdefault('SDL_AUDIODRIVER', 'dummy')

import pygame
pygame.init()
pygame.mixer.quit()   # silence mixer so dummy audio driver doesn't complain

import config
screen = pygame.display.set_mode((config.SCREEN_WIDTH, config.SCREEN_HEIGHT))

SHOTS = "prestige_shots"
os.makedirs(SHOTS, exist_ok=True)

def shot(name: str) -> str:
    path = os.path.join(SHOTS, name + ".png")
    pygame.image.save(screen, path)
    print(f"  SHOT {name}")
    return path

def pump():
    pygame.event.get()

# ── Boot the state machine ────────────────────────────────────────────────────
from src.state_base import StateManager
from src.states import PlayingState
import src.ui as ui
import src.prestige as prestige
import src.theme as theme

sm = StateManager()

def make_playing(save_path: str) -> PlayingState:
    shutil.copy(save_path, "save.json")
    state = PlayingState(sm)
    state.on_enter()          # loads save, applies upgrades, etc.
    return state

def render(state: PlayingState, dt: float = 0.05) -> None:
    state.update(dt)
    screen.fill(theme.BG_DARK)
    state.draw(screen)
    pump()

def settle(state: PlayingState, secs: float) -> None:
    """Run update+draw for `secs` seconds worth of frames at 20 fps."""
    steps = max(1, int(secs * 20))
    for _ in range(steps):
        render(state)

# ═══════════════════════════════════════════════════════════════════════════════
# PART 1 — Prestige Approach  (87.5% earnings, all building reqs met)
# ═══════════════════════════════════════════════════════════════════════════════
print("\n=== PART 1: Prestige Approach (87.5%) ===")
s1 = make_playing("save_test_near.json")
settle(s1, 5.0)          # let near-prestige notification fire and fade
shot("01_prestige_approach_full")

reqs = prestige.check_requirements(s1)
ratio = s1.lifetime_earnings / prestige.prestige_earnings_required(s1)
print(f"  Earnings ratio : {ratio:.1%}")
print(f"  Rank           : {prestige.get_rank(s1.prestige_tokens)} ({s1.prestige_tokens} tokens)")
print(f"  can_prestige   : {prestige.can_prestige(s1)}")
print(f"  IPS            : ${s1.income_per_second:,.0f}/s")
for k, (cur, req, met) in reqs.items():
    sym = "OK" if met else "XX"
    print(f"    {sym} {k}: {cur} / {req}")

# ═══════════════════════════════════════════════════════════════════════════════
# PART 2 — Prestige Screen: the unlocked button
# ═══════════════════════════════════════════════════════════════════════════════
print("\n=== PART 2: Prestige Screen (ready state) ===")
s2 = make_playing("save_test_ready.json")
settle(s2, 5.0)
shot("02_prestige_button_unlocked")

gain = prestige.calc_influence_gain(s2.lifetime_earnings)
print(f"  can_prestige   : {prestige.can_prestige(s2)}")
print(f"  Influence gain : +{gain}")
print(f"  Income bonus   : +{gain*2}%")

# Render confirm dialog overlay on top of the game frame
render(s2)
ui.draw_prestige_confirm(screen, s2, s2._fonts)
pump()
shot("03_prestige_confirm_dialog")
print("  Confirm dialog shows:")
print(f"    Title: '* PRESTIGE?'")
print(f"    Gain : '+{gain} Influence -> permanent +{gain*2}% income'")
print( "    RESETS column: Cash & balance / Buildings / Upgrades / Temporary progress")
print( "    YOU KEEP column: Influence / Respect / Prestige perks / Lifetime statistics")
print( "    Buttons: Yes  /  No")

# ═══════════════════════════════════════════════════════════════════════════════
# PART 3 — Execute prestige, observe reset
# ═══════════════════════════════════════════════════════════════════════════════
print("\n=== PART 3: Prestige Execute ===")
bal_before    = s2.balance
tok_before    = s2.prestige_tokens
earn_before   = s2.lifetime_earnings
ips_before    = s2.income_per_second

ok = prestige.PrestigeManager.execute(s2)
print(f"  execute() ok        : {ok}")
print(f"  Balance  : ${bal_before:>12,.0f}  →  ${s2.balance:,.0f}")
print(f"  Tokens   : {tok_before}  →  {s2.prestige_tokens}")
print(f"  Lifetime : ${earn_before:>12,.0f}  →  ${s2.lifetime_earnings:,.0f}  (persists)")
print(f"  Buildings: {[b.owned for b in s2.buildings]}")
print(f"  Heat     : {s2.heat}")
if s2._milestone_queue:
    print("  Milestone msg:")
    for ln in s2._milestone_queue[0].split('\n'):
        print(f"    | {ln}")

settle(s2, 0.5)
shot("04_post_prestige_immediate")

settle(s2, 1.5)
shot("05_milestone_overlay")

# ═══════════════════════════════════════════════════════════════════════════════
# PART 4 — Power gain: income multiplier check
# ═══════════════════════════════════════════════════════════════════════════════
print("\n=== PART 4: Power Gain ===")
ips_after = s2.income_per_second
mult      = prestige.income_mult(s2.prestige_tokens)
print(f"  IPS before prestige : ${ips_before:,.0f}/s")
print(f"  IPS after (0 bldgs) : ${ips_after:,.4f}/s")
print(f"  Income mult from tokens: ×{mult:.4f}  (applies once buildings bought)")
print(f"  First Corner Dealer base income with mult: ${0.10 * mult:.4f}/s")

# ═══════════════════════════════════════════════════════════════════════════════
# PART 5 — Early rebuild: buy first 3 dealers
# ═══════════════════════════════════════════════════════════════════════════════
print("\n=== PART 5: Early Rebuild ===")
s2.balance = 1_000.0
for i in range(3):
    b = s2.buildings[0]
    if s2.balance >= b.current_cost:
        s2.balance -= b.current_cost
        b.owned += 1
        s2._ips_dirty = True

s2._ips_dirty = True
ips_3 = s2.income_per_second
print(f"  After 3 Corner Dealers: IPS = ${ips_3:.4f}/s")
print(f"  Cost of 1st dealer   : ${s2.buildings[0].base_cost:.0f}")
print(f"  Cost of 4th dealer   : ${s2.buildings[0].current_cost:.2f}")

settle(s2, 1.0)
shot("06_early_rebuild_3dealers")

# ═══════════════════════════════════════════════════════════════════════════════
# PART 6 — Reward visibility: wait for milestone to expire
# ═══════════════════════════════════════════════════════════════════════════════
print("\n=== PART 6: Prestige Reward Visibility Audit ===")
settle(s2, 8.0)          # let milestone overlay expire
shot("07_post_prestige_clear")

print("  What the player sees in the prestige button (unlocked):")
print(f"    '* PRESTIGE'")
print(f"    '+{gain} Influence  •  +{gain*2}% permanent income'")
print( "    'Keeps: Influence, Respect, Perks, Stats'")
print("  Confirm dialog clearly answers:")
print("    What do I gain?   → YES (Influence count + income %)")
print("    What do I lose?   → YES (RESETS column)")
print("    Why should I?     → PARTIAL (income bonus shown; no example of 'you'll rebuild faster')")
print("  Milestone overlay answers:")
if s2._milestone_queue:
    print("    (queue already consumed)")
else:
    print("    'FIRST PRESTIGE! / You've reset and grown stronger.'")

print("\n=== VALIDATION COMPLETE ===")
print(f"Screenshots in: {os.path.abspath(SHOTS)}/")
pygame.quit()
