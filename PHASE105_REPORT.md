# Phase 105 — Automation Timing Audit

**Date:** 2026-06-15  
**Scope:** Measurement only — no balance or code changes.

---

## Objective

Determine when managers and automation unlock relative to the first prestige cycle,
and when the game transitions from manual play to self-running empire.

---

## Method

`_measure_p105.py` drives **real `PlayingState`** with the same three profiles as Phase 104:

| Profile | CPS | Active time | Buys/sec |
|---------|-----|-------------|----------|
| CASUAL | 1.5 | 25% | 0.15 |
| ENGAGED | 4.0 | 33% | 0.50 |
| OPTIMIZER | 6.0 | 45% | 1.20 |

**Definitions used in this audit:**

- **Managed building** — first manager hired for a building tier that is already owned (passive income boost via `compute_base_income`).
- **True automation** — **The Accountant** hired; auto-buys best building every 3s via `tick_manager_effects`.
- **Passive crossover** — `income_per_second` exceeds sustained click $/s for the profile.
- **60s idle-capable** — active click layer contributes <10% of combined active+passive $/s (first time after 2 min).
- **Dead period** — >60s with no purchase and nothing affordable.

Manager hire order in sim: first affordable in list order (Sticky Pete → Consigliere).

---

## Manager roster & costs (reference)

| # | Manager | Building | Cost | Primary hook |
|---|---------|----------|------|--------------|
| 1 | Sticky Pete | Corner Dealer | $75K | Hustle — boosts your tap value |
| 2 | The Collector | Protection Racket | $600K | Protection — softens rival & police raid |
| 3 | The Mechanic | Chop Shop | $750K | Off-book vehicle operations |
| 4 | Lucky Sal | Sports Betting Ring | $4M | Luck — golden coins drop far more often |
| 5 | Clean Carl | Pawn Shop | $20M | The Lawyer — keeps your record clean |
| 6 | The Accountant | Loan Shark Office | $60M | AUTO-BUY |

*Full roster: 11 managers; Accountant (6th) is the only auto-buy.*

---

## Automation timelines

### CASUAL

- **First prestige:** 71m36s
- **Automation vs midpoint:** C) Near first prestige

| Event | Time | Money (lifetime) | IPS | Prestige % | Rank |
|-------|------|------------------|-----|------------|------|
| 1st manager | 50m09s | $1.08M | 1.94K/s | 5.4% | Made Man |
| 2nd manager | 70m39s | $17.7M | 40K/s | 88.3% | Made Man |
| 3rd manager | NEVER | — | — | — | — |
| First managed building | 50m09s | $1.08M | 1.94K/s | 5.4% | Made Man |
| The Accountant (auto-buy) | NEVER | — | — | — | — |
| First Accountant auto-buy | NEVER | — | — | — | — |
| Passive > click crossover | 1m47s | $141 | 0/s | 0.0% | Street Hustler |
| 60s idle-capable moment | 10m30s | $13.5K | 31/s | 0.1% | Crew Member |

**First manager:** Sticky Pete (Corner Dealer)

### ENGAGED

- **First prestige:** 59m42s
- **Automation vs midpoint:** C) Near first prestige

| Event | Time | Money (lifetime) | IPS | Prestige % | Rank |
|-------|------|------------------|-----|------------|------|
| 1st manager | 39m32s | $1.08M | 1.9K/s | 5.4% | Made Man |
| 2nd manager | 59m07s | $18M | 41.9K/s | 90.1% | Made Man |
| 3rd manager | NEVER | — | — | — | — |
| First managed building | 39m32s | $1.08M | 1.9K/s | 5.4% | Made Man |
| The Accountant (auto-buy) | NEVER | — | — | — | — |
| First Accountant auto-buy | NEVER | — | — | — | — |
| Passive > click crossover | 4m25s | $5.77K | 8/s | 0.0% | Crew Member |
| 60s idle-capable moment | 35m30s | $487.4K | 632/s | 2.4% | Associate |

**First manager:** Sticky Pete (Corner Dealer)

### OPTIMIZER

- **First prestige:** 47m40s
- **Automation vs midpoint:** C) Near first prestige

| Event | Time | Money (lifetime) | IPS | Prestige % | Rank |
|-------|------|------------------|-----|------------|------|
| 1st manager | 32m59s | $1.81M | 2.77K/s | 9.0% | Made Man |
| 2nd manager | NEVER | — | — | — | — |
| 3rd manager | NEVER | — | — | — | — |
| First managed building | 32m59s | $1.81M | 2.77K/s | 9.0% | Made Man |
| The Accountant (auto-buy) | NEVER | — | — | — | — |
| First Accountant auto-buy | NEVER | — | — | — | — |
| Passive > click crossover | 8m32s | $31.2K | 29/s | 0.2% | Crew Member |
| 60s idle-capable moment | NEVER | — | — | — | — |

**First manager:** Sticky Pete (Corner Dealer)

---

## Manual friction

| Profile | Total purchases | Avg interval | Dead periods | Buy bursts |
|---------|-----------------|--------------|--------------|------------|
| CASUAL | 204 | 0m21s | 0 | 1 |
| ENGAGED | 204 | 0m17s | 0 | 10 |
| OPTIMIZER | 204 | 0m14s | 0 | 12 |

**Friction observations:**

- **CASUAL:** no dead periods (always saving toward next buy); 1 manual buy bursts in first ~10 min; never reached The Accountant ($60M) before prestige; 27 manual purchases in final 5 min
- **ENGAGED:** no dead periods (always saving toward next buy); 10 manual buy bursts in first ~10 min; never reached The Accountant ($60M) before prestige; 27 manual purchases in final 5 min
- **OPTIMIZER:** no dead periods (always saving toward next buy); 12 manual buy bursts in first ~10 min; never reached The Accountant ($60M) before prestige; 32 manual purchases in final 5 min

---

## Emotional transition analysis

### When does ENGAGED stop feeling like a clicker?

- **Passive crossover** at 4m25s (0% to prestige) — idle $/s beats clicking.
- **Psychological idle window** at 35m30s (clicks <10% of earnings rate).
- **First manager** (Sticky Pete) at 39m32s — click boost, not automation.
- **True automation never unlocked** before first prestige.

---

## Audit questions answered

### Is automation too late?

**First manager (Sticky Pete) averages 40m53s** — at ~70%–69% of the prestige run. Classification: **C) Near first prestige**.
**The Accountant is not reached before first prestige** in some/all profiles — automation is absent entirely.

### Which manager creates the first "idle feeling"?

**Sticky Pete** is always first hired (~75K), but he boosts **clicks**, not automation. The first *passive* shift is **passive crossover** (idle > click $/s), not a manager. **The Accountant** is the first manager that removes manual building buys — if reached.

### Which building becomes self-sustaining first?

Corner Dealer income ramps first; **Protection Racket** multiplier makes dealer tier self-reinforcing. No building auto-purchases itself until **The Accountant** (Loan Shark tier manager) is hired.

### Are players still micromanaging near prestige?

- **CASUAL:** 27 manual purchases in last 5 min; Accountant=no; 2 managers hired.
- **ENGAGED:** 27 manual purchases in last 5 min; Accountant=no; 2 managers hired.
- **OPTIMIZER:** 32 manual purchases in last 5 min; Accountant=no; 1 managers hired.

### Where should automation ideally appear?

Design intent (Phase 104 targets): **15–30 min** = "empire running itself"; **30–60 min** = "optimizing systems." Current data suggests:

| Ideal milestone | Current ENGAGED (approx) | Gap |
|-----------------|--------------------------|-----|
| First *automation* manager | NEVER | Should be ~15–25 min |
| Passive crossover | 4m25s | OK (~9 min) |
| First manager (any) | 39m32s | Too late for *automation* feel |
| First prestige | 59m42s | — |

---

## Remaining concerns

1. **Accountant cost ($60M)** gates true automation to the back third of the prestige run (if reached at all).
2. **First three managers** are passive modifiers (click, raid, income) — they do not reduce manual building buys.
3. **CASUAL may never reach Accountant** before prestige at current pacing.
4. **Harness does not simulate tab switching** or operations/crew — real players may feel friction differently.
5. **Prestige gate at $20M lifetime** extends run length, pushing all manager timestamps later.

---

## Re-run

```powershell
python _measure_p105.py
```
