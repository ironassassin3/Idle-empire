# Neon Noir — Port the Direction Study to the Live Shell

**Status:** Approved design (2026-07-17)
**Source study:** `godot/design/premium_main.gd` direction `b` (owner-picked, commit `df5f7d9`)
**Owner goal:** deliver "the 70% premium vision" — the study, in the actual game, not a mock.

## Goal

Bring the live main-screen shell up to the Neon Noir direction study by (1) amending
the shared `GameTheme` palette to Neon Noir so the whole app reads cohesively, (2)
punching up the already-cool `city_view` with the study's premium atmospheric moves,
and (3) giving business rows the code-drawn gradient depth the study has. No new
mechanics, no new screens — a look, delivered.

## Why this is small, not a rebuild

The live `city_view.gd` (812 lines) is **already a cool-noir scene** richer than the
mock: sky bands (`SKY_BACK ≈ #0e1226`), horizon glow, skyline + lit windows,
reflections, rain, vignette, searchlights, a gold keyline frame, and full reactive
behavior (facade pulse, heat hostility, district flash, raid surge). It already has
`NEON_WARM/COOL/RED` and a per-business color system (`GameTheme.building_neon()` +
`CountMedallion.HUES`).

The tonal clash the owner feels is that the **city is cool** while the **sheet, rows,
and chrome around it are warm gilded** (`GameTheme.BG=#08070a`, gold-dominant, flat
`StyleBoxFlat` rows). The amendment aligns the chrome to a city that is already Neon
Noir, and gives the rows the depth the mock's `_CardBg` gradient provides.

## Constraints (law)

- **ART_POLICY:** code-drawn only — gradients/linework via `_draw`, `StyleBoxFlat`,
  real `GameFonts`. No generative assets.
- **Tokens only where tokens exist:** new colors go through `GameTheme`; the study's
  palette values are the amendment (`b` direction), not per-file hardcodes.
- **Preserve all reactive logic** in `city_view.gd`: facade pulse, heat hostility
  (`SIREN_RED/BLUE`), district flash, raid surge, searchlights — recolor/additive only.
- **Preserve row layering & beats** in `building_row.gd`: the gradient is drawn
  *behind* the existing wax seal / afford underbar / unlock ink-wipe; those and the
  purchase coin-arc / medallion flare stay exactly as-is.
- **No save-schema changes, no new settings, no balance changes, no new audio.**
- **Semantic colors survive:** `SIREN_RED`, `SIREN_BLUE`, `GREEN` (income), `RED`
  keep their meaning; they are verified for legibility against the cooler ground, not
  repurposed.
- Godot binary: `E:/Downloads/Godot_v4.6.3-stable_win64.exe` (or `$env:GODOT_BIN`).

## Chosen approach

**In-place `GameTheme` token retint** — over a parallel flagged token set or a
per-screen scoped repaint. Rationale: least code, matches the study author's
"kit-amendment candidate" intent, every consumer inherits it for free, and the
existing shell capture matrix + overlay smoke catch regressions. A parallel flag
doubles token maintenance for an already-decided direction; scoped-per-screen was
ruled out by the owner (whole-app cohesion is the ask).

## The three edits

### 1. Theme amendment — `godot/scripts/ui/game_theme.gd`

Neon Noir base (study `b` values):

| Token | From | To |
|---|---|---|
| `BG` | `#08070a` | `#06070c` |
| `BG_PANEL` | `#121018` | `#0c0f18` |
| `BG_CARD` | `#1a1520` | `#11151f` |

- Retint the warm off-token chrome blacks so overlays/menus stop reading warm against
  the city: `INK_DEEP`, `PLATE`, `CHIP_BG`, `TAB_ACTIVE`, `TAB_IDLE`, `INK_FIELD`,
  `SHEET_GLASS` (already cool — confirm), and the row background family
  (`ROW_BG_BUYABLE/LOCKED/OWNED/PETE`) which currently carry a **green** cast — move to
  cool neutrals so the gradient accent (edit 3) provides the color, not the base.
- Add two jewel tokens: `JEWEL_TEAL := Color("2fd6c6")`, `JEWEL_MAGENTA := Color("e5457e")`.
- Keep `GOLD`/`GOLD_BRIGHT` — demoted by usage (buy button + focal accent), not deleted.
- Leave `SIREN_RED/SIREN_BLUE/GREEN/RED` values unchanged.
- **Off-token sweep:** grep `shell/` + overlay scripts for hardcoded `Color("…")`
  (dragon, gambling, event, film-grain, scrim). Align only the ones that visibly clash
  warm-on-cool; leave intentional semantic colors. Enumerate hits in the plan, don't
  blanket-replace.

### 2. City neon punch-up — `godot/scripts/ui/city_view.gd`

Recolor + additive only; **no reactive-logic edits**.

- Deepen/cool `SKY_BACK/MID/HAZE/GLOW` and `SILHOUETTE*` a touch toward the study.
- Push `NEON_COOL` toward teal `#2fd6c6` (via new `JEWEL_TEAL` or a local const).
- Add the three moves the live scene lacks, drawn in the existing `_draw` pipeline:
  1. **Rooftop neon-sign blooms** — a few bright win-colored radial blooms atop select
     silhouettes (study `_Backdrop` rooftop-sign pass), in the skyline draw.
  2. **Wet-street vertical neon streaks** — short vertical neon lines in the reflection
     band under the brightest signs (study reflection pass), in `_draw_reflections`.
  3. **Deco corner brackets** — double-keyline corner accents on the frame (study frame
     pass), extending `_draw_frame`.
- Facade pulse, heat hostility, district flash, raid surge, searchlights: untouched.

### 3. Gradient business rows — `godot/scripts/ui/building_row.gd`

- In `_draw`, **before** `GameTheme.draw_row_wax_seal(...)`, paint the study's
  `_CardBg`: a vertical gradient body (lit top → dark base) + a left accent bar, where
  `accent = GameTheme.building_neon(_building.icon_key)`.
- Buyable/PETE rows sit a shade warmer/brighter with a lit top-edge highlight; locked
  rows flatter and dimmer (study `buyable` branch).
- The affordance `StyleBoxFlat` (`GameTheme.apply_row_affordance`) becomes
  near-transparent so `_draw` owns the visible body — no double-fill. Confirm the wax
  seal, afford underbar, and unlock ink-wipe still layer correctly on top.
- Draw order (locked in): **gradient body → left accent bar → wax seal → afford
  underbar → unlock ink-wipe.**

## Verification

1. `shell_smoke` (`godot/scripts/tools/shell_smoke.gd`) — no regression / no errors.
2. Shell capture matrix at **720×1280** and **1080×1920** (`design_preview.ps1` /
   `ui_capture.ps1 -Shell`), seeded — live judgment against the study pixels.
3. V3 token lint passes (fx_layer / shell token discipline).
4. **Overlay smoke:** pop dragon-patron, gambling, and event overlays; confirm no
   warm-on-cool clash and all text legible against the retinted ground.
5. `python -m graphify update .` after code edits.

## Out of scope (explicit)

- Masthead restyle (hero number, jewel IPS line, heat pill) — not selected.
- Filled-disc medallion rebuild (`count_medallion.gd`) — not selected; existing ring
  medallion stays. (The row *accent* still comes from `building_neon`, which the
  medallion already consumes.)
- Nav-dock gold active-tab treatment — not selected.
- The `godot/design/premium_*` study files — reference only; not shipped, not deleted.

## Risk

Whole-app retint subtly shifts **every** overlay and menu cooler — the intended
cohesion, and the single thing to verify hardest (step 4 above). Everything else is
localized to two `_draw` methods and a palette table.
