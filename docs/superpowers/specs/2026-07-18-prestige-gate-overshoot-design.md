# Prestige Gate — De-Punish the Overshoot — Design

**Date:** 2026-07-18
**Status:** Approved (owner, this session — "B only")
**Scope:** Change the next-prestige-gate formula in both runtimes from
`route_earnings × GROWTH` to `previous_gate × GROWTH`, so how far a player overshoots
the current gate no longer inflates the next one. Growth constant is validated by sim
and left at 8.0 unless the lab proves B-alone still walls.

## Problem

The prestige gate is the mid/late-game wall. Sim evidence (this session):

- First prestige lands ~40–65 min; a **second prestige never occurs** even over a
  300-minute run, at any growth value swept (2.5 / 3.0 / 3.5). The strategy sim's blank
  P2/P3 columns are correct — only one prestige happens. (The final Influence of ~137 is
  NOT many prestiges: `prestige_tokens` is also minted by non-prestige faucets — goals
  `src/goals.py:262`, operations `:252`, rivals `:572+`, buildings `:282`, events, dragon
  — so tokens climb ~12 → 137 across the run on one real prestige plus faucet income.)
- Lowering `PRESTIGE_EARNINGS_GROWTH` from 8.0 → 2.5 did not make P2 reachable, so growth
  is the weak lever.
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

## Validation (sims-first, per CLAUDE.md) — FINDINGS

**The "P2 never lands" wall was a sim artifact, not a game balance bug.**
`sim_prestige_strategies.py` never selected a prestige branch, so the count≥1 branch
requirement in `check_requirements` was unsatisfiable and NO second prestige could ever
fire — at any growth value, with or without B. Real players (and Godot) pick a branch via
the prestige-tree UI, so they already reach P2+. Growth 8.0 is fine and is NOT changed.

Fix applied to the lab: model branch commitment + first-perk purchase after each prestige
(`sim_prestige_strategies.py`, Kingpin branch). With that, at growth 8.0 **and** the B
formula, cadence is healthy: P1 ~47–58 min, then P1→P2 ~10–15 min, stabilizing at ~13–27
min gaps that grow gently (no cliff); final Influence ~650–800 over 300 min.

B's own effect is invisible in this sim because the sim auto-prestiges the instant it is
eligible (route ≈ gate, ~zero overshoot). B is a **fairness fix for real play**: a player
who banks earnings well past the gate before pressing prestige would otherwise get a next
gate of `route × 8` instead of `gate × 8`. That behavior change is proven by the unit test
`tests/test_prestige_gate.py` (9× overshoot → next gate 800M, not 7.2B).

Remaining step: port the formula to Godot for parity; `shell_smoke` PASS; a Godot prestige
produces `previous_gate × 8`, not `route_earnings × 8` (headless probe, see plan).

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
