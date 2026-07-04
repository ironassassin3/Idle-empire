# UI Style Audit — Criminal Empire (Godot)

**Date:** 2026-06-29  
**Scope:** P15 city-first ink theme (`UI_CITY_V2` + `UI_CITY_VIEW`, rustic off)  
**Method:** `docs/ui/capture_matrix/` review · fresh Godot screenshots (`_audit_*.png`) · theme/row/overlay code paths  
**Policy:** [`ART_POLICY.md`](../../ART_POLICY.md) — no AI assets; MM or code only

---

## Verdict

**The ink noir direction is locked and shippable as a code-first foundation.** Typography, palette, city viewport, and screen-to-screen theming are coherent. The gap to “next level” is not a missing art direction — it is **surface material depth** (procedural bakes vs authored MM graphs) and **content iconography** (lists are text-only). Do asset work only after this audit’s P1 backlog; skip rustic rollback unless taste gate fails.

**Composite score: 3.7 / 5** — strong identity, not yet premium tactile polish.

---

## Five-axis rubric

| Axis | Score | Evidence | Gap |
|------|-------|----------|-----|
| **1. Typography hierarchy** | **4 / 5** | `GameFonts` → `apply_city_v2_theme()`; menu uses Limelight + Cinzel + Cormorant italic + Space Mono (`_audit_menu.png`). HUD balance/IPS mono, rank Cinzel. | Building row names use theme body (Cormorant) not heading — names don’t pop vs descriptions. Section headers gold-capped but no size jump on Turf/Rivals. |
| **2. Surface tactility** | **3 / 5** | Six PNGs wired via `GameTheme._mm_slice_style()`; menu ledger shows subtle panel grain (`_audit_menu.png`). | All PNGs are `InkTextureBaker` procedural exports — `material_maker/` is empty (no `.mmat`). Progress tracks are flat `StyleBoxFlat` (`ink_progress_track_style`). Rows tint card texture via modulate — borders read, material doesn’t. |
| **3. Icon coverage** | **3.5 / 5** | Nine Phosphor SVGs on bottom nav + Turf subtabs; gear on config (`GameIcons`). | **Zero** per-building, faction, operation, perk, or resource icons. Lists (Bldgs, Rivals, Crew, tree branches) are text-scannable only. |
| **4. City viewport identity** | **4 / 5** | `city_view.gd` — tiered skyline, building signatures, pedestrians/traffic, heat haze/siren, district strip, art-deco frame. Signature vs generic idle UI. | Tier 0 still sparse on small screens (lamppost helps). Heat/district drama hard to validate in stale matrix — re-capture `tier2_heat75.png`. |
| **5. Menu → game → overlay cohesion** | **4 / 5** | Ink modal styles on menu ledger, overlays, prestige tree; rustic brackets gated (`overlay_frame.gd`, `menu_ledger_panel.gd`). `#0c0c14` field on menu + game. | Wax seal on buy rows (`draw_row_wax_seal`) reads rustic in ink path. Tutorial pill visible on most matrix shots — clutters 15s taste flow. |

---

## P15 taste gate (automated + code review)

| Step | Criterion | Result | Notes |
|------|-----------|--------|-------|
| 1 | Menu ink field, ledger modal, readable CTAs | **PASS** | `_audit_menu.png` — textured ink panel, no corner brackets |
| 2 | New/Continue → game, no layout pop | **DEFER** | Needs owner 15s device capture |
| 3 | Hustle band tap (no duplicate HUSTLE) | **PASS** | `HustleBand` dedicated; fallback hidden when city v2 |
| 4 | Bldgs buy → green ink affordance | **PASS** | `make_ink_row_card_flat(BUYABLE)` + `apply_row_affordance` |
| 5 | Config ink chips, no warm parchment | **PASS** | `ink_config_row_style()` / `apply_ink_chip_button` |

### Fail-criteria check (code)

| Fail condition | Result |
|----------------|--------|
| Rustic ledger brackets with city v2 | **PASS** — gated |
| City viewport missing | **PASS** — `CityViewport` on when `UI_CITY_VIEW` |
| Tab row clipped at 720×1280 | **DEFER** — owner device |
| Hustle dead zone | **PASS** — `get_hustle_rect_global()` |
| Config/Stats warm `BG_CARD` | **PASS** — `is_city_v2_active()` branches |

**Owner sign-off:** still open ([`P15_REPORT.md`](../../P15_REPORT.md) § Owner Taste Gate).

---

## Capture matrix status

| Item | Status |
|------|--------|
| Matrix count | 29 PNGs + README (2026-06-20) |
| Staleness | **High** — predates OFL font pack, Phosphor nav icons, ink texture bakes |
| Fresh audit shots | `_audit_menu.png`, `_audit_affordance.png`, `_audit_heat75.png`, `_audit_tier2.png` (2026-06-29) |
| Action | **Regenerate full matrix** after P1 asset pass; bump README date |

---

## KEEP (do not regress)

- **Palette tokens** in `game_theme.gd` — ink bg `#08070a` / `#0c0c14`, gold `#c8a35a`, bone text `#e8e0d4`
- **City viewport** as code-drawn signature (`city_view.gd`) — not texture swaps
- **Font stack** aligned with landing (`godot/assets/fonts/`)
- **Phosphor nav icons** — stroke weight matches ink chrome
- **Ink affordance borders** — green buyable / gold locked / owned green-muted
- **Overlay queue + reduced motion** — film grain off when particles off
- **Procedural audio** path (M1 music) — no external clip dependency
- **Hand `icon.svg`** crown motif for launcher

---

## FIX (code / polish, no new art)

| Priority | Item | Where | Effort |
|----------|------|-------|--------|
| P0 | Regenerate capture matrix after font/icon/texture land | `screenshot.gd` + `docs/ui/capture_matrix/` | 30 min |
| P0 | Owner 15s taste gate + Moto G FPS pass | manual | 1 hr |
| P1 | Gate wax seal to rustic only; city v2 uses ink dot affordance | `game_theme.gd` `draw_row_wax_seal` | 15 min |
| P1 | Building row name → `GameFonts.heading()` | `building_row.gd` | 10 min |
| P1 | Screenshot harness: ensure seeded cash/heat/tier visible before capture (raise `--frames` or force `_refresh_city` post-seed) | `screenshot.gd` | 30 min |
| P2 | Hide tutorial pill after step 1 in capture/taste scripts | `game_screen.gd` / harness flag | 20 min |
| P2 | Prestige tree branch buttons — ink chip style parity with config | `prestige_tree_overlay.gd` | 30 min |

---

## ADD (assets — policy-safe, by ROI)

### P1 — highest impact

| Asset | Count | Source | Wiring exists? |
|-------|-------|--------|----------------|
| Material Maker `panel_9slice.mmat` + PNG | 1 | MM per [`MATERIAL_MAKER_SPEC.md`](../../godot/assets/ui/MATERIAL_MAKER_SPEC.md) | Yes — `TEX_PANEL` |
| MM `card_frame` + `modal_frame` + `tab_bar` | 3 | MM | Yes — `TEX_CARD`, `TEX_MODAL`, `TEX_TAB_BAR` |
| Building row icons | 11 | Hand SVG or Phosphor subset → `assets/icons/buildings/` | **New** — `GameIcons` + `building_row.tscn` icon slot |

### P2 — identity / scannability

| Asset | Count | Source | Notes |
|-------|-------|--------|-------|
| Rival faction crests | 5 | Hand SVG (owner) or minimal code SVG | Rivals tab text wall |
| Prestige branch glyphs | 4 | Phosphor or hand SVG | Kingpin / Warlord / Cartel / Consigliere |
| Perk node icons | ~12–20 | Phosphor map | Tree grid readability |
| Progress bar track PNG | 1 | MM | Fills stay code-drawn per policy |

### P3 — atmosphere (optional)

| Asset | Source | Notes |
|-------|--------|-------|
| `film_grain.mmat` | MM | Replace bake; keep alpha 5–8% |
| `wax_seal.mmat` | MM | Only if rustic path revived |

### Explicitly defer

- AI asset packs, stock UI kits, DALL·E backgrounds
- Raster city skyline sprites (breaks procedural identity)
- External music/SFX libraries

---

## Prioritized backlog (recommended order)

```
1. Owner taste gate (15s) + device FPS        ← unblock P15 sign-off
2. Regenerate capture matrix                  ← baseline for future diffs
3. MM panel + card graphs (commit .mmat)      ← tactile upgrade, zero code
4. 11 building SVGs                           ← list scannability
5. Code fixes: wax seal gate, row heading font
6. MM modal + tab_bar
7. Faction crests + tree glyphs
```

---

## Style one-liner (for future assets)

> **Ink art-deco noir** — cold navy-black surfaces, hairline gold brass, bone serif body, mono economy numbers, procedural neon city. Not parchment/rustic (P14), not neon cyberpunk. Material depth from MM noise + edge wear; motion from code (grain, skyline, heat); icons as thin gold strokes.

---

## Audit artifacts

| File | Purpose |
|------|---------|
| `docs/ui/capture_matrix/_audit_menu.png` | Current menu (fonts + panel texture) |
| `docs/ui/capture_matrix/_audit_tier2.png` | Current game shell (post-font pass) |
| `docs/ui/capture_matrix/*.png` | Historical matrix (pre-pass) |

---

## Sign-off

| Gate | Owner | Date | Pass? |
|------|-------|------|-------|
| Style audit (this doc) | Agent | 2026-06-29 | ✅ |
| P15 taste gate (15s flow) | Owner | | ☐ |
| Device pass (Moto G ≥30 FPS) | Owner | | ☐ |
| P15 phase close | Owner | | ☐ |
