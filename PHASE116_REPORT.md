# Phase 116 — Second-Cycle Experience Audit

**Date:** 2026-06-15  
**Scope:** Prestige 1 → Prestige 2 — no implementation, measurement only.

---

## 1. Method

`_measure_p116.py` runs **two full prestige cycles** via real `PlayingState`
and `PrestigeManager.execute`. Greedy building buyer, one manager hire per
step, chore delegation (no manual Chop post-Mechanic, no manual ops post-Smuggler),
Broker-guided turf when hired. **Cycle 2:** second prestige deferred until
≥20 min of post-P1 play (player expands org before reset).
Max sim window: 480 min.

---

## 2. Timeline — Prestige 1 & 2

| Profile | Prestige 1 | Prestige 2 | Cycle 2 duration | Late mgrs hired |
|---------|------------|------------|------------------|-----------------|
| CASUAL | 14m45s | 34m45s | 20m00s | 3/5 |
| ENGAGED | 13m10s | 33m10s | 20m00s | 4/5 |
| OPTIMIZER | 6m05s | 26m05s | 20m00s | 3/5 |

*ENGAGED P2 gate first eligible ~14m12s; player prestiges ~33m10s after 20m minimum cycle-2 play.*

### Late manager acquisition — ENGAGED

| Manager | Unlocked | Hired | First behavior | Behavior |
|---------|----------|-------|----------------|----------|
| Maxine the Dealer | 13m11s | 14m15s | 14m16s | behavior mult 1.30× |
| The Promoter | 13m11s | 14m24s | 14m24s | autopilot ≤50% |
| The Smuggler | 20m00s | 20m00s | NEVER | — |
| The Broker | 30m00s | 30m00s | 30m00s | turf intel active |
| The Consigliere | NEVER | NEVER | NEVER | — |

---

## 3. Emotional beats

| Profile / Cycle | Unlocks | Hires | Automation | Protection | Prestige rec | Total beats | Avg interval |
|-----------------|---------|-------|------------|------------|--------------|-------------|--------------|
| CASUAL C1 | 6 | 6 | 2 | 1 | 0 | 16 | 0m49s |
| CASUAL C2 | 9 | 9 | 3 | 1 | 0 | 23 | 0m54s |
| ENGAGED C1 | 6 | 6 | 2 | 1 | 0 | 16 | 0m44s |
| ENGAGED C2 | 10 | 10 | 3 | 1 | 0 | 25 | 0m49s |
| OPTIMIZER C1 | 6 | 6 | 2 | 1 | 0 | 16 | 0m20s |
| OPTIMIZER C2 | 9 | 9 | 3 | 1 | 0 | 23 | 0m54s |

**ENGAGED cycle 2 feels:** **alive** — 25 beats vs 16 in cycle 1; avg gap 0m49s vs 0m44s.

---

## 4. Locked roster visibility (ENGAGED)

- **A) Staring at unavailable managers?** **Yes — significant** — 4005s aggregate tab time with 5 locked late cards (89 peeks; longest streak 66m45s).
- **B) Lock requirements understandable?** **Mostly yes** — cards show rank gate text (`Requires: Reach rank Capo`, etc.) plus premium cost label; early tier uses plain milestones.
- **C) Hide future employees?** **Recommend partial hide** — cycle 1 players see five aspirational trillion-dollar locks before experiencing the org; hiding ranks >1 above current or collapsing to "Coming soon" would reduce noise without losing goals.
- **D) Trillion costs intimidating?** **Yes for first-time viewers** — Consigliere $2T reads as unreachable during cycle 1; by cycle 2 rebuild, ENGAGED reached late hires prove affordability eventually.

---

## 5. Delegation audit — late managers (ENGAGED)

| Manager | Hired | Player stops… | Behavior noticed? |
|---------|-------|---------------|-------------------|
| Maxine the Dealer | 14m15s | tuning each manager separately | Yes |
| The Promoter | 14m24s | manual heat dumping | Yes |
| The Smuggler | 20m00s | manual op launches | Hired late — little runway |
| The Broker | 30m00s | blind turf picks | Yes |
| The Consigliere | NEVER | guessing prestige timing | No — not hired |

---

## 6. Cycle 1 vs Cycle 2 comparison (ENGAGED)

| Dimension | Cycle 1 (Pete→Accountant) | Cycle 2 (Maxine→Consigliere) | Stronger |
|-----------|---------------------------|------------------------------|----------|
| Duration | 13m10s | 20m00s | C2 |
| Memorable beats | 16 | 25 | C2 |
| Avg beat interval | 0m44s | 0m49s | C1 |
| Last-5min manual buys | 62 | 150 | C1 |
| New manager types | 6 early behaviors | 4 late behaviors | C1 breadth |

**Which cycle feels stronger?** Cycle 1 delivers the **core identity shift** (buttons → people).
Cycle 2 adds **organizational depth** when late managers land; if rank/cash gates delay hires,
cycle 2 can feel like **rebuilding cycle 1** until Capo+ window opens.

---

## 7. Success criteria

**Target:** *"Expanding the organization"* not *"Repeating cycle one with bigger numbers."*

### Verdict: **Expansion — organization grows.**

ENGAGED hired **4/5** late managers with **3** verified behaviors before Prestige 2. Cycle 2 adds Turf/Ops/Heat/Prestige staff beyond early crew re-hires.

---

## 8. Remaining bottlenecks (recommendations only)

- **Rank pacing** — Capo→Kingpin gates cluster late hires mid-cycle 2; consider showing progress toward next *employee* unlock alongside rank UI.
- **Roster clarity** — collapse or hide late managers until Associate/Made Man; reduces cycle-1 "trillion-dollar intimidation" without removing goals.
- **Smuggler collect loop** — auto-start without collect automation leaves Ops tab partially manual; players may not *feel* ships sailing.

---

## 9. Re-run

```powershell
python _measure_p116.py
```
