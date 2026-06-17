# Phase 110 — Manager Acquisition Audit

**Date:** 2026-06-15  
**Scope:** Acquisition-model evaluation only — no implementation, no manager redesign.

---

## 1. Root Problem (confirmed)

Phase 109 proved **behavior-based managers are valuable** (Pete ends buy-guesswork;
Sal ends coin-chasing). Phase 107 proved **cash-priced managers lose to buildings**
under greedy play: only **2 of 11** hired before prestige; Sal and Accountant
**never** banked unspent.

| Issue | Status after Phase 109 |
|-------|------------------------|
| Manager **identity** | Solved (behavior hooks live) |
| Manager **access** | **Not solved** — shared cash economy blocks hires |

Players should encounter managers as **natural milestones**, not as purchases they
must force by stopping building buys (Phase 106 reserve / nudge model).

---

## 2. Current Baseline (greedy buyer, Phase 107/109)

| Manager | Cost | First affordable (ENGAGED) | Actually hired | Phase 108 target |
|---------|------|----------------------------|----------------|------------------|
| Sticky Pete | $40K | ~35m | ~38m | 10–18m |
| The Collector | $400K | ~55m | ~56m | 15–22m |
| The Mechanic | $900K | NEVER | NEVER | 18–26m |
| Lucky Sal | $2M | NEVER | NEVER | 12–20m |
| The Accountant | $1.5M | NEVER | NEVER | 22–32m |
| Clean Carl | $6M | NEVER | NEVER | 25–35m |

**Save model today:** `managers: [hired × 11]` by index in `save_load.py` — order
is load-critical. Balance is the sole hire gate in `handle_click`.

**Competition axes managers lose on:**

1. **Buildings** — next tier always beats manager IPS ROI  
2. **Upgrades** — same wallet, same greed loop  
3. **Prestige savings** — banking $20M lifetime implicitly delays all discretionary spends  

---

## 3. Milestone Timing vs Cash (measured)

`_measure_p110.py` compares **proposed unlock beats** (computed from gameplay state,
not implemented) against greedy **afford / hire** times:

| Manager | Proposed unlock | ENGAGED unlock | ENGAGED afford$ | Gap (unlock → afford) |
|---------|-----------------|----------------|-----------------|------------------------|
| Sticky Pete | Lifetime ≥ $25K | **11m54s** | 35m00s | **~23 min early** |
| The Collector | ≥ 3 Rackets | **2m04s** | 53m11s | **~51 min early** |
| The Mechanic | ≥ 2 Chop Shops | **11m58s** | NEVER | unlock OK, cash blocks |
| The Accountant | ≥ 4 building types | **28m58s** | NEVER | unlock OK, cash blocks |
| Clean Carl | Heat ≥ 40% | **8m40s** | NEVER | unlock OK, cash blocks |
| Lucky Sal | Catch 1 coin *(sim)* | NEVER* | NEVER | needs gameplay-linked unlock† |

\* Greedy sim never clicks coins; † **Recommend unlock: own 1 Sports Betting Ring**
(already owned mid-run) instead of coin-catch for reliability.

**Conclusion:** Milestones fire at the **right narrative moments** (8–29 min ENGAGED).
Cash affordability lags by **23–51+ minutes** or never arrives. **Unlock timing is
correct; payment channel is wrong.**

---

## 4. Candidate Approaches — Evaluation Matrix

Scores: **1** poor · **3** acceptable · **5** excellent  
Complexity: **S** (<2 dev-days) · **M** (2–4) · **L** (5+)

### A) Milestone unlocks

*Manager HIRE button activates when empire reaches a beat; cost reduced or removed.*

| Criterion | Score | Notes |
|-----------|-------|-------|
| Implementation complexity | **M** | Unlock table + `can_hire()` + locked UI on manager cards |
| Save risk | **5** | Best if unlocks **computed** from existing fields (buildings, lifetime, heat, rank) — **zero new save keys** |
| UI impact | **3** | Padlock → "UNLOCKED" badge; milestone toast (reuse `_milestone_queue`) |
| Player clarity | **5** | Same mental model as `goals.py` — "I grew, I earned this" |
| Progression quality | **5** | Ties managers to empire story; hits Phase 108 windows |

**Pros:** Least invasive structurally; reuses goals/rank patterns; no second wallet.  
**Cons:** Unlock alone insufficient if full cash cost remains (see measured gap).

**Verdict:** **Core of recommended system** — must pair with non-competing payment.

---

### B) Dedicated manager budget

*Separate `manager_budget` accrues from income; buildings cannot spend it.*

| Criterion | Score | Notes |
|-----------|-------|-------|
| Implementation complexity | **L** | New balance, accrual rule, spend routing, HUD slot |
| Save risk | **3** | New field + migration default `0`; offline accrual edge cases |
| UI impact | **2** | Second money bar — crowded stats header (900px wide) |
| Player clarity | **2** | "Why two balances?" requires tutorial |
| Progression quality | **4** | Decouples fully once understood |

**Pros:** Hard separation from building wallet.  
**Cons:** Highest UI weight; teaches new resource; accrual rate is another tuning surface.

**Verdict:** **Rejected as primary** — effective but not *least invasive*. Viable fallback if milestone+free hire feels too generous.

---

### C) Influence costs (`prestige_tokens`)

*Managers cost Influence instead of cash.*

| Criterion | Score | Notes |
|-----------|-------|-------|
| Implementation complexity | **S–M** | Swap cost type on hire button |
| Save risk | **5** | No new fields |
| UI impact | **3** | Show token price; deduct from `prestige_tokens` |
| Player clarity | **2** | **Two "Influence" concepts** already confuse (`prestige_tokens` vs Respect field) |
| Progression quality | **2** | **Shifts competition to perk tree / turf** (~12 tokens to Made Man); Pete at 2 tokens delays Waterfront, perks |

**Pros:** Uses existing meta currency.  
**Cons:** Does not remove competition — moves it. Early run token budget is intentionally tight for rank/perk pacing.

**Verdict:** **Rejected for early managers (0–5)**. Optional for **late/post-prestige** managers (7–10) where cash is absurd and tokens are plentiful.

---

### D) Reputation / rank requirements

*Managers unlock at hierarchy rank or achievement.*

| Criterion | Score | Notes |
|-----------|-------|-------|
| Implementation complexity | **S** | `get_rank()` / achievement checks already exist |
| Save risk | **5** | Derived from existing state |
| UI impact | **3** | Rank badge on card ("Requires Associate") |
| Player clarity | **4** | Rank-ups already celebrated |
| Progression quality | **2** for early · **5** for late | Made Man ~30–60m — **too late for Pete/Sal** |

**Pros:** Perfect for Consigliere, Broker, Smuggler (post-prestige fantasy).  
**Cons:** Cannot gate first convenience managers without breaking Phase 108 windows.

**Verdict:** **Partial adopt** — rank gates for managers **index ≥ 7** only.

---

### E) Hybrid systems

*Combine milestone + payment decoupling + late rank gates.*

| Criterion | Score | Notes |
|-----------|-------|-------|
| Implementation complexity | **M** | Milestone table + nominal fee tier + rank overlay |
| Save risk | **4** | Mostly computed; optional `manager_unlock_seen` runtime flags for toasts |
| UI impact | **3** | Unlock badge + small fee or "FREE — unlocked" |
| Player clarity | **5** | "Reach milestone → hire from payroll" reads cleanly |
| Progression quality | **5** | Early natural, late aspirational |

**Verdict:** **Recommended.**

---

## 5. Recommended Acquisition System

### **Hybrid: Milestone unlock + nominal payroll fee (early) · Rank gate (late)**

Decouple **availability** from **building wallet competition**. Keep manager
personalities, list order, and `managers[]` hired-by-index save format.

#### Tier 1 — First run convenience (managers 0–5)

| # | Manager | Unlock when (computed) | Hire fee | Rationale |
|---|---------|--------------------------|----------|-----------|
| 0 | Sticky Pete | Lifetime ≥ $25K *(existing goal beat)* | **$5K** or free | ~12m ENGAGED; fee &lt; one dealer buy |
| 1 | The Collector | ≥ 3 Protection Rackets | **$25K** | Matches protection fantasy after racket investment |
| 2 | The Mechanic | ≥ 2 Chop Shops | **$50K** | Partial-auto predecessor |
| 3 | Lucky Sal | ≥ 1 Sports Betting Ring | **$100K** | Visible luck tier; avoids coin-click sim dependency |
| 4 | Clean Carl | Heat ≥ 40% once | **$200K** | Lawyer when heat matters |
| 5 | The Accountant | ≥ 4 distinct building types owned | **$500K** | Automation capstone; fee ≪ old $1.5M |

**Rules:**

- **Locked:** card greyed, padlock, unlock hint ("Own 3 Rackets").  
- **Unlocked, can't afford fee:** pulsing HIRE like today — fee is reachable without stopping building ladder for minutes.  
- **Unlocked + affordable:** one-click hire; toast + milestone overlay.  
- **No save migration:** unlock = pure function of `state`; `hired` bool unchanged.

#### Tier 2 — Post-prestige / empire scale (managers 6–10)

Keep **high cash costs** OR add **rank gate** (Capo / Boss / …) so they remain
second-cycle goals. Identity already **LATE** in Phase 107; no first-run change needed.

#### What this removes

| Player no longer… | Because… |
|-------------------|----------|
| Banks $40K–$2M while skipping buildings | Fee is 10–50× lower than old costs |
| Relies on reserve/nudge behavior | Unlock arrives **before** fee is trivial, not after prestige |
| Chooses manager vs next building on same ROI axis | Unlock is **earned**; fee is **payroll**, not IPS investment |

---

## 6. Rejected Alternatives (summary)

| Approach | Verdict | Why rejected |
|----------|---------|--------------|
| **Cash-only (status quo)** | Reject | Phases 106–107 proved unreachable; competes on IPS |
| **Lower cash costs alone** | Reject | Phase 106: greedy buyer still NEVER hires Accountant at $1.5M |
| **Dedicated manager budget (primary)** | Reject | Solves decoupling but **most UI/tutorial invasive** |
| **Influence costs (early managers)** | Reject | Competes with perk/turf tree; confuses token vs Respect |
| **Rank-only gates (early)** | Reject | Made Man too late for 10–20m convenience targets |
| **Achievements-only gates** | Reject | Irregular timing; hard to pace first run |
| **Free unlimited hires** | Reject | Removes all tension; no payroll moment |
| **Phase 106 nudges alone** | Reject as sole fix | Behavioral band-aid; OPTIMIZER Pete still ~20m+ |

---

## 7. Complexity & Migration Estimates

| Work item | Complexity | Save risk | Notes |
|-----------|------------|-----------|-------|
| `manager_unlocked(state, idx)` computed | **S** | None | Pure function over existing fields |
| Locked / unlocked manager card UI | **S** | None | `draw_panel` + `handle_click` guard |
| Nominal fee hire logic | **S** | None | Replace `balance >= mgr.cost` with unlock + fee |
| Milestone toasts on first unlock | **S** | None | Runtime flags (like Phase 106 nudges) |
| Proposed unlock table tuning | **M** | None | Sim pass with `_measure_p110.py` |
| Rank gates for managers 7–10 | **S** | None | Reuse `prestige.get_rank` |
| Dedicated budget (if ever needed) | **L** | Medium | New save field — defer |
| Influence-priced managers | **S** | Low | Deferred — not recommended early |

**Total recommended implementation (Phase 111):** **M (~3 dev-days)**  
UI + unlock logic + fee retune + milestone copy + measurement reg pass.

### Migration risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Old saves: managers never hired | **Low** | On load, recompute unlocks — players may instantly see unlocked cards (positive) |
| Old saves: Pete already hired | **None** | `hired[i]` preserved; unlock irrelevant |
| Order change breaks saves | **Critical** | **Do not reorder** `MANAGERS` list — costs/unlocks by index only |
| `cost` field semantics change | **Low** | Keep field for display/fee; document as payroll not building ROI |
| Players with modded/bloated saves | **Low** | Computed unlocks may fire immediately — acceptable |
| Goal double-reward feel | **Low** | Pete unlock aligns with $25K goal but **grants behavior**, not Influence |

---

## 8. Success Criteria — Will This Work?

| Criterion | Met? | How |
|-----------|------|-----|
| Managers don't compete with buildings | **Yes** | Unlock earned by building; fee ≪ building purchases |
| Managers don't compete with upgrades | **Yes** | Fee tier below mid-upgrade costs at unlock time |
| Managers don't compete with prestige savings | **Yes** | Fees are $5K–$500K vs $20M lifetime gate |
| Natural encounter without reserving | **Yes** | Unlock fires 8–29m; fee affordable shortly after without halting ladder |
| Preserve personalities / order / saves | **Yes** | No roster changes; hired-by-index unchanged |
| Preserve economy when possible | **Mostly** | Building/upgrade curves untouched; manager **fees** replace old **costs** |

**Projected first-run hires (ENGAGED, post-change estimate):**

| Manager | Unlock | Fee affordable (est.) | vs Phase 108 target |
|---------|--------|----------------------|------------------------|
| Sticky Pete | ~12m | ~13–15m | ✓ 10–18m |
| Lucky Sal | ~18m | ~20–22m | ✓ 12–20m |
| The Collector | ~2m (unlock) / hire ~15m | ~16–18m | ✓ 15–22m |
| The Accountant | ~29m | ~32–35m | ✓ 22–32m |

*(Estimates from unlock timing + nominal fee being 1–3 min of income at unlock.)*

---

## 9. Architectural Conclusion

**Least invasive path that satisfies access:**

> **Computed milestone unlocks + nominal payroll fee (early tier) · rank gates (late tier)**

This adds **no new currency**, **no new save fields**, **one new UI state** (locked
manager card), and reuses the **`goals.py` pacing philosophy** already tuned for
first prestige. It directly fixes the measured 23–51 minute gap between "should
hire" and "can afford without self-sabotage."

**Do not implement** dedicated budget or Influence-priced early managers unless
playtesting shows nominal fees still fail — those are heavier hammers.

---

## 10. Re-run timing analysis

```powershell
python _measure_p110.py
```

Related baselines:

```powershell
python _measure_p107.py   # greedy hire ceiling
python _measure_p109.py   # behavior value proof
```
