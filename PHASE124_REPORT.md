# Phase 124 — City-First Layout

> **Historical — pygame prototype only.** Superseded by Godot portrait layout (P7).

**Date:** 2026-06-15  
**Scope:** Presentation only — left-column layout, scene atmosphere, click overlay. No gameplay, balance, or save changes.

---

## 1. Objective

Make the **city the visual centerpiece** of Idle Empire. The player should feel like they are watching their empire grow, not reading menus.

---

## 2. Success questions (15-second test)

| Question | Before (Phase 121 audit) | After (Phase 124) |
|----------|--------------------------|-------------------|
| Do they notice a **city**? | Rarely — scene was a ~70–160px footer sliver (~12% viewport) | **Yes** — scene is **43.6%** of window height at 900×720 |
| Do they notice an **empire**? | Click square + stat rows dominate | Skyline tiers, lampposts, traffic, neon signs scale with buildings |
| Do they see **growth**? | Only if they read building tab numbers | Skyline density visibly changes; rank/territory lighting layers add late-game glow |
| Or just **menus**? | ~75–85% perceived UI chrome | City first → header → goals → tabs; menus support the world |

**Verdict:** Left column now reads as **empire viewport + command stack**, not clicker panel with a thumbnail.

---

## 3. Layout metrics (900×720 landscape)

| Element | Before | After |
|---------|--------|-------|
| Scene height | ~70–160px elastic (~12%) | **314px (43.6%)** — hard floor `_SCENE_MIN_H=120`, target ≥40% viewport |
| Click zone | Separate 260×260 block above scene | **113×113 glass overlay** centered lower in scene |
| Draw order | Click → scene (scene under button) | **Scene → click overlay → prestige → goals → stats** |
| Goals | Full-width panel competing with scene | **Compact 72px glass panel** below prestige (max 2 rows) |
| Prestige | 44px strip | **72–96px** scaled strip under city |

Computed rects after `reinit_layout(900, 720)`:

```
_SCENE_RECT   Rect(8, 110, 402, 314)   # 43.6% of 720
CLICK_RECT    Rect(152, 223, 113, 113) # inside scene, lower-center
PRESTIGE_RECT Rect(8, 428, 402, 72)
GOALS         y=504, h=72
STAT_CLUSTER  y=582, h=42
```

---

## 4. Wireframes

### Before (Phase 121 — menu-first)

```
┌─ LEFT (~46%) ─────────────┐ ┌─ TABS / PANELS ─────────────┐
│ ┌───────────────────────┐ │ │ Bldgs │ Upgrs │ Mgrs │ …     │
│ │   BIG CLICK SQUARE    │ │ ├─────────────────────────────┤
│ │   (260×260 blue tile) │ │ │                             │
│ └───────────────────────┘ │ │      spreadsheet panel      │
│ prestige strip            │ │                             │
│ goals (3 rows)            │ │                             │
│ clicks / crew / mult      │ └─────────────────────────────┘
│ ┌─ tiny scene sliver ───┐ │
│ └───────────────────────┘ │
└───────────────────────────┘
```

### After (Phase 124 — city-first)

```
┌─ LEFT (~46%) ─────────────┐ ┌─ TABS / PANELS ─────────────┐
│ ┌─ CITY SKYLINE ────────┐ │ │ Bldgs │ Upgrs │ Mgrs │ …     │
│ │  YOUR EMPIRE  ~44% h  │ │ ├─────────────────────────────┤
│ │  smoke · traffic ·    │ │ │                             │
│ │  neon · heat haze     │ │ │      spreadsheet panel      │
│ │     ╭ HUSTLE ╮        │ │ │                             │
│ │     │ glass  │        │ │ └─────────────────────────────┘
│ └───────────────────────┘ │
│ prestige (compact)          │
│ OBJECTIVES (2 max)        │
│ clicks · crew · mult      │
└───────────────────────────┘
```

Visual hierarchy (implemented):

1. **City** — framed noir viewport with gold corner accents  
2. **Command header** — Phase 122 strips (unchanged)  
3. **Current goals** — below prestige, never over skyline  
4. **Tabs + systems** — right column unchanged  

---

## 5. Click zone integration

| Before | After |
|--------|-------|
| Solid blue 3D button in dedicated panel | Translucent **glass** disc with gold border |
| Label: implicit "click here" | **HUSTLE** display font + `+value` + hover "tap the street" |
| Idle pulse: blue glow ring | Soft **gold ellipse** pulse when income > 0 |
| Felt like app button | Reads as **street-level interaction** on the city |

Portrait mode: unchanged — scene hidden, click zone remains top block (existing constraint from SESSION4).

---

## 6. Empire growth visibility (presentation layers)

All driven by existing state fields — **no new mechanics**.

| Signal | Trigger | Effect |
|--------|---------|--------|
| Skyline tiers | `total_buildings` thresholds | Empty lot → storefronts → mid-rise → full towers (existing `draw_scene` tiers, now large enough to read) |
| District lighting | Building tier ≥35 | Flickering window grids, neon signs |
| Traffic | tier ≥15 | Animated car(s) on street |
| Smoke wisps | `heat ≥ 40` | Drifting ellipses above street |
| Heat haze | `heat ≥ 25` | Crimson atmospheric wash |
| Police activity | `heat ≥ 60` | Blue flash pulse (raid atmosphere) |
| Rank glow | rank ≥ Crime Lord | Gold horizon band |
| Territory lights | ≥5 territories owned | Window dots along skyline base |

Atmosphere renderer: `_draw_scene_atmosphere()` in `src/ui.py`.

---

## 7. Goal panel placement

- Moved **below** prestige — never overlaps `_SCENE_RECT`
- Height capped at `_GOALS_FULL_H = 72` (header + 2 objective rows)
- Glass panel styling matches Phase 122 noir (`_draw_glass_panel`)
- `current_goals(state, max_count=2)` — fewer rows, same goal data

Header still shows primary goal (Phase 122); left panel is detail, not duplicate billboard.

---

## 8. Theme cohesion

Preserved from Phase 122 noir palette:

- Gold accents (`NOIR_GOLD`, corner frame on city viewport)
- Glass panels (click overlay, objectives)
- Display fonts (`disp_xs` for HUSTLE / OBJECTIVES labels)
- Dark city atmosphere (ink sky bands, muted street)

Removed: bright blue click panel container that broke noir tone.

---

## 9. Files changed

| File | Changes |
|------|---------|
| `src/ui.py` | `reinit_layout()` city-first stacking; `draw_left_empire_frame()`; `draw_click_zone()` glass overlay; `draw_scene(..., state=)` + `_draw_scene_atmosphere()`; compact `draw_objectives()`; layout constants |
| `src/states.py` | Draw order: scene before click overlay |

### Preserve checklist

- [x] No mechanic changes  
- [x] Save fields untouched  
- [x] Tab structure unchanged  
- [x] Manager systems unchanged  
- [x] Portrait path preserved (scene skipped, existing behavior)  
- [x] Performance: atmosphere uses small surfaces; scene clip unchanged  

---

## 10. Screenshots

### After (captured)

Run: `python phase124_capture.py` → `phase124_screenshots/`

| File | Scenario |
|------|----------|
| `01_early_city.png` | 1 building, low heat — sparse lot |
| `02_mid_growth.png` | Mid tier skyline, heat 48% (smoke) |
| `03_late_skyline_heat.png` | Full towers, heat 72% (haze + police flash) |
| `04_prestige_locked_stack.png` | Locked prestige + goals + stat strip fit check |

### Before (reference)

Pre-124 layout documented in **Phase 121 audit** (`PHASE121_REPORT.md` §7) — scene sliver + dominant click square. No separate capture was kept; wireframe above matches audited layout.

---

## 11. Layout notes for future phases

- Scene width tracks `left_w - 2×pad` (~402px at default) — could extend to bleed under divider in Phase 125+  
- Click overlay size scales with scene (`min(40% width, 36% height)`) — stays proportional on resize  
- `_SCENE_MIN_H` prevents collapse on short windows; if stack overflows, scene yields before prestige (stack pinned below city)  
- Dragon HUD path unchanged — replaces scene when active  

---

## 12. Next steps (Presentation Saga)

### Recommended next: **Phase 127 — Noir theme pass**

Shift from “polished idle dashboard” to **organized-crime ledger**: dossier-style tabs, front-business building cards, menu aligned with landing page, serif for names/ranks + mono for numbers only. **No generative AI assets** — pygame primitives and typography only (`CLAUDE.md` Art & Assets).

| Phase | Focus | Status |
|-------|-------|--------|
| 125 | Turf sub-tab badges | Queued |
| 126 | Stats tiering + achievement entry | Queued |
| 127 | **Theme pass (typography, palette, tabs, cards, menu)** | **Next** |
| 128 | Shield pulse / auto-buy attribution toasts | Queued |

### Parallel track (non-UI — complete, no gameplay change)

Claude-side harness/docs sync (independent of UI phases):

- `sim_test_suite.py` — Pete's Pick (`pete_recommends_index`), hard prestige wipe assertions, 0 starting dealers
- `sim_smoke.py` — Phase 100 flat nav (`buildings` / `upgrades` / `managers` / `turf` / `stats`)
- `sim_harness.py` — corrected bootstrap comment (sim still seeds dealers for stability)
- `PROJECT_RULES.md` — prestige = semi-fresh restart; permanent multiplier persists

---

## 13. Re-run captures

```powershell
python phase124_capture.py
```
