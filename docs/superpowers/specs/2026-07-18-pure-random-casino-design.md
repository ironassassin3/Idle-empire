# Pure-Random Cash Casino — Design

**Date:** 2026-07-18
**Status:** Approved (owner, this session)
**Scope:** Remove the timing/skill "nudge" from the cash-wager casino so it is honest
RNG with a single fixed house edge. The free-spin Luck Wheel (already pure-skill) is
untouched.

## Context

Two gambling modes exist today:

- **Luck Wheel** (free spins from ads/daily) — *already pure skill*: the player stops a
  sweeping marker and the band is fully determined by where they stop. Positive-EV, no
  cash loss. **No change.**
- **Cash-wager casino** — the disliked hybrid: the outcome band is drawn by pure RNG, but
  the player's stop timing tweaks a return-to-player scalar `RTP(skill)` from 0.80
  (random timing) to 0.97 (perfect). Neither honest luck nor real skill.

Owner decision this session: make the cash casino **pure-random** with a single fixed RTP;
keep cash wagering (it is a wanted cash sink). Hard constraint retained: **in-game
currency only, never real money** ([[gambling_no_real_money]]).

## The change

The wheel shape is already fair: `Σ weights == 1` and `Σ band*weight == 1.0`, so the mean
multiplier is exactly 1.0 and the entire edge lives in the RTP scalar. Collapse
`RTP(skill)` to one constant.

### `godot/scripts/systems/gambling_system.gd`

- Add `const WAGER_RTP := 0.90` (10% house edge). Remove `WAGER_RTP_BASE`,
  `WAGER_RTP_SKILL`, `WAGER_SKILL_TOL`.
- Delete `wager_skill()`, `wager_rtp()`, and `roll_sweet_spot()`.
- `resolve_wager(state, stake, rng)` — drop the `position` parameter. Body becomes:
  `band = wager_draw_band(rng)` (unchanged), `mult = band * WAGER_RTP`, then the existing
  debit/credit/stats logic verbatim. Result dict drops `skill`/`rtp`... keep `rtp` in the
  dict as the constant (UI may show it) but remove `skill`.
- `make_gambling()` / `merge_save_gambling()`: `wager_sweet_spot` becomes vestigial —
  leave the key initialised to `-1.0` for save-shape stability, but nothing writes a real
  value. (No migration; lifetime stats unchanged.)

### `godot/scripts/autoload/game_state.gd`

- The `roll_sweet_spot` wrapper (line ~1313) is removed or repurposed: the overlay no
  longer stages a sweet spot. The wager entry point calls `resolve_wager(self, stake, _rng)`
  (line ~1319) without a position.

### UI — `gambling_wheel.gd` + `gambling_overlay.gd`

- **Cash-wager mode only:** remove the sweet-spot target band and the skill-meter
  rendering (`_sweet_spot`, `set_sweet_spot`, the target-band draw at lines ~104/146/149).
- Replace the timing input with a **SPIN** action: the marker auto-spins and animates to
  rest on the RNG-drawn band (outcome predetermined by `resolve_wager`; the animation is
  cosmetic reveal, not input). A losing/winning result reads honestly as luck.
- **Free-spin Luck Wheel mode:** unchanged — still the skill/timing stop.

### Sim — `sim_gambling.py`

- Update the `--wager` path: drop `_wager_skill`/skill-conditioned RTP; payout multiplier
  becomes `band(RNG) * WAGER_RTP`. The sim must still prove **EV == WAGER_RTP < 1** (house
  always wins long-run). This is the balance guardrail.
- pygame gameplay (`src/gambling.py`) has no cash-wager (free-spin only) → no change.

## Constraints

- In-game currency only; never real money.
- Wheel band shape + weights unchanged (mean stays 1.0); only the RTP scalar changes.
- Luck Wheel (free-spin, pure-skill) behavior byte-for-byte unchanged.
- No save migration; lifetime wager stats preserved.

## Verification

- `sim_gambling.py --wager`: measured long-run EV ≈ 0.90 (±noise), never > 1.0, at every
  simulated player behavior (there is no longer a skill axis to beat it).
- `shell_smoke` PASS.
- Headless/seeded gambling-overlay still: cash-wager mode shows a SPIN control and no
  sweet-spot target; free-spin mode still shows the skill marker.
- A resolved wager debits the stake and credits `stake * band * 0.90` (spot-check via a
  small headless probe or the overlay).

## Out of scope

- Luck Wheel changes. Band values/weights/jackpot retuning. New casino games. Any real-
  money or ad-reward-to-cash linkage.
