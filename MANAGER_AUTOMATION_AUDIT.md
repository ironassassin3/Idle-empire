# Manager Automation Audit (2026-06-22)

Stress-tested with `sim_prestige_strategies.py` and cross-checked against `src/managers.py`, `godot/scripts/systems/manager_system.gd`, and `PHASE111_REPORT.md`.

## Verdict: **Needs tuning** (acceptable idle fantasy, too much too early)

Managers are intentionally designed to remove manual chores (Phase 111). That works for genre fans, but the **early stack (Pete → Sal → Mechanic → Accountant, all before first prestige)** collapses the Buildings loop and golden-coin micro-engagement while Turf/Rivals/Upgrades still need the player. Result: mid-session feels like watching notifications, not running an empire.

---

## What managers do

| Manager | Automation | Passive only |
|---------|------------|--------------|
| Sticky Pete | PETE'S PICK highlight (best income/$) | 1.5× Dealer income |
| The Collector | Raid shield (1st hit / 5m) | −35% raid damage, 1.5× Racket |
| The Mechanic | **Auto-buy Chop Shop** every 3s (2× cost buffer) | 1.5× Chop Shop |
| Lucky Sal | **Auto-collect golden coins** (~0.75s) | 1.5× Betting |
| Clean Carl | One free heat dump at 60% | Heat forecast, −30% heat gain |
| The Accountant | **Auto-buy best building** every 3s | 1.5× Loan Shark |
| Maxine | — | +10% speed to all manager behaviors per casino |
| The Promoter | **Heat autopilot** toward player target | — |
| The Smuggler | **Auto-start ops** + ready alerts (collect manual) | +30% op rewards |
| The Broker | Turf intel + **free retry** on failed capture | +15% turf success |
| Consigliere / Rudy / Rob | Prestige / empire **advisory only** | +20% Influence (Consigliere) |

**Not automated:** turf capture, rival actions, upgrade purchases (unless Talent Scout perk), op collection, prestige timing (advisory only).

**Stacking:** Prestige perk *Talent Scout* (`auto_buy`) also calls `_auto_buy_best` every 5s — duplicates Accountant after prestige.

---

## Unlock timing (ENGAGED sim, `_measure_p111.py`)

| Manager | Unlock / hire | vs first prestige (~31m) |
|---------|---------------|--------------------------|
| Pete, Sal | ~12m | Well before P1 |
| Mechanic | ~20m | Before P1 |
| Accountant | ~27m | **Before P1** |
| Late tier (Maxine+) | Capo+ rank | Post-P1 |

Real players must open Mgrs tab to hire; milestones prompt unlocks. Payroll ($3K–$65K) is cheap vs buildings.

---

## Sim evidence

`python sim_prestige_strategies.py --active 0.33 --minutes 120 --prestiges 10`

| Strategy | 1st prestige | P1→P2 gap | Final Influence @120m |
|----------|--------------|-----------|------------------------|
| **balanced** (managers) | 12m43s | 6m23s | **1797** |
| **no_managers** | 12m17s | 25m43s | 538 |
| **pure_idle** (10% active, managers) | 32m00s | 15m55s | 899 |

Pure idle comparison (10% active, no turf):

| | P1 | Influence @60m |
|--|-----|----------------|
| idle + managers | 31m40s | 109 |
| idle − managers | 33m49s | 40 |

**Takeaways**

- First prestige timing barely changes — gates are earnings/building based.
- **Post-P1 snowball is manager-driven** (3× Influence @120m engaged; ~2.7× @60m idle).
- Phase 111 ENGAGED run: **0 Pete-pick buys** after Accountant — recommendation UI becomes decorative.
- Sim hires managers without unlock gates; real game is slightly less aggressive but Accountant still lands pre-P1.

---

## Godot UX

| Surface | Status |
|---------|--------|
| Pete's Pick on building rows | ✅ Gold star + affordance |
| Autobuy notifications | ✅ Green/gold toast + subdued SFX |
| Heat autopilot label | ✅ Shown in heat bar |
| Broker turf intel | ✅ Highlight in turf UI |
| Prestige advisory | ✅ Consigliere / Rudy on prestige button |
| **Manager roster live status** | ❌ Thin — hired rows show only "On payroll" (pygame has AUTO badges, "Empire automation active", etc.) |
| **Bonus text accuracy** | ❌ `manager_defs.gd` lists income mults, not auto-buy behavior |

Silent automation is partially surfaced via notifications, but players can ignore Bldgs/Mgrs tabs entirely after hiring.

---

## Pain points

1. **Accountant auto-buys best building every 3s** — player never needs Buildings tab during idle; Pete's Pick redundant.
2. **Mechanic auto-buys Chop Shops** — second automation lane before first prestige.
3. **Sal auto-collects coins** — removes click micro-reward with no opt-out.
4. **Six early hires before P1** — "set and forget" achievable in first session.
5. **Talent Scout perk stacks** another auto-buy after prestige.
6. **Godot manager UI under-communicates** what is running on autopilot.

**Still requires player:** Turf, Rivals, Upgrades, prestige decision, op collection.

---

## Options (ranked)

| Rank | Option | Impact | Effort |
|------|--------|--------|--------|
| 1 | **A) Gate Accountant auto-buy later** (Made Man / post-P1; keep income mult early) | High — preserves early engagement | Low |
| 2 | **E) Better UX** (Godot manager status parity + honest bonus text) | Medium — doesn't fix autoplay feel | Low |
| 3 | **C) Split lanes** — managers = income boost; automation = late unlock or separate hire tier | High — clearest design | Medium |
| 4 | **D) Cooldowns / caps** (e.g. Accountant 1 buy / 15s, or % of balance per tick) | Medium | Low–medium |
| 5 | **B) Suggest, don't act** | High — changes idle identity | Medium |
| 6 | **Keep as-is** | — | Only if target is ultra-idle mobile |

---

## Recommendation

| Target | Action |
|--------|--------|
| **Godot 1.0 ship** | **A + E**: defer Accountant (and optionally Mechanic) **purchase automation** until post-P1 or Made Man; keep Pete/Sal/Collector as QoL. Port pygame manager status strings to `manager_row.gd`. Fix `manager_defs` bonus copy. |
| **Pygame lab** | Keep current behavior until Godot tuning is decided; re-run `sim_prestige_strategies.py` after gate changes before porting constants. |

Do **not** remove managers entirely — they're core idle progression. Tune **when** full automation kicks in and **how visibly** it runs.

---

## IMPLEMENTED (2026-06-22) — Option A + E

**Gate:** `MANAGER_AUTOBUY_REQUIRES_PRESTIGE` + `MANAGER_AUTOBUY_MIN_PRESTIGE_COUNT = 1` in `config.py` / `game_config.gd`.

| Behavior | Pre-P1 | Post-P1 |
|----------|--------|---------|
| Accountant auto-buy | Off (income mult on) | On |
| Mechanic Chop auto-buy | Off (income mult on) | On |
| Talent Scout / Kingpin Monopoly perk auto-buy | Off | On |
| Pete / Sal / Collector / Carl / Promoter / Smuggler | Unchanged | Unchanged |

**UX:** `manager_row.gd` shows AUTO pill — muted + "Unlocks after 1st prestige" when gated; green + "Auto-buying" when active. `manager_defs.gd` bonus copy updated.

**Files:** `src/managers.py`, `src/prestige_tree.py`, `config.py`, `godot/scripts/systems/manager_system.gd`, `godot/scripts/systems/prestige_tree.gd`, `godot/scripts/autoload/game_config.gd`, `godot/scripts/data/manager_defs.gd`, `godot/scripts/ui/manager_row.gd`, `godot/scenes/manager_row.tscn`.
