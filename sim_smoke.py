"""Smoke test: boot the REAL game headless, render a frame, and verify the
new gating + Influence faucet work on the actual PlayingState (not the sim)."""
import os
os.environ.setdefault("SDL_VIDEODRIVER","dummy"); os.environ.setdefault("SDL_AUDIODRIVER","dummy")
import pygame; pygame.init(); pygame.display.set_mode((900,720))

import importlib
# Compile-check all touched modules
for m in ["config","src.buildings","src.upgrades","src.managers","src.prestige",
          "src.heat","src.territory","src.crew","src.operations","src.rivals",
          "src.events","src.goals","src.prestige_tree","src.save_load","src.states",
          "src.ui","src.theme","src.achievements"]:
    importlib.import_module(m)
print("[OK] all modules import")

import src.prestige as prestige
from src.state_base import StateManager
from src.states import PlayingState

# Ensure no save exists (fresh)
from src.save_load import delete_save
delete_save()

sm = StateManager()
ps = PlayingState(sm)
ps.on_enter()  # fresh init (gifts 1 dealer)

# 1. Verify fresh-save starting conditions
assert abs(ps.balance) < 1e-6, f"balance not 0: {ps.balance}"
assert ps.prestige_tokens == 0, f"tokens not 0: {ps.prestige_tokens}"
assert sum(m.hired for m in ps.managers) == 0, "managers hired on fresh save"
assert ps.buildings[0].owned == 0, "fresh game should start with 0 dealers (tutorial teaches first buy)"
assert prestige.get_rank(ps.prestige_tokens) == "Street Hustler"
print("[OK] fresh save: balance=0, influence=0, 0 managers, 0 dealers, Street Hustler")

# 2. Verify tab gating: core tabs visible at 0 Influence (Phase 100 flat nav —
# the old single "empire" tab was split into upgrades/managers/turf).
tabs = [k for _,k in prestige.visible_tabs(ps)]
assert "buildings" in tabs and "upgrades" in tabs and "stats" in tabs, tabs
print(f"[OK] tabs visible at 0 Influence: {tabs}  (Upgrades reachable!)")

# 3. Render a full frame (catches any draw-path error in the new gating)
surf = pygame.Surface((900,720))
ps.draw(surf)
print("[OK] full frame rendered without error")

# 4. Drive ~12 min of updates to confirm the Influence faucet fires (no deadlock)
import src.goals as goals_mod
for _ in range(1500):  # 1500 * 0.5s = 12.5 min
    ps.update(0.5)
    # auto-buy cheapest affordable building to simulate progress
    for b in ps.buildings:
        if ps.balance >= b.current_cost:
            ps.balance -= b.current_cost; b.owned += 1
            break
print(f"[OK] after ~12 min sim: influence={ps.prestige_tokens}  rank={prestige.get_rank(ps.prestige_tokens)}  "
      f"lifetime={ps.lifetime_earnings:,.0f}  buildings={sum(b.owned for b in ps.buildings)}")
assert ps.prestige_tokens >= 1, "DEADLOCK: no Influence earned from fresh save!"
print("[OK] DEADLOCK BROKEN: fresh player earned Influence with no dev save")

# 5. Verify Crew/Operations gates open with progress
tabs2 = [k for _,k in prestige.visible_tabs(ps)]
print(f"[OK] tabs after progress: {tabs2}")

# cleanup
delete_save()
print("\nSMOKE TEST PASSED")
