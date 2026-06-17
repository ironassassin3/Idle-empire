# P2–P5 Session Handoff — Criminal Empire Godot Port

Copy everything inside the **prompt block** below into a new Cursor chat to continue work.

---

## Prompt (paste this)

```
You are continuing the Criminal Empire Godot 4 GDScript port (hybrid approach).

## Project
- **Open in Godot:** `d:\2d_game\godot\project.godot` (NOT `criminal-empire-(4.3)/`, NOT repo root)
- **Reference implementation (mechanics source of truth):** Python pygame-ce at `d:\2d_game\` — run with `python main.py`
- **Read first:** `d:\2d_game\godot\P2_HANDOFF.md`, `d:\2d_game\CLAUDE.md`, `d:\2d_game\godot\README.md`
- **Architecture map (optional):** `d:\2d_game\graphify-out\port\GRAPH_REPORT.md` + `graph.json` — rebuild after big changes: `/graphify` on `src/` + `godot/scripts` with `--update`.
- **Godot version on user's machine:** 4.6.3 (`E:/Downloads/Godot_v4.6.3-stable_win64.exe`)
- **Constraint:** No generative AI image assets (see CLAUDE.md Art & Assets)

## Hybrid approach (do NOT abandon)
- Port **mechanics faithfully** from `src/*.py` — same numbers, save fields, income pipeline
- **Do NOT port** pygame `draw_panel()` — rebuild each tab as Godot scenes (ScrollContainer + row prefabs)
- Keep pygame sim/tests as balance reference; Godot gets Godot-native UI (touch-friendly)
- One save schema shared with pygame (`save.json` keys + migration defaults)

## P1 completed (do not regress)
- Core loop: 11 buildings, click, upgrades, prestige, heat + police raids
- `ManagerSystem` — Mechanic, Accountant, Collector, Carl, Consigliere (+ Smuggler/Broker in P4)
- `compute_base_income` — manager bonus by `building_index`, casino/racket globals, prestige perk mults
- Save: buildings, managers, upgrades, manager runtime fields
- Title + game scenes use `CanvasLayer`; theme `theme/noir_theme.tres`

## P2 status — Done

| # | System | Notes |
|---|--------|-------|
| Territory | 20 districts, warfare, milestones, rival-held blocked on turf tab |
| Rivals | 5 factions, player actions, defeat rewards, activity log |
| Crew | 5 roles, unlock @ 5 buildings, wired to income/heat/turf/raids |
| Operations | 5 ops, timers, crew+cash+turf gates, Cartel perk mults |
| Stats | Tiered sections, peak IPS, throttled refresh, achievements browser |

## P3 status — Done

| # | System | Notes |
|---|--------|-------|
| Achievements | 74 defs, +1% IPS each, save `achievements[]` |
| Prestige perk tree | 4 branches × 4 perks + overlay; `perks_purchased[]`, `prestige_branch` |
| Graphify port map | `graphify-out/port/` |

## P4 status — Done (session 2026-06)

| # | System | Notes |
|---|--------|-------|
| Rival AI parity | Full `_take_action`, Blackwater indirect AI, rival-vs-rival — `rival_ai.gd` |
| Manager ops | Smuggler +30% op reward, auto-start/ready toasts; Broker +15% turf, retry CD, intel UI |
| Events | 11 syndicate events (6 generic + 5 Blackwater), choice overlay — `event_system.gd` |
| Goals | 21 goals, influence faucet, save `goals_completed[]` — `goal_system.gd` |
| Tutorial + milestones | 5-step banner, tab/heat/respect popups, milestone queue — `tutorial_system.gd` |
| Config tab | 9th tab **Cfg**: volume, FPS, particles, reset tutorial, delete save |
| UI polish (partial) | Tab badges (`Crew 3/5`, `Ops*`, `Turf ★`), turf header ops/broker hints |
| Offline return | Load-time passive + welcome overlay — `offline_system.gd` |
| Buffs | Syndicate/event income + op mults — `buff_system.gd` |
| Dragon | **Save stubs only** (`dragon_key`, `dragon_xp`, `dragon_stage`, `dragon_abilities[]`) |

### P4 bug fixes (still valid)
- **`trait` reserved** in Godot 4.6 → use `trait_text` in rival row UI
- **No `//` integer division** in GDScript — use `int(x / 3600.0)` not Python `//` (breaks parse → purple screen)
- **`prestige_tree.gd` `BRANCH_ORDER`** must be literal strings, not `PackedStringArray([KINGPIN, ...])` (4.6 const expression rule)
- Rival elimination: defeat bonus replaces attack loot (no double-pay)
- Rival attack gate: `max($25k, IPS×20)`; turf on rival land blocked on turf tab
- Main menu New Game: always `GameState.reset_new_game()` after optional save delete

### P3 behavior notes (still valid)
- **PRESTIGE** opens `prestige_tree_overlay.tscn` (not instant prestige)
- Prestige influence → both `prestige_tokens` and `influence` (Respect)
- Prestige reset clears `prestige_branch`; owned perks persist; `peak_income` resets per cycle

## Gaps / partial ports (P5 should know)

- **Dragon patron:** save stubs only — no gameplay/UI (`src/dragon.py` is large; affects income/ops/rivals in pygame)
- **Golden coin + Lucky Sal:** coin spawn, autocollect, `coins_caught` achievement
- **Sticky Pete:** best building pick highlight on Bldgs tab
- **The Promoter:** heat autopilot to player target (`tick_promoter_heat` in pygame)
- **Rudy Riches / Rob Revenue:** prestige strategist + empire analyst dashboards
- **Rival elimination overlay:** pygame full-screen epitaph (`_elim_overlay`); Godot uses notification text only
- **Event buff cleanup:** `bw_attack_bonus` / `bw_negotiate_bonus` state fields don't decay with buff timer — verify parity
- **Audio:** Config volume sliders save but no SFX/music playback wired yet
- **Prestige tree UI polish:** first-visit banner, perk hover detail panel, Dragon Patron button
- **Motion pass (Phase 128):** shield pulse, hustle/crit toasts, auto-buy motion — not started on Godot
- **Pygame import:** new P4 save keys (`goals_completed`, tutorial flags, settings) may need migration defaults when importing old pygame saves (Godot-only keys ignored by pygame)

## Key Godot files

| Area | Path |
|------|------|
| Simulation hub | `scripts/autoload/game_state.gd` |
| Save | `scripts/autoload/save_manager.gd` |
| Events / goals / tutorial / offline / buffs | `event_system.gd`, `goal_system.gd`, `tutorial_system.gd`, `offline_system.gd`, `buff_system.gd` |
| Rivals AI | `scripts/systems/rival_ai.gd`, `rival_system.gd` |
| Managers | `scripts/systems/manager_system.gd`, `operation_system.gd` (Smuggler tick) |
| Prestige tree | `prestige_tree.gd`, `prestige_tree_overlay.gd` |
| Main UI + overlays | `scripts/ui/game_screen.gd`, `scenes/game_screen.tscn` (OverlayLayer: event/milestone/offline) |
| Row prefabs | `scenes/*_row.tscn` |

## UI tabs (9)

`game_screen.gd` enum `Tab { BLDGS, UPGRS, TURF, RIVALS, CREW, OPS, STATS, MGRS, CONFIG }`

Overlays (priority): offline → syndicate event → milestone queue → tutorial banner.

## Income pipeline (add since P3)

After achievement mult, multiply by `BuffSystem.income_mult()` (syndicate/event buffs).

Op rewards: `ManagerSystem.operation_reward_mult()` (Smuggler) × `BuffSystem.operation_reward_mult()` × Cartel/district perks.

## Save fields (P4 additions)

Goals: `goals_completed[]` (keys only; defs rebuilt on load).

Tutorial: `tutorial_step`, `shown_*_tutorial` flags (raid, ops, crew, turf, rivals, influence, heat, syndicate).

Settings: `master_volume`, `sfx_volume`, `music_volume`, `mute_all`, `fps_cap`, `show_particles`.

Dragon stubs: `dragon_key`, `dragon_xp`, `dragon_stage`, `dragon_abilities[]`.

Runtime (not saved): `buffs[]`, `pending_event`, `milestone_queue`, `broker_retry_cd`, `smuggler_timer`, `show_offline_overlay`.

## Godot 4.6 gotchas

- **No `//`** — integer division: `int(a / b)` or `a / b` with int cast
- **`trait` reserved** — never as variable name
- **Const arrays:** literal values only in `const X = [...]` when using PackedStringArray
- **Strict typing** on ternary/`:=` locals
- **Autoload + class_name:** preload from callers, not cross-autoload refs in class bodies
- **Headless verify:**
  `"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --path "d:\2d_game\godot" --headless "res://scenes/game_screen.tscn" --quit-after 3 2>&1 | Select-String "SCRIPT ERROR"`

## Architecture rules

- All rates × `dt` in `_process`
- `_ips_dirty` at tick start; `income_per_second()` cached once per frame
- Milestone strings: `\n` separator (title line, then body)
- Do not commit unless user asks

## Recommended next work (P5) — pick one slice per session

### Slice 1 — Polish & feel (recommended first)
- Rival **elimination overlay** (full-screen epitaph like pygame `_elim_overlay`)
- **Raid / first-heat tutorial** milestones (`shown_raid_tutorial`, heat 50% warning — partial in `tutorial_system.gd`, wire heat raid path)
- **Motion pass (Phase 128 lite):** Collector shield pulse on heat bar, hustle streak indicator, goal-complete toast styling
- **Event buff decay:** tie `bw_attack_bonus` / `bw_negotiate_bonus` to buff `remaining` or clear on expiry

### Slice 2 — Remaining managers
- **Sticky Pete** — best income/$ affordable building highlight (`managers.py` `petes_pick`)
- **Lucky Sal + golden coin** — floating coin, autocollect, `coins_caught` save + achievement
- **The Promoter** — heat autopilot target cycle (40/50/60%)
- **Rudy / Rob** — prestige advice + income breakdown panels (Stats or Mgrs sub-panel)

### Slice 3 — Dragon patron (large)
- Port `src/dragon.py` in phases: passive mults → HUD widget → abilities/requests
- Wire prestige-tree Dragon Patron button; remove stub-only status
- Save migration for dragon fields already stubbed

### Slice 4 — Save / QA / graphify
- Pygame save import test with P4 fields; document Godot-only keys
- Headless smoke: load save → tick 60s sim → verify no script errors
- `/graphify` update on `src/` + `godot/scripts`
- Optional: switch renderer from Forward Plus to **Compatibility** (2D-only project)

### Slice 5 — Mobile prep (defer until parity stable)
- Touch targets audit on row prefabs
- Export templates + portrait lock in `project.godot`
```

---

## P5 session plan (detail for next agent)

**Goal:** Move from “feature-complete P4” to **polish + remaining pygame parity** without regressing income/save.

### Session order (suggested)

| Priority | Slice | Est. effort | Deliverable |
|----------|-------|-------------|-------------|
| **P5-A** | Polish & feel | Medium | Elimination overlay scene, raid tutorial hook, buff decay fix, 2–3 motion cues |
| **P5-B** | Pete + Sal + coin | Medium | Pete highlight on building row; coin spawn/collect loop; Sal autocollect |
| **P5-C** | Promoter + Rudy/Rob | Medium | Heat autopilot; prestige advice labels on left panel or Stats |
| **P5-D** | Dragon phase 1 | Large | Passive mults + HUD chip only (no full ability tree yet) |
| **P5-E** | QA + graphify | Small | Import test matrix, headless smoke script, update `graphify-out/port/` |

### P5-A acceptance checklist
- [ ] Defeating a rival shows overlay with faction epitaph + rewards (not just toast)
- [ ] First police raid triggers milestone popup once
- [ ] `bw_negotiate_bonus` clears when `bw_negotiate` buff expires
- [ ] Headless `game_screen.tscn` — zero SCRIPT ERROR
- [ ] New Game → play 2 min → syndicate event appears and resolves without crash

### P5-B acceptance checklist
- [ ] Pete highlights one building row when Mechanic-tier manager hired/unlocked
- [ ] Golden coin appears periodically; Sal autocollects when hired
- [ ] `coins_caught` increments and saves

### Do NOT start P5 until
- Confirm game runs past title menu (purple-screen compile bugs fixed in P4 tail session)
- Run headless check above

---

## Context for the agent

### Repo layout
```
d:\2d_game\
  main.py              ← pygame entry (still full game)
  src/                 ← mechanics source of truth
  save.json            ← pygame save (importable from Godot title screen)
  graphify-out/port/   ← architecture graph
  godot/               ← ONLY Godot project to use
    project.godot
    P2_HANDOFF.md
    scenes/            main_menu, game_screen (+ OverlayLayer), prestige_tree_overlay, *_row
    scripts/
      autoload/        game_state, save_manager, game_config, format_util
      systems/         territory, rival, rival_ai, crew, operation, manager, heat,
                       prestige, prestige_tree, achievements, event, goal, tutorial,
                       offline, buff, world_state
      ui/              game_screen, main_menu, prestige_tree_overlay, *_row, game_theme
      data/            building, upgrade, manager defs
    theme/noir_theme.tres
```

### P4 deliverables (completed this session)

**Rival AI** — `rival_ai.gd`: `_grow`, `_take_action`, `_blackwater_action`, rival-vs-rival, catch-up wealth, Collector raid formula.

**Manager ops** — Smuggler: +30% op reward, `tick_smuggler_ops` every 2s. Broker: +15% turf success, 5min retry on fail, green BROKER button intel.

**Events / goals / tutorial** — Full event pool + `OverlayLayer` choice UI; 21 goals with influence faucet; milestone queue + 5-step tutorial banner.

**Config** — 9th tab with volume/FPS/particles, reset tutorial, delete save.

**Offline** — `save_timestamp` delta → passive earnings × offline mult → welcome overlay.

**Bug fix** — GDScript `//` parse failure broke all autoloads (purple screen).

### UI tab state
9 tabs including **Cfg**. PRESTIGE opens perk tree overlay. Overlays block input when active.

### Headless sanity check
```powershell
& "E:/Downloads/Godot_v4.6.3-stable_win64.exe" --path "d:\2d_game\godot" --headless "res://scenes/main_menu.tscn" --quit-after 3 2>&1 | Select-String "SCRIPT ERROR"
& "E:/Downloads/Godot_v4.6.3-stable_win64.exe" --path "d:\2d_game\godot" --headless "res://scenes/game_screen.tscn" --quit-after 3 2>&1 | Select-String "SCRIPT ERROR"
```
Empty output = scripts compile.

### Graphify
Update after P5: `/graphify d:\2d_game\src d:\2d_game\godot\scripts --update`

### Presentation saga (pygame reference only)
Phases 121–127 done on pygame. Godot: Phase 125 turf badges partial (tab/header hints); Phase 128 motion queued for P5-A.
