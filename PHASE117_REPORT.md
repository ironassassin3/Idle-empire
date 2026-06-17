# Phase 117 — Late Roster Visibility & Runway

**Date:** 2026-06-15  
**Scope:** UI visibility, rank progress on late cards, executive-team grouping,
minor rank-gate tuning (Smuggler → Underboss, Consigliere → Crime Lord).
No new managers or mechanics.

---

## 1. Changes shipped

| Area | Before (P116) | After (P117) |
|------|---------------|--------------|
| Late roster | All 5 late cards visible from first Mgrs visit | Hidden until **Made Man**; teaser row only |
| Locked late cost | Full premium ($30B–$2T) on card | **Rank progress bar** + "affordable when unlocked" |
| Grouping | Flat list | **STREET CREW** / **EXECUTIVE TEAM** sections; collapse toggle |
| Smuggler gate | Boss (75 Inf) | **Underboss (45 Inf)** |
| Consigliere gate | Kingpin (165 Inf) | **Crime Lord (115 Inf)** |

---

## 2. Visibility metrics — before vs after

| Profile | Metric | P116 baseline | P117 measured | Δ |
|---------|--------|---------------|---------------|---|
| CASUAL | Locked peeks (P116 metric) | 72 | 62 | 14% reduction |
| CASUAL | Locked view-sec (peeks×45) | 3240 | 2790 | 14% reduction |
| CASUAL | Locked card-sec (intensity) | — | 6930 | — |
| CASUAL | Cycle-1 teaser peeks | — | 25 | — |
| CASUAL | Cycle-1 locked peeks | — | 18 | — |
| ENGAGED | Locked peeks (P116 metric) | 89 | 60 | 33% reduction |
| ENGAGED | Locked view-sec (peeks×45) | 4005 | 2700 | 33% reduction |
| ENGAGED | Locked card-sec (intensity) | — | 5670 | — |
| ENGAGED | Cycle-1 teaser peeks | — | 17 | — |
| ENGAGED | Cycle-1 locked peeks | — | 10 | — |
| OPTIMIZER | Locked peeks (P116 metric) | 95 | 64 | 33% reduction |
| OPTIMIZER | Locked view-sec (peeks×45) | 4275 | 2880 | 33% reduction |
| OPTIMIZER | Locked card-sec (intensity) | — | 6570 | — |
| OPTIMIZER | Cycle-1 teaser peeks | — | 19 | — |
| OPTIMIZER | Cycle-1 locked peeks | — | 14 | — |

**ENGAGED longest locked streak:** 4005s → 2700s

---

## 3. Late manager acquisition (cycle 2 window)

| Manager | P116 ENGAGED | P117 ENGAGED |
|---------|--------------|--------------|
| Maxine the Dealer | 13m11s / hire 14m15s | unlock 10m03s, hire 11m28s, — |
| The Promoter | 15m20s / hire 16m10s | unlock 10m03s, hire 11m41s, — |
| The Smuggler | 20m00s / hire 20m00s (0s runway) | unlock 10m03s, hire 11m50s, — |
| The Broker | 18m40s / hire 19m30s | unlock 20m00s, hire 20m00s, — |
| The Consigliere | NEVER | unlock 28m43s, hire 28m43s, advice |

**Late hired before P2:** P116 **4/5** → P117 **5/5**
  
**Smuggler runway (hire → P2):** P116 **0s** → P117 **18m12s**

**Consigliere:** P116 unlock NEVER → P117 unlock 28m43s, hire 28m43s, advice events 1

**Cycle-1 pre-Made-Man:** 17 teaser peeks, 10 locked peeks after Made Man (rank-progress cards, not $2T sticker shock).

---

## 4. Profile summary

| Profile | P1 | P2 | Late hired | Behaviors | Locked view-sec |
|---------|----|----|------------|-----------|-----------------|
| CASUAL | 16m00s | 36m00s | 5/5 | 2 | 2790 |
| ENGAGED | 10m03s | 30m03s | 5/5 | 3 | 2700 |
| OPTIMIZER | 12m06s | 32m06s | 5/5 | 3 | 2880 |

---

## 5. Verdict

### **Goal met** — cycle-1 intimidation replaced by teaser + rank progress; Smuggler runway **18m12s**; Consigliere hired **28m43s** before P2 **30m03s** with prestige advice active.

---

## 6. Remaining concerns

- Consigliere advice window before P2 is ~1–2 min in ENGAGED sim — enough to see the feature, but not to lean on it heavily.
- Broker/Consigliere premium payroll still gates hire after rank unlock — progress bars reduce intimidation but cash wall remains.
- Executive collapse toggle is manual — new players may not discover it without tooltip.

---

## 7. Re-run

```powershell
python _measure_p117.py
```
