# Phase 113 — Mid-Tier Manager Implementation

**Date:** 2026-06-15  
**Scope:** The Mechanic, The Collector, Clean Carl — Phase 108 behaviors.

---

## 1. What each manager removes

| Manager | Before (P112) | After (P113) | Player stops… |
|---------|---------------|--------------|---------------|
| **The Mechanic** | Income mult only | Auto-buys Chop Shop at 2× buffer | Manually buying Chop Shops |
| **The Collector** | −35% invisible raid math | Shield absorbs 1st raid / 5 min | Panic-checking after every raid |
| **Clean Carl** | −30% heat gain only | Forecast + 1 free 60% dump / run | Babysitting heat toward 60% |

---

## 2. Behavior metrics — all profiles

| Profile | Prestige | Mechanic hire | Mech auto-buys | Chop manual post-mech | Collector hire | Raids absorbed | Carl hire | Carl emergency | Heat ≥55s pre/post Carl |
|---------|----------|---------------|----------------|----------------------|----------------|----------------|-----------|----------------|-------------------------|
| CASUAL | 51m06s | 34m13s | 18 | 0 | 13m05s | 6 | 41m33s | 1 | 1378s / 283s |
| ENGAGED | 31m32s | 18m12s | 9 | 0 | 7m33s | 4 | 23m09s | 1 | 754s / 155s |
| OPTIMIZER | 18m22s | 11m02s | 9 | 0 | 11m01s | 2 | 15m14s | 1 | 303s / 55s |

---

## 3. ENGAGED before/after (P112 vs P113)

| Metric | Phase 112 | Phase 113 | Change |
|--------|-----------|-----------|--------|
| First prestige | 30m54s | 31m32s | +38s |
| Mechanic hired | 18m08s | 18m12s | — |
| Chop manual after Mechanic | all | **0** | delegated |
| Mechanic auto-buys | 0 | **9** | NEW |
| Raids fully absorbed | 0 | **4** | NEW |
| Carl emergency dumps | 0 | **1** | NEW |
| Heat ≥55s after Carl | N/A | **155s** | visible |
| Raid damage taken | baseline | **$7,336,308** | — |
| Manual buys (last 5 min) | 40 | 19 | -21 |

### Success question — after hiring each manager, what did the player stop doing?

1. **The Collector** (~7m33s): stop fearing the **first raid** in each 5-minute window — **4** fully absorbed this run.
2. **The Mechanic** (~18m12s): stop manually buying **Chop Shops** — **9** auto-buys, **0** manual.
3. **Clean Carl** (~23m09s): stop **watching heat constantly** — forecast in header + **1** emergency dump; **155s** above 55% post-hire vs **754s** pre-hire.

**Verdict:** All three mid-tier managers now change player actions, not just stats.

---

## 4. Remaining friction

- No major regressions detected.

**Next highest-priority problem:**

**Late-tier manager identity** — Maxine (synergy), Promoter (heat autopilot), Smuggler
(ops queue), Broker (turf intel), and Consigliere (prestige advisory) remain stat sticks.
Mid-tier bridge is complete; next bottleneck is making **late managers** change Turf/Ops/Prestige tabs.

---

## 5. Re-run

```powershell
python _measure_p113.py
```
