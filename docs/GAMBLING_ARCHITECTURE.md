# Active Gambling — "Luck Wheel" Architecture

> Skill/timing minigame whose only faucet is the **daily-return engagement hook**.
> Designed so it can **never become the dominant activity** (see §3).

## 1. Layering (follows the existing Godot port conventions)

| Concern | Location | Mirrors |
|---|---|---|
| Pure model — segments, payout, grant rules, resolve | `scripts/systems/gambling_system.gd` (RefCounted, static) | `operation_system.gd` |
| Feature flag + high-level tuning | `scripts/autoload/game_config.gd` → `GAMBLING_ENABLED` | existing config block |
| Runtime container | `GameState.gambling: Dictionary` | `GameState.operations` |
| make / merge / to_save | `GamblingSystem.*` | `OperationSystem.*_save` |
| Daily grant | `GameState._apply_daily_reward()` → `grant_daily_spins()` | single once/day date gate |
| Player actions | `GameState.start_gamble_round()` / `resolve_gamble()` / `grant_gamble_ad_spin()` | `start/collect_operation` |
| `SWEEP_SPEED` + all economy knobs | `gambling_system.gd` (single source) | `gambling_wheel.gd` reads `SWEEP_SPEED` |
| View | `scenes/gambling_overlay.tscn` + `scripts/ui/gambling_overlay.gd` | `prestige_tree_overlay`, Phase 92 modal rules |

**State lifecycle:** `gambling` is account-level engagement state (banked spins, lifetime
stats). It resets on **new game** and **survives prestige** — it is intentionally *not*
wiped in `do_prestige()`, unlike run systems (operations/crew/territory).

## 2. Core loop

1. Daily login (the existing once-per-day `_apply_daily_reward` gate) banks 1 free spin
   (2 at a maxed 7-day streak), capped at 5 banked.
2. Player opens the Luck Wheel overlay → `start_gamble_round()` shuffles the segment ring
   (Fisher–Yates) so the jackpot band moves every spin → returns layout to the UI.
3. A marker sweeps the ring; the player taps to stop it (**skill = timing**).
4. `resolve_gamble(position)` maps the stop position → segment → multiplier, pays out
   `base_stake × multiplier`, and consumes one spin.
5. `base_stake = max(50, income_per_second × 90s)` — payout is **income-scaled**.

## 3. Anti-cannibalization — why it can't become "the only thing to do"

The risk is real: an active variable-reward minigame is the most compulsive structure in
games. Six structural defenses, most already enforced in code:

| # | Lever | Status | Mechanism |
|---|---|---|---|
| 1 | **Rate-limited faucet** | ✅ enforced | Spins come *only* from the daily login (1–2/day, cap 5). It is not grindable — you physically cannot play more than your banked spins. This is the #1 defense. |
| 2 | **Income-scaled payout** | ✅ enforced | `base_stake ∝ income_per_second`. Gambling is a *multiplier on progress you already made*, never an alternative income source. A neglected empire gets tiny spins, so you must play the core loop to make gambling worth anything. |
| 3 | **Insulated from the prestige gate** | ✅ enforced | Winnings add to `balance`/`lifetime_earnings` but **not** `prestige_route_earnings`. You cannot gamble your way to prestige faster. |
| 4 | **No wager, no loss** | ✅ by design | Worst outcome is 0× (a spent free spin), never a cash loss. Removes loss-chasing — the engine of compulsive gambling. No sunk cost, no tilt. |
| 5 | **Skill, not pure slot RNG** | ✅ by design | Timing-based outcome avoids the dissociative variable-ratio "zone," and is far safer for app-store / loot-box-regulation posture. |
| 6 | **It's a moment, not a session** | ✅ by format | A spin is ~5s; 1–2/day = seconds of gambling per day. The format itself cannot fill a play session. |

**Tuning (G-TUNE-1, validated in `sim_gambling.py`):** all knobs live in
`gambling_system.gd` (`SWEEP_SPEED` included — UI reads from there). With
`SWEEP_SPEED = 1.7` and the 16-segment ring (mean 1.375×, single 10× band),
measured per-spin EV is ~1.38× random / ~2.14× skilled / ~3.0× expert (60ms
jitter). Daily faucet at 2 login spins/day: random **0.58%**, skilled **0.89%**
of 12h offline cap; bot worst case **4.17%** (PASS). Login + ad (3 spins/day):
bot **6.25%** (FAIL on paper — human expert **1.87%**; ad spin stays capped at
`FREE_SPIN_CAP`). Vs daily login reward at streak 7: skilled gambling ≈ **37%**
of streak payout — side dish, not main course.

```powershell
python sim_gambling.py
python sim_gambling.py --compare-daily-reward
python sim_gambling.py --sweep-speed 2.0
```

**Telemetry:** `gamble_spin_resolve` logs `lifetime_winnings_ratio`
(`lifetime_winnings / lifetime_earnings`). Tripwire: ratio > **8%** over 7 days →
lower `BASE_INCOME_SECONDS` by 10–15. Also watch `best_mult` and spins/session.

**Monetization caution:** the rewarded-ad `+1 spin` hook is capped at `FREE_SPIN_CAP`.
Selling *uncapped* spins would break levers 1 and 6 — keep any ad/IAP spin source
rate-limited. The whole safety model rests on supply scarcity.

**Inverse failure mode:** don't starve it so hard nobody engages. Per-spin payout should
*feel* generous (income-scaled + a visible 10× jackpot band); scarcity comes from supply,
not from stingy payouts.

## 4. View contract (TODO — `gambling_overlay.gd`)

A modal `Control` following Phase 92 rules (`modal_panel_rect`, `blit_fit_center`,
clamp at small/large res). Responsibilities:

- On open: `var segs = GameState.start_gamble_round()`; if `segs.is_empty()`, show
  "No spins — come back tomorrow" + (optional) watch-ad-for-spin button.
- Drive marker sweep in `_process` (normalized position 0→1 looping). Faster sweep = harder.
- On tap: capture position, call `GameState.resolve_gamble(position)`, display the returned
  result string, then offer "Spin again" if `GameState.gambling_free_spins() > 0`.
- Entry points: (a) the daily/offline **return overlay** ("You earned a free spin!"),
  using `GameState.gambling_spins_granted`; (b) a persistent HUD chip / Turf subtab that
  shows the banked-spin count and is dimmed at 0.
