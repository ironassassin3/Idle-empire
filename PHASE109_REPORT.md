# Phase 109 — Early Manager Prototype

**Date:** 2026-06-15  
**Scope:** Sticky Pete (buy advisor) + Lucky Sal (auto-collect coins).
Behavior hooks in `src/managers.py`, `src/buildings.py`, `src/states.py`.

---

## 1. Prototype changes

| Manager | Old primary | New primary | Secondary (unchanged) |
|---------|-------------|-------------|-------------------------|
| Sticky Pete | +25% click power | **PETE'S PICK** — highlights best affordable building | 1.5× Dealer income |
| Lucky Sal | +50% coin spawn rate | **Auto-collect** golden coins after 0.75s flash | 1.5× Betting income |

Preserved: manager list order, costs, save fields, building economy, 1.5× income mults.

---

## 2. Method

`_measure_p109.py` drives real `PlayingState` with:

- **Suboptimal building buyer** pre-Pete (2nd-best ROI); **follows Pete's pick** post-hire
- **Partial coin clicking** (`coin_click_frac`) pre-Sal; Sal auto-collect post-hire
- **Auto-hire Pete** when affordable; **Sal focus run** reserves cash for Sal

| Profile | Coin click rate (pre-Sal) |
|---------|---------------------------|
| CASUAL | 30% |
| ENGAGED | 45% |
| OPTIMIZER | 60% |

---

## 3. Success question — what does the player stop doing?

### Sticky Pete

| Profile | Hired | Pre-Pete suboptimal buys | Post-Pete off-pick buys | Post-Pete on-pick buys |
|---------|-------|--------------------------|-------------------------|------------------------|
| CASUAL | 52m18s | 49 | 0 | 90 |
| ENGAGED | 32m58s | 47 | 0 | 89 |
| OPTIMIZER | 19m44s | 38 | 0 | 91 |

**Answer:** After Pete, the player stops **guessing which building to buy**.
Suboptimal purchases drop to zero when the sim follows PETE'S PICK; the UI removes
comparison friction (gold highlight + label on Buildings tab). The old +25% click
bonus did not change any action — it only inflated a number.

### Lucky Sal (reserving buyer — `run_sal_focus`)

Full prestige run rarely banks $2M for Sal before reset. Isolated Sal run
reserves income when Sal is within ~3 min (Phase 106 nudge model).

| Profile | Hired | Pre-Sal expired | Pre-Sal manual | Post-Sal auto (10m) | Post-Sal expired |
|---------|-------|-----------------|----------------|---------------------|------------------|
| CASUAL | 50m59s | 40 | 20 | 12 | 0 |
| ENGAGED | 36m59s | 23 | 22 | 13 | 0 |
| OPTIMIZER | 32m08s | 19 | 20 | 14 | 0 |

**Answer:** After Sal, the player stops **chasing golden coins across the screen**.
Post-hire: expired = 0, manual = 0, all coins Sal-auto. Pre-hire: partial clicking
leaves many expired. The old +50% spawn rate only changed a timer.

### Lucky Sal — full prestige run

| Profile | Hired in prestige run |
|---------|----------------------|
| CASUAL | NEVER |
| ENGAGED | NEVER |
| OPTIMIZER | NEVER |

---

## 4. Per-profile timelines

### CASUAL (prestige 76m47s)

- **Pete hired:** 52m18s
- **Sal hired:** NEVER
- **Suboptimal buys (pre-Pete):** 49
- **Post-Pete building picks:** 90 on-pick, 0 off-pick
- **Coins at prestige:** 27 manual, 0 Sal auto, 63 expired

### ENGAGED (prestige 52m17s)

- **Pete hired:** 32m58s
- **Sal hired:** NEVER
- **Suboptimal buys (pre-Pete):** 47
- **Post-Pete building picks:** 89 on-pick, 0 off-pick
- **Coins at prestige:** 26 manual, 0 Sal auto, 36 expired

### OPTIMIZER (prestige 33m26s)

- **Pete hired:** 19m44s
- **Sal hired:** NEVER
- **Suboptimal buys (pre-Pete):** 38
- **Post-Pete building picks:** 91 on-pick, 0 off-pick
- **Coins at prestige:** 32 manual, 0 Sal auto, 10 expired

---

## 5. Behavioral vs economic — verdict

| Criterion | Old (+click / +coin rate) | Prototype (Pete / Sal) |
|-----------|---------------------------|-------------------------|
| Changes player action | No | **Yes** |
| Visible in UI | No | **Yes** (PETE'S PICK / SAL label) |
| Memorable hire moment | No | **Yes** (toast on hire) |
| Answers "what did I stop doing?" | No | **Yes** |
| Competes with building ROI for *meaning* | Yes (same axis: more $) | **No** (different axis: convenience) |

Phase 109 supports Phase 108's thesis: **behavior-changing managers create
stronger progression feelings than income multipliers**, even before acquisition
model decoupling (milestone unlocks) is implemented.

---

## 6. Limitations

1. Harness auto-hires Pete/Sal when affordable — does not model ROI competition
   (Phase 107 greedy buyer still skips managers). Acquisition redesign remains
   required for real sessions.
2. Sal costs $2M — **never reached** in full prestige run without reserving;
   `run_sal_focus` isolates post-hire coin behavior.
3. Pete's pick uses the same ROI formula as an optimal bot — human "off-pick"
   buys are modeled via pre-hire suboptimal buyer only.

---

## 7. Re-run

```powershell
python _measure_p109.py
```
