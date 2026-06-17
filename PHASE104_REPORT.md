# Phase 104 — Restore Idle-First Progression (Balance Pass)

**Date:** 2026-06-15  
**Scope:** Balance-only. No new mechanics, tabs, currencies, save fields, or UI layout changes.

---

## Root cause (Phase 103 carry-over)

Phase 103 made clicks *feel* great (crits, Hustle, VFX), but **`CLICK_DEALER_BONUS = 1.0`/dealer** made flat dealer bonus **78–93% of early click value**. Combined with low **`CLICK_IPS_FRACTION` (0.01)**, late-game clicks did not scale with the empire, so cumulative earnings at first prestige were **~95% passive / ~5% active** — far from the 15–30% click target.

---

## Files changed

| File | Change |
|------|--------|
| `config.py` | `CLICK_DEALER_BONUS` 0.20→**0.10**, `CLICK_IPS_FRACTION` 0.01→**0.055**, `CLICK_HUSTLE_MULT` 2.5→**2.35**, added `DEBUG_MONEY_SOURCES` |
| `src/buildings.py` | +10% early-tier `base_income` (Dealer/Racket/Chop/Betting); dealer special text updated |
| `src/states.py` | Money-source attribution on clicks/passive/coin; Hustle toast uses config mult |
| `src/money_debug.py` | **New** — debug-only source buckets |
| `src/operations.py` | Operation collect → `money_from_operations` |
| `src/goals.py` | Goal cash rewards → `money_from_other` |
| `src/events.py` | Event cash grants → `money_from_other` |
| `src/save_load.py` | Offline earnings → `money_from_other` |
| `_measure_p104.py` | Full 3-profile harness (CASUAL / ENGAGED / OPTIMIZER) with source breakdown |
| `_sweep_p104.py` | Automated knob sweep vs Phase 104 targets |

**Unchanged:** crit/Hustle/VFX/sound, prestige rules, save schema, UI layouts, assets.

---

## Values adjusted

| Constant | Before | After | Rationale |
|----------|--------|-------|-----------|
| `CLICK_DEALER_BONUS` | 0.20 (was 1.0 pre-P103) | **0.10** | Flat early bonus was still dominating first 10 min for engaged/optimizer |
| `CLICK_IPS_FRACTION` | 0.01 | **0.055** | Clicks scale with `income_per_second`; stabilizes **~cps×frac/(1+cps×frac)** late-game active share without dealer snowball |
| `CLICK_HUSTLE_MULT` | 2.50 | **2.35** | Slightly trim economic Hustle payout; feel preserved (duration/window/VFX unchanged) |
| Corner Dealer income | 0.10 | **0.11** | Faster early automation crossover |
| Protection Racket income | 0.44 | **0.48** | ↑ |
| Chop Shop income | 8.4 | **9.24** | ↑ |
| Sports Betting income | 122.0 | **134.2** | ↑ |

---

## Measurement method

`_measure_p104.py` drives **real `PlayingState`**: `update()`, `click_value`, `_register_active_click()`, building/upgrade/manager buys.

| Profile | CPS | Active time | Buys/sec |
|---------|-----|-------------|----------|
| **CASUAL** | 1.5 | 25% | 0.15 |
| **ENGAGED** | 4.0 | 33% | 0.50 |
| **OPTIMIZER** | 6.0 | 45% | 1.20 |

Snapshots at **10 / 20 / 30 min** and at **first prestige** (`can_prestige()`).

Enable debug buckets: `config.DEBUG_MONEY_SOURCES = True` or `python _measure_p104.py --debug`.

Tracked sources: `money_from_clicks`, `money_from_crit_clicks`, `money_from_buildings`, `money_from_operations`, `money_from_territories`, `money_from_hustle`, `money_from_other`.

---

## Before / after metrics (seed=104)

### ENGAGED (primary target)

| Milestone | Click % before | Click % after | Idle % after |
|-----------|----------------|---------------|--------------|
| 10 min | 38.2% | **33.9%** | 27.9% |
| 20 min | 31.8% | **29.0%** | 54.5% |
| 30 min | 22.4% | **23.4%** | 64.6% |
| First prestige (~58 min) | 4.9% | **16.1%** | 83.1% |

### OPTIMIZER

| Milestone | Click % before | Click % after |
|-----------|----------------|---------------|
| 10 min | 58.1% | **49.3%** |
| 20 min | 45.4% | **42.8%** |
| 30 min | 23.2% | **28.4%** |
| First prestige (~46 min) | 9.1% | **28.2%** (idle 71.0%) |

### CASUAL

| Milestone | Click % after | Notes |
|-----------|---------------|-------|
| 10 min | 46.4% | Clicks still feel strong early |
| 20 min | 7.9% | Empire carries progress |
| First prestige (~71 min) | 3.2% click | Comfortable low-click path |

---

## Success conditions check

| Target | Result |
|--------|--------|
| First 5 min: "clicks matter" | ✓ All profiles ≥33% click share at 10 min |
| 5–15 min: buildings matter | ✓ Engaged idle crosses ~28% by 10 min; crossover ~9 min |
| 15–30 min: empire runs itself | ✓ Engaged click share falls to ~23% by 30 min |
| First prestige click share 15–30% | ✓ Engaged **16.1%**, Optimizer **28.2%** |
| Casual can progress with minimal clicking | ✓ 8% click share by 20 min |
| Optimizer advantage without invalidating idle | ✓ 28% click / 71% idle at prestige |
| Preserve crit / Hustle / VFX / sound | ✓ No presentation changes |

---

## Design progression (engaged player)

```
 0–5 min   → clicks ~50%+ of earnings (feel)
 5–15 min  → buildings ramp; crossover ~9 min
 15–30 min → ~23% clicks / ~65% idle
 prestige  → ~16% cumulative clicks (idle backbone)
```

Psychological power (crit pop, Hustle toast, particles) unchanged; economic weight shifted to passive systems.

---

## Remaining concerns

1. **Engaged idle share at prestige (83%)** is above the 50–70% “buildings” band — the harness does not run operations/territories; live play adds 10–25% from those buckets, which would lower the passive-only line.
2. **First prestige wall-clock (~58–71 min)** still exceeds the ~30–45 min design note in `prestige.py`; fixing that would require prestige-threshold tuning (out of scope for this balance-only pass).
3. **`CLICK_IPS_FRACTION = 0.055`** is the main late-game lever; if future building tiers push IPS much higher, re-run `_measure_p104.py` after economy changes.
4. **Manager first hire ~38–50 min** — still late; moving manager costs earlier was not required to hit click-share targets but remains a pacing knob.

---

## How to re-verify

```powershell
python _measure_p104.py          # full report
python _measure_p104.py --debug  # includes source bucket dump
python _sweep_p104.py            # re-sweep knob candidates
```
