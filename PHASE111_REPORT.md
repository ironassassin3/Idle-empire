# Phase 111 — Manager Access Implementation

**Date:** 2026-06-15  
**Change:** Phase 110 acquisition model — milestone unlocks + payroll fees
(early tier), rank gates + premium costs (late tier). No new save fields.

---

## 1. Implementation summary

| Tier | Managers | Unlock | Cost |
|------|----------|--------|------|
| Early (0–5) | Pete → Accountant | Computed milestones | $3K–$65K payroll |
| Late (6–10) | Maxine → Consigliere | Rank gate | Premium cash (unchanged) |

| Manager | Unlock | Payroll |
|---------|--------|---------|
| Sticky Pete | $25K lifetime | $3K |
| The Collector | 3 Rackets | $10K |
| The Mechanic | 2 Chop Shops | $8K |
| Lucky Sal | $25K lifetime OR 1 Betting Ring | $4K |
| Clean Carl | Heat 40% or 80 heat generated | $50K |
| The Accountant | $200K lifetime OR 4 building types | $65K |

**Late rank gates:** Capo · Underboss · Boss · Crime Lord · Kingpin.

Phase 106 cash nudges removed; unlock milestones via `tick_unlock_milestones`.
Phase 109 behavior hooks preserved.

---

## 2. Before / after — hire times (greedy buyer, no reserving)

| Manager | Phase 107 (old cash) | Phase 111 unlock | Phase 111 hired |
|---------|---------------------|------------------|-----------------|
| Sticky Pete | 38m33s | 11m50s | 11m50s |
| Lucky Sal | NEVER | 11m50s | 11m50s |
| The Mechanic | NEVER | 13m04s | 20m03s |
| The Accountant | NEVER | 21m57s | 27m25s |

### All profiles — Phase 111 hires

| Profile | Pete | Sal | Mechanic | Accountant | Prestige |
|---------|------|-----|----------|------------|----------|
| CASUAL | 32m19s | 36m23s | 37m56s | 44m12s | 51m09s |
| ENGAGED | 11m50s | 11m50s | 20m03s | 27m25s | 31m01s |
| OPTIMIZER | 11m43s | 14m07s | 14m21s | 21m39s | 28m23s |

---

## 3. ENGAGED success criteria (target windows)

| Manager | Target | Unlock | Hired | Verdict |
|---------|--------|--------|-------|---------|
| Sticky Pete | 10–20 min | 11m50s | 11m50s | OK |
| Lucky Sal | 10–20 min | 11m50s | 11m50s | OK |
| The Mechanic | 17–25 min | 13m04s | 20m03s | OK |
| The Accountant | 20–35 min | 21m57s | 27m25s | OK |

---

## 4. Manual actions removed (ENGAGED, full run)

- **Golden coins expired:** 13 (Sal auto-collect after hire)
- **Sal auto-collects:** 24
- **Pete on-pick buys** (if Pete hired): 0

**What players stop doing:** guessing building ROI (Pete), chasing coins (Sal),
banking $40K–$2M for managers (payroll fees fit between building buys).

---

## 5. Full hire order (ENGAGED)

Sticky Pete → Lucky Sal → The Collector → The Mechanic → Clean Carl → The Accountant

---

## 6. Remaining concerns

- ENGAGED targets met under greedy sim without reserving or Phase 106 nudges.
- Greedy sim auto-hires when payroll affordable — real players must open Managers tab once; unlock milestones prompt this.
- Late managers (6–10) still require Capo+ rank and premium cash — unchanged by design for post-prestige runs.

---

## 7. Re-run

```powershell
python _measure_p111.py
```
