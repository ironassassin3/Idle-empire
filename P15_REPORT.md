# P15 Report — City-First UI Rebuild v2

**Scope this session:** P15.9 — ink chrome polish (header, status strip, bottom nav, toasts)  
**Direction:** Concept A — Skyline progression strip ([`UI_REBUILD_V2_ARCHITECTURE.md`](UI_REBUILD_V2_ARCHITECTURE.md))

## Done (P15.1–P15.7)

| Phase | Deliverable | Notes |
|-------|-------------|-------|
| P15.1 | `city_view.tscn`, `city_view.gd` | Skyline tiers 5/15/35/80; 30 Hz redraw; headless skips `_draw`. |
| P15.2 | `game_screen.tscn` layout | Header → CityViewport → StatusStrip → Body/Right → BottomBar. |
| P15.3 | GameState binding | `city_view.refresh(...)`; hustle tap → `_on_hustle`. |
| P15.3b | Visual differentiation | Godot-native v2 renderer (parallax, facades, district strip, siren heat). |
| P15.4 | Theme v2 | `city_noir_theme.tres`; ink `StyleBoxFlat` scroll wraps; rustic gated off when city v2; gold-cap section headers. |
| P15.5 | Status strip + coin on city | Coin/ad row on city bottom bar; compact heat + prestige + dragon chips; `get_hustle_rect()`. |
| P15.6 | Tab row ink cards | `make_ink_row_card_flat` — dark fill + thin gold/green border; zero content margin on row root. |
| P15.7 | Rollback flags | `UI_CITY_VIEW` hides CityViewport + fallback HUSTLE btn; independent from `UI_RUSTIC_THEME`. |

## P15.8

| Item | Status |
|------|--------|
| Skyline contrast / tier-0 read | Brighter sky/silhouette palette; horizon glow; lamppost + figure on tier 0; neon/rim lift |
| Telemetry `ui_city_tier_change` | Fires on tier boundary cross in `_track_city_tier` |
| Telemetry `ui_hustle_tap` | Fires from `_on_hustle` with `source` + `tutorial_step` |
| Status strip heat bar | Ink track + dynamic green/red fill in city v2 |
| Screenshot `--districts N` | Seeds territory strip for capture matrix |

## P15.9 (this session)

| Item | Status |
|------|--------|
| Header HUD ink chips | Rank gold-on-ink; gear btn ink chip; tighter chip StyleBoxes |
| Bottom nav active state | `make_ink_tab_strip_flat` — lifted active tab, gold underline, bone idle text |
| Status strip readability | Heat/shield/buff font sizes; prestige chip gold when ready; dragon unchanged |
| Toast + tutorial ink pills | Notif wrapped in `ink_toast_style`; tutorial banner ink panel (blue accent) |
| Overlay frames | `overlay_frame.gd` skips ledger brackets in city v2; `ink_overlay_modal_style` |

## Key visual changes (P15.4–P15.6)

- **Panels:** Ink `#0c0c14` flat panels with 1px gold hairline (no rustic leather wrap).
- **Tab scroll areas:** Minimal 2px ink frame — avoids row margin clip regression.
- **Section headers:** Gold caps on ink strip (`FRONT BUSINESSES`, etc.).
- **Rows:** Ink card fill + 1px affordance border (green buyable, gold Pete, muted locked).
- **Status strip:** Single compact heat row — prestige chip + dragon chip; coin floats on city street band.
- **City hustle:** Click value drawn on glass overlay (StatusStrip `ClickInfo` hidden in v2).

## Flags (`game_config.gd`)

| Flag | Default | Effect |
|------|---------|--------|
| `UI_CITY_V2` | `true` | City-first layout + ink theme path |
| `UI_CITY_VIEW` | `true` | When `false`: hide CityViewport, restore StatusStrip rows + fallback HUSTLE |
| `UI_RUSTIC_THEME` | `false` | Rustic bake + ledger wraps (independent rollback) |

## Verify

| Check | Result |
|-------|--------|
| `python sim_smoke.py` | PASS |
| `python sim_godot_soak.py` (Godot 4.6.3, 60s) | PASS — soak + income parity |

## Remaining (P15.9+)

- [ ] Capture matrix PNGs filled (`docs/ui/capture_matrix/`)
- [x] Telemetry: `ui_city_tier_change`, `ui_hustle_tap`
- [ ] Device pass (Moto G FPS ≥30)
- [ ] Owner taste gate (15s recording, P14 vs P15 side-by-side)
- [ ] P14 funnel regression check
- [ ] Main menu ink pass (if still ledger-ish)

## Screenshot presets (P15.8 partial)

```bash
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out tier0.png --city-tier 0
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out tier4.png --city-tier 4 --heat 75
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out districts5.png --city-tier 2 --districts 5
```
