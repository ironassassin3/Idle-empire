# Identity Medallion Pass — Design

**Date:** 2026-07-18
**Status:** Approved (owner, this session)
**Scope:** One shared code-drawn glyph library + medallion control, applied to four list
screens (Rivals, Managers, Turf, Crew). ART_POLICY: primitives only, no assets.

## Context

The 2026-07-17 UI audit found four screens with placeholder-grade identity while the
Buildings tab already has a proven idiom (`count_medallion.gd`: tinted disc + code-drawn
business glyph + `GameTheme.building_neon` single-sourced color):

- **Rivals** — faction "symbol" is a bare letter jammed into the name ("D Crimson Kings");
  no faction color anywhere on the card despite `rival_system.gd` carrying per-faction
  `color`, `symbol`, `faction_key`, `theme`.
- **Managers** — pure text cards; no emblem. Owner's stated art want
  (manager sprites → decided code-drawn sigils, never painterly portraits).
- **Turf** — flat gray district cards; no district-type glyph; plain "YOU" holder tag.
- **Crew** — bare letters P/C/S/T/H as the avatar column.

Owner decisions locked this session: all four screens in one pass; rivals get **full
faction theming** (medallion + tinted accent edge + tinted name), not medallion-only.

## Components

### 1. `SigilGlyphs` — shared glyph library (new)

`godot/scripts/ui/sigil_glyphs.gd`, `class_name SigilGlyphs`, static functions drawing on
a passed `CanvasItem` (same signature style as `count_medallion.gd`'s
`_draw_business_glyph(key, center, radius, color)`).

- **Business glyphs (moved, not redrawn):** the 11 `match` arms move verbatim from
  `count_medallion.gd::_draw_business_glyph` into
  `SigilGlyphs.draw_glyph(canvas, key, c, radius, col)`. `CountMedallion` delegates to it;
  its public API and the Buildings tab are unchanged.
- **Faction crests** (keys = `faction_key`): `crimson_kings` flame, `silver_hand` open
  palm, `iron_union` gear, `network` eye, `blackwater` triple wave. Bold single-color
  marks readable at ~40 px, same visual weight as the business set.
- **District types:** `residential` house, `commercial` awning storefront, `industrial`
  smokestack, `government` columned portico.
- **Crew roles:** `crew_protection` shield, `crew_collection` coin stack,
  `crew_smuggling` crate, `crew_territory` pennant flag, `crew_heat` droplet.
  (Prefixed keys so they can never collide with business/district keys in the one
  `draw_glyph` dispatch.)
- Unknown key falls back to the existing filled-circle default.

### 2. `IdentityMedallion` — thin display control (new)

`godot/scripts/ui/identity_medallion.gd`, `class_name IdentityMedallion extends Control`
(~60 lines). Properties, each `queue_redraw` on change:

- `glyph_key: String` — dispatched through `SigilGlyphs.draw_glyph`.
- `tint: Color` — disc fill = `tint.darkened(0.74)`, ring = tint at 0.95, inner accent
  ring = tint at 0.5, glyph = `tint.lightened(0.35)`.
- `dimmed: bool` — grayscale treatment for eliminated/locked (disc `Color("161020")`,
  ring `GameTheme.CHIP_BORDER`, glyph `GameTheme.TEXT_MUTED`).

Same disc geometry as `CountMedallion` (radius = min side/2 − 3, 2 px outer ring) so the
five list screens read as one family. No count badge, no font dependency.

## Per-screen application

### Rivals (`rival_row.gd` + its scene)

- `IdentityMedallion` inserted at the left of the Top HBox (44×44), `glyph_key` =
  `faction_key`, `tint` = rival `color`. Eliminated → `dimmed = true`.
- The letter prefix is removed: name label shows the faction name only.
- Name label color = faction `color` lightened toward readability (min contrast against
  the card: `color.lerp(Color.WHITE, 0.35)`).
- Left accent edge: per-faction `border_color` on the row's StyleBox (same pattern as
  building rows' per-business accent). Eliminated rows keep the muted default.
- Action buttons stay neutral violet (`apply_row_buy_button` untouched) so CTAs remain
  consistent across the game.

### Managers (`manager_row.gd` + its scene)

- `IdentityMedallion` at the left of the Header HBox (40×40), `glyph_key` = the business
  key of the building the manager runs, `tint` = `GameTheme.building_neon(key)` — the
  manager, their row, and their tower in the city all carry the same signature color.
- Mapping: `manager_defs.gd` row[1] is the building index; the index→key map is the
  canonical building key order (`dealer, racket, chop, betting, pawn, loan, casino, club,
  dock, arms, hq`). The three index-10 managers (Consigliere, Rudy, Rob) all read `hq`
  (crown) — acceptable, they are the HQ tier.
- Locked/unhired-but-visible rows: `dimmed = true` until hired.

### Turf (`territory_row.gd` + its scene)

- `IdentityMedallion` (36×36), `glyph_key` = `district_type`, `tint` = the district's
  existing `color`.
- Holder tag coloring: "YOU" → `GameTheme.GOLD`; rival-held → `GameTheme.SIREN_RED` with
  the rival's name; unclaimed → `GameTheme.TEXT_MUTED`. Text content unchanged otherwise.

### Crew (`crew_row.gd` + its scene)

- The letter Label is replaced by an `IdentityMedallion` (36×36), `glyph_key` =
  `crew_<role>`, fixed per-role tints from existing tokens:
  Protection `GameTheme.NEON_CYAN`-family token, Collection `GameTheme.GREEN`,
  Smuggling `GameTheme.GOLD`, Territory the violet hero token, Heat `GameTheme.SIREN_BLUE`.
  (Exact token names resolved in the plan against `game_theme.gd`; if a named token is
  absent, use the closest existing constant — no new palette entries.)

## Constraints

- ART_POLICY: primitives only; colors from existing tokens/data. No textures, no assets.
- No per-frame allocation; `_draw` only, redraw on property change.
- Scene changes limited to inserting one medallion node per row scene (and deleting the
  crew letter label).
- `CountMedallion` public behavior unchanged — Buildings tab must be pixel-equivalent.
- No save/balance/signal changes anywhere in this pass.

## Verification

- `shell_smoke.gd` passes (headless).
- `ui_capture.ps1` before/after stills of tabs 7 (Mgrs), 2 (Turf), 3 (Rivals), 4 (Crew)
  at 720×1280, read and judged: crests/tints distinct per faction, manager emblems match
  their business neon, district glyphs legible at 36 px, crew roles tellable apart.
- Buildings-tab still (tab 0) before/after compare: no visible change.

## Out of scope

Gold-remnant theme cleanup, goal-bar/toast micro-polish, rooftop-sign identity, casino/
dragon/prestige surfaces — later passes.
