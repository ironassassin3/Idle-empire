# Project: Criminal Empire — 2D Idle Game (pygame-ce)

## What This Is
A modular idle/incremental game where the player builds a criminal empire. Core loop: buy buildings → earn income/s → buy upgrades → gain Influence → prestige. Layered systems: heat, territory warfare, rival factions, crew assignments, illegal operations, prestige perk tree.

## Commands
```
python main.py        # run the game
pip install pygame-ce # install dependency (pygame-ce, NOT pygame)
flake8 .              # lint (if installed)
```

## Key Files
| File | Purpose |
|---|---|
| `main.py` | Engine entry point. `MenuState` → `PlayingState` handoff only. |
| `config.py` | All constants: `SCREEN_WIDTH=900`, `SCREEN_HEIGHT=720`, `FPS`, colours, font sizes. |
| `src/states.py` | `PlayingState` — main game loop: `update()`, `draw()`, `handle_events()`. Tab routing, milestone queue, achievement throttle, income cache. |
| `src/buildings.py` | 11 `Building` dataclasses, `draw_panel()`, `handle_click()`, `update_building_specials()`. |
| `src/managers.py` | 11 manager objects, `compute_base_income()`. |
| `src/upgrades.py` | Tiered upgrades with `effect_key` system. |
| `src/prestige.py` | Prestige/Influence system, 13 `HIERARCHY` ranks (Street Hustler → Shadow Government), `RANK_UNLOCKS`. |
| `src/prestige_tree.py` | Perk tree, `perks_purchased` list. |
| `src/ui.py` | All render helpers: `draw_stats()`, `draw_right_panel()`, `draw_milestone_overlay()`, notification stack, surface caches. |
| `src/save_load.py` | JSON save/load with field migration. `load_game_preview()` for title screen. |
| `src/heat.py` | Heat meter (0–100). `reduce_heat()`. Police raids at 60%+. |
| `src/territory.py` | 5 territories + warfare (Attack/Bribe/Negotiate/Sabotage). Success chance uses rival penalty. |
| `src/rivals.py` | 5 rival factions with Traits, passive growth, rival-vs-rival combat, defeat system. |
| `src/crew.py` | 5 crew roles (Protection/Collection/Smuggling/Territory/Heat). Pool = total buildings owned. |
| `src/operations.py` | 5 illegal ops with timer/collect loop. Requires crew + cash + territories. |
| `src/events.py` | 6 syndicate event types, 3-choice overlay, outcome toasts. |
| `src/tutorial.py` | Step-based tutorial, `skip_tutorial()`, `get_skip_rect()`. |
| `src/state_base.py` | `GameState` abstract base class. |

## Architecture Rules

### State machine
All states inherit `GameState` (src/state_base.py). `main.py` only switches between `MenuState` and `PlayingState` — no loose booleans.

### Income pipeline
```
buildings.income_per_second
  → managers.compute_base_income
  → PlayingState.income_per_second   # applies prestige mult × heat mult × territory mult × syndicate buffs × crew collection bonus
```
`income_per_second` is a cached property — `_ips_dirty = True` is set at the top of `update()` so it recomputes at most once per frame.

### Delta time
Every movement, rate, and timer must multiply by `dt`. Never tie speed to FPS.

### Tab system (9 tabs in states.py `_TAB_RECTS`)
`Bldgs / Upgrs / Turf / Rivals / Crew / Ops / Stats / Config / Mgrs`
Tab width = 52px, labels use `'xs'` font.

### Adding a new subsystem
1. Create `src/<system>.py`.
2. Init in `PlayingState.__init__`.
3. Wire into `update()` and `draw()`.
4. Add save/load fields with migration in `save_load.py`.

### Milestone messages
Strings in `_milestone_queue` **must** use `\n` as line separator:
- First line → title (gold text)
- Remaining lines → body (xs muted text)
`draw_milestone_overlay()` in ui.py handles all cases. Do not pass flat strings.

### Performance — do not regress
- `_ips_dirty` / `_ips_cached` pattern in `PlayingState` — never call income computation more than once per frame.
- `_STATS_SURF_CACHE` in ui.py rebuilds the stats tab surface at ~5fps, not 60fps.
- `_ach_check_timer` — achievements evaluated every 0.5s, not every frame.
- Notification/coin/orbit surfaces are globally reused — do not allocate new surfaces per-frame in draw code.

## Code Style
- **Naming:** PEP 8. `snake_case` functions/variables/files, `PascalCase` classes, `UPPER_CASE` constants.
- **Imports:** Explicit only. Never `from pygame.locals import *`.
- **File size:** >300 lines → refactor helpers into a new module.
- **Comments:** Only for non-obvious WHY (hidden constraints, workarounds). No docblock novels.

## Art & Assets
- **No generative AI assets** — do not use AI image generation for sprites, icons, portraits, textures, backgrounds, or marketing art.
- Visual work stays **code-drawn** (pygame primitives, typography, theme palette) or **hand-authored assets** the user provides.

## Presentation Saga (UI pass — presentation only)

| Phase | Status | Notes |
|-------|--------|-------|
| 121 | Done | Audit + vision (`PHASE121_REPORT.md`) |
| 122 | Done | Command-center header (`PHASE122_REPORT.md`) |
| 123 | Done | Employee roster / Managers tab (`PHASE123_REPORT.md`) |
| 124 | Done | City-first left column + overlap fixes (`PHASE124_REPORT.md`) |
| **127** | **Done** | Noir theme pass — palette, atmosphere, dossier tabs, cards, menu (`PHASE127_REPORT.md`) |
| **125** | **Next (recommended)** | Turf sub-tab badges (ops ready, broker) |
| 126 | Queued | Stats tiering + achievement entry |
| 128 | Queued | Motion P0 (shield pulse, auto-buy toasts) |

**Parallel non-UI work (no gameplay change, zero collision with UI):** `sim_test_suite.py`, `sim_smoke.py`, and `sim_harness.py` were brought in sync with current design (Pete's Pick, hard prestige wipe, 0 starting dealers, Phase 100 flat nav). `PROJECT_RULES.md` now documents the intended prestige reset: buildings/income wipe, persistent prestige multiplier survives.

## Save/Load
New fields must be added with a migration default in `save_load.py` so old saves don't crash. Check `load_game_preview()` separately — it reads a lightweight subset for the title screen.

## graphify

This project has knowledge graphs under `graphify-out/`:

| Graph | Path | Use for |
|-------|------|---------|
| **Port map** (preferred) | `graphify-out/port/graph.json`, `GRAPH_REPORT.md`, `graph.html` | pygame↔Godot layout, save schema, income pipeline, architecture |
| Full repo | `graphify-out/graph.json` | Broad corpus incl. phase reports/screenshots |

Rules:
- For cross-cutting architecture questions (save fields, income pipeline, tab layout, pygame↔Godot parity), query the **port map** first: read `graphify-out/port/GRAPH_REPORT.md` or run `python -m graphify query "<question>"` when `graphify-out/graph.json` exists (queries use root graph; for port-specific context read `graphify-out/port/GRAPH_REPORT.md` directly).
- Use `python -m graphify path "<A>" "<B>"` and `python -m graphify explain "<concept>"` for scoped subgraphs.
- After modifying **code** in this session, run `python -m graphify update .` (AST-only, no API cost). On Windows use `python -m graphify`, not bare `graphify update`.
- After large **Godot port** changes under `src/` or `godot/`, refresh the port map: `/graphify` on `src/` + `godot/scripts` with `--update` (or ask the user to run it).
- Git **post-commit hook** auto-rebuilds the root graph via `graphify_rebuild.py` (code files only).
- Doc/paper/image changes need manual `/graphify --update` (LLM semantic extraction).
