# UI capture matrix

Screenshot baseline for touch-first UI validation. Capture after each UI phase on portrait ship (720×1280, 9:16).

## Tooling

Windowed Godot only — headless cannot read viewport textures.

**Capture the live shell (`game_shell.tscn`).** `screenshot.gd` defaults to the
retired `game_screen.tscn` fallback unless `--shell` is passed — the 2026-06-20
matrix below was captured that way and shows a scene players never see. Always
target the shell now, either via the batch fast-path (one Godot launch for the
whole set) or `screenshot.gd --shell`:

```powershell
# Fast path — batch spec, one launch (preferred):
.\ui_capture.ps1 -Spec docs/ui/capture_matrix/matrix.jobs.json
# Single shot:
E:/Downloads/Godot_v4.6.3-stable_win64.exe --path godot -s res://scripts/tools/ui_capture.gd -- \
  --shell --tab 0 --out docs/ui/capture_matrix/tier0_bldgs.png --city-tier 0 --w 720 --h 1280
```

`ui_capture` job/flag keys: `shell`, `tab N` (0 Bldgs … 8 Config), `out`, `w`/`h`,
`frames`, `cash`, `city_tier N`, `owned_list [..]` (per-building counts),
`all_buildings_owned N`, `heat N`, `districts N`, `prestige_tokens N`,
`offline_hours N`, `no_overlays`, `debug_rects`.

## Shell refresh (2026-07-04)

Regenerated on the live **shell** at 720×1280 (gilded surfaces, OFL fonts,
Phosphor nav, code-drawn building glyphs, layered city skyline that scales with
owned count). 17 core city/rows/atmosphere shots below are current; the tab,
menu, stats/config, and overlay (offline / prestige-tree) shots still show the
old `game_screen` baseline and are pending a shell re-capture.

Current (shell): `tier0–4_bldgs`, `buildings1/10/40/100_bldgs`,
`tier2_heat0/50/75`, `tier2_districts0/5/20`, `tier2_affordance`, `tab_bldgs`.

## P15 capture matrix (2026-06-20 — legacy `game_screen`)

Automated via `screenshot.gd` at 720×1280. 29 PNGs; **pre-shell** unless listed
as refreshed above.

| File | Description |
|------|-------------|
| `menu_ink.png` | Main menu ink pass (`--menu`) |
| `tier0_bldgs.png` | Empty lot skyline, Bldgs tab (`--city-tier 0`) |
| `tier1_bldgs.png` | Tier 1 skyline (5 buildings) |
| `tier2_bldgs.png` | Tier 2 skyline (15 buildings) |
| `tier3_bldgs.png` | Tier 3 skyline (35 buildings) |
| `tier4_bldgs.png` | Tier 4 skyline (80 buildings) |
| `buildings1_bldgs.png` | 1 building — tier transition probe |
| `buildings10_bldgs.png` | 10 buildings — mid tier-1 silhouette |
| `buildings40_bldgs.png` | 40 buildings — tier-3 threshold |
| `buildings100_bldgs.png` | 100 buildings — max silhouette |
| `tier2_heat0.png` | Tier 2, heat 0% — calm atmosphere |
| `tier2_heat50.png` | Tier 2, heat 50% — rising haze |
| `tier2_heat75.png` | Tier 2, heat 75% — crimson haze + siren wedge |
| `tier2_districts0.png` | Tier 2, 0 districts unlocked |
| `tier2_districts5.png` | Tier 2, 5 district dots |
| `tier2_districts20.png` | Tier 2, 20 district dots (full strip) |
| `tier2_affordance.png` | Tier 2, `$5000` cash — green ink row borders |
| `crime_lord_tier2.png` | Tier 2, 75 prestige tokens — Crime Lord horizon glow |
| `tab_bldgs.png` | Bldgs tab, tier 2 |
| `tab_upgrs.png` | Upgrs tab, tier 2 |
| `tab_turf.png` | Turf tab, tier 2 |
| `tab_rivals.png` | Rivals tab, tier 2 |
| `tab_crew.png` | Crew tab, tier 2 |
| `tab_ops.png` | Ops tab, tier 2 |
| `stats_ink.png` | Stats tab ink cards + progress bars |
| `tab_mgrs.png` | Mgrs tab, tier 2 |
| `config_ink.png` | Config tab ink row cards + chips |
| `offline_overlay.png` | Offline return overlay — city dimmed (`--offline-overlay --city-tier 2`) |
| `prestige_tree.png` | Prestige tree ink modal (`--prestige-tree --city-tier 2`) |

## P14 reference (historical)

| Profile | Resolution | Aspect | Device reference |
|---------|------------|--------|------------------|
| Portrait ship | 720×1280 | 9:16 | Godot editor / emulator |
| Tall phone | 1080×2340 | 19.5:9 | Punch-hole safe-area stress |
| Short phone | 720×1280 | 16:9 | Header single-line check |

### P14 surfaces

- `main_menu` — continue / new / preview hierarchy
- `game_screen` — header economy HUD, buy-mult chip, tab badges
- Each bottom tab (Bldgs, Upgrs, Mgrs, Turf subtabs, Stats, Config)
- Overlay queue: offline → daily → milestone → event (sequential, not stacked)

## Regenerate overlay shots (PowerShell)

```powershell
$godot = "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
$dir = "docs/ui/capture_matrix"
& $godot --path godot -s res://scripts/tools/screenshot.gd -- --offline-overlay --city-tier 2 --out $dir/offline_overlay.png --w 720 --h 1280
& $godot --path godot -s res://scripts/tools/screenshot.gd -- --prestige-tree --city-tier 2 --out $dir/prestige_tree.png --w 720 --h 1280
```

## Regenerate all P15 shots (PowerShell)

```powershell
$godot = "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
$dir = "docs/ui/capture_matrix"
# See git history or P15_REPORT.md for full capture list; example:
& $godot --path godot -s res://scripts/tools/screenshot.gd -- --menu --out $dir/menu_ink.png --w 720 --h 1280
& $godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out $dir/tier2_heat75.png --city-tier 2 --heat 75 --w 720 --h 1280
```
