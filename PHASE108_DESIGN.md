# Phase 108 — Manager Role Redesign (Design Only)

**Date:** 2026-06-15  
**Scope:** Role and progression design — no code, values, or new systems implemented.

---

## 1. Root Problem (from Phase 107)

Managers compete directly with buildings on the **same axis** (cash → income ROI).
Buildings win every comparison. Under greedy play, only **2 of 11** managers are
hired before first prestige; **The Accountant** (the sole behavior-changing hire)
is never reached without hire-nudges.

**Diagnosis:** Managers are priced and described like **building upgrades** (+25% click,
1.5× income, −35% raid damage). Players rationally ask *"what's my $/s?"* — and
buildings always answer higher.

**Design mandate:** Separate responsibilities.

| Layer | Job |
|-------|-----|
| **Buildings** | Generate money. Scale IPS. Define tier progression. |
| **Managers** | Change how the game **feels and plays**. Remove friction. Create milestones. |

Income multipliers may remain as **secondary** seasoning, never the reason to hire.

---

## 2. Design Principles

1. **Behavior first.** Every manager must alter player actions, attention, or anxiety —
   not just a number on the stats tab.
2. **Memorable before/after.** The player should notice the session *shift* the moment
   they hire — a new UI element, a stopped chore, a new automation line in the log.
3. **Non-competing acquisition.** Managers must not be pure cash sinks competing with
   the next building. *(Future implementation options: milestone unlock + nominal fee,
   Influence gate, "operations completed" quest, or dedicated Manager Budget that
   buildings cannot consume — out of scope here, but required for the design to land.)*
4. **Preserve flavor.** Keep names, titles, building pairings, and criminal personas.
   Change *what they do*, not *who they are*.
5. **Progressive delegation.** Early managers remove small chores; mid managers automate
   slices of the loop; late managers orchestrate systems (heat, ops, turf, prestige).

---

## 3. Desired Progression (ENGAGED baseline)

Target emotional arc for a first prestige run (~55–65 min):

| Window | Player state | Manager role |
|--------|--------------|--------------|
| **0–10 min** | Manual empire — click, buy, compare buildings | *No managers yet* |
| **10–20 min** | First **convenience** — something stops being annoying | QoL / Information |
| **20–35 min** | First **automation** — empire buys or runs without constant tabbing | Automation (partial → full) |
| **35–50 min** | **Reduced micromanagement** — heat, rivals, ops need less babysitting | Protection / Risk / Efficiency |
| **50+ min** | Empire **self-maintaining** — player optimizes systems, not chores | Orchestration / Prestige prep |

*CASUAL runs skew +5–10 min; OPTIMIZER runs skew −5–10 min on each window.*

---

## 4. Future Role Categories

| Category | What it does | Example feeling |
|----------|--------------|-----------------|
| **Automation** | Performs actions the player used to click | "It runs while I watch" |
| **Convenience** | Removes a recurring micro-task | "I don't have to remember that" |
| **Information** | Surfaces decisions the player couldn't see | "Now I know what to do" |
| **Protection** | Shields against loss events | "Raids don't scare me" |
| **Risk reduction** | Lowers probability or severity of bad states | "Heat won't surprise me" |
| **Efficiency** | Makes other systems or managers work better | "My crew works smarter" |
| **Quality-of-life** | Visible delight, not raw power | "Coins find me" |
| **Prestige preparation** | Helps time and maximize reset | "I know when to walk away" |

---

## 5. Roster Redesign — Manager by Manager

Each entry: **current purpose** → **proposed purpose**, with audit answers and target window.

---

### 1. Sticky Pete — Corner Dealer

**Current purpose:** +25% click power + 1.5× Dealer income.  
**Phase 107 verdict:** TRAP — click boost after passive crossover; first hire ~37m (nudged) / ~47m (greedy).

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | "My clicks feel weak" | "I don't know what to buy next" / tab-hopping to compare buildings |
| B) Behavior change | Encourages more clicking | Player **stops comparing ROI manually** — Pete pins/highlights best-value building; optional one-click confirm |
| C) Emotional moment | Stat bump | **"Someone's running the block"** — first delegation, not first DPS |
| D) Economic or experiential? | Economic (click %) | **Experiential** (Information + Convenience). Secondary: +10% click if any click bonus kept |

**Proposed role:** **Information + Convenience** — Street Boss watches the strip and **marks the best buy** (glow + tooltip: "Pete recommends…"). Player can ignore it; most will follow. Removes decision fatigue without auto-spending cash.

**Category:** Information, Convenience  
**Intended unlock window:** **10–18 min** (first manager milestone)  
**Flavor preserved:** Street Boss, corner crew, loyal hustler.

---

### 2. The Collector — Protection Racket

**Current purpose:** −35% raid damage + 1.5× Racket income.  
**Phase 107 verdict:** INVISIBLE — second hire only; raid effect never felt in idle sim.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | Raid income loss | Sudden rival/police hits that **punish idle tabbing** |
| B) Behavior change | Passive multiplier on damage formula | Player **stops panic-checking Rivals** after every notification; first raid after hire shows blocked/absorbed hit |
| C) Emotional moment | Invisible math | **"Untouchable"** — visible shield icon, raid toast: "Collector handled it" |
| D) Economic or experiential? | Economic (−35% damage) | **Experiential** (Protection). Secondary: small racket income floor |

**Proposed role:** **Protection** — **Absorbs the first raid hit** each cooldown (e.g. 5 min) completely; subsequent raids in window reduced. UI: shield meter on stats bar.

**Category:** Protection, Risk reduction  
**Intended unlock window:** **15–22 min** (rivals begin to matter)  
**Flavor preserved:** Enforcer, nobody skips payment.

---

### 3. The Mechanic — Chop Shop

**Current purpose:** 1.5× Chop Shop income only.  
**Phase 107 verdict:** TRAP — never hired; strictly dominated by next building.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | Chop tier underperforming | **Reinvestment chore** — player forgets to buy next Chop Shop |
| B) Behavior change | None (income only) | **Auto-buys Chop Shop only** when balance ≥ 2× next unit cost (single-tier micro-automation) |
| C) Emotional moment | None | **"One shop runs itself"** — bridge to full automation; chop bonus procs flash on screen |
| D) Economic or experiential? | Pure economic | **Experiential** (Automation, partial). Secondary: 1.2× chop income |

**Proposed role:** **Automation (tier-scoped)** — First **partial** auto-buy. Teaches "managers run things" before The Accountant runs everything. Visible log: "Mechanic ordered another Chop Shop."

**Category:** Automation  
**Intended unlock window:** **18–26 min** (stepping stone before full auto-buy)  
**Flavor preserved:** Night Shift, off-book vehicles, counts money alone.

---

### 4. Lucky Sal — Sports Betting Ring

**Current purpose:** +50% golden coin frequency + 1.5× Betting income.  
**Phase 107 verdict:** INVISIBLE — never hired; coin boost imperceptible.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | Slow coin cadence | **Missing coins** while on Buildings/Upgrades tabs |
| B) Behavior change | Slightly faster spawn timer | Player **never chases coins** — Sal **auto-collects all golden coins** empire-wide |
| C) Emotional moment | Ambient RNG | **"Jackpot finds you"** — coin fly-to-balance animation + Sal quip toast |
| D) Economic or experiential? | Economic (spawn rate) | **Experiential** (Quality-of-life). Secondary: +25% coin value |

**Proposed role:** **Quality-of-life + Convenience** — Auto-collect golden coins. Highly **visible**; casual players immediately understand.

**Category:** Quality-of-life, Convenience  
**Intended unlock window:** **12–20 min** (overlaps Pete; either Pete or Sal first depending on milestone path — see §7)  
**Flavor preserved:** Bookmaker, luck, never lost a bet.

---

### 5. Clean Carl — Pawn Shop

**Current purpose:** −30% heat gain + 1.5× Pawn income.  
**Phase 107 verdict:** TRAP — never hired; heat is slow-burn.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | Heat rising toward raids | **Heat anxiety** — fear of crossing 60% threshold |
| B) Behavior change | Passive heat gain multiplier | Player **stops heat babysitting**; Carl shows **heat forecast** ( "+X in 2 min" ) and grants **one free emergency dump** when crossing 60% (once per run until prestige) |
| C) Emotional moment | Invisible modifier | **"The Lawyer fixed it"** — milestone toast when auto-dump fires |
| D) Economic or experiential? | Economic (−30% gain) | **Experiential** (Risk reduction, Information). Secondary: pawn upgrade discount stacks slightly faster |

**Proposed role:** **Risk reduction + Information** — Heat forecast bar + one **Get-Out-of-Raid** auto-dump. Makes heat a **managed resource**, not a surprise.

**Category:** Risk reduction, Information  
**Intended unlock window:** **25–35 min** (heat becomes real threat)  
**Flavor preserved:** Front Man, The Lawyer, legitimate receipts.

---

### 6. The Accountant — Loan Shark Office

**Current purpose:** AUTO-BUYS best building every 3s + 1.5× Loan Shark income.  
**Phase 107 verdict:** CORE (design) — only behavior-changing manager; unreachable under greedy ROI.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | Manual building-buy fatigue | Constant **Buildings tab babysitting** through mid/late run |
| B) Behavior change | Auto-buy loop (already correct!) | Player **leaves Buildings tab** for Turf/Ops/Stats; purchases continue; manual buys become optional optimization |
| C) Emotional moment | "Empire runs itself" *(if reached)* | **THE milestone** — full-screen or milestone overlay: "The Accountant is on payroll. Your empire buys itself." |
| D) Economic or experiential? | Mixed (auto-buy + income) | **Experiential** (Automation). Secondary: loan-shark interest tick |

**Proposed role:** **Automation (full)** — Keep auto-buy best building every 3s. **Acquisition must decouple from building ROI** (milestone unlock: e.g. "Own 4 building types" + flat fee, not competing with tier-6 costs). This is the **20–35 min** anchor.

**Category:** Automation  
**Intended unlock window:** **22–32 min** (first true automation; ENGAGED target ~25 min)  
**Flavor preserved:** Fixer, debts disappear, legally most of the time.

---

### 7. Maxine the Dealer — Underground Casino

**Current purpose:** 1.5× Casino income.  
**Phase 107 verdict:** LATE — unreachable first run.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | Casino tier weak | **Other managers feel weak** — no synergy between hires |
| B) Behavior change | None | Each owned casino **amplifies other managers' behavioral effects** (+10% per casino to auto-buy speed, shield duration, coin collect radius, etc.) — **not** raw IPS |
| C) Emotional moment | None | **"The house boosts the family"** — manager cards show green synergy badges |
| D) Economic or experiential? | Pure economic | **Experiential** (Efficiency). Secondary: casino income |

**Proposed role:** **Efficiency (meta-manager)** — Makes *behaviors* stronger, not buildings richer. Reinforces "managers are a team."

**Category:** Efficiency  
**Intended unlock window:** **Post-prestige / 50+ min** (second-cycle power spike)  
**Flavor preserved:** Pit Boss, house always wins.

---

### 8. The Promoter — Nightclub

**Current purpose:** Active −0.6 heat/s + 1.5× Nightclub income.  
**Phase 107 verdict:** LATE — unreachable first run; heat lever is good identity, buried.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | Heat management | Manual heat reduction across tabs |
| B) Behavior change | Passive heat tick down | **Schedules heat laundering** — player sets target (e.g. "keep below 50%"); Promoter auto-spends nightclub laundering / crew heat actions |
| C) Emotional moment | Invisible drift down | **"VIP access to safety"** — heat line stabilizes; player watches bar flatline |
| D) Economic or experiential? | Mixed | **Experiential** (Automation + Risk reduction). Secondary: nightclub income |

**Proposed role:** **Automation + Risk reduction** — **Heat autopilot** within band player chooses. First "set and forget" system manager.

**Category:** Automation, Risk reduction  
**Intended unlock window:** **38–48 min** (reduced micromanagement phase)  
**Flavor preserved:** Club King, VIP list, launders heat.

---

### 9. The Smuggler — Dock Smuggling Op

**Current purpose:** +30% operation rewards + 1.5× Dock income.  
**Phase 107 verdict:** LATE — ops identity unused first run.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | Ops feel unrewarding / tedious | **Ops tab babysitting** — start timer, return, collect |
| B) Behavior change | Bigger payout number | **Auto-starts next operation** when crew free + requirements met; notifies when ready to collect |
| C) Emotional moment | Bigger number | **"Ships sail without me"** — ops queue runs in background |
| D) Economic or experiential? | Economic (+30%) | **Experiential** (Automation, Convenience). Secondary: +15% op rewards |

**Proposed role:** **Automation + Convenience** — Ops queue autopilot (one slot initially).

**Category:** Automation, Convenience  
**Intended unlock window:** **40–52 min**  
**Flavor preserved:** Dock Master, containers, customs doesn't exist.

---

### 10. The Broker — Arms Broker

**Current purpose:** +15% territory success + 1.5× Arms income.  
**Phase 107 verdict:** LATE — turf system unused first run.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | Failed territory actions | **Turf guesswork** — which district, which action |
| B) Behavior change | Slightly higher success % | **Reveals best territory action** per district (intel overlay); **one free retry** on failed capture per cooldown |
| C) Emotional moment | Hidden math | **"Intel wins wars"** — map highlights weak rival district |
| D) Economic or experiential? | Economic (+15%) | **Experiential** (Information, Convenience). Secondary: territory success bonus |

**Proposed role:** **Information + Convenience** — Turf intel dashboard + retry. Player still chooses to attack; Broker removes blind picks.

**Category:** Information, Convenience  
**Intended unlock window:** **45–58 min**  
**Flavor preserved:** Arms Dealer, supply chain, discreet.

---

### 11. The Consigliere — Crime Syndicate HQ

**Current purpose:** +20% Influence on prestige + 1.5× HQ income.  
**Phase 107 verdict:** LATE — prestige bonus irrelevant before first reset.

| Question | Current | Proposed |
|----------|---------|----------|
| A) Pain removed | "When should I prestige?" | **Prestige timing uncertainty** — am I leaving money on table? |
| B) Behavior change | More Influence next cycle | **Prestige advisory dashboard** — shows IPS if reset now vs 5/10 min; recommends reset window; optional **auto-bank 10%** of earnings toward prestige prep |
| C) Emotional moment | Invisible next-cycle bonus | **"The whole board is visible"** — capstone clarity before first reset |
| D) Economic or experiential? | Economic (+20% Influence) | **Experiential** (Prestige preparation, Information). Secondary: +20% Influence |

**Proposed role:** **Prestige preparation + Information** — Makes first prestige a **confident decision**, not a guess. Capstone of first run.

**Category:** Prestige preparation, Information  
**Intended unlock window:** **50–65 min** (at/near prestige gate)  
**Flavor preserved:** Underboss, sees everything, optimizes the operation.

---

## 6. Special Focus — Sticky Pete, The Collector, The Accountant

| Dimension | Sticky Pete | The Collector | The Accountant |
|-----------|-------------|---------------|----------------|
| **Current: increases income?** | Indirect (clicks) | Only via 1.5× mult | Yes (auto-buy + mult) |
| **Proposed: increases income?** | Secondary only | Secondary only | Secondary (interest); **primary is auto-buy** |
| **Current: reduces friction?** | No | Only if raids hurt | Yes — if reached |
| **Proposed: reduces friction?** | **Yes** — buy decision | **Yes** — raid panic | **Yes** — building tab |
| **Current: changes behavior?** | More clicking | None perceptible | New mode — if reached |
| **Proposed: changes behavior?** | **Stop comparing ROI** | **Stop raid panic** | **Leave Buildings tab** |
| **Current: memorable milestone?** | No | No | Yes — but absent |
| **Proposed: memorable milestone?** | **First delegate** (~15m) | **First shield** (~18m) | **Empire runs itself** (~25m) |

**Recommended first-run hire order (ENGAGED, by design intent):**

```
Lucky Sal or Sticky Pete  →  The Collector  →  The Mechanic  →  The Accountant
   (12–18m)                    (15–22m)          (18–26m)          (22–32m)
         ↓
Clean Carl → The Promoter → The Smuggler → The Broker → The Consigliere
  (25–35m)     (38–48m)       (40–52m)      (45–58m)      (50–65m)
```

Sal vs Pete: **branching first milestone** — Sal for casual/coin-chasers (visible delight), Pete for optimizers (buy intel). Both are experiential, neither is raw IPS.

---

## 7. Acquisition Model (Design Recommendation)

Phase 106–107 proved **cash-cost managers lose to buildings**. Future implementation
should consider (design options, not committed):

| Option | Effect |
|--------|--------|
| **Milestone unlock** | Hire button activates at gameplay beat ("First rival raid survived"), cost is nominal |
| **Manager Budget** | Separate wallet; building purchases cannot drain it |
| **Influence fee** | Mid-tier managers cost Respect, not cash |
| **Quest chain** | Pete free after tutorial; Accountant after Mechanic proves partial auto |

**Rule:** The player should never math-compare "manager vs next building" on the same
currency for **behavioral** managers. Buildings stay the money engine.

---

## 8. Income Multipliers — Demotion Policy

Current pattern: every manager = **1.5× building income** (plus niche).

**Proposed policy:**

- **Remove 1.5× as primary hook** from UI copy and hire motivation.
- **Keep at most ~1.1–1.2×** as silent secondary on some managers, or tie bonus to
  *behavior usage* (Accountant: bonus scales with auto-buys performed).
- **Buildings own IPS.** Managers own **time, attention, and anxiety**.

---

## 9. Summary Table

| # | Manager | Category (proposed) | Unlock window | Milestone phrase |
|---|---------|---------------------|---------------|------------------|
| 1 | Sticky Pete | Information, Convenience | 10–18 min | "Someone's watching the block" |
| 2 | The Collector | Protection | 15–22 min | "Raids bounce off" |
| 3 | The Mechanic | Automation (partial) | 18–26 min | "One shop runs itself" |
| 4 | Lucky Sal | Quality-of-life | 12–20 min | "Coins find you" |
| 5 | Clean Carl | Risk reduction | 25–35 min | "The Lawyer fixed it" |
| 6 | The Accountant | Automation (full) | 22–32 min | **"Empire runs itself"** |
| 7 | Maxine the Dealer | Efficiency | 50+ min | "House boosts the family" |
| 8 | The Promoter | Automation, Risk | 38–48 min | "Heat on autopilot" |
| 9 | The Smuggler | Automation, Convenience | 40–52 min | "Ships sail without me" |
| 10 | The Broker | Information | 45–58 min | "Intel wins wars" |
| 11 | The Consigliere | Prestige prep | 50–65 min | "The whole board visible" |

---

## 10. Architectural Conclusions

1. **Phase 107 was right:** Pricing cannot fix an identity that competes with buildings.
   Roles must be redesigned before costs matter again.

2. **The Accountant stays the automation king** — but needs **earlier, decoupled
   acquisition** and a **partial automation predecessor** (Mechanic) so the 20–35 min
   window is reachable without nudges alone.

3. **Sticky Pete must stop being a click upgrade.** His Street Boss fantasy is
   *delegation*, not DPS. First hire should answer "what do I buy?" not "tap harder."

4. **The Collector must be felt, not calculated.** A visible absorbed raid beats
   −35% on a formula the player never inspects.

5. **Late managers (Maxine → Consigliere) finally connect to Turf/Ops/Prestige** instead
   of arriving as invisible income mults on unreachable tiers.

6. **Success test for Phase 109+ implementation:** After hire, ask *"What did I stop
   doing?"* If the answer is "nothing, my numbers went up" — the redesign failed.

---

## 11. Out of Scope (Explicit)

This document does **not** specify:

- Code changes, balance numbers, or new save fields
- New currencies, tabs, or subsystems
- Final acquisition implementation (milestone vs budget vs Influence)
- UI mockups or copy strings

**Next step (future phase):** Implement acquisition decoupling + one manager
(Lucky Sal or Sticky Pete redesign) as proof-of-milestone; measure with `_measure_p107`
successor against the §3 progression windows.

---

## Re-run reference

Phase 107 audit (current-state baseline):

```powershell
python _measure_p107.py
```
