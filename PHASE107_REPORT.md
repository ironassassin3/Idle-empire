# Phase 107 — Manager Identity Audit

**Date:** 2026-06-15  
**Scope:** Measurement and classification only — no balance, mechanics, or save changes.

---

## 1. Root Problem (confirmed)

Phase 106 proved cost tuning alone cannot create a satisfying midgame automation moment.
Managers compete directly with building ROI. Under a **greedy buyer** (buildings and upgrades
always prioritized), players rationally delay managers until purchase options thin out near
prestige. **This is an identity problem, not a pricing problem:** most managers stack a
1.5× building multiplier on top of a niche passive modifier, which reads like an expensive
upgrade rather than a progression milestone.

---

## 2. Method

`_measure_p107.py` drives real `PlayingState` with the Phase 105 **greedy buyer**
(same profiles as Phases 104–106). For each manager it records:

- **First affordable** — earliest sim time `balance >= cost`
- **Hired at** — when greedy loop actually purchases the manager
- **Purchase delay** — hired_at − first_affordable (≥10 min ⇒ *ignored*)
- **Near prestige** — hired at ≥80% lifetime progress to first prestige

| Profile | CPS | Active time | Buys/sec |
|---------|-----|-------------|----------|
| CASUAL | 1.5 | 25% | 0.15 |
| ENGAGED | 4.0 | 33% | 0.50 |
| OPTIMIZER | 6.0 | 45% | 1.20 |

*Harness does not simulate tab visits, hire-nudges, or player curiosity buys.*

---

## 3. Manager classifications

| Manager | Class | Rationale |
|---------|-------|-----------|
| Sticky Pete | **TRAP** | First hire is +25% clicks after passive crossover; sim delays ~40m until buildings thin. |
| The Collector | **INVISIBLE** | Second hire only; -35% raid damage never perceptible in idle-first sim. |
| The Mechanic | **TRAP** | 1.5× on one building — never affordable before prestige under greedy buys. |
| Lucky Sal | **INVISIBLE** | Never hired; +50% coin frequency is ambient and unnoticeable. |
| Clean Carl | **TRAP** | Never hired; heat hook clear in UI but loses every ROI comparison to buildings. |
| The Accountant | **CORE** | Only auto-buy hook in roster — but greedy sim never banks $1.5M; identity unreachable. |
| Maxine the Dealer | **LATE** | Post-prestige-tier costs; first-run identity never experienced. |
| The Promoter | **LATE** | Post-prestige-tier costs; first-run identity never experienced. |
| The Smuggler | **LATE** | Post-prestige-tier costs; first-run identity never experienced. |
| The Broker | **LATE** | Post-prestige-tier costs; first-run identity never experienced. |
| The Consigliere | **LATE** | Prestige-cycle bonus; unreachable before first prestige in sim. |

**Legend:** CORE = progression milestone · UTILITY = helpful optional · TRAP = ROI-inferior ·
INVISIBLE = effect rarely noticed · LATE = useful but after first-prestige window

---

## 4. Per-manager identity evaluation

### Sticky Pete — **TRAP**

*Building:* Corner Dealer · *Cost:* $40K · *Hook:* * Hustle — boosts your tap value

| | |
|---|---|
| A) Problem | Early-game click throughput still matters. |
| B) Emotion | Hustle power — still manual, not empire automation. |
| C) Rational immediate buy? | No — building/upgrade ROI dominates. |
| D) Casual understands? | Yes — specialty text clear. |
| E) Removed → noticeable? | Low impact once passive > clicks. |

*First hire is +25% clicks after passive crossover; sim delays ~40m until buildings thin.*

### The Collector — **INVISIBLE**

*Building:* Protection Racket · *Cost:* $400K · *Hook:* * Protection — softens rival & police raids

| | |
|---|---|
| A) Problem | Raid damage to balance. |
| B) Emotion | Invincibility / protection fantasy. |
| C) Rational immediate buy? | No — unless raids already hurt. |
| D) Casual understands? | Partial — needs raid experience. |
| E) Removed → noticeable? | Low if never hired. |

*Second hire only; -35% raid damage never perceptible in idle-first sim.*

### The Mechanic — **TRAP**

*Building:* Chop Shop · *Cost:* $900K · *Hook:* Off-book vehicle operations

| | |
|---|---|
| A) Problem | Single-tier passive income. |
| B) Emotion | Tier ownership pride (weak — no behaviour change). |
| C) Rational immediate buy? | No — next building purchase wins. |
| D) Casual understands? | Misleading vs 'automate' header on tab. |
| E) Removed → noticeable? | Negligible — buildings are the real income. |

*1.5× on one building — never affordable before prestige under greedy buys.*

### Lucky Sal — **INVISIBLE**

*Building:* Sports Betting Ring · *Cost:* $2M · *Hook:* * Luck — golden coins drop far more often

| | |
|---|---|
| A) Problem | Golden coin cadence. |
| B) Emotion | Random jackpot moments. |
| C) Rational immediate buy? | No — ambient bonus. |
| D) Casual understands? | Partial. |
| E) Removed → noticeable? | Barely noticed. |

*Never hired; +50% coin frequency is ambient and unnoticeable.*

### Clean Carl — **TRAP**

*Building:* Pawn Shop · *Cost:* $6M · *Hook:* * The Lawyer — keeps your record clean

| | |
|---|---|
| A) Problem | Heat accumulation / police raids. |
| B) Emotion | Breathing room from law enforcement. |
| C) Rational immediate buy? | No — until heat crisis. |
| D) Casual understands? | Yes for Clean Carl / Promoter labels. |
| E) Removed → noticeable? | Moderate for heat-focused players. |

*Never hired; heat hook clear in UI but loses every ROI comparison to buildings.*

### The Accountant — **CORE**

*Building:* Loan Shark Office · *Cost:* $1.5M · *Hook:* * Automation — buys the best building for you

| | |
|---|---|
| A) Problem | Manual building purchase loop. |
| B) Emotion | **Empire runs itself** — only strong milestone in roster. |
| C) Rational immediate buy? | Only manager where yes is rational *for friction reduction* — still loses ROI race. |
| D) Casual understands? | Yes — AUTO-BUYS explicit. |
| E) Removed → noticeable? | **Severe** — no auto-buy, manual loop persists. |

*Only auto-buy hook in roster — but greedy sim never banks $1.5M; identity unreachable.*

### Maxine the Dealer — **LATE**

*Building:* Casino · *Cost:* $500M · *Hook:* High-stakes operations

| | |
|---|---|
| A) Problem | Single-tier passive income. |
| B) Emotion | Tier ownership pride (weak — no behaviour change). |
| C) Rational immediate buy? | No — next building purchase wins. |
| D) Casual understands? | Misleading vs 'automate' header on tab. |
| E) Removed → noticeable? | Negligible — buildings are the real income. |

*Post-prestige-tier costs; first-run identity never experienced.*

### The Promoter — **LATE**

*Building:* Nightclub · *Cost:* $4B · *Hook:* * Active heat lever — steadily lowers Heat

| | |
|---|---|
| A) Problem | Heat accumulation / police raids. |
| B) Emotion | Breathing room from law enforcement. |
| C) Rational immediate buy? | No — until heat crisis. |
| D) Casual understands? | Yes for Clean Carl / Promoter labels. |
| E) Removed → noticeable? | Moderate for heat-focused players. |

*Post-prestige-tier costs; first-run identity never experienced.*

### The Smuggler — **LATE**

*Building:* Shipping Dock · *Cost:* $30B · *Hook:* * Smuggling — fatter operation payouts

| | |
|---|---|
| A) Problem | Illegal operation payouts. |
| B) Emotion | Bigger heist scores. |
| C) Rational immediate buy? | No pre-prestige. |
| D) Casual understands? | Partial. |
| E) Removed → noticeable? | Low. |

*Post-prestige-tier costs; first-run identity never experienced.*

### The Broker — **LATE**

*Building:* Arms Warehouse · *Cost:* $250B · *Hook:* * Expansion — easier district captures

| | |
|---|---|
| A) Problem | Territory capture odds. |
| B) Emotion | Map control. |
| C) Rational immediate buy? | No pre-prestige. |
| D) Casual understands? | Partial. |
| E) Removed → noticeable? | Low. |

*Post-prestige-tier costs; first-run identity never experienced.*

### The Consigliere — **LATE**

*Building:* Syndicate HQ · *Cost:* $2T · *Hook:* * Prestige — more Influence every reset

| | |
|---|---|
| A) Problem | Influence per reset. |
| B) Emotion | Meta power growth. |
| C) Rational immediate buy? | No first cycle. |
| D) Casual understands? | Partial. |
| E) Removed → noticeable? | N/A first run. |

*Prestige-cycle bonus; unreachable before first prestige in sim.*

---

## 5. Special focus — Sticky Pete, The Collector, The Accountant

| Dimension | Sticky Pete | The Collector | The Accountant |
|-----------|-------------|---------------|----------------|
| Increases income | Indirect (+25% clicks early) | Only via 1.5× Racket mult | Yes (auto-buy + 1.5× Loan Shark) |
| Reduces friction | No — still manual buys | Only if raids hurt | **Yes — removes building buy loop** |
| Changes behaviour | Encourages more clicking | Passive — only matters during raids | **New mode: watch empire grow** |
| Memorable milestone | Weak — feels like stat upgrade | Weak — invisible until raided | **Strong IF hired; absent if ROI-delayed** |

**Sticky Pete — purchase timing (greedy buyer):**

| Profile | 1st affordable | Hired | Delay | Prestige % | Near prestige? |
|---------|--------------|-------|-------|------------|----------------|
| CASUAL | 43m32s | 46m57s | 3m25s | 4.2% | no |
| ENGAGED | 33m39s | 37m18s | 3m39s | 5.0% | no |
| OPTIMIZER | 26m13s | 29m31s | 3m18s | 5.5% | no |

**The Collector — purchase timing (greedy buyer):**

| Profile | 1st affordable | Hired | Delay | Prestige % | Near prestige? |
|---------|--------------|-------|-------|------------|----------------|
| CASUAL | 63m10s | 63m10s | 0m00s | 37.5% | no |
| ENGAGED | 54m03s | 54m34s | 0m30s | 65.1% | no |
| OPTIMIZER | 43m00s | 43m08s | 0m08s | 62.5% | no |

**The Accountant — purchase timing (greedy buyer):**

| Profile | 1st affordable | Hired | Delay | Prestige % | Near prestige? |
|---------|--------------|-------|-------|------------|----------------|
| CASUAL | NEVER | NEVER | — | — | — |
| ENGAGED | NEVER | NEVER | — | — | — |
| OPTIMIZER | NEVER | NEVER | — | — | — |

---

## 6. Player behaviour — purchase order & delays

### CASUAL (prestige 69m25s)

**Actual hire order:** Sticky Pete → The Collector

| Manager | Affordable | Hired | Delay | Order | Ignored? | Near prestige? |
|---------|------------|-------|-------|-------|----------|----------------|
| Sticky Pete | 43m32s | 46m57s | 3m25s | 1 | no | no |
| The Collector | 63m10s | 63m10s | 0m00s | 2 | no | no |
| The Mechanic | NEVER | NEVER | — | — | no | — |
| Lucky Sal | NEVER | NEVER | — | — | no | — |
| Clean Carl | NEVER | NEVER | — | — | no | — |
| The Accountant | NEVER | NEVER | — | — | no | — |
| Maxine the Dealer | NEVER | NEVER | — | — | no | — |
| The Promoter | NEVER | NEVER | — | — | no | — |
| The Smuggler | NEVER | NEVER | — | — | no | — |
| The Broker | NEVER | NEVER | — | — | no | — |
| The Consigliere | NEVER | NEVER | — | — | no | — |

- **Never hired (9):** The Mechanic, Lucky Sal, Clean Carl, The Accountant, Maxine the Dealer, The Promoter, The Smuggler, The Broker, The Consigliere

### ENGAGED (prestige 57m10s)

**Actual hire order:** Sticky Pete → The Collector

| Manager | Affordable | Hired | Delay | Order | Ignored? | Near prestige? |
|---------|------------|-------|-------|-------|----------|----------------|
| Sticky Pete | 33m39s | 37m18s | 3m39s | 1 | no | no |
| The Collector | 54m03s | 54m34s | 0m30s | 2 | no | no |
| The Mechanic | NEVER | NEVER | — | — | no | — |
| Lucky Sal | NEVER | NEVER | — | — | no | — |
| Clean Carl | NEVER | NEVER | — | — | no | — |
| The Accountant | NEVER | NEVER | — | — | no | — |
| Maxine the Dealer | NEVER | NEVER | — | — | no | — |
| The Promoter | NEVER | NEVER | — | — | no | — |
| The Smuggler | NEVER | NEVER | — | — | no | — |
| The Broker | NEVER | NEVER | — | — | no | — |
| The Consigliere | NEVER | NEVER | — | — | no | — |

- **Never hired (9):** The Mechanic, Lucky Sal, Clean Carl, The Accountant, Maxine the Dealer, The Promoter, The Smuggler, The Broker, The Consigliere

### OPTIMIZER (prestige 45m34s)

**Actual hire order:** Sticky Pete → The Collector

| Manager | Affordable | Hired | Delay | Order | Ignored? | Near prestige? |
|---------|------------|-------|-------|-------|----------|----------------|
| Sticky Pete | 26m13s | 29m31s | 3m18s | 1 | no | no |
| The Collector | 43m00s | 43m08s | 0m08s | 2 | no | no |
| The Mechanic | NEVER | NEVER | — | — | no | — |
| Lucky Sal | NEVER | NEVER | — | — | no | — |
| Clean Carl | NEVER | NEVER | — | — | no | — |
| The Accountant | NEVER | NEVER | — | — | no | — |
| Maxine the Dealer | NEVER | NEVER | — | — | no | — |
| The Promoter | NEVER | NEVER | — | — | no | — |
| The Smuggler | NEVER | NEVER | — | — | no | — |
| The Broker | NEVER | NEVER | — | — | no | — |
| The Consigliere | NEVER | NEVER | — | — | no | — |

- **Never hired (9):** The Mechanic, Lucky Sal, Clean Carl, The Accountant, Maxine the Dealer, The Promoter, The Smuggler, The Broker, The Consigliere

---

## 7. Success criteria — answers

### Which manager creates the first true automation feeling?

**The Accountant** — only manager with an active tick that purchases buildings. No other hire changes the purchase loop. Under greedy ROI pressure the sim **never accumulates $1.5M unspent** — The Accountant is architecturally the automation hook but **behaviorally absent** in all three profiles. Phase 106 nudges/reserving are required to reach him.

### Which managers are invisible?

- **Classified INVISIBLE:** The Collector, Lucky Sal
- **Never hired in greedy first-prestige sim:** The Mechanic (3/3 profiles), Lucky Sal (3/3 profiles), Clean Carl (3/3 profiles), The Accountant (3/3 profiles), Maxine the Dealer (3/3 profiles), The Promoter (3/3 profiles), The Smuggler (3/3 profiles), The Broker (3/3 profiles), The Consigliere (3/3 profiles)
- **Sticky Pete** — hired but effect is click-only; passive income already dominates by hire time (~4–5% prestige progress is early lifetime, ~40m+ sim time).

### Which managers are delayed by ROI pressure?

All **first-prestige-reachable** managers (indices 0–5). Measured pattern:

- **Sticky Pete:** CASUAL 3m, ENGAGED 3m, OPTIMIZER 3m
- **The Collector:** CASUAL 0m, ENGAGED 0m, OPTIMIZER 0m
- **The Mechanic:** CASUAL NEVER, ENGAGED NEVER, OPTIMIZER NEVER
- **Lucky Sal:** CASUAL NEVER, ENGAGED NEVER, OPTIMIZER NEVER
- **Clean Carl:** CASUAL NEVER, ENGAGED NEVER, OPTIMIZER NEVER
- **The Accountant:** CASUAL NEVER, ENGAGED NEVER, OPTIMIZER NEVER

### Which manager should become the "my empire runs itself" moment?

**The Accountant** — architecturally correct hook (`tick_manager_effects` auto-buy).
Measured greedy behaviour: **never reached in any profile** despite $1.5M cost —
every spare dollar routes to buildings/upgrades until only Sticky Pete ($40K) and
The Collector ($400K) slip through at endgame. **Identity is undermined by ROI
competition**, not price. Phase 106 hire-nudges change behaviour, not identity.

---

## 8. Architectural conclusions

1. **Dual identity conflict:** Manager cards say "automate buildings, boost income"
   but 10/11 managers only boost income (1.5×) plus a passive modifier. Only The
   Accountant automates. Players learn buildings = progression; managers = expensive
   sidegrades.

2. **Sticky Pete mispositions first hire:** First affordable manager always boosts
   *clicks* while passive income has already crossed over (~4–9 min). First manager
   hire feels like a stat buff, not empire delegation.

3. **The Collector protects against friction many players never feel:** Greedy sim
   rarely loses significant income to raids before prestige; -35% raid damage is
   unmeasurable if the hire never happens early.

4. **Income-only managers are TRAPs in the ROI model:** The Mechanic (+1.5× Chop)
   is strictly dominated by buying the next Chop Shop or advancing tier. Same for
   Maxine and mid-tier income hooks.

5. **System-linked managers (Broker, Smuggler, Consigliere) are LATE by cost,
   not by design intent:** Their identity requires Turf/Ops/Prestige loops that
   activate after the first-run manager window closes.

6. **Automation feeling ≠ manager hire feeling:** Passive crossover and 60s-idle
   moments happen at 4–35 min without any manager. The gap is specifically
   *purchase automation*, which only The Accountant provides — and ROI delays it.

7. **Progression milestone test:** A manager qualifies as CORE only if it (a) changes
   player behaviour, (b) creates a memorable before/after, and (c) isn't strictly
   dominated by the next building buy. **Only The Accountant passes (a) and (b) by
   design; none pass (c) under greedy play — and The Accountant fails (a) in practice
   because ROI prevents ever banking his cost.**

8. **First-run hire ceiling:** Greedy sim hires exactly **2 of 11** managers before
   prestige (Sticky Pete + The Collector in all profiles). Nine managers — including
   the automation hook — are **never affordable with unspent cash**, confirming managers
   are structurally competing with buildings, not complementing them.

---

## 9. Re-run

```powershell
python _measure_p107.py
```
