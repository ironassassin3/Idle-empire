# P15 Report — City-First UI Rebuild v2

**Scope this session:** P15.1 → P15.3b (core + visual differentiation)  
**Direction:** Concept A — Skyline progression strip ([`UI_REBUILD_V2_ARCHITECTURE.md`](UI_REBUILD_V2_ARCHITECTURE.md))

## pygame parity → Godot identity (P15.3b)

Owner taste gate: initial P15.1 renderer mirrored pygame `draw_scene` too literally (lamppost, single storefront, hustle disc). **P15.3b** rewrites [`city_view.gd`](godot/scripts/ui/city_view.gd) as a Godot-native v2 renderer per architecture §6.1:

- 3-layer parallax skyline (not flat pygame sky bands)
- Top-3 owned **building-type** neon facades (not generic storefront rects)
- Horizontal **district strip** with territory colors (replaces scattered gold dots)
- Crimson **top gradient** + rotating **siren wedge** for heat (not smoke ellipses)
- Art-deco chevron frame; **YOUR EMPIRE** label hidden (header shows rank)
- Hustle: radial pulse rings + street reflection line

Pygame tier **thresholds** unchanged (5/15/35/80); geometry and motion are not pixel-parity.

## Done (P15.1–P15.3b)

| Phase | Deliverable | Notes |
|-------|-------------|-------|
| P15.1 | `godot/scenes/ui/city_view.tscn`, `godot/scripts/ui/city_view.gd` | Code-drawn skyline tiers (thresholds 5/15/35/80), atmosphere, glass hustle overlay. 30 Hz redraw throttle; headless skips `_draw`. |
| P15.2 | `game_screen.tscn` layout | `Header → CityViewport (~30% min 180px) → StatusStrip → Body/Right → BottomBar`. Removed `Body/Left` column. |
| P15.3 | GameState binding | `city_view.refresh(...)` from `game_screen._process`; hustle tap → `_on_hustle`; `UI_RUSTIC_THEME=false`, `UI_CITY_V2=true`. |
| P15.3b | Visual differentiation | v2 renderer; `refresh()` extended with top building keys + district strip slots. |

## Verify

| Check | Result |
|-------|--------|
| `python sim_smoke.py` | PASS |
| `python sim_godot_soak.py` (Godot 4.6.3, 60s) | PASS — soak + income parity (post P15.3b) |

## Remaining (P15.4–P15.8)

- **P15.4** — Theme v2: retire `_apply_rustic_surfaces` / row wrap together; noir flat default
- **P15.5** — Coin ad row on city strip; `get_hustle_rect()` for tutorial highlight
- **P15.6** — Tab row de-ledger (ink StyleBoxFlat cards)
- **P15.7** — `UI_CITY_VIEW` rollback flag + dev toggle
- **P15.8** — Capture matrix, telemetry (`ui_city_tier_change`), device pass, owner taste gate
