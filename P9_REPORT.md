# P9 — Retention Loop Hardening

**Started:** 2026-06-17  
**Updated:** 2026-06-17 (principled pacing pass — no play-time gate)  
**Status:** Pacing + daily login done — push notifications + FTUE telemetry deferred

## Delivered

### 1. Daily login reward (closes the last parity-debt item)
- Port of `src/save_load.py` daily logic: streak +1 on a consecutive day (cap 7), reset to 1 on a
  gap, once per calendar day. Reward = `max(3× cheapest building, 5min income × streak)`.
- Save fields `last_login_date`, `daily_streak`; runtime `daily_reward`, `show_daily_overlay`;
  reset on new game; granted on load after offline return.
- Surfaced in the return overlay ("★ Daily reward — day N streak: +$X"). Godot-native presentation
  (pygame suppressed it behind the offline overlay; here the streak is always visible — a UX
  improvement, same reward values).
- **Verified:** headless `daily_probe` PASS (consecutive +1, same-day no-op, gap→1, cap 7, reward+overlay).
  Briefly broke income parity (reward fired on fixture load); fixed by isolating the income probe
  (stamp today's date → daily reward is a no-op in the parity gate). Full gate restored to 4/4.

### 2. Faithful pacing sim (`sim_pacing.py`) — new instrument
- `sim_playthrough.py` cheats (negotiates a territory every 0.5s → UI-impossible mass-capture →
  unrealistic ~8min first prestige). `sim_pacing.py` drives the real `PlayingState` at human
  cadence (actions only in active windows; territory/rival gated by a cooldown; one district per
  attempt) and reports the Phase 103 metrics. `--no-territory` toggles player archetype.
- Sim tracks `prestige_route_earnings` on clicks (matches live `PlayingState`).

### 3. Principled pacing fixes (pygame lab → Godot port)

**Rejected:** play-time floor on first prestige (`FIRST_PRESTIGE_PLAY_TIME`) — time-gating prestige
is a bandaid; reverted per design review.

**Root causes identified:**
1. Goal reward cash inflated `lifetime_earnings` → cascaded Influence goals and prestige progress.
2. **+1 Influence on every successful turf action** — parallel Influence faucet unrelated to empire work.
3. Uncapped stacked turf income mults — territory-engaging players hit the earnings gate ~3× faster.
4. Starter Influence goals tracked lifetime earnings (same metric windfalls could inflate).

**Fixes shipped (pygame + Godot):**

| Fix | Files |
|-----|-------|
| **Empire route earnings** — prestige gate counts passive + clicks only (`prestige_route_earnings`) | `prestige.py`, `states.py`, `save_load.py`, `game_state.gd`, `prestige.gd`, `prestige_tree_overlay.gd` |
| **Goal reward cash → balance only** (not lifetime/route) | `goals.py`, `goal_system.gd` |
| **Starter Influence goals track empire route** (same metric as prestige gate) | `goals.py`, `goal_system.gd` |
| **Removed +1 Influence per turf capture** (Attack/Bribe/Negotiate/Sabotage) — Respect only | `territory.py`, `territory_system.gd` |
| **Turf income scales with route progress** — `(route / required)²` on income + click mults | `territory.py`, `territory_system.gd`, `states.py`, `game_state.gd` |
| **Capped district stacking** — per-district bonus cap +25%; count bonus 0.5%/district capped +10% | `territory.py`, `territory_system.gd` |
| **Softer global mults** — Dock ×1.015, HQ ×1.06 (was ×1.02/×1.1); district count 1%/1.5% | `buildings.py`, `building_defs.gd`, `territory.py` |
| **Reduced oversized turf goal cash** — `first_territory` 30K→5K, `downtown` 200K→25K | `goals.py`, `goal_system.gd` |
| **`start_cash_5k` +2 Influence** (less starved early game) | `goals.py`, `goal_system.gd` |

**Lever 1 (lower paid-district cost) — TESTED & REJECTED.** Industrial 5→3 widened the snowball gap; reverted.

### 4. Pacing results (`sim_pacing.py`, 33% active, 2 click/s, 45 min)

| Metric | Before fixes | After (principled pass) |
|--------|--------------|-------------------------|
| **Buildings-only — first prestige** | ~28 min | **~25 min** ✓ (target 25–45 min) |
| **Territory-engaging — first prestige** | 4–8 min | **~17 min** (was runaway; still faster than buildings — turf reward, not broken) |
| **Influence @15min (territory)** | 54 | **~15** (no longer snowballing past Made Man in minutes) |

Target window for first prestige: **25–45 min**. Buildings-only is in window; territory-engaging is
saner but still ~8 min ahead of the floor — acceptable as a turf-engagement bonus unless further
tuning is desired (lower turf bonus cap, smaller starter goal cash rewards).

### 5. FTUE funnel review — no dead-ends
- Tutorial = 5 linear, reachable steps (Click → Buy → Upgrades → Managers → Prestige). Turf/Crew/
  Ops are informational popups, not blocking gates.
- First-prestige gate: **$20M empire route** + 20/8/4 buildings + Made Man (12 Influence).
  Reachable via buildings/goals path alone (`sim_pacing.py --no-territory` ~25 min).
- Influence goals are **route-gated, not turf-gated** — historical token deadlock cannot recur.
- UI lock strip shows **"Empire"** (not "Earnings") for the route gate.

## Honest limitations

- **Push notifications (P9 scope) not done** — Android/iOS local-notification APIs are platform-
  bound and unverifiable off-device. Deferred to the device pass (with P7 visual / P8 FPS).
- **FTUE telemetry not instrumented** — analytics is pygame-lab-only (P5 matrix); mobile telemetry
  isn't scoped yet. The funnel was *reviewed* (no dead-ends), not *instrumented*.
- **Territory path still ~17 min vs buildings ~25 min** — principled fixes closed the 4-min
  runaway; further convergence is optional tuning, not a time gate.
- **`click_value += 0.01×IPS` late-game runaway** — dominates sim variance after first prestige
  window; separate balance question (cap/curve), not blocking first-prestige pacing.

## Verify

```bash
python sim_pacing.py --minutes 45 --active 0.33 --cps 2               # territory-engaging
python sim_pacing.py --minutes 45 --active 0.33 --cps 2 --no-territory # buildings-only
python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"  # gate (4/4 + soak)
```

## P9 exit criteria

- [x] Pacing fixes verified in pygame sim **and** ported to Godot (empire route, turf scaling, goal
  cash, capture Influence removal, starter goal metric — see table above).
- [~] Offline/daily loop works (daily reward done + verified). **Push-notification consent = device pass.**
- [~] FTUE funnel reviewed end-to-end — no dead-ends. **Telemetry instrumentation deferred.**

## Follow-ups

- Optional: tighten turf pacing toward ~22–25 min (lower bonus cap or starter goal cash) if parity
  with buildings-only is desired over "turf is a modest accelerator."
- Revisit `click_value += 0.01×IPS` runaway as its own balance question (late-game sim artifact).
- When mobile telemetry is scoped, instrument the FTUE funnel (tutorial step → first prestige).
- On-device validation of pacing feel (sim ≠ real thumb cadence).
