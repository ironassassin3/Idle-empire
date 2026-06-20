# UI Rebuild v2 Architecture — Criminal Empire (Godot 1.0)

**Status:** Design document only (2026-06-20). **No implementation in this phase.**  
**Supersedes:** P14 rustic/ledger visual direction for *future* UI work. P14 UX patterns (HUD, badges, overlays, telemetry) remain in force.  
**Prior art:** [`UI_OVERHAUL_ARCHITECTURE.md`](UI_OVERHAUL_ARCHITECTURE.md) (P14), [`PHASE124_REPORT.md`](PHASE124_REPORT.md) (pygame city-first), [`P14_REPORT.md`](P14_REPORT.md) (lessons).  
**Policy:** [`ART_POLICY.md`](ART_POLICY.md) — code-drawn city + optional Material Maker ambient tiles only; no generative AI.

---

## 1. Problem statement

### Why P14 / rustic failed user taste

P14 delivered **retention UX** (economy HUD, buy-mult, tab badges, overlay queue, telemetry, M1 music) but optimized for **ledger clarity**, not **empire fantasy**. Owner feedback after P14.9:

| Issue | Evidence | Player read |
|-------|----------|-------------|
| **No city display** | Godot `game_screen.gd` left column = coin, hustle, heat, prestige, dragon HUD — **zero skyline/scene node** | "Spreadsheet with wax seals" |
| **Rustic ledger over-indexed** | `RusticTextureBaker`, warm paper/leather panels, bracket ledger frames (`overlay_frame.gd`, `menu_ledger_panel.gd`) | Dossier/accountant, not crime boss watching a city grow |
| **Wrong hierarchy for fantasy** | P14 north star: *"ledger-clear idle crime sim"* ([`UI_OVERHAUL_ARCHITECTURE.md`](UI_OVERHAUL_ARCHITECTURE.md) §1) | Correct for scanability; **wrong emotional anchor** |
| **Pygame parity gap** | Phase 124 achieved 43.6% viewport city + atmosphere; never ported to Godot portrait | Regression vs lab prototype the owner liked |
| **15-second test fails** | Phase 121 audit verdict still applies to Godot ship build | Silent viewer sees tabs and numbers, not an empire |

P14 was the **right UX pass on the wrong visual thesis**. Touch-first patterns ship; **rustic ledger chrome and city absence** do not.

### Gap vs pygame city fantasy

| Dimension | Pygame Phase 124–127 | Godot P14 |
|-----------|----------------------|-----------|
| City viewport | ~44% left column, always visible (landscape) | **Missing** |
| Growth signal | Skyline tiers from `total_buildings` | Building tab numbers only |
| Heat fantasy | Smoke, crimson haze, police flash on city | Heat bar in left column |
| Turf fantasy | Window dots along skyline base (≥5 districts) | Turf tab rows only |
| Hustle placement | Glass overlay **on** city street | Separate button in left stack |
| Theme | Noir ink/gold **on city** | Rustic paper panels **around lists** |

---

## 2. Design north star

> **The player runs a criminal empire they can *see* grow — not a ledger they scroll.**

**Fantasy contract:** Portrait phone, 15 seconds, no text → viewer recognizes **a noir city under syndicate control** getting denser, hotter, and more lit as buildings and districts accumulate.

**References:**

- **Internal:** Phase 124 city-first layout ([`PHASE124_REPORT.md`](PHASE124_REPORT.md)), Phase 127 noir palette ([`PHASE127_REPORT.md`](PHASE127_REPORT.md)), landing page art-deco noir ([`PHASE121_REPORT.md`](PHASE121_REPORT.md) §2).
- **Genre:** Egg Inc. (farm as primary visual, menus secondary), Idle Light City (dark → lit skyline), Idle Miner (gameplay zone vs UI zone separation), Ant/Bee Colony lineage (construction-as-reward — with retention caveats).

**Non-goals:** New mechanics, new tabs/currencies, generative art, abandoning P14 HUD/overlay/telemetry patterns.

---

## 3. What pygame had — city/atmosphere inventory

All presentation-only; driven by existing state. Source: [`src/ui.py`](src/ui.py).

### Layout (Phase 124)

| Element | Location | Ref |
|---------|----------|-----|
| `_SCENE_RECT` | ~43.6% viewport height, left column | `reinit_layout()` ~L72–186 |
| `draw_left_empire_frame()` | Gold corner brackets on city viewport | L1306–1318 |
| `CLICK_RECT` | Glass hustle disc **inside** scene, lower-center | Phase 124 metrics |
| Draw order | Scene → click overlay → prestige → goals → stats | [`PHASE124_REPORT.md`](PHASE124_REPORT.md) §4 |

### Skyline tiers (`draw_scene`, L1363–1526)

| `total_buildings` | Visual |
|-------------------|--------|
| &lt; 5 | Empty lot, lamppost, lone figure, stars |
| 5–14 | Storefronts, neon sign |
| 15–34 | Multiple storefronts, **animated traffic** |
| 35–79 | Mid-rise with **flickering window grids**, neon signs |
| ≥ 80 | **Full towers**, moon, dual traffic lanes |

Helpers: `_lamppost`, `_storefront`, `_car`, `_figure`, sky bands (ink → smoke gradient).

### Atmosphere layers (`_draw_scene_atmosphere`, L1321–1360)

| Signal | Trigger | Effect |
|--------|---------|--------|
| Heat haze | `heat ≥ 25` | Crimson wash overlay |
| Smoke wisps | `heat ≥ 40` | Drifting ellipses above street |
| Police flash | `heat ≥ 60` | Blue pulse (raid atmosphere) |
| Rank glow | rank ≥ Crime Lord | Gold horizon band |
| Territory lights | ≥ 5 districts owned | Gold window dots along skyline base |

### Hustle on city (`draw_click_zone`, L1250–1298)

- Glass disc with gold border, **HUSTLE** display label, `+click_value`
- Gold ellipse pulse when `income_per_second > 0`
- Hover: "tap the street" — diegetic, not app-button

### Global atmosphere (Phase 127)

| Layer | Function | Ref |
|-------|----------|-----|
| `draw_noir_atmosphere()` | Film grain + vignette (cached) | L421–425 |
| Heat wash (full frame) | Crimson overlay scales with heat | Phase 127 §4 |
| `_draw_glass_panel()` | Objectives, prestige, stat mini-cards | L760+ |

### Portrait constraint (pygame)

Scene **hidden** in portrait; click zone remains top block ([`PHASE124_REPORT.md`](PHASE124_REPORT.md) §5). **Godot v2 must invert this:** portrait is ship target — city is **mandatory** in portrait, not optional.

---

## 4. Competitive UI research — city/world visualization

| Game | Visual progression hook | What to steal | What to avoid |
|------|-------------------------|---------------|---------------|
| **Egg Inc.** | 3D farm + chicken swarm is the screen; menus minimal ([Play Store](https://play.google.com/store/apps/details?id=com.auxbrain.egginc)) | **Single focal world**; research unlocks change farm appearance | 3D asset pipeline — use code silhouettes |
| **Idle Light City** | Dark grid → neon-lit skyline; tier changes building style ([CookieClickers.io](https://cookieclickers.io/game/idle-light-city/)) | **Lighting-up progression**; landmark multipliers as visual anchors | Pure grid builder — CE has turf warfare narrative |
| **Idle Miner Tycoon** | Mine depth = vertical layers; UI/gameplay zone split ([Ballmann redesign](https://www.ballmann.design/idle-miner)) | **Clear boundary** between world viewport and chrome; collapsible event drawer | Launch pop-up floods; floating promo icons |
| **AdVenture Capitalist** | Business icons row — weak city fantasy | One-tap buy scanability | No persistent world — CE differentiator is city |
| **Monument Builder / Ant Colony** | Construction completes visibly ([Rakib Jahan case study](https://rakibjahan.com/ant-colony-development-overview-and-iterations/)) | **Short-term visual milestones** per upgrade | Visual-only loops without depth — CE has turf/heat/rivals |
| **Office Cat / Food Empire Inc.** | Station unlocks change diorama | Front-business readable silhouettes | Hyper-casual shallow UI — CE needs stat depth |
| **Melvor Idle** | No city — stats excellence | Deep drill-down when requested | Header bloat on mobile — keep CE header single-line |
| **Hades** | Hub world + peripheral HUD | **Diegetic interaction** in world space | PC hover density |

**Synthesis:** Retention correlates with **visible state change** tied to existing counters (buildings, districts, heat). Leaders separate **world viewport** from **management chrome** and never hide the world behind ledger panels.

---

## 5. Three concept directions (owner picks later)

### A) Skyline progression strip

**Mock (portrait 720×1280):**

```
┌─────────────────────────────┐
│ $12.4M  ▲ $2.1K/s   [Rank▾] │  ← P14 economy header (keep)
├─────────────────────────────┤
│ ┌─ YOUR EMPIRE ───────────┐ │
│ │  ★ · skyline tiers · ★  │ │  ← ~28–32% height (220–380px)
│ │  smoke / traffic / neon │ │
│ │      ╭ HUSTLE ╮         │ │  ← glass tap on street
│ └─────────────────────────┘ │
│ heat ▓▓▓░░  prestige chip   │  ← compact status strip
├─────────────────────────────┤
│     [ tab content scroll ]  │
├─────────────────────────────┤
│ Bldgs Upgrs Mgrs Turf Stats │  ← P14 bottom nav (keep)
└─────────────────────────────┘
```

| Pros | Cons |
|------|------|
| Direct Phase 124 parity; binds to `total_buildings` tiers | 20 districts not individually visible |
| One `_draw()` module; low scene complexity | Less turf "map game" fantasy |
| Strong 15-second test | Fixed height fights small phones + dragon HUD |
| Heat/rank atmosphere already specced in pygame | |

**Portrait fit:** Excellent — horizontal skyline reads at any width; hustle overlay centered in strip.

---

### B) District map (turf-integrated)

**Mock:**

```
┌─────────────────────────────┐
│ header (economy HUD)          │
├─────────────────────────────┤
│ ┌ stylized city map ────────┐ │
│ │ 20 nodes · player=gold    │ │  ← abstract nodes, not geo-accurate
│ │ rival=tinted · contested=pulse│
│ │ tap node → Turf tab focus │ │
│ └───────────────────────────┘ │
│ building tier bar (11 pips)   │  ← secondary strip
├─────────────────────────────┤
│ tab content / bottom nav      │
└─────────────────────────────┘
```

| Pros | Cons |
|------|------|
| Binds to **20 districts** + 5 rivals + contested state | Harder to read in 15s test ("map" vs "city") |
| Turf tab and world view **unified** | More UI code (layout, hit tests, 20 nodes) |
| Capture/loss visibly changes map | Building growth less visceral than skyline |
| Achievement hooks (City Dominator) | Risk of "strategy map" not "street noir" |

**Portrait fit:** Good with **simplified 4×5 grid** or **vertical ward list** hybrid; full map crowded on narrow widths.

---

### C) Front-business street scene

**Mock:**

```
┌─────────────────────────────┐
│ header                        │
├─────────────────────────────┤
│ side-view street scroll ──►   │
│ [Laundromat][Bar][Casino]...  │  ← 11 building slots
│ owned=lit · locked=dark shell │
│ hustle on sidewalk            │
├─────────────────────────────┤
│ tabs / bottom nav             │
└─────────────────────────────┘
```

| Pros | Cons |
|------|------|
| Each of **11 buildings** has identity | Horizontal scroll fights thumb zone |
| Front-business fantasy (Phase 127 cards) | Weak district/20-node story |
| Strong early-game readability | Late-game horizontal sprawl |
| Pete pick can highlight one storefront | Doesn't show "empire scale" towers |

**Portrait fit:** Moderate — prefer **2-row staggered strip** (6+5) over horizontal scroll; still cramped.

---

## 6. Recommended direction

**Primary: Concept A — Skyline progression strip**  
**Secondary layer: District glow from Concept B** (window dots + optional mini-map chip, not full map)

### Rationale tied to existing systems

| System | Skyline strip binding |
|--------|----------------------|
| **11 buildings** | `total_buildings` → 5 skyline tiers (pygame thresholds: 5/15/35/80) |
| **20 districts** | Base skyline **window dots** + count; Turf tab keeps detail rows |
| **Heat** | `_draw_scene_atmosphere` parity: haze, smoke, police flash |
| **Rank / prestige** | Horizon gold band at Crime Lord+ |
| **5 rivals** | Optional: rival-colored smog at map edge (Turf subtab context) |
| **Hustle / coin** | Glass overlay **on** city (Phase 124), not left-column stack |
| **Dragon patron** | Collapsed chip **beside** city strip, not competing for 40% left column |

Concept B alone over-indexes turf UI (already a full tab). Concept C under-delivers late-game tower fantasy. **A + district dots** matches pygame proven layout and P14 mobile portrait constraint.

---

## 7. Information architecture

### Chrome budget (learn from P14 mistakes)

**Max 4 persistent regions** (was 3 in P14; city adds one):

1. **Header** — economy nouns only (P14.3 keep)
2. **City viewport** — **always visible** (NEW)
3. **Status micro-strip** — heat + shield + prestige-ready chip (collapsed from old left column)
4. **Bottom nav** — verbs (P14.4 keep)

**Retire:** Tall left column competing with tabs. Coin/hustle move **into** city viewport.

### Where city lives

| Context | City visibility |
|---------|-----------------|
| All 5 primary tabs | **Always visible** (fixed height %) |
| Turf subtabs | Same strip; optional pulse on district capture |
| Config (gear) | City visible behind dim or shrinks to 18% — **never hidden** |
| Full-screen overlays (prestige tree, dragon patron, elim) | City hidden OK |
| Queued modals (offline, milestone, event) | Dim city; **do not** remove from tree |
| Tutorial banner | Bottom of city strip or below status strip — **never over skyline** |

### HUD (keep P14)

- Balance largest, IPS second, rank truncates
- Buy-mult chip, advice chip
- Tab badge pills
- Overlay single-flight queue

### Tabs (unchanged structure)

5 bottom + Turf 4 subtabs + gear Config — **content styling** changes in P15.6, not IA.

### Overlays (P14 lessons)

| Keep | Fix |
|------|-----|
| Queue: offline → daily → elim → milestone → event | Bracket ledger frames → **city-aware modal** (dark glass, not paper ledger) |
| Telemetry dismiss timing | — |
| Reduced motion skips grain/pulse | City atmosphere respects reduced motion (static haze OK) |

---

## 8. Visual language v2

### Move away from rustic ledger

| Retire (P14/rustic) | Replace with |
|---------------------|--------------|
| Warm paper/leather `RusticTextureBaker` panels | **Ink/smoke** flat + subtle grain ([`noir_theme.tres`](godot/theme/noir_theme.tres) base) |
| Ledger bracket frames on every surface | Gold corner accents **on city viewport only** |
| Wax-seal metaphor as dominant buy affordance | **Neon/sign glow** on affordable rows; seal optional icon |
| "Case file" / dossier tab copy styling | Short verb labels on bottom nav (already done) |
| Menu ledger hero panel | City silhouette preview + economy stats |

### New palette / texture approach

| Layer | Method |
|-------|--------|
| City sky/street | Code `_draw()` — pygame parity ([`src/ui.py`](src/ui.py) `draw_scene`) |
| UI panels | `StyleBoxFlat` ink/smoke + 1px gold hairline |
| Ambient grain | Existing film grain overlay (P14.8) — **lighter** over city |
| Optional MM | **One** brick/asphalt tile for street band only — not full ledger paper ([`ART_POLICY.md`](ART_POLICY.md) §4) |
| Motion / heat | Code modulate — never baked into textures |
| Typography | Display serif for rank/city label; mono for numbers only (Phase 127) |

### Audio alignment

[`MUSIC_ARCHITECTURE.md`](MUSIC_ARCHITECTURE.md): M1 famiglia loop + M2 heat tension **react to city viewport** (heat haze visible ↔ tension layer). District capture stinger (M3 stub) fires on map dot pulse.

---

## 9. Phase plan P15+

**Umbrella: P15 — City-First UI Rebuild v2**

| Phase | Goal | Scope (in) | Deliverables | Exit criteria | Deps |
|-------|------|------------|--------------|---------------|------|
| **P15.0** | Architecture lock & taste gate | This doc; owner picks A/B/C; 3 mock screenshots (code-drawn spike, no ship) | Signed direction; `docs/ui/p15_mocks/` | Owner 15s-test pass on mock | P14 complete |
| **P15.1** | `city_view` module spike | `city_view.gd` + unit draw; tier thresholds from pygame | Standalone `Control` renders 5 tiers headless | Screenshot matches pygame tier 1 vs 5 | P15.0 |
| **P15.2** | Layout restructure | `game_screen.tscn`: Header → CityViewport → StatusStrip → Body → BottomBar; remove tall left column | Scene tree diff; safe-area pass | City ≥28% on 720×1280; notch clears header | P15.1 |
| **P15.3** | Data binding | `GameState` → skyline tier, heat layers, rank glow, district dots | `city_view.refresh(state, dt)` API | Buying building changes tier ≤1 frame; heat 60+ flash | P15.2 |
| **P15.4** | Theme v2 | Default `noir_theme.tres`; `UI_RUSTIC_THEME=false`; retire rustic wrap paths | `GameTheme` v2 tokens; flag rollback | Soak PASS; owner rejects rustic in side-by-side | P15.2 |
| **P15.5** | Hustle + coin on city | Move `_coin_btn` / `_hustle` into city overlay; glass styling | Tap targets ≥48px on street | Hustle SFX unchanged; coin ad row optional below strip | P15.3 |
| **P15.6** | Tab content de-ledger | Row cards: ink frames not paper; building names stay front-business | Row scene theme pass | Affordability scan at glance (green/gold edge) | P15.4 |
| **P15.7** | Migration / rollback | `GameConfig.UI_CITY_VIEW` + `UI_RUSTIC_THEME` independent flags | Config toggle (dev); README | One-flag revert to P14 layout for soak | P15.2–P15.6 |
| **P15.8** | Validation | Capture matrix; telemetry ext; device pass | `P15_REPORT.md`; matrix filled | Moto G FPS ≥30; owner taste gate; 5+ UI events still fire | P15.7 |

**Estimated:** 9 sub-phases (P15.0–P15.8). **Out of scope:** new mechanics, MM batch export (optional P15.4+), 3D city, generative art.

---

## 10. Technical architecture

### Module: `city_view.gd`

```
res://scenes/ui/city_view.tscn
  CityView (Control)          ← scripts/ui/city_view.gd
    HustleOverlay (Control)   ← glass tap zone, optional separate for input
    DistrictDots (Control)    ← optional sub-layer
```

**Responsibilities:**

- `_draw()` skyline tiers (port from pygame `draw_scene` logic)
- `_draw_atmosphere()` heat/rank/district layers
- `refresh(state, time)` — called from `game_screen._process` at 30fps max (not every sim tick)
- `get_hustle_rect()` — for tutorial highlights

### Scene integration (`game_screen.tscn`)

```
Root/VBox/
  Header          (unchanged P14)
  CityViewport    (NEW — size_flags_vertical expand ratio ~0.30)
  StatusStrip     (HBox: HeatBar, Shield, PrestigeChip, DragonChip collapsed)
  Body/
    Right/        (tab scrolls — remove Left column)
  BottomBar       (unchanged)
```

### Data binding

| State field | City effect |
|-------------|-------------|
| `buildings[i].owned` → sum | Skyline tier |
| `GameState.heat` | Haze, smoke, police flash |
| `prestige_tokens` → rank | Horizon glow |
| `territories` owned count | Window dots (cap 12) |
| `GameState._time` or local `_t` | Traffic, flicker, pulse |
| Rival contested districts | Optional dot color override |

**No new save fields.** Read-only bind to existing `GameState`.

### Performance budget

| Rule | Target |
|------|--------|
| City redraw | ≤30 Hz; skip if tab occluded by full-screen overlay |
| Allocations | **Zero per frame** — no `Image.create` in `_draw` |
| Cached surfaces | Grain/vignette global (existing); city uses immediate draw only |
| Draw calls | Single `Control._draw` + child overlays ≤5 |
| District dots | O(min(owned, 12)) circles |
| Memory | No new textures &gt;256² except optional MM street tile |

### Safe area / portrait

- `_apply_safe_area()` applies to `Root` margins — city viewport **inside** safe area, not under notch
- Minimum city height: 180px @ 720w; scales with `%` of body
- Short aspect (19.5:9): city yields to **min height** before header compresses

---

## 11. What to keep from P14

Explicit **do not regress**:

- Global buy-mult chip (×1 / ×10 / Max)
- Tab badge pills (Bldgs/Upgrs/Mgrs/Turf)
- Economy HUD hierarchy (balance &gt; IPS &gt; rank)
- Advice chip (Sticky Pete / Rudy)
- Overlay single-flight queue + dismiss telemetry
- All P14 UI telemetry events ([`P14_REPORT.md`](P14_REPORT.md) §9)
- M1 music + heat tension stub ([`MUSIC_ARCHITECTURE.md`](MUSIC_ARCHITECTURE.md))
- Reduced motion toggle
- Safe area application
- Row affordability tint logic (restyle, don't remove)
- `sim_godot_soak.py` / `memory_soak.gd` PASS requirement
- Config gear isolation; no sixth tab

---

## 12. What to discard

| Asset / pattern | File(s) | Action |
|-----------------|---------|--------|
| Rustic default ON | `GameConfig.UI_RUSTIC_THEME`, `rustic_ui.gd` | Default **false**; deprecate |
| `RusticTextureBaker` as primary skin | `rustic_texture_baker.gd` | Keep for rollback only |
| `_apply_rustic_surfaces()` panel wrap | `game_screen.gd` L251+ | Remove when v2 ships |
| Ledger bracket overlay chrome | `overlay_frame.gd`, `menu_ledger_panel.gd` | Replace with dark glass |
| Warm paper palette tokens | `GameTheme` rustic path | Revert to noir ink/bone/gold |
| Tall left column layout | `game_screen.tscn` Body/Left | Replace with city + status strip |
| P14 north star wording | docs | "Ledger-clear" → "City-visible" |

**Optional keep:** MM PNG drop-in path for **one** ambient tile — not full ledger suite.

---

## 13. Validation

### Capture matrix (extend [`docs/ui/capture_matrix/`](docs/ui/capture_matrix/README.md))

| Scenario | Assert |
|----------|--------|
| 0 buildings | Empty lot tier |
| 1 / 10 / 40 / 100 buildings | Tier transitions |
| Heat 0 / 50 / 75 | Haze + smoke + flash |
| 0 / 5 / 20 districts | Dot count |
| Crime Lord rank | Horizon glow |
| Each bottom tab | City visible |
| Offline overlay | City dimmed, not removed |
| Prestige tree full-screen | City hidden OK |

Tooling: extend [`godot/scripts/tools/screenshot.gd`](godot/scripts/tools/screenshot.gd) with `--city-tier` presets.

### User taste gate (blocking)

Before P15.4 ships to default:

1. Owner 15-second silent screen recording
2. Side-by-side: P14 rustic vs P15 city — **city must win** on "empire" prompt
3. If fail → revisit Concept B map or hybrid without reverting P14 UX patterns

### Device pass

- [`DEVICE_TEST_CHECKLIST.md`](DEVICE_TEST_CHECKLIST.md) §A–B on Moto G
- FPS ≥30 with city + grain + music
- Hustle tap ≥48px @ bottom third of city strip

### Telemetry (extend, don't replace)

Add optional:

| Event | When |
|-------|------|
| `ui_city_tier_change` | Skyline tier boundary crossed |
| `ui_hustle_tap` | Hustle on city (migrate from button id) |

Existing P14 funnel must remain green after P15.8.

---

## Appendix — file map (implementation reference)

| Purpose | Path |
|---------|------|
| Current ship UI | [`godot/scripts/ui/game_screen.gd`](godot/scripts/ui/game_screen.gd) |
| Pygame city reference | [`src/ui.py`](src/ui.py) `draw_scene`, `_draw_scene_atmosphere`, `draw_click_zone` |
| Theme tokens | [`godot/scripts/ui/game_theme.gd`](godot/scripts/ui/game_theme.gd) |
| Districts data | [`godot/scripts/systems/territory_system.gd`](godot/scripts/systems/territory_system.gd) (20 districts) |
| Phase 124 spec | [`PHASE124_REPORT.md`](PHASE124_REPORT.md) |
| P14 exit state | [`P14_REPORT.md`](P14_REPORT.md) |

---

## Decision log (owner)

| Date | Decision |
|------|----------|
| 2026-06-20 | Doc created; **implementation deferred**; recommended A (skyline strip) pending owner pick |
