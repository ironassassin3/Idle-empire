# P15 Report — City-First UI Rebuild v2

**Scope this session:** P15.1 → P15.3 (core)  
**Direction:** Concept A — Skyline progression strip ([`UI_REBUILD_V2_ARCHITECTURE.md`](UI_REBUILD_V2_ARCHITECTURE.md))

## Done (P15.1–P15.3)

| Phase | Deliverable | Notes |
|-------|-------------|-------|
| P15.1 | `godot/scenes/ui/city_view.tscn`, `godot/scripts/ui/city_view.gd` | Code-drawn skyline tiers (thresholds 5/15/35/80), atmosphere (heat haze/smoke/police flash, Crime Lord+ glow, district window dots), glass hustle overlay. 30 Hz redraw throttle; headless skips `_draw`. |
| P15.2 | `game_screen.tscn` layout | `Header → CityViewport (~30% min 180px) → StatusStrip → Body/Right → BottomBar`. Removed `Body/Left` column. |
| P15.3 | GameState binding | `city_view.refresh(...)` from `game_screen._process`; hustle tap → `_on_hustle`; `UI_RUSTIC_THEME=false`, `UI_CITY_V2=true`. |

## Verify

| Check | Result |
|-------|--------|
| `python sim_smoke.py` | PASS |
| `python sim_godot_soak.py` (Godot 4.6.3, 60s) | PASS — soak + income parity |

## Remaining (P15.4–P15.8)

- **P15.4** — Theme v2: retire `_apply_rustic_surfaces` / row wrap together; noir flat default
- **P15.5** — Coin ad row on city strip; `get_hustle_rect()` for tutorial highlight
- **P15.6** — Tab row de-ledger (ink StyleBoxFlat cards)
- **P15.7** — `UI_CITY_VIEW` rollback flag + dev toggle
- **P15.8** — Capture matrix, telemetry (`ui_city_tier_change`), device pass, owner taste gate
