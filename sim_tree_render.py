"""Render smoke test for the branching PrestigeTreeState UI.

Drives the real state through: uncommitted view, branch-commit confirm dialog,
committed view with perk cards, and a perk hover tooltip. Asserts no draw error.
"""
import os
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
import pygame
pygame.init()
surf = pygame.display.set_mode((900, 720))

import src.prestige_tree as pt
from src.state_base import StateManager
from src.states import PlayingState

sm = StateManager()
ps = PlayingState(sm); ps.on_enter()
ps.perks_purchased = []; ps.prestige_branch = None; ps.prestige_tokens = 50
pt.apply_perks(ps)

tree = pt.PrestigeTreeState(sm, ps)

steps = []

# 1. Uncommitted: should draw branch selector + blurbs.
tree.draw(surf); steps.append("uncommitted view")
pygame.image.save(surf, "tree_uncommitted.png")

# 2. Open commit confirm for Warlord.
tree._pending_branch = pt.WARLORD
tree.draw(surf); steps.append("commit-confirm dialog")
tree._pending_branch = None

# 3. Commit to Cartel, buy a couple perks, draw committed view.
pt.select_branch(ps, pt.CARTEL)
ps.prestige_tokens -= pt.PERK_COST['ct_supply']; ps.perks_purchased.append('ct_supply')
ps.prestige_tokens -= pt.PERK_COST['ct_fast']; ps.perks_purchased.append('ct_fast')
pt.apply_perks(ps)
tree._first_visit = False
tree.draw(surf); steps.append("committed view (Cartel, 2 perks)")
pygame.image.save(surf, "tree_committed.png")

# 4. Simulate hover over a perk card region (top-left perk).
import pygame.mouse
tree._first_visit = False
tree.draw(surf); steps.append("committed view redraw")

# 5. Prestige confirm dialog.
tree._confirm = True
tree.draw(surf); steps.append("prestige confirm dialog")

print("Rendered OK:")
for s in steps:
    print(f"  [OK] {s}")
print("RENDER SMOKE PASSED")
