# Active Gambling — "Luck Wheel" Architecture

> Two modes on one wheel:
> 1. **Free daily spin** (§1–4) — skill/timing, positive-EV, **no cash loss**; faucet is the daily-return hook.
> 2. **Cash-wager casino** (§5) — stake real balance, **can lose it**; a deliberate cash *sink* whose safety comes from a structural **house edge** (RTP < 1), not from supply scarcity.
>
> The free spin can never become dominant (§3). The casino can be played anytime with
> unlimited stakes; it is safe because the house always wins long-run — see §5.

## 1. Layering (follows the existing Godot port conventions)

| Concern | Location | Mirrors |
|---|---|---|
| Pure model — segments, payout, grant rules, resolve | `scripts/systems/gambling_system.gd` (RefCounted, static) | `operation_system.gd` |
| Feature flag + high-level tuning | `scripts/autoload/game_config.gd` → `GAMBLING_ENABLED` | existing config block |
| Runtime container | `GameState.gambling: Dictionary` | `GameState.operations` |
| make / merge / to_save | `GamblingSystem.*` | `OperationSystem.*_save` |
| Daily grant | `GameState._apply_daily_reward()` → `grant_daily_spins()` | single once/day date gate |
| Player actions | `GameState.start_gamble_round()` / `resolve_gamble()` / `grant_gamble_ad_spin()` | `start/collect_operation` |
| Rewarded-ad spin | `gambling_overlay` → `Monetization.show_rewarded(PLACEMENT_GAMBLE_SPIN)` → `_on_ad_rewarded` → `grant_gamble_ad_spin()` | `PLACEMENT_OFFLINE_DOUBLE` / `PLACEMENT_FREE_COIN` |
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
| 1 | **Rate-limited faucet** | ✅ enforced | Spins come from the daily login (1–2/day) plus an optional rewarded-ad +1, all clamped to `FREE_SPIN_CAP` (5). It is not grindable — you physically cannot play more than your banked spins, and the ad spin is capped at the same ceiling. This is the #1 defense. |
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

**Guardrail decision (G-TUNE-2):** the login+ad **6.25% bot worst case** is
**accepted as-shipped** — no `BASE_INCOME_SECONDS` cut. Rationale: it requires 0ms-perfect
timing (physically impossible; human expert at 60ms jitter = **1.88%**), the ad spin is
already clamped to `FREE_SPIN_CAP`, and the "inverse failure mode" below warns that
scarcity must come from *supply*, not stingy payouts — trimming would tax every real
player to defend against a supply-capped theoretical bot. The live `lifetime_winnings_ratio`
tripwire (>8% / 7 days) is the governor: only real-world data reopens this, not the paper bot.

**Monetization caution:** the rewarded-ad `+1 spin` hook routes through the
`Monetization` autoload (`PLACEMENT_GAMBLE_SPIN`), which grants via
`grant_gamble_ad_spin()` — capped at `FREE_SPIN_CAP`. Selling *uncapped* spins would
break levers 1 and 6 — keep any ad/IAP spin source rate-limited. The whole safety
model rests on supply scarcity. The `sim_gambling.py` login+ad (3 spins/day) scenario
shows a **6.25% bot worst case** (over the 5% guardrail on paper); the cap + human
timing keep it safe in practice, but the tripwire in **Telemetry** below governs it.

**Inverse failure mode:** don't starve it so hard nobody engages. Per-spin payout should
*feel* generous (income-scaled + a visible 10× jackpot band); scarcity comes from supply,
not from stingy payouts.

## 4. View (as built — `gambling_overlay.tscn` + `gambling_overlay.gd`)

A `CanvasLayer` overlay (layer 11) matching the shipped `prestige_tree_overlay` /
`dragon_patron_overlay` pattern: a full-screen `Dim` + a centred `PanelContainer`.

- On open: `start_round` is staged; the `Wheel` (`gambling_wheel.gd`) renders the
  shuffled segment ring. SPIN starts the marker sweep (button → STOP); STOP freezes the
  marker and calls `resolve_gamble(position)`. "Spin again" is offered while
  `gambling_free_spins() > 0`; at 0 the CTA disables and a capped watch-ad-for-spin button
  shows (hidden when `remove_ads` is owned or already at `FREE_SPIN_CAP`). It calls
  `Monetization.show_rewarded(PLACEMENT_GAMBLE_SPIN)`; the reward returns via the
  `ad_reward_granted` signal → `_on_ad_reward()` re-stages the round. The MockBackend
  grants instantly in editor/headless, so the flow is fully testable without a device.
- `gambling_wheel.gd` reads `GamblingSystem.SWEEP_SPEED` and animates a normalised
  position 0→1 in `_process`; the segment under the needle is exactly what `resolve_gamble`
  scores (WYSIWYG, no hidden RNG).
- Entry points: (a) a **header 🎰 chip** with a live banked-spin badge in `game_screen.gd`
  (hidden when `GAMBLING_ENABLED` is false); (b) a **"Spin now" CTA on the daily/offline
  return overlay**, shown when `gambling_spins_granted > 0`.

**Resolution safety:** no clamp/scroll code is needed. The project's `canvas_items` stretch
+ `expand` aspect (720×1280 base) keeps the logical viewport ≥ the base size, so the 680×520
panel can never clip; `grow_vertical = 2` lets it expand from centre if the 125% accessibility
text scale grows content past the design height. (The pygame `modal_panel_rect`/`blit_fit_center`
helpers from the Phase 92 prototype work do **not** exist — and are not needed — in the Godot port.)

## 5. Cash-wager casino (as built — `resolve_wager` + overlay BET path)

The casino shares the wheel but is a different beast from the free spin: you **stake real
balance and can lose it**. It exists as a deliberate **cash sink**. Its entire safety model
is one invariant, not the six free-spin levers:

> **Expected value < 1× at every skill level — the house always keeps an edge.**

**How the edge can't leak (the key design trick).** Payout is
`stake × band × RTP(skill)`, split into two independent parts:

| Part | Source | Property |
|---|---|---|
| **Band** (variance / jackpot) | RNG draw over `WAGER_BANDS` weighted by `WAGER_WEIGHTS` | Mean is pinned to **exactly 1.0** (`Σ band·weight = 1.0`), so the segment RNG contributes **zero** net EV — it only adds spread. |
| **RTP** (the house edge) | `wager_rtp(s) = WAGER_RTP_BASE + WAGER_RTP_SKILL·s` | `0.80` (random) … `0.97` (perfect timing). **Capped below 1**, so EV = 1.0 × RTP(s) = RTP(s) < 1 always. |

Because EV is `1.0 × RTP(s)`, **skill nudges the odds but can never flip them** — even a
0ms-perfect bot bleeds ~3%/wager. This is why "unlimited stakes" is safe: there is no
aim-the-jackpot exploit (timing sets RTP, **not** which band you draw), and no positive-EV
grind. Winnings still feed `balance`/`lifetime_earnings` but **not** `prestige_route_earnings`.

**Validated** (`sim_gambling.py --wager`, mirrored + re-checked in-engine via
`scripts/tools/wager_probe.gd`):

```
profile              EV(x)   house edge
random tap           0.816     18.4%
expert (60ms)        0.873     12.7%
perfect bot (0ms)    0.971      2.9%   ← worst case, still < 1.0 → PASS
```

~83% of wagers return less than the stake — the mathematical consequence of a mean-1.0
shape with a fat 25× jackpot tail (bigger jackpot ⇒ more frequent small losses). That's a
**feel** knob (`WAGER_WEIGHTS` / `WAGER_JACKPOT`), not a safety one; retune freely as long as
`Σ band·weight` stays 1.0.

**View / flow.** The overlay's `BetRow` (¼ / ½ / Max presets) sets `_stake`; **BET $X** stages
a round via `start_wager_round()` (rolls a random sweet-spot). The wheel switches to
**skill-meter mode** (`set_sweet_spot`) — a dim track with a graded AIM zone, *not* a payout
ring, so it never implies an outcome. STOP → `place_wager(position, stake)` → `resolve_wager`
debits the stake, draws the band, scales by RTP(timing), credits the payout; a loss is shown
in red. **Telemetry:** `gamble_wager_resolve` logs `lifetime_wager_net_ratio` (net / wagered)
— expected negative; a *positive* trend means the edge is broken and is a hard tripwire.

**Save:** `lifetime_wagered` + `lifetime_wager_net` (survive prestige, migrate via
`merge_save_gambling`); `wager_sweet_spot` is runtime-only.
