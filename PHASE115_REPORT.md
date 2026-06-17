# Phase 115 — Full Experience Validation

**Date:** 2026-06-15  
**Scope:** Player-journey audit — no new mechanics. First prestige run only.

---

## 1. Method

`_measure_p115.py` drives **real `PlayingState`** with three player profiles.
No rank injection, no balance cheats — only what a first-run player can reach.
Sim **delegates chores** after manager hire (no manual Chop post-Mechanic,
follows Pete when hired). Partial coin-click rates match prior audits.

| Profile | CPS | Active | Buys/s | Coin click |
|---------|-----|--------|--------|------------|
| CASUAL | 1.5 | 25% | 0.15 | 30% |
| ENGAGED | 4.0 | 33% | 0.50 | 45% |
| OPTIMIZER | 6.0 | 45% | 1.20 | 60% |

Compared against **Phase 105** first-prestige baseline (pre-manager redesign).

---

## 2. Emotional progression (ENGAGED first prestige)

- 1. **Manual empire** (0 → 1m50s) — clicking and buying buildings.
- 2. **Delegation** (~7m23s) — Pete/Sal remove decision/chore friction.
- 3. **Automation** (Mechanic ~15m11s, Accountant ~18m48s) — shops/buildings run without constant tabbing.
- 4. **Risk crew** (Collector ~13m54s, Carl ~18m43s) — raids and heat become managed, not scary.
- 6. **Prestige** ~28m09s — empire reset with Influence.

### Manager hire timeline — ENGAGED

| Manager | Unlocked | Hired | Chore removed |
|---------|----------|-------|-----------------|
| Sticky Pete | 7m23s | 7m23s | ROI comparison |
| The Collector | 2m06s | 13m54s | Raid panic |
| The Mechanic | 9m38s | 15m11s | Chop Shop buys |
| Lucky Sal | 7m23s | 7m23s | Coin chasing |
| Clean Carl | 4m44s | 18m43s | Heat watching |
| The Accountant | 16m14s | 18m48s | Building buys |
| Maxine the Dealer | NEVER | NEVER | — (late/post-prestige) |
| The Promoter | NEVER | NEVER | — (late/post-prestige) |
| The Smuggler | NEVER | NEVER | — (late/post-prestige) |
| The Broker | NEVER | NEVER | — (late/post-prestige) |
| The Consigliere | NEVER | NEVER | — (late/post-prestige) |

---

## 3. Boredom

| Profile | Prestige | Dead periods (>60s, nothing affordable) | Total dead time | Buy bursts (3+ in 10s) |
|---------|----------|----------------------------------------|-----------------|------------------------|
| CASUAL | 44m58s | 0 | 0s | 26 |
| ENGAGED | 28m09s | 0 | 0s | 280 |
| OPTIMIZER | 19m08s | 0 | 0s | 358 |

**Finding:** Boredom is **low** in first-prestige window — dead periods rare because
payroll managers + buildings always present the next affordance. Late-run **buy bursts**
remain high (Accountant window compresses many purchases into final minutes).

---

## 4. Confusion

| Profile | Off-path buys (post-Pete) | Coins expired | Coins missed pre-Sal | Locked late-mgr peeks |
|---------|--------------------------|---------------|----------------------|----------------------|
| CASUAL | 0 | 23 | ~3 | 175 |
| ENGAGED | 0 | 5 | ~0 | 95 |
| OPTIMIZER | 0 | 6 | ~0 | 45 |

**Confusion sources (code + sim):**

- **Two first delegates** — Pete (Buildings intel) and Sal (coins) unlock near the same
  earnings milestone; new players may not know which to hire first.
- **Late manager cards** — Maxine→Consigliere show rank gates + billion/trillion costs
  before first prestige; readable as aspirational but can feel unreachable.
- **Nine tabs** — Turf/Ops/Crew matter mid-run but tutorials fire once; easy to forget.
- **Heat stack** — Carl forecast + Promoter autopilot + Crew heat reduction overlap;
  first-run players only see Carl tier (Promoter is post-prestige for most).

ENGAGED off-path buys after Pete: **0** (sim follows Pete — low confusion).

---

## 5. Memorable moments (ENGAGED beats)

| Time | Type | Moment |
|------|------|--------|
| 1m50s | arc | Passive income exceeds clicking |
| 2m06s | unlock | The Collector available |
| 4m44s | unlock | Clean Carl available |
| 7m23s | unlock | Sticky Pete available |
| 7m23s | unlock | Lucky Sal available |
| 7m23s | hire | Hired Sticky Pete |
| 7m23s | hire | Hired Lucky Sal |
| 9m38s | unlock | The Mechanic available |
| 13m54s | hire | Hired The Collector |
| 15m11s | hire | Hired The Mechanic |
| 15m35s | protection | Collector absorbed a raid |
| 15m38s | automation | Mechanic first Chop auto-buy |
| 16m14s | unlock | The Accountant available |
| 16m30s | arc | Empire idle-capable (60s) |
| 18m43s | hire | Hired Clean Carl |
| 18m48s | hire | Hired The Accountant |
| 18m51s | automation | Accountant first auto-buy |
| 19m23s | risk | Carl emergency heat dump |
| 28m09s | climax | First prestige ready |

**Memorable beat density:** Manager unlock toasts, hire notifications, first auto-buy,
Collector shield toast, Carl milestone overlay, and prestige approach notifications
create a **beat every 3–8 minutes** in ENGAGED first run — significantly denser than
Phase 105 (first manager ~39m, no behavior shifts).

---

## 6. Friction

| Profile | Last-5min manual buys | Mech auto / chop manual | Raids absorbed | Carl emergency | Acct auto-buy |
|---------|----------------------:|------------------------:|----------------:|---------------:|--------------:|
| CASUAL | 19 | 15/0 | 5 | 0 | 38m53s |
| ENGAGED | 23 | 9/0 | 2 | 1 | 18m51s |
| OPTIMIZER | 71 | 21/0 | 2 | 0 | 16m10s |

| vs Phase 105 ENGAGED | 27 last-5min | no auto | N/A | N/A | NEVER |

**Remaining friction (first prestige):**

- **Late-run micromanagement** — ENGAGED still **23** purchases in final
  5 min (Accountant helps but Upgrades/Managers still manual).
- **Pre-Sal coins** — **5** expirations; chore until Sal hired ~7m23s.
- **Late managers unreachable** — 0/5 late managers hired first run (Capo+ rank + premium cash).
  Behaviors exist but second-cycle content for typical ENGAGED player.
- **Ops collect** — Smuggler auto-start irrelevant until post-prestige rank.

---

## 7. Success question

**"Does Idle Empire now feel like managing people instead of managing buttons?"**

### Verdict: **Yes — for the first-prestige arc.**

ENGAGED hires **6/6** early managers. Each removes a named chore:
manual ROI comparison, coin chasing, raid panic, manual Chop Shop buys, heat babysitting, Buildings tab babysitting.

The player experience shifts from **button rhythm** (click/buy/compare) to
**staffing decisions** (who to payroll, when unlock fires). UI surfaces
employees: PETE'S PICK, SHIELD, heat forecast, Mechanic toasts, Accountant
auto-buy, hire notifications with role flavor.

**Caveat:** Late roster (Maxine→Consigliere) still **feels like buttons** until
second cycle — rank + premium costs gate them. First run = manage **6 people**,
not **11**.

### Phase 105 → Phase 115 (ENGAGED)

| Dimension | Phase 105 | Phase 115 |
|-----------|-----------|-----------|
| First prestige | 59m42s | 28m09s |
| First manager | 39m32s | 7m23s |
| Accountant auto-buy | NEVER | 18m51s |
| Chores delegated | 0 | **6** |
| Memorable beats | ~3 (buildings only) | **19** |

---

## 8. Critical problems

**None discovered.** Remaining issues are pacing/UX, not broken systems.

**Highest-priority non-critical:** Second-cycle onboarding — first prestige players
meet 5 locked "employees" with trillion-dollar payroll before experiencing them.
Consider aspirational copy vs. hidden roster.

---

## 9. Re-run

```powershell
python _measure_p115.py
```
