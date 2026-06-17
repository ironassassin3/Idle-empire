# Phase 112 — Post-Manager Experience Audit

**Date:** 2026-06-15  
**Scope:** Measurement only — reflects Phases 109 (behavior), 110–111 (access).

---

## 1. Method

`_measure_p112.py` drives **real `PlayingState`**: milestone unlock + payroll hire,
Pete buy-advisor, Sal auto-collect, Accountant auto-buy. Greedy buyer hires managers
when `can_hire_manager` before building purchases. Partial coin-click sim.

| Profile | CPS | Active | Buys/s | Coin click |
|---------|-----|--------|--------|------------|
| CASUAL | 1.5 | 25% | 0.15 | 30% |
| ENGAGED | 4.0 | 33% | 0.50 | 45% |
| OPTIMIZER | 6.0 | 45% | 1.20 | 60% |

Baseline: **Phase 105** (pre-redesign, old cash manager costs).

---

## 2. Timeline — Phase 112

### CASUAL

| Event | Time |
|-------|------|
| Passive > click crossover | 2m30s |
| Sticky Pete unlocked | 19m03s |
| Sticky Pete hired | 24m29s |
| Lucky Sal unlocked | 19m03s |
| Lucky Sal hired | 27m19s |
| The Mechanic unlocked | 21m33s |
| The Mechanic hired | 29m48s |
| The Accountant unlocked | 32m51s |
| The Accountant hired | 38m32s |
| Accountant first auto-buy | 38m44s |
| 60s idle-capable | 12m30s |
| First prestige | 44m42s |

### ENGAGED

| Event | Time |
|-------|------|
| Passive > click crossover | 2m09s |
| Sticky Pete unlocked | 8m07s |
| Sticky Pete hired | 13m29s |
| Lucky Sal unlocked | 8m07s |
| Lucky Sal hired | 15m15s |
| The Mechanic unlocked | 11m16s |
| The Mechanic hired | 16m12s |
| The Accountant unlocked | 19m43s |
| The Accountant hired | 23m02s |
| Accountant first auto-buy | 23m08s |
| 60s idle-capable | 16m00s |
| First prestige | 27m55s |

### OPTIMIZER

| Event | Time |
|-------|------|
| Passive > click crossover | 4m32s |
| Sticky Pete unlocked | 4m14s |
| Sticky Pete hired | 6m05s |
| Lucky Sal unlocked | 4m14s |
| Lucky Sal hired | 7m24s |
| The Mechanic unlocked | 4m15s |
| The Mechanic hired | 8m07s |
| The Accountant unlocked | 11m02s |
| The Accountant hired | 15m20s |
| Accountant first auto-buy | 15m38s |
| 60s idle-capable | NEVER |
| First prestige | 20m17s |

*OPTIMIZER never hits 60s idle-capable: high CPS + buy rate keeps active layer above 10% of total $/s through prestige.*

---

## 3. Phase 105 vs Phase 112 (ENGAGED focus)

| Metric | Phase 105 | Phase 112 | Change |
|--------|-----------|-----------|--------|
| First prestige | 59m42s | 27m55s | −1906s (better) |
| First manager (Pete) | 39m32s | 13m29s | −1562s (better) |
| The Accountant hired | NEVER | 23m02s | NEW |
| Accountant auto-buy | NEVER | 23m08s | NEW |
| 60s idle-capable | 35m30s | 16m00s | −1170s (better) |
| Manual buys (last 5 min) | 27 | 44 | +17 |
| Avg purchase interval | ~17s | ~10s | −7s |
| Buy bursts (3+ in 10s) | — | 429 | — |

### All profiles — friction comparison

| Profile | P105 last-5min buys | P112 last-5min | P112 coins expired | P112 off-path buys | P112 dead periods |
|---------|--------------------:|---------------:|-------------------:|------------------:|------------------:|
| CASUAL | 27 | 21 | 22 | 0 | 0 |
| ENGAGED | 27 | 44 | 8 | 0 | 0 |
| OPTIMIZER | 32 | 69 | 2 | 0 | 0 |

---

## 4. Success questions — progression arc

### ENGAGED emotional chain

1. **Manual empire** (0 – passive crossover ~4m) — unchanged from P105.
2. **Delegation** (Pete ~13m29s, Sal ~15m15s) — **NEW**; was first manager at 39m in P105.
3. **Partial automation** (Mechanic ~16m12s, Accountant hire ~23m02s, auto-buy ~23m08s) — **NEW**; P105 never reached Accountant.
4. **Prestige** ~27m55s — **53% faster** than P105.

**Verdict:** Manual → Delegation → Automation → Prestige arc **now exists** for ENGAGED.
Missing transition: **Mechanic** still income-only (no partial auto-buy behavior yet — Phase 108 design not implemented).

### Did manual burden decrease?

- Last-5min manual purchases: **27 → 44** (ENGAGED) — **slightly worse**, because faster progression compresses more building tiers into the final 5 min.
- Accountant auto-buy active: **True** — building buys delegated for ~4 min pre-prestige.

### Did automation arrive earlier?

- Accountant hired: **NEVER → 23m02s** (~82% through run).

### Did actions become less repetitive?

- Off-path building buys after Pete: **0** (greedy sim always follows best ROI).
- Coin expirations: **8**; **11** collected manually; **17** Sal auto-collected.
- Buy bursts (3+ purchases in 10s): **429** — shorter avg interval (~10s vs ~17s P105) but more clustered late-run buys.

---

## 5. Remaining friction & next bottleneck

**Remaining friction:**

- ENGAGED still **44 manual purchases** in final 5 min — Accountant auto-buy reduces but does not eliminate late-run building micromanagement.
- **8 coin expirations** before/during early run — Sal fixes post-hire only.

**Next highest-priority problem (identified, not assumed):**

**Mid-tier manager identity gap** — The Mechanic, Collector, and Clean Carl still
behave as passive income multipliers. Phase 108 designed partial auto-buy / raid shield /
heat forecast behaviors; only Pete, Sal, and Accountant change player actions today.
Post-access bottleneck shifts from *"can't reach managers"* to *"mid managers don't
change the loop."*

Secondary: **CASUAL prestige pacing** — first prestige 44m42s vs ENGAGED 27m55s; Accountant window 5m58s pre-prestige.

---

## 6. Re-run

```powershell
python _measure_p112.py
```
