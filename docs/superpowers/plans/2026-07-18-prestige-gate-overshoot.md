# Prestige Gate Overshoot Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change the next-prestige-gate formula in both runtimes from `route_earnings × GROWTH` to `previous_gate × GROWTH`, so overshooting the current gate no longer inflates the next one — making the 2nd/3rd prestige reachable. Per `docs/superpowers/specs/2026-07-18-prestige-gate-overshoot-design.md`.

**Architecture:** One formula line changes in each runtime's prestige routine, capturing the just-satisfied gate before `prestige_count` is incremented. pygame is the balance lab (proven first via unit test + strategy sim); the validated formula is ported to Godot and checked with a headless probe.

**Tech Stack:** Python 3 / pygame-ce (lab), Godot 4.6.3 GDScript (ship target), `shell_smoke.gd` headless probe.

## Global Constraints

- Godot binary: `E:\Downloads\Godot_v4.6.3-stable_win64.exe`.
- `PRESTIGE_EARNINGS_GROWTH` stays **8.0** in both `godot/scripts/autoload/game_config.gd:27` and `src/prestige.py:53`. Do NOT change it in this plan. If Task 2's sim shows P2 still never lands at 8.0, STOP and report the growth value needed — a separate owner decision.
- `previous_gate` = `prestige_earnings_required(prestige_count, next_prestige_earnings)` evaluated BEFORE `prestige_count` is incremented (first prestige → `FIRST_PRESTIGE_EARNINGS`; later → current `next_prestige_earnings`).
- No save-schema change: `next_prestige_earnings` already persists; only its computation changes.
- pygame↔Godot parity: both runtimes must end with the identical formula.
- Run `python -m graphify update .` after code edits (AST-only, no API cost).

---

### Task 1: pygame — de-punish formula + unit test (TDD)

**Files:**
- Create: `tests/test_prestige_gate.py`
- Modify: `src/prestige.py:454-457` (`_do_execute`)

**Interfaces:**
- Consumes: `src.prestige.PrestigeManager.execute(state)`, `src.prestige.prestige_earnings_required(state)`, `PRESTIGE_EARNINGS_GROWTH`; `PlayingState` via `StateManager` (real state builder the sims use).
- Produces: behavior only — `state._next_prestige_earnings == previous_gate * GROWTH` after a prestige. No new public symbols.

- [ ] **Step 1: Write the failing test**

Create `tests/test_prestige_gate.py`:

```python
"""The next prestige gate is previous_gate x GROWTH, independent of overshoot."""
import os
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")
import pygame
pygame.init()
pygame.display.set_mode((320, 240))

import src.prestige as prestige
from src.state_base import StateManager
from src.states import PlayingState


def _fresh_state():
    sm = StateManager()
    ps = PlayingState(sm)
    ps.on_enter()
    return ps


def test_next_gate_ignores_overshoot():
    ps = _fresh_state()
    # Second-cycle prestige (count>=1 => only the earnings requirement gates it).
    ps._prestige_count = 1
    ps._next_prestige_earnings = 100_000_000.0     # the gate just crossed
    ps._prestige_route_earnings = 900_000_000.0    # a 9x overshoot
    ps.lifetime_earnings = 2_000_000_000.0         # plenty for influence calc
    assert prestige.can_prestige(ps), "setup must satisfy the gate"

    prestige.PrestigeManager.execute(ps)

    growth = prestige.PRESTIGE_EARNINGS_GROWTH
    expected = 100_000_000.0 * growth              # previous_gate x GROWTH
    punished = 900_000_000.0 * growth              # the old route x GROWTH bug
    assert ps._next_prestige_earnings == expected, (
        f"gate should be {expected:.0f} (prev x {growth}), "
        f"got {ps._next_prestige_earnings:.0f}")
    assert ps._next_prestige_earnings != punished
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest tests/test_prestige_gate.py -v` (or `python -m pytest tests/test_prestige_gate.py::test_next_gate_ignores_overshoot -v`).
Expected: FAIL — actual `_next_prestige_earnings` is `7.2e9` (900M × 8), not `8.0e8`.

- [ ] **Step 3: Apply the formula fix**

In `src/prestige.py::_do_execute`, capture the prior gate before the count increment. Change the block at line 442-457. Insert the capture immediately before line 444 (`state._prestige_count += 1`):

```python
        # Capture the gate just satisfied BEFORE incrementing the count, so the
        # next gate ladders off it (not off however far this run overshot).
        _prev_gate = prestige_earnings_required(state)
        state.prestige_tokens    += influence_gain
        state.influence          = getattr(state, 'influence', 0) + influence_gain
        state._prestige_count    = getattr(state, '_prestige_count', 0) + 1
```

Then replace line 457:

```python
        state._next_prestige_earnings = prestige_route_earnings(state) * PRESTIGE_EARNINGS_GROWTH
```

with:

```python
        state._next_prestige_earnings = _prev_gate * PRESTIGE_EARNINGS_GROWTH
```

(Keep the existing comment block above line 457; only the right-hand side changes.)

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/test_prestige_gate.py -v`
Expected: PASS.

- [ ] **Step 5: Regression — existing sims still import/run**

Run: `python sim_test_suite.py` (fast) — expect no NEW failures vs baseline. Note: memory records 2 pre-existing stale failures (dealer/head-start); those are acceptable, anything else is not.

- [ ] **Step 6: Commit**

```powershell
git add tests/test_prestige_gate.py src/prestige.py
git commit -m "fix(prestige): next gate ladders off previous gate, not route overshoot (pygame)"
```

---

### Task 2: pygame — validate cadence in the lab (measurement gate)

**Files:** none (measurement only; may write a throwaway note).

**Interfaces:** Consumes `sim_prestige_strategies.py` (unchanged — its cadence reporting is already correct).

- [ ] **Step 1: Run the long-horizon cadence sim at growth 8.0**

Run: `python sim_prestige_strategies.py --active 0.33 --minutes 300 --prestiges 6`

- [ ] **Step 2: Read the result against acceptance**

- Baseline (pre-fix, recorded this session): P2 never lands in 300 min for any strategy.
- Acceptance: with the fix, the P2 and P3 columns now show times for the faster strategies, and the cadence-gap table shows consecutive gaps that grow gently (a stretch), not a re-wall.
- If P2 still shows "—" for every strategy at 8.0: **STOP.** Re-run at `IDLE_PRESTIGE_GROWTH=3.0` and `=4.0` to find the value where P2/P3 land, and report that number to the owner as a proposed `PRESTIGE_EARNINGS_GROWTH` change (do NOT apply it — it is out of this plan's approved scope).

- [ ] **Step 3: Record the finding**

State the observed P1/P2/P3 cadence (and, if triggered, the growth value that unblocks P2) in the task report. No commit.

---

### Task 3: Godot — port the formula + headless probe

**Files:**
- Modify: `godot/scripts/autoload/game_state.gd:757-769` (`do_prestige`)
- Create (scratch, not committed): `godot/scripts/tools/prestige_gate_probe.gd`

**Interfaces:**
- Consumes: `GameState` autoload, `Prestige.prestige_earnings_required(prestige_count, next_prestige_earnings)`, `GameConfig.PRESTIGE_EARNINGS_GROWTH`.
- Produces: behavior parity with pygame — `next_prestige_earnings = previous_gate × GROWTH`.

- [ ] **Step 1: Write the headless probe (the failing check)**

Create `godot/scripts/tools/prestige_gate_probe.gd`:

```gdscript
extends SceneTree
## Headless assertion: the next prestige gate ladders off the previous gate,
## not off route overshoot. Run:
##   godot --headless --path godot -s res://scripts/tools/prestige_gate_probe.gd

func _init() -> void:
	var gs := GameState
	# Second-cycle prestige (count>=1 => only the earnings requirement gates it).
	gs.prestige_count = 1
	gs.next_prestige_earnings = 100_000_000.0     # gate just crossed
	gs.prestige_route_earnings = 900_000_000.0    # 9x overshoot
	gs.lifetime_earnings = 2_000_000_000.0
	var growth: float = GameConfig.PRESTIGE_EARNINGS_GROWTH
	var expected := 100_000_000.0 * growth
	var ok := gs.do_prestige()
	if not ok:
		push_error("[gate_probe] FAIL — do_prestige refused (can_prestige false)")
		quit(1)
		return
	var got: float = gs.next_prestige_earnings
	if is_equal_approx(got, expected):
		print("[gate_probe] PASS — next gate %.0f == prev %.0f x %.1f" % [got, 100_000_000.0, growth])
		quit(0)
	else:
		push_error("[gate_probe] FAIL — next gate %.0f, expected %.0f (route-overshoot bug gives %.0f)" % [got, expected, 900_000_000.0 * growth])
		quit(1)
```

- [ ] **Step 2: Run the probe to verify it FAILS on current code**

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/prestige_gate_probe.gd | Select-String "gate_probe"
```

Expected: `[gate_probe] FAIL — next gate 7200000000, expected 800000000 ...` (current code uses route × growth).

If instead it fails with "do_prestige refused", the Godot `check_requirements` for count>=1 needs another field satisfied — inspect `godot/scripts/systems/prestige.gd::check_requirements` and set the missing field in the probe, then re-run to reach the real FAIL.

- [ ] **Step 3: Apply the formula fix**

In `godot/scripts/autoload/game_state.gd::do_prestige()`, capture the prior gate at the top of the function (after the `can_prestige` guard, before any mutation). Insert after line 759 (`return false`) block — i.e. as the first line after the guard:

```gdscript
	var _prev_gate: float = Prestige.prestige_earnings_required(prestige_count, next_prestige_earnings)
```

Then replace line 769:

```gdscript
	next_prestige_earnings = prestige_route_earnings * GameConfig.PRESTIGE_EARNINGS_GROWTH
```

with:

```gdscript
	next_prestige_earnings = _prev_gate * GameConfig.PRESTIGE_EARNINGS_GROWTH
```

(`_prev_gate` is captured before line 768's `prestige_count += 1`, so it sees the old count — first prestige resolves to `FIRST_PRESTIGE_EARNINGS`, later ones to the current gate.)

- [ ] **Step 4: Run the probe to verify it PASSES**

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/prestige_gate_probe.gd | Select-String "gate_probe"
```

Expected: `[gate_probe] PASS — next gate 800000000 == prev 100000000 x 8.0`.

- [ ] **Step 5: shell_smoke regression**

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd | Select-String "PASS|FAIL"
```

Expected: `[shell_smoke] PASS — 200 frames, no crash`.

- [ ] **Step 6: Graph refresh + cleanup + commit**

```powershell
Remove-Item -Force godot\scripts\tools\prestige_gate_probe.gd, godot\scripts\tools\prestige_gate_probe.gd.uid -ErrorAction SilentlyContinue
python -m graphify update .
git add godot/scripts/autoload/game_state.gd
git commit -m "fix(prestige): next gate ladders off previous gate, not route overshoot (Godot parity)"
```

(The probe is scratch — deleted before commit. shell_smoke is the retained regression.)
