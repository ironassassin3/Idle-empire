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

## Remaining (P15 validation close-out)

- [x] Capture matrix PNGs — **complete** (29 in `docs/ui/capture_matrix/` incl. offline + prestige tree)
- [x] Telemetry: `ui_city_tier_change`, `ui_hustle_tap`
- [ ] Device pass (Moto G FPS ≥30) — **owner manual**
- [ ] Owner taste gate (15s flow — see below) — **owner manual**
- [x] P14 funnel regression check (see below)
- [x] Main menu ink pass
- [x] Prestige tree ink pass (P15.12)

## Owner Taste Gate

**Purpose:** Subjective “does this feel like the product?” check before P15 sign-off. Record or screen-capture a **15-second** portrait run; compare against P14 baseline if available.

### 15s flow script

| Step | Time | Action | Pass if |
|------|------|--------|---------|
| 1 | 0–3s | Launch → main menu | Ink field `#0c0c14`; ledger panel is ink modal (no corner brackets); Continue/New readable |
| 2 | 3–5s | Tap **New game** (or Continue) | Transitions to game without layout pop; city viewport visible at top |
| 3 | 5–8s | Tap **hustle band** on city (street/coin row) | Click feedback visible; no double HUSTLE button when `UI_CITY_V2` |
| 4 | 8–11s | **Bldgs tab** → buy one building | Ink row card + green affordance border; purchase SFX optional |
| 5 | 11–15s | Open **Config** (gear or tab) | Ink row cards + chip toggles; no warm `BG_CARD` panels |

### Fail criteria (any = fail)

- Rustic ledger brackets on modals/menus when city v2 is on
- City viewport missing or replaced by flat placeholder (unless `UI_CITY_VIEW=false` rollback test)
- Tab row or bottom nav unreadable / clipped at 720×1280
- Hustle tap dead zone (no response on street band)
- Config/Stats still on warm parchment cards in city v2

### Sign-off

- [ ] **Owner taste gate PASS** — Date: ______ — Notes: ______

## P14 funnel regression

Verify P14 UI telemetry still fires after P15 layout changes. No new analytics SDK required for this slice.

### Events to verify

| Event | When | Payload keys |
|-------|------|--------------|
| `ui_overlay_queue_ok` | Offline dismissed → daily pending | `ok: true` |
| `ui_overlay_shown` | Blocking overlay appears | `kind`: offline / daily / milestone / event / elim |
| `ui_overlay_dismiss_ms` | Overlay dismissed | `kind`, `ms` |
| `ui_hustle_tap` | City hustle band tapped | `source`, `tutorial_step` |
| `ui_city_tier_change` | Building count crosses tier boundary | `tier`, `from`, `buildings` |
| `ui_tab_open` | Bottom nav or gear opens tab | `tab` |
| `ui_config_open` | Gear opens Config | `{}` |
| `ui_prestige_tree_open` | Prestige chip opens tree | `eligible` |

### How to run

**Automated probe (headless):**

```bash
E:/Downloads/Godot_v4.6.3-stable_win64.exe --path godot --headless \
  -s res://scripts/tools/telemetry_probe.gd -- --telemetry-probe \
  --output user://telemetry_probe.jsonl
```

Expect JSON stdout with `"ok": true`, `ui_event_kinds` ≥ 5, building/upgrade row probes OK. Inspect `user://telemetry_probe.jsonl` (path printed in stdout) for `ui_overlay_queue_ok`, `ui_tab_open`, `ui_prestige_tree_open`.

**Manual (windowed):** Play 2–3 min, buy a building to trigger `ui_city_tier_change`, tap hustle once, open Config via gear — then read dev telemetry sink if enabled, or re-run probe after a code path change.

**City tier boundary:** Use screenshot harness `--buildings 4` then buy 1 in-game, or `--city-tier 1` vs `--city-tier 0` for visual-only check.

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

## P15.12 — validation close-out (this session)

| Item | Status |
|------|--------|
| Owner taste gate script | `P15_REPORT.md` § Owner Taste Gate |
| Device checklist P15 items | `DEVICE_TEST_CHECKLIST.md` § P15 |
| Screenshot `--offline-overlay` | Harness preset + `offline_overlay.png` |
| Screenshot `--prestige-tree` | Harness preset + `prestige_tree.png` |
| Prestige tree ink pass | `prestige_tree_overlay.gd` — ink modal, chips, no ledger brackets |
| P14 funnel regression doc | `P15_REPORT.md` § P14 funnel regression |

## Verify

| Check | Result |
|-------|--------|
| `python sim_smoke.py` | PASS (P15.12) |
| `python sim_godot_soak.py` (Godot 4.6.3, 60s) | PASS — soak + income parity (P15.12) |
| Capture `offline_overlay.png` + `prestige_tree.png` | PASS — harness presets |

## Capture matrix (P15.8+)

| Status | Detail |
|--------|--------|
| **Complete** | 29 PNGs at 720×1280 in [`docs/ui/capture_matrix/`](docs/ui/capture_matrix/README.md) |
| Automated | Menu ink, tiers 0–4, building counts, heat/districts, affordance, Crime Lord, all 9 tabs |
| Harness presets | `--offline-overlay`, `--prestige-tree` (P15.12) |

Harness: windowed Godot 4.6.3 — `screenshot.gd` with `--city-tier`, `--heat`, `--districts`, `--prestige-tokens`, `--menu`, `--offline-overlay`, `--prestige-tree`.

## Screenshot presets (P15.8+)

```bash
godot --path godot -s res://scripts/tools/screenshot.gd -- --menu --out docs/ui/capture_matrix/menu_ink.png --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out docs/ui/capture_matrix/tier0_bldgs.png --city-tier 0 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out docs/ui/capture_matrix/tier2_heat75.png --city-tier 2 --heat 75 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out docs/ui/capture_matrix/tier2_districts5.png --city-tier 2 --districts 5 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out docs/ui/capture_matrix/crime_lord_tier2.png --city-tier 2 --prestige-tokens 75 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 6 --out docs/ui/capture_matrix/stats_ink.png --city-tier 2 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 8 --out docs/ui/capture_matrix/config_ink.png --city-tier 2 --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --offline-overlay --city-tier 2 --out docs/ui/capture_matrix/offline_overlay.png --w 720 --h 1280
godot --path godot -s res://scripts/tools/screenshot.gd -- --prestige-tree --city-tier 2 --out docs/ui/capture_matrix/prestige_tree.png --w 720 --h 1280
```
