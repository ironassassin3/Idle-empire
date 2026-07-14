# Criminal Empire — Godot Design Kit

Read this **before** building any design scene. It is the contract for the
`/godot-design` loop: every design must be assembled from the tokens, fonts,
and components below — never invented colors, never downloaded/AI art
(see `ART_POLICY.md`: code-built only).

## The loop

1. Author a Control scene under `godot/design/<name>.tscn` (+ optional `<name>.gd`).
2. Render it: `.\design_preview.ps1 -Scene godot\design\<name>.tscn` (repo root).
   PNGs land in `godot/design/shots/`. Multi-res: `-Sizes 720x1280,1080x1920`.
3. Look at the PNG, critique against this kit, edit, re-render. Iterate.
4. Ship: port the final scene/nodes into `game_screen.tscn` / the real overlay.

The harness (`godot/scripts/tools/design_preview.gd`) installs all project
autoloads (`GameState`, `FormatUtil`, `GameConfig`, …) and applies the project
theme + fonts, so real components work standalone. Seed money for affordance
states with `-Cash 50000`.

### ui_capture — the fast path (preferred)

`ui_capture.ps1` / `godot/scripts/tools/ui_capture.gd` supersedes
`design_preview.ps1` for anything beyond a single mock render:

- **Exact-pixel SubViewport capture** — renders offscreen at the requested
  size; the OS window never clamps 1080×1920 on a 1080p monitor.
- **Batch specs** — `.\ui_capture.ps1 -Spec godot\design\capture_matrix.json`
  renders a whole matrix (tabs × sizes × seeds) in ONE engine launch (~2s/shot).
- **`-DebugRects`** — outlines every visible Control in the capture (magenta =
  zero-area/collapsed) and writes `<out>.rects.json` with rect + min-size per
  node. Use it FIRST when a layout looks wrong.
- **Input playback** (spec `inputs` array) — synthetic taps/drags before
  capture, e.g. drive the content sheet to PEEK/FULL:
  `{"at": 60, "type": "drag", "x": 360, "y": 507, "to_x": 360, "to_y": 880, "frames": 14}`
- Shipped-screen capture: `-Shell -Tab N` (Stage & Ledger shell) plus seeds
  (`cash`, `city_tier`, `heat`, `districts`, `no_overlays`) per job.

Single shot: `.\ui_capture.ps1 -Shell -Tab 0 -Size 1080x1920 -Cash 500 -NoOverlays -DebugRects`

## Canvas

- Ship target is **portrait mobile, 720×1280** (`project.godot` viewport,
  stretch `canvas_items` / `expand`). Design at 720×1280 first; sanity-check
  1080×1920.
- Root clear color is `#1a1520`-ish (`boot_splash/bg_color`). Add your own
  full-rect `ColorRect` with `GameTheme.BG` when the design needs the true bg.

## Tokens — `GameTheme` (`godot/scripts/ui/game_theme.gd`, class_name `GameTheme`)

Colors (constants, use these — never hex literals in scenes you intend to ship):

| Token | Hex | Use |
|---|---|---|
| `BG` | `08070a` | app background |
| `BG_PANEL` | `121018` | panel fill |
| `BG_CARD` | `1a1520` | card fill |
| `GOLD` | `c8a35a` | brand accent, headings, borders |
| `GOLD_BRIGHT` | `ecca7d` | emphasis / hover gold |
| `TEXT` | `e8e0d4` | body text |
| `TEXT_MUTED` | `8a8070` | secondary text |
| `GREEN` / `RED` | `6a9a6a` / `9a4a4a` | positive / negative |
| `BLUE_BRIGHT` / `ACCENT` | `6a9aaa` / `4a6a8a` | info accents |
| `TAB_ACTIVE` / `TAB_IDLE` | `2a2030` / `141018` | tab strips |
| `BADGE_BG` / `BADGE_BORDER` | `3a2a18` / `c8a35a` | badges |
| `CHIP_BG` / `CHIP_BORDER` | `1e1828` / `6a5a40` | chips |
| `ROW_BG_BUYABLE/LOCKED/OWNED/PETE` | see file | row affordance fills |

Font-size tokens: `FONT_BALANCE 28`, `FONT_IPS 17`, `FONT_RANK 12`,
`FONT_CHIP 13`, `FONT_TAB 13`, `FONT_MENU_TITLE 52`, `FONT_MENU_SUBTITLE 18`.
Buttons: `MENU_BTN_MIN_H 52`, `OVERLAY_BTN_MIN_H 48` (touch minimums — never
smaller). Scale helper: `GameTheme.scaled_font(base)`.

StyleBox / helper API (call from an attached script in `_ready()`):

- Panels: `panel_style()`, `ink_panel_style()`, `stat_card_style()`,
  `menu_ledger_style()`, `overlay_ledger_style()`, `header_strip_style()`,
  `list_section_header_style()`, `tab_bar_bg_style()`
- Rows: `row_card_style(GameTheme.RowAffordance.BUYABLE)…`,
  `apply_row_affordance(row, aff)`, `apply_row_buy_button(btn)`,
  `draw_row_wax_seal(control, aff)`
- Chips/tabs: `chip_style(active)`, `tab_strip_style(active)`,
  `apply_tab_button(btn, active)`, `make_tab_badge_flat()`
- Buttons: `apply_menu_button(btn, primary)`, `apply_overlay_cta(btn, primary)`,
  `apply_button_icon(btn, GameIcons.SWORD, 20)`, `apply_gear_icon_button(btn)`
- Labels: `apply_economy_hud(balance, ips, rank)`, `apply_flavor_label(lbl)`,
  `apply_list_section_title(lbl)`
- `ink_*` variants are the ink/parchment pass; plain variants are noir flat.
  Rustic texture theme only activates in-game (`init_rustic()`), don't depend
  on it in previews.

## Fonts — `GameFonts` (class_name, `godot/scripts/ui/game_fonts.gd`)

Applied to the root theme by the harness: default/body = Cormorant Garamond,
Buttons/TabBar = Cinzel. For explicit roles:
`GameFonts.heading()` (Cinzel — titles), `GameFonts.body()` /
`body_italic()` (Cormorant — prose/flavor), `GameFonts.display()`
(Limelight — big marquee numbers/logotype), `GameFonts.mono(bold)`
(Space Mono — tabular money/stats). Set via
`lbl.add_theme_font_override("font", GameFonts.heading())`.

## Icons — `GameIcons` (class_name, Phosphor SVG, MIT)

`GameIcons.texture("gear")` → `Texture2D`. Available: `gear, buildings,
trend-up, users-three, users, map-pin, chart-bar, sword, briefcase`
(`godot/assets/icons/phosphor/`). Tint gold via modulate or
`apply_button_icon`. Need another glyph? Add the Phosphor SVG + license note —
never draw ad-hoc icon art.

## Reusable components (`godot/scenes/`)

Instance these rather than rebuilding their pattern:

| Scene | Script | What it is |
|---|---|---|
| `building_row.tscn` | `ui/building_row.gd` | list row: name/count/income + buy button, affordance styling |
| `upgrade_row.tscn`, `manager_row.tscn`, `rival_row.tscn`, `crew_row.tscn`, `territory_row.tscn`, `operation_row.tscn` | matching `ui/*.gd` | same row pattern per system |
| `ui/hustle_band.tscn` | `ui/hustle_band.gd` | click-buff status band |
| `ui/city_view.tscn` | `ui/city_view.gd` | procedural skyline header |
| `gambling_overlay.tscn` | `ui/gambling_overlay.gd` | full-screen overlay example (wheel + wagers) |
| — | `ui/overlay_dim.gd`, `ui/overlay_frame.gd` | overlay scrim + framed modal panel |
| — | `ui/menu_ledger_panel.gd` | menu ledger card |
| — | `ui/count_medallion.gd` (`CountMedallion`) | code-drawn owned-count ring (rows) |
| — | `ui/gold_rule.gd` (`GoldRule`) | deco divider — hairlines + diamond |
| — | `ui/heat_threshold_tick.gd` (`HeatThresholdTick`) | 60% raid tick over the heat bar |
| — | `ui/masthead_scrim.gd` (`MastheadScrim`) | top/bottom legibility gradient over the city view |

Row titles: always `GameTheme.apply_row_title(lbl, size)` — Cinzel gold, all
row types share it. The game screen's masthead (city + scrim + hero balance +
rank plate + heat + chips) lives in `game_screen.tscn` under `Root/VBox/Masthead`.

Buttons: `GameTheme.make_game_button_flat(fill, pressed)` — chunky bevel
(darker bottom edge) is the ship button language; all CTAs route through
`apply_row_buy_button` / `apply_menu_button` / `apply_gold_chip`. One BUY per
row (global ×1/×10/Max chip sets quantity). Identity discs: `CountMedallion`
(`initial`, `hue_index`, `count`, `locked`). Menu backdrop: `MenuBackdrop`.
| — | `ui/stats_dashboard.gd` | stats grid |
| — | `ui/film_grain_overlay.gd` | grain post-FX layer |

Rows populate from `GameState` (harness resets a new game; use `-Cash` to make
things buyable). For pure-layout mocks, plain Controls + GameTheme styles are
fine — but match the row pattern (PanelContainer ▸ Margin 6 ▸ VBox sep 4,
name 14px gold / meta 11px muted, buttons ≥44px tall).

## Data/format helpers

- `FormatUtil.format_money(n)` / `format_number(n)` (autoload) — always use for
  cash ("$1.24M" style). In design scripts: `get_node("/root/FormatUtil")` or
  rely on components that already call it.
- `GameState` (autoload) — live balances, buildings, heat, territories.

## Rules

1. **Code-built only** (ART_POLICY.md). Primitives, StyleBoxes, the licensed
   fonts/icons above. No generated images, no stock art.
2. Tokens over literals — a design that needs a new color/size adds it to
   `GameTheme` at port time, with a reason. Exception: `/godot-design explore`
   scenes may use marked non-kit values to *argue for* kit amendments (see the
   skill's Explore mode); those values ship only by being promoted to
   `GameTheme`, never by porting the scene as-is. Fiction is the guardrail:
   proposals must live inside "criminal empire noir."
3. Touch targets ≥ 44px; portrait-first; text must survive 720px width.
4. Design scenes live in `godot/design/` and are throwaway until ported —
   never wire game logic into them; shipping means porting nodes/styles into
   the real scenes (`game_screen.tscn`, overlays).
5. `godot/design/shots/` is gitignored render output.
