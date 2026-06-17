# Phase 120 — UI Cohesion Audit

**Date:** 2026-06-15  
**Scope:** Audit only — no code or balance changes. Evaluates whether presentation
matches systems after Phase 107–119 manager overhaul.

---

## 1. Root question

**Has Idle Empire become better than its presentation?**

**Verdict: Partially yes.** Backend systems (13 managers, heat autopilot, ops queue,
prestige strategists, empire dashboard) outpace what the UI surfaces persistently.
Players always see money and income/sec; automation and attribution are mostly
ephemeral (hire toasts, header micro-hints, tab-deep panels).

---

## 2. Method

`_measure_p120.py` drives **real `PlayingState`** with CASUAL / ENGAGED / OPTIMIZER
profiles (same cadence as Phase 105). Tab visits and dwell are simulated with
profile-weighted switching intervals (75s / 45s / 28s). Hierarchy checks run at
5m, 15m, 30m, and 60m. Cognitive-load counts sample early/mid/late snapshots.

---

## 3. Tab usage metrics

### CASUAL (sim 31m02s, P1 11m02s)

| Tab | Visits | Dwell (s) | Share |
|-----|--------|-----------|-------|
| buildings | 14 | 972 | 46.5% |
| stats | 8 | 381 | 18.2% |
| managers | 23 | 376 | 18.0% |
| upgrades | 4 | 214 | 10.2% |
| operations | 2 | 81 | 3.9% |
| territory | 2 | 67 | 3.2% |

### ENGAGED (sim 30m46s, P1 10m46s)

| Tab | Visits | Dwell (s) | Share |
|-----|--------|-----------|-------|
| buildings | 21 | 630 | 27.8% |
| managers | 35 | 420 | 18.5% |
| upgrades | 16 | 355 | 15.7% |
| territory | 8 | 234 | 10.3% |
| crew | 10 | 224 | 9.9% |
| stats | 6 | 170 | 7.5% |
| operations | 6 | 139 | 6.1% |
| rivals | 5 | 95 | 4.2% |

### OPTIMIZER (sim 26m40s, P1 6m40s)

| Tab | Visits | Dwell (s) | Share |
|-----|--------|-----------|-------|
| buildings | 24 | 560 | 29.1% |
| managers | 35 | 444 | 23.1% |
| stats | 22 | 357 | 18.6% |
| crew | 10 | 156 | 8.1% |
| operations | 8 | 121 | 6.3% |
| upgrades | 8 | 107 | 5.6% |
| rivals | 6 | 103 | 5.4% |
| territory | 6 | 76 | 3.9% |

### Tab audit (ENGAGED)

- **Most dwell:** buildings (28%), managers (19%), upgrades (16%)
- **Rarely visited (<4% dwell):** none
- **Hidden too deep:** Rob dashboard & heat breakdown (Stats scroll); Broker intel (Territory);
  Consigliere/Rudy tables (Prestige button only); Achievements (Stats footer button → pushed state).
- **Achievements access:** ENGAGED opened Stats 6×; achievements overlay reachable from Stats footer only (not a main tab).
- **Ops ready indicator:** Main-tab dot checks `key == 'operations'` but Ops lives under Turf sub-tab —
  pulsing ready cue likely **never fires** on the tab bar players see.

---

## 4. Information hierarchy

Can players immediately answer the seven core questions?

| Question | Always visible? | Confusion points |
|----------|-----------------|------------------|
| How much money am I making? | **Yes** — balance + ▲ ips/sec in header | Prestige mult pill only after first prestige |
| What is my next goal? | **Mostly** — goals panel + ▸ hint | Goals column hides in portrait; late-game hint often empty |
| What should I buy next? | **Only on Buildings tab** | Pete's PETE'S PICK requires Pete hire + tab visit |
| Which manager just helped me? | **No** | Silent auto-buys (Mechanic, Accountant); raids absorbed off-screen |
| What systems are automated? | **Partial** | v AUTOMATED on cards; no global automation strip |
| Why should I prestige? | **Only when unlocked** | Locked button shows reqs, not benefits; Influence value unclear early |
| What problem needs attention? | **Partial** | Heat/RAIDS in header; ops-ready lacks tab cue; rival threats buried in Turf |

**CASUAL confusion themes (1):** Prestige benefits hidden until gate opens
**ENGAGED confusion themes (1):** Prestige benefits hidden until gate opens
**OPTIMIZER confusion themes (1):** Prestige benefits hidden until gate opens

---

## 5. Header audit

| Element | Permanent? | Assessment |
|---------|------------|------------|
| Money (balance) | Yes | Clear, gold, largest type — **keep** |
| Income/sec | Yes | Row 2 left — **keep** |
| Heat bar + % | Yes | Compact; raid tick at 60% — **keep** |
| Shield / forecast / AUTO≤N | Conditional | Only when Collector/Carl/Promoter hired — **good but easy to miss** |
| Rank + progress | Yes | Useful gate preview — **keep** |
| News ticker | Yes | Flavor + system hints — low priority vs heat hints when crowded |
| Prestige recommendation | **No** | Lives on left prestige button, not header — optimizers may never look |

**Deserves permanent space:** balance, ips/sec, heat, rank progress.  
**Deserves a dedicated automation/status strip (currently absent):** active auto-buy,
Sal coin mode, Smuggler queue, Promoter target.

---

## 6. Cognitive load (ENGAGED snapshots)

| Phase | Tab sampled | Buttons | Meters | Labels | Locked | Warnings | Auto msgs |
|-------|-------------|---------|--------|--------|--------|----------|-----------|
| early | buildings | 13 | 2 | 25 | 0 | 0 | 0 |
| mid | managers | 8 | 2 | 27 | 7 | 0 | 0 |
| late | stats | 2 | 2 | 35 | 0 | 0 | 1 |

**Feel:** Early game ≈ manageable empire UI; mid Managers tab ≈ **spreadsheet of cards**
(13 rows, rank bars, LOCKED badges); late Stats tab ≈ **dashboard dump** (2600px virtual scroll).
Player manages numbers in panels more than a city scene (scene shrinks for goals reserve).

---

## 7. Manager visibility

| Manager | UI surface | Invisible in sim? |
|---------|------------|-------------------|
| Sticky Pete | Buildings PETE'S PICK badge | No |
| The Collector | Header SHIELD hint | No |
| The Mechanic | Silent Chop auto-buy | No |
| Lucky Sal | Golden coin SAL label | No |
| Clean Carl | Header heat forecast | No |
| The Accountant | Silent building auto-buy | No |
| Maxine the Dealer | Managers card +N% badge | **Yes** |
| The Promoter | Header AUTO≤N + card target | No |
| The Smuggler | Ops auto-start + notifications | **Yes** |
| The Broker | Territory BROKER glow | **Yes** |
| The Consigliere | Prestige button advice | No |
| Rudy Riches | Prestige window table | No |
| Rob Revenue | Stats ROB dashboard | No |

**Consistently invisible helpers (never noticed within 120s of hire in 2+ profiles):** Maxine the Dealer, The Broker, The Smuggler

**Most visible:** Sticky Pete (Buildings badge), Promoter (header AUTO), Collector (SHIELD).  
**Most invisible:** Maxine, Broker (tab-deep, no ambient cue); Smuggler (ops buried under Turf).  
**Silent but detected:** Mechanic & Accountant auto-buys fire in sim but show no UI attribution.

---

## 8. Visual identity

The UI reads as **"a collection of menus and numbers"** more than **"a growing criminal empire"**:

- **Color:** Consistent dark navy + gold accent (`theme.py`) — cohesive but generic idle-game palette.
- **Typography:** 4-tier font scale; xs-heavy tab labels feel utilitarian.
- **Spacing:** Header and tab bar clean; Stats and Managers panels dense.
- **Panel hierarchy:** Left guidance (goals) vs right spreadsheet (tabs) — empire scene is deprioritized.
- **Theme cohesion:** Copy/flavor strong in manager cards; chrome is neutral dashboard.

---

## 9. Locked content audit

| Profile | Locked manager peeks | Dwell on locked exec cards |
|---------|---------------------|----------------------------|
| CASUAL | 21 | 301s |
| ENGAGED | 35 | 420s |
| OPTIMIZER | 29 | 403s |

- **Rank requirement confusion:** LOCKED cards show rank gates but Executive teaser appears only at Made Man;
  CASUAL spends less time on Managers tab — discovers late roster late.
- **Collapsed presentation:** Phase 117 teaser/collapse helps; still **6+ locked exec rows** visible when expanded.
- **Recommendation:** Default-collapse locked exec section; surface *next unlock* in goals/header instead.

---

## 10. Success question

| Dimension | Clear? | Gap |
|-----------|--------|-----|
| What is happening? | Partial | Income yes; manager actions often silent |
| Why is it happening? | Weak | Heat bonus/raid rules in tooltip only |
| Who is helping? | Weak | No attribution feed |
| What to do next? | Good early | `next_focus_hint` + goals; fades late |

---

## 11. UI strengths (keep)

1. **Header economy triad** — balance, ips/sec, heat always readable.
2. **Goals + next-focus hint** — answers "what now" for first hour.
3. **Prestige button progress** — live requirement rows while locked.
4. **Manager card flavor** — specialty lines communicate fantasy.
5. **Rob dashboard** — best post-overhaul information design (labeled shares + recommendations).
6. **Turf sub-tab visibility while locked** — Phase 102 pattern reduces surprise gates.

---

## 12. Recommendations only (no implementation)

1. **Automation status strip** — persistent icons for Accountant/Mechanic/Smuggler/Sal/Promoter state.
2. **Manager attribution toasts** — brief "Mechanic bought Chop Shop" / "Collector blocked raid".
3. **Fix Ops ready indicator** — pulse on Turf→Ops sub-tab (or main Turf tab when op ready).
4. **Collapse locked Managers by default** — show next unlock + rank progress in goals.
5. **Prestige "why" while locked** — one line: "Reset for Influence → permanent income".
6. **Stats tab tiering** — Rob dashboard + session cards above fold; lifetime stats collapsed.
7. **Reduce mid-game tab overload** — merge Crew into Managers or surface crew summary on Buildings.
8. **Empire visual weight** — enlarge scene or tie building count to header skyline motif.

---

## 13. Primary conclusion

**Presentation has fallen behind systems** for automation transparency and manager attribution.
Core economy readability remains strong; the gap is *delegation visibility* — players earn helpers
but often cannot see them working. Address attribution and tab-depth before a full visual redesign.

---

## 14. Re-run

```powershell
python _measure_p120.py
```
