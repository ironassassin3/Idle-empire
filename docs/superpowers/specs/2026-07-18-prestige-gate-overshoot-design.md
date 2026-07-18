# Prestige Gate — De-Punish the Overshoot — Design

**Date:** 2026-07-18
**Status:** Approved (owner, this session — "B only")
**Scope:** Change the next-prestige-gate formula in both runtimes from
`route_earnings × GROWTH` to `previous_gate × GROWTH`, so how far a player overshoots
the current gate no longer inflates the next one. Growth constant is validated by sim
and left at 8.0 unless the lab proves B-alone still walls.

## Problem

The prestige gate is the mid/late-game wall. Sim evidence (this session):

- First prestige lands ~40–65 min; a second prestige is effectively unreachable in a
  normal session, and lowering `PRESTIGE_EARNINGS_GROWTH` from 8.0 → 3.0 barely changed
  long-horizon progression (final Influence at 300 min: 137 vs 137 vs 146 for 2.5/3.0/3.5).
  Growth is the weak lever.
- Root cause is the formula, not the constant. Both runtimes compute the next gate as
  `prestige_route_earnings × GROWTH` (Godot `game_state.gd:769`, pygame
  `src/prestige.py:457`). Idle players overshoot the gate heavily — they keep earning
  while deciding to prestige — so `route_earnings` can be 5–10× the gate just crossed.
  That overshoot term dominates the constant:

  | Crossed 50M gate, earned 300M before pressing | Next gate |
  |---|---|
  | Current `300M × 8` | 2.4B |
  | Formula fix `50M × 8` | 400M |
  | Formula fix `50M × 3` | 150M |

  Punishing a strong run with a disproportionately larger next wall is the bug.

## The fix (B)

Base the next gate on the **gate that was just satisfied**, not on how much was earned:

`next_prestige_earnings = previous_gate × PRESTIGE_EARNINGS_GROWTH`

where `previous_gate` is `prestige_earnings_required(prestige_count, next_prestige_earnings)`
evaluated **before** `prestige_count` is incremented (so the first prestige uses
`FIRST_PRESTIGE_EARNINGS`, subsequent ones use the current `next_prestige_earnings`). The
gate becomes a clean geometric ladder anchored at `FIRST_PRESTIGE_EARNINGS`, independent
of overshoot.

### Godot — `godot/scripts/autoload/game_state.gd`

In `do_prestige()`, capture the prior gate at the top (before `prestige_count += 1` at
line 768), then at line 769 replace:

```gdscript
next_prestige_earnings = prestige_route_earnings * GameConfig.PRESTIGE_EARNINGS_GROWTH
```

with `previous_gate * GameConfig.PRESTIGE_EARNINGS_GROWTH`, using
`Prestige.prestige_earnings_required(prestige_count, next_prestige_earnings)` captured
pre-increment.

### pygame — `src/prestige.py`

In the prestige routine, capture the prior gate before `state._prestige_count += 1`
(line 444), then at line 457 replace `prestige_route_earnings(state) * PRESTIGE_EARNINGS_GROWTH`
with `previous_gate * PRESTIGE_EARNINGS_GROWTH`.

## Growth constant (A — NOT changed on spec)

`PRESTIGE_EARNINGS_GROWTH` stays **8.0** in both `game_config.gd:27` and
`src/prestige.py:53`. The sim sweep will confirm B-alone-at-8.0 gives a readable cadence
(target: each prestige reachable, cadence stretching gently rather than walling). Only if
the lab proves 8.0 still walls will a lower value be proposed — reported back to the owner
as a separate decision, not silently bundled in.

## Validation (sims-first, per CLAUDE.md)

1. Fix `sim_prestige_strategies.py`'s per-prestige timestamp reporting — the P2/P3
   columns and cadence-gap table are currently blank despite prestiges occurring (final
   Influence of 137 with 12 at P1 proves ~10 prestiges happened). Without this the
   cadence is unmeasurable.
2. With the reporting fixed and the B formula in pygame, run the strategy sim at a long
   horizon (≥300 min) and read the real P1→P2→P3 gaps at growth 8.0.
3. Acceptance: P2 and P3 are reached within a long-but-finite session, and the gap
   between consecutive prestiges grows gently (a stretch, not a cliff). If not met at
   8.0, report the growth value that does meet it.
4. Port the (validated) formula to Godot; `shell_smoke` PASS; a Godot prestige in the
   live shell produces a next-gate value equal to `previous_gate × 8`, not
   `route_earnings × 8`.

## Save compatibility

`next_prestige_earnings` already persists (both runtimes). The change only affects how the
*next* value is computed at prestige time. Old saves keep their current stored gate and
pick up the geometric ladder on their next prestige — no migration, no field added.

## Out of scope

- Lowering `PRESTIGE_EARNINGS_GROWTH` (A) unless step 3 forces it.
- Post-prestige reset design (hard wipe stays — Phase 20).
- Influence-gain / mastery / perk-tree tuning.
- Any UI change to the gate bar (it reads `prestige_earnings_required`, which is
  unchanged).
