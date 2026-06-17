# Phase 114 — Late Manager Identity Implementation

**Date:** 2026-06-15  
**Scope:** Maxine, Promoter, Smuggler, Broker, Consigliere — Phase 108 behaviors.

---

## 1. What each manager removes

| Manager | Before (P113) | After (P114) | Player stops… |
|---------|---------------|--------------|---------------|
| **Maxine** | +IPS via casinos | +10% behaviors per casino | Tuning each manager separately |
| **Promoter** | Flat −0.6 heat/s | Heat autopilot to target | Manual heat babysitting |
| **Smuggler** | +30% op rewards | Auto-starts ops + ready alerts | Ops tab babysitting |
| **Broker** | +15% success math | Intel highlight + free retry | Blind turf picks |
| **Consigliere** | +20% Influence | Prestige advisory dashboard | Guessing when to reset |

---

## 2. Behavior metrics — all profiles

| Profile | Prestige | Maxine | Promoter | Smuggler | Broker | Consigliere | Mech× peak | Smuggler starts | Broker retries | Heat >target post-Promoter |
|---------|----------|--------|----------|----------|--------|-------------|-------------|-----------------|----------------|---------------------------|
| CASUAL | 22m00s | 6m46s | 7m00s | 10m00s | 14m00s | 18m00s | 15.50× | 1 | 1 | 8s |
| ENGAGED | 22m00s | 4m00s | 6m30s | 10m00s | 14m00s | 18m00s | 23.80× | 1 | 2 | 0s |
| OPTIMIZER | 22m00s | 4m00s | 4m53s | 10m00s | 14m00s | 18m00s | 30.00× | 1 | 0 | 0s |

---

## 3. ENGAGED before/after (P113 vs P114)

| Metric | Phase 113 | Phase 114 | Change |
|--------|-----------|-----------|--------|
| First prestige | 31m32s | 22m00s | -572s |
| Smuggler auto-starts | 0 | **1** | NEW |
| Broker free retries | 0 | **2** | NEW |
| Maxine behavior mult (peak) | 1.0 | **23.80×** | NEW |
| Heat above Promoter target | N/A | **0s** | visible |
| Consigliere advice at prestige | no | **prestige now** | NEW |
| Manual buys (last 5 min) | 19 | 150 | +131 |
| Turf actions (broker intel) | 0 | **11** | NEW |

### Success question — after hiring each manager, what did the player stop doing?

1. **Maxine** (~4m00s): stop treating managers as isolated — behaviors ran at **23.80×** speed with casinos.
2. **Promoter** (~6m30s): stop manually dumping heat — autopilot held over target only **0s**.
3. **Smuggler** (~10m00s): stop starting ops manually — **1** auto-launches, **0** ready alerts.
4. **Broker** (~14m00s): stop blind turf picks — **11** intel-guided actions, **2** free retries.
5. **Consigliere** (~18m00s): stop guessing reset timing — advisory: **prestige now**.

**Verdict:** All 11 managers now alter player actions. Manager roster transformation complete.

---

## 4. Remaining friction

- **Ops collect** still manual — Smuggler auto-starts but player must collect (by design).
- **Late manager costs** still require premium cash + rank; first-run reach depends on rank progress.
- **Maxine synergy** scales with casino count — minimal until mid/late buildings online.

**Next highest-priority problem:** First-run **rank pacing** to late managers — behaviors exist
but Capo+ gates mean many players meet Maxine–Consigliere post-prestige, not pre-prestige.

---

## 5. Re-run

```powershell
python _measure_p114.py
```
