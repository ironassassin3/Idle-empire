# Project: Criminal Empire — 2D Idle Game

> **MANDATORY — read before any art/UI/audio work:** [`ART_POLICY.md`](ART_POLICY.md)  
> No generative-AI assets. Visuals and SFX are **code-built** (or owner-provided hand art only).

## Ship target vs prototype

| Runtime | Role |
|---------|------|
| **`godot/`** | **1.0 product** — mobile launch vehicle. All player-facing UI, feel, and new features land here. |
| **pygame (`src/`, `main.py`)** | **Prototype / balance lab** — mechanics reference and sim harness (`sim_pacing.py`, `sim_smoke.py`, income parity). Not maintained for UI or presentation. Do not spend effort on pygame polish phases. |

Balance changes: prove in pygame sims if convenient, then port constants to Godot. Gameplay/UI work: **Godot first.**

## Communication Style
- Be concise by default. Lead with the conclusion, then minimal supporting detail.
- Prefer bullets and short tables over paragraphs. No preamble, no filler, no motivational language.
- Don't restate the question or recap context the user already has.
- Answer what was asked — don't volunteer tangents or over-explain.
- Match response length to the task: one-liners for simple things, detail only when it changes a decision.
- Don't be a yes-man. Challenge weak reasoning and give evidence-based pushback when warranted.
- Show code/file refs as clickable links, not fenced restatements of code the user can open.

## What This Is
A modular idle/incremental game where the player builds a criminal empire. Core loop: buy buildings → earn income/s → buy upgrades → gain Influence → prestige. Layered systems: heat, territory warfare, rival factions, crew assignments, illegal operations, prestige perk tree.

## Commands
```
# Ship target (Godot 1.0)
# Open godot/project.godot in Godot 4.3+ and press F5

# Prototype / balance lab (pygame — sims + optional manual playtest)
python main.py
python sim_pacing.py --minutes 45 --active 0.33 --cps 2
python sim_godot_soak.py --godot "<path-to-godot>"
pip install pygame-ce   # only needed for lab sims
flake8 .
```

## Key Files (pygame prototype — lab reference)

Use these when tuning balance or running sims. **Do not treat pygame UI (`src/ui.py`) as the product UI.**

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

**Full policy (required reading):** [`ART_POLICY.md`](ART_POLICY.md)

- **No generative-AI assets** — images, sprites, textures, UI art, audio, or marketing visuals.
- **Code-built by default** — pygame/Godot primitives, theme tokens, procedural SFX.
- **Procedural music (Godot):** motif/scales/tempo scaffold � [MUSIC_ARCHITECTURE.md](MUSIC_ARCHITECTURE.md), godot/scripts/audio/music_defs.gd (MusicDefs); PCM/sequencer in M1+.
- **Hand-authored only** when the project owner explicitly supplies files (agents must not AI-generate on their behalf).

## Presentation Saga (pygame — **archived**)

Phases 121–127 and 125 were pygame-only UI passes. **Inactive** — Godot `game_screen.gd` is the live UI. Do not continue this track unless explicitly reviving the prototype.

| Phase | Status | Notes |
|-------|--------|-------|
| 121–127, 125 | Done (pygame) | Historical; parity ideas already ported or superseded in Godot P6–P7 |
| 126, 128 | **Godot only** — Phase 126 done (`PHASE126_REPORT.md`); 128 partial in P6 |

**Lab sims (still maintained):** `sim_pacing.py`, `sim_smoke.py`, `sim_harness.py`, `sim_godot_soak.py` — pygame design (Pete's Pick, hard prestige wipe, 0 starting dealers).

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
