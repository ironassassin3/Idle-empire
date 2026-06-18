# P5 — Parity Lockdown Report

**Date:** 2026-06-16  
**Status:** **Exit criteria met** (scoped deliverables + automated verify)  
**Next phase:** P6 — Audio & Feel

---

## Automated verification (run anytime)

```bash
# Full P5 gate (60s soak + income parity)
python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"

# Individual checks
python sim_income_parity.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
python sim_godot_soak.py --skip-income --seconds 60
```

**Last run:** 2026-06-16 — soak 60.00s / play_time 59.99s, zero `SCRIPT ERROR`; income parity PASS (3/3 fixtures, 1% tolerance).

---

## ROADMAP exit criteria

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Feature-parity matrix — no **stub** rows in P5 scope | **PASS** | Table below — all P5-scoped rows **Full** |
| Headless `game_screen` 60s sim, zero script errors | **PASS** | `headless_soak.gd` + `sim_godot_soak.py` |
| Income within tolerance vs pygame (fixed ticks) | **PASS** | `sim_income_parity.py` — fresh + 2 mid fixtures |
| Rival epitaph overlay + buff decay | **PASS** | `game_screen.gd` ElimPanel; `buff_system.gd` clears BW bonuses |

---

## P5 scoped deliverables (must be Full)

| Deliverable | pygame | Godot | Status |
|-------------|--------|-------|--------|
| Dragon patron (passive → HUD → abilities) | `src/dragon.py` | `dragon_system.gd`, `dragon_patron_overlay.*`, HUD chip | **Full** |
| Sticky Pete best-value highlight | `managers.py` | `manager_system.gd` + `building_row.gd` | **Full** |
| Lucky Sal + golden coin | `managers.py`, `states.py` | `game_state.gd`, `game_screen.gd` CoinBtn | **Full** |
| The Promoter heat autopilot | `managers.py` | `manager_system.gd`, `manager_row.gd` | **Full** |
| Rudy / Rob advice panels | `managers.py` | `prestige_advice`, `empire_efficiency_report` in UI | **Full** |
| Rival elimination epitaph overlay | `rivals.py` / UI | `show_elimination_overlay`, ElimPanel | **Full** |
| Event buff decay (`bw_*_bonus`) | `states.py` buffs | `buff_system.gd` | **Full** |
| Raid / first-heat tutorial hook | `tutorial.py` | `tutorial_system.gd` `on_police_raid` | **Full** |

No row in this table is stub-only.

---

## Full port matrix (pygame → Godot)

Broader audit for post-P5 debt. **Partial** = playable but formula/UI gap; **Missing** = not ported.

| System | pygame | Godot | Status | Notes |
|--------|--------|-------|--------|-------|
| Buildings | `buildings.py` | `building_defs.gd`, `game_state.gd` | **Full** | Arms influence fragments + loan shark cap/rate + betting jackpot formula ported (2026-06-17) |
| Managers (13) | `managers.py` | `manager_system.gd` | Partial | Hire unlock toasts; Carl heat forecast UI; late-roster collapse |
| Upgrades | `upgrades.py` | `upgrade_defs.gd` | **Full** | 25 upgrades, same effect keys |
| Prestige | `prestige.py` | `prestige.gd` | **Full** | `get_cumulative_rank_perks` + rank income/op/heat/territory bonuses ported (parity debt closed) |
| Prestige tree | `prestige_tree.py` | `prestige_tree.gd` | **Full** | S9 branches + legacy perks |
| Heat | `heat.py` | `heat_system.gd` | Partial | `reduce_heat` UI; Carl forecast (rank heat decay bonus now ported) |
| Territory | `territory.py` | `territory_system.gd` | Partial | milestone influence mult (rank_territory_bonus now ported) |
| Rivals | `rivals.py` | `rival_system.gd`, `rival_ai.gd` | **Full** | AI, defeat, epitaph |
| Crew | `crew.py` | `crew_system.gd` | **Full** | Five roles + save merge |
| Operations | `operations.py` | `operation_system.gd` | **Full** | `rank_operation_reward_bonus` now in reward mult |
| Events | `events.py` | `event_system.gd` | **Full** | 11-event pool |
| Goals | `goals.py` | `goal_system.gd` | Partial | `next_focus_hint` helper |
| Tutorial | `tutorial.py` | `tutorial_system.gd` | Partial | Banner UX only (no spotlight/skip rect) |
| Achievements | `achievements.py` | `achievement_system.gd` | **Full** | 74 achievements; stats panel browser |
| Save/load | `save_load.py` | `save_manager.gd`, `game_state.gd` | Partial | No `_migrate` layer; daily login reward; offline rival sim |
| Dragon | `dragon.py` | `dragon_system.gd` | **Full** | P5 complete |
| Offline | `save_load.py` | `offline_system.gd` | Partial | Cash + **rival sim events** OK (ported 2026-06-17); daily streak/reward still missing |
| Buffs | `states.py` | `buff_system.gd` | **Full** | BW bonus decay on expiry |
| Analytics | `analytics.py` | — | Missing | Intentionally pygame-lab only unless mobile telemetry added later |

**Income parity note:** Rank-perk gap closed (new `late_national` fixture, +10% rank income, matches pygame). Building specials are RNG/timer-driven and stay out of the deterministic income-parity gate by design — verified by formula-match to `src/buildings.py` + live 60s soak.

---

## Known follow-ups (not blocking P6)

1. ~~Port `get_cumulative_rank_perks` into `prestige.gd` (income / ops / heat / territory drift).~~
   **Done 2026-06-17** — full perk table + 4 bonus fns ported; income parity verified
   with new `late_national` fixture (+10% rank income matches pygame); 60s soak clean.
2. ~~Align building specials (Arms, Loan Shark, betting jackpot).~~
   **Done 2026-06-17** — betting jackpot (building IPS×30, 60–150s), loan shark
   (0.05%/min, cap 2 offices), Arms Broker influence fragments (+save/load) ported;
   chop aligned to single-proc/tick. Verified live in 60s soak (no script errors).
   *Note: specials are RNG/timer-driven, so not covered by the deterministic income
   parity gate — matched to `src/buildings.py` by formula + live-soak smoke.*
3. Daily login reward (offline rival simulation **done 2026-06-17** — deterministic
   seeded port in `offline_system.gd`, events shown in return overlay; verified by
   headless probe + clean scene soak). Daily login reward still pending → fold into P9.
4. Analytics — add only when mobile instrumentation is scoped.

---

## Artifacts added in P5 verify pass

| File | Purpose |
|------|---------|
| `sim_income_parity.py` | Pygame ↔ Godot IPS diff (3 fixtures) |
| `godot/scripts/tools/income_parity_probe.gd` | Godot side of income probe |
| `godot/scripts/tools/headless_soak.gd` | 60s `game_screen` live sim |
| `sim_godot_soak.py` | One-command P5 gate |
