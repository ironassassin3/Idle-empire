# P15 Report — City-First UI Rebuild v2

**Scope this session:** P15.11 — tab body ink consistency (Config/Stats cards, config chips)  
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

## P15.10 — main menu ink pass

| Item | Status |
|------|--------|
| Ledger panel | `menu_ledger_style()` → `ink_overlay_modal_style` when city v2; brackets gated in `menu_ledger_panel.gd` |
| Preview card | `make_ink_menu_preview_flat` — dark ink fill, gold hairline |
| Menu buttons | `make_ink_menu_button_flat` + `apply_menu_button` ink branch (primary gold border) |
| Background | `#0c0c14` ink field when city v2 |
| Safe area | Portrait margins via `DisplayServer.get_display_safe_area()` in `main_menu.gd` |
| Screenshot | `screenshot.gd --menu` preset for capture matrix |

## P15.11 — tab body ink consistency

| Item | Status |
|------|--------|
| Config row cards | `ink_config_row_style()` — `#0a0a12` fill + gold hairline (replaces warm `BG_CARD`) |
| Config cycle toggles | `apply_ink_chip_button` — header-matching ink chips (not menu ledger buttons) |
| Config action buttons | Cloud sign-in, restore, menu, reset, delete — full-width ink chips |
| Stats stat cards | `ink_stat_card_style()` — ink flat cards with padded interior |
| Stats progress bars | `ink_progress_track_style()` track when city v2 |
| Stats muted lines | `TEXT_MUTED` in city v2 (was green secondary) |
| Stats achievements row | Ach button + close — ink chips; list bone text |
| Turf/Rivals/Crew/Ops | Rows already ink via P15.6; subtab headers gold in v2 |

## Remaining (P15.11+)

- [x] Capture matrix PNGs — **partial** (27 automated in `docs/ui/capture_matrix/`; offline overlay + prestige tree manual)
- [x] Telemetry: `ui_city_tier_change`, `ui_hustle_tap`
- [ ] Device pass (Moto G FPS ≥30)
- [ ] Owner taste gate (15s recording, P14 vs P15 side-by-side)
- [ ] P14 funnel regression check
- [x] Main menu ink pass (if still ledger-ish)

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
| `python sim_smoke.py` | PASS (capture matrix session) |
| `python sim_godot_soak.py` (Godot 4.6.3, 60s) | PASS — soak + income parity (P15.11) |

## Capture matrix (P15.8)

| Status | Detail |
|--------|--------|
| **Partial** | 27 PNGs at 720×1280 in [`docs/ui/capture_matrix/`](docs/ui/capture_matrix/README.md) |
| Automated | Menu ink, tiers 0–4, building counts 1/10/40/100, heat 0/50/75, districts 0/5/20, affordance, Crime Lord glow, all 9 tabs |
| Manual | Offline overlay (city dimmed), prestige tree full-screen |

Harness: windowed Godot 4.6.3 — `screenshot.gd` with `--city-tier`, `--heat`, `--districts`, `--prestige-tokens`, `--menu`.

## Screenshot presets (P15.8+)

```bash
godot --path godot -s res://scripts/tools/screenshot.gd -- --menu --out docs/ui/capture_matrix/menu_ink.png --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out docs/ui/capture_matrix/tier0_bldgs.png --city-tier 0 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out docs/ui/capture_matrix/tier2_heat75.png --city-tier 2 --heat 75 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out docs/ui/capture_matrix/tier2_districts5.png --city-tier 2 --districts 5 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out docs/ui/capture_matrix/crime_lord_tier2.png --city-tier 2 --prestige-tokens 75 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 6 --out docs/ui/capture_matrix/stats_ink.png --city-tier 2 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 8 --out docs/ui/capture_matrix/config_ink.png --city-tier 2 --w 720 --h 1280
```
