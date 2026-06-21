# UI Rebuild v2 Architecture — Criminal Empire (Godot 1.0)

**Status:** Direction **LOCKED — Concept A (Skyline progression strip)** selected by owner 2026-06-20. **P15.1–P15.3 implemented** (city_view module, layout restructure, GameState binding). P15.4+ pending.  
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

## 5. Three concept directions (owner picked **A**)

> **Decision (2026-06-20): Concept A — Skyline progression strip.** B and C retained below as fallbacks only; if the P15.0 taste gate fails, revisit B (district map) per §13, do **not** revert P14 UX patterns. A is detailed first; B/C kept for the audit trail.

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

Every UI-visible phase verifies with the existing **[`screenshot.gd`](godot/scripts/tools/screenshot.gd)** harness (built 2026-06-20; boots `game_screen` windowed, seeds a fresh game, captures any tab to PNG in ~3s — Godot 4 cannot read back a viewport under `--headless`). No phase is "done" without a before/after capture diff at 720×1280.

| Phase | Goal | Scope (in) | Deliverables | Exit criteria | Deps |
|-------|------|------------|--------------|---------------|------|
| **P15.0** | Architecture lock & taste gate | This doc; **owner picked A ✅ (2026-06-20)**; 3 code-drawn mock captures (spike branch, no ship) | Signed direction (done); `docs/ui/p15_mocks/` tier-1 + tier-5 + heat-75 PNGs | Owner 15s-test pass on mock | P14 complete |
| **P15.1** | `city_view` module spike | `scenes/ui/city_view.tscn` + `city_view.gd`; port `draw_scene` tiers (`src/ui.py` L1363–1526), thresholds **5 / 15 / 35 / 80** | Standalone `Control` renders 5 tiers; driven by an injected int, not yet `GameState` | `screenshot.gd` spike preset renders tier 0 vs 80 matching pygame silhouette | P15.0 | **Done** |
| **P15.2** | Layout restructure | `game_screen.tscn`: `VBox` → Header → **CityViewport** → StatusStrip → Body/Right → BottomBar; delete `Body/Left` column | Scene tree diff; `_apply_safe_area` covers new region | City ≥28% on 720×1280; notch clears header; **Right still single-wrapper-visible** (see §14 collapse gotcha) | P15.1 | **Done** |
| **P15.3** | Data binding | `GameState` → tier / heat / rank glow / district dots via `refresh()` | `city_view.refresh(state, dt)`; throttled ≤30 Hz | Buying a building changes tier ≤1 frame; `heat ≥ 60` flash; Crime Lord+ glow | P15.2 | **Done** |
| **P15.4** | Theme v2 | Default `noir_theme.tres`; `UI_RUSTIC_THEME=false`; retire `_apply_rustic_surfaces` / `_wrap_content_panel` / `_scroll_vis` **together** (§14) | `GameTheme` v2 tokens; flag rollback path | Soak PASS; owner rejects rustic in side-by-side; **no row-clip regression** | P15.2 |
| **P15.5** | Hustle + coin on city | Relocate `_hustle` / `_coin_btn` (`Body/Left`) into city overlay; glass styling; `get_hustle_rect()` for tutorial highlight | Tap targets ≥48px on street | Hustle SFX/crit/buff unchanged; tutorial step-1 highlight still lands on hustle | P15.3 |
| **P15.6** | Tab content de-ledger | Row cards: ink `StyleBoxFlat` not paper texture; building names stay front-business; keep affordance tint | Row scene theme pass | Affordability scan at glance (green/gold edge); capture all 9 tabs render | P15.4 |
| **P15.7** | Migration / rollback | `GameConfig.UI_CITY_VIEW` + `UI_RUSTIC_THEME` as **independent** flags | Dev config toggle; README | One-flag revert to P14 layout passes soak | P15.2–P15.6 |
| **P15.8** | Validation | Capture matrix (§13); telemetry ext (§13); device pass | `P15_REPORT.md`; matrix filled; `screenshot.gd --city-tier` presets | Moto G FPS ≥30; owner taste gate; P14 funnel still green | P15.7 |

**Estimated:** 9 sub-phases (P15.0–P15.8). **Out of scope:** new mechanics, MM batch export (optional P15.4+), 3D city, generative art.

**Critical path & parallelism:** P15.1 (city module) and P15.4 (theme v2) touch disjoint files and can proceed in parallel after P15.0; both gate P15.6. P15.2 (scene restructure) is the serial bottleneck — it must land before P15.3/P15.5 (both need the CityViewport node) and is the phase most exposed to the §14 collapse gotcha. Sequence: **P15.0 → P15.1 ∥ P15.4 → P15.2 → P15.3 → P15.5 → P15.6 → P15.7 → P15.8.**

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

| City effect | Source (verified against live `GameState`) |
|-------------|---------------------------------------------|
| Skyline tier | `GameState.total_buildings_owned()` — exists at [`game_state.gd:732`](godot/scripts/autoload/game_state.gd#L732); do **not** re-sum `buildings[i].owned` in the view |
| Haze / smoke / police flash | `GameState.heat` (`float`, 0–100) [`game_state.gd:41`](godot/scripts/autoload/game_state.gd#L41) |
| Horizon glow | `GameState.get_rank()` [`game_state.gd:729`](godot/scripts/autoload/game_state.gd#L729) → compare via `Prestige._rank_index(...) >= _rank_index("Crime Lord")` (mirror pygame `_draw_scene_atmosphere`) |
| Window dots (cap 12) | count of `GameState.territories` with `unlocked == true` |
| Traffic / flicker / pulse | local `_t` accumulator in `city_view`, advanced in `_process(delta)` — **not** a `GameState` time field |
| Optional dot color override | rival-contested districts (Turf subtab context only) |

**No new save fields.** Read-only bind to existing `GameState`. `city_view` never mutates state; `game_screen._process` pushes data in via `refresh(...)`.

### Godot draw-API realities (port gotchas from pygame `_draw()`)

pygame primitives do not map 1:1 to `CanvasItem._draw`. Plan for these in P15.1:

| pygame | Godot `_draw` equivalent |
|--------|--------------------------|
| `pygame.draw.rect(..., border_radius=r)` | `draw_rect()` has **no** corner radius; use a `StyleBoxFlat.draw()` for the frame, plain `draw_rect` for skyline blocks (they're square anyway) |
| `pygame.draw.ellipse` (lamppost pool, smoke wisps) | no `draw_ellipse`; approximate with `draw_circle` or `draw_colored_polygon` — keep wisps cheap (≤3 circles) |
| Per-surface `SRCALPHA` blits | use `Color(r,g,b,a)` directly; **no `Image.create`/`Surface` allocation in `_draw`** (perf budget §10) |
| Hardcoded 404×320 scene rect | `draw_set_transform(Vector2.ZERO, 0, size / Vector2(404, 320))` so pygame coordinates port verbatim into a virtual canvas that scales to the actual viewport. Non-uniform stretch is acceptable for a horizontal strip (skyline is rect-dominant) |
| `pygame.font.SysFont("serif", ...)` "YOUR EMPIRE" label | a child `Label` with the noir display font, not a `_draw` string, so it respects theme + `scaled_font` |
| Color8 vs float | pygame uses 0–255; Godot `Color8(r,g,b,a)` takes 0–255 and converts — port the noir constants once as `const Color8(...)` |

**Redraw throttle:** animation (traffic, window flicker, hustle pulse) needs continuous redraw, but the budget caps city at ≤30 Hz. Accumulate `delta` and `queue_redraw()` only when `_t` crosses a 1/30s step; skip entirely when a full-screen overlay occludes the city (P15.3 reads the overlay-queue state already tracked by `game_screen`).

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

## 14. Codebase reality check (added 2026-06-20)

Hard facts gathered while fixing the rustic row-clipping bug this session. These convert the plan from "design intent" to "execution-ready" and pre-empt the traps already hit once.

### 14.1 The rustic-collapse gotcha (must not reappear in P15.2/P15.4)

P14's rustic path wraps each of the 9 tab `ScrollContainer`s under `Body/Right` in a runtime `PanelContainer` (`_wrap_content_panel`, [`game_screen.gd`](godot/scripts/ui/game_screen.gd) ~L285) for the leather frame. The wrapper is `SIZE_EXPAND_FILL`. Visibility was toggled on the **inner scroll**, not the wrapper, so all 9 wrappers stayed visible and a `VBoxContainer` split its height 9 ways → the active tab collapsed to a **~51px sliver** and clipped every row. Fixed by `_scroll_vis()` (drives wrapper + scroll together).

**Implication for the rebuild:**

- P15.2 removes `Body/Left` and reshapes `Body`, but `Body/Right` keeps the 9-scroll pattern. Any container holding multiple `EXPAND_FILL` children **must** keep the single-visible-child invariant. Re-verify with `screenshot.gd` after the restructure, not by eye.
- P15.4 sets `UI_RUSTIC_THEME=false` and retires `_apply_rustic_surfaces` / `_wrap_content_panel`. `_scroll_vis()` is a **no-op when unwrapped** (it only touches the wrapper if `_rustic_panel` meta is set), so it can stay; retire the wrap and the meta together to avoid a half-state. Do not delete `_scroll_vis` and leave `_wrap_content_panel`, or the bug returns.

### 14.2 `Body/Left` column disposition (P15.2 / P15.5)

Every node currently in `Root/VBox/Body/Left` and where it goes. Source: [`game_screen.gd`](godot/scripts/ui/game_screen.gd) L36–43 + scene.

| Node | Today | v2 destination |
|------|-------|----------------|
| `HustleBtn` (`_hustle`) | left-stack button | **Glass tap on city street** (P15.5); keep SFX/crit/buff + `get_hustle_rect` for tutorial |
| `CoinBtn` (`_coin_btn`) | left-stack | City overlay or ad-row below strip (P15.5) |
| `HeatLabel` + `HeatBar` | left-stack | **Status micro-strip** (heat is also a city atmosphere driver — keep the bar for exact %) |
| `ShieldLabel` (`_shield_label`) | left-stack | Status micro-strip |
| `PrestigeBtn` + `PrestigeInfo` | left-stack | Status strip prestige-ready chip (button opens existing prestige tree overlay) |
| `BuffLabel` (`_buff_label`) | left-stack | Status strip (Hustle-burst buff indicator) |
| `ClickInfo` (`_click_info`) | left-stack | Beside hustle on city, or status strip |
| `DragonHud` (`_dragon_hud`) | left-stack panel | **Collapsed chip beside city** (§6/§7) — must not reclaim a 40% column |

No node is deleted; all relocate. This is layout surgery, not feature removal — keeps every P14 signal (§11).

### 14.3 Tooling already in place

- **`screenshot.gd`** ([`godot/scripts/tools/screenshot.gd`](godot/scripts/tools/screenshot.gd)) exists and is the per-phase verification gate. P15.1 adds tier presets; P15.8 adds `--city-tier` + heat/district presets for the capture matrix (§13). Invocation: `<godot> --path godot -s res://scripts/tools/screenshot.gd -- --tab N --out shot.png --cash 5000` (seed cash so affordance/tier states populate; fresh `reset_new_game` starts at 0 buildings = tier-0 empty lot).
- **Soak harnesses** (`headless_soak.gd`, `sim_godot_soak.py`, `memory_soak.gd`) remain the regression gate per §11; run after P15.2 and P15.4.
- Godot binary this project builds against: `Godot_v4.6.3-stable_win64`.

### 14.4 Open questions for P15.0 mock (resolve before P15.2 code)

1. **City height on short aspect (19.5:9):** §10 says city yields to min 180px before header compresses — confirm the dragon chip + status strip still fit at 720×1480 logical.
2. **Dragon chip placement:** beside city (horizontal) vs. floating corner — affects CityViewport width budget.
3. **Hustle tap vs. scroll:** city strip sits above the tab scroll; ensure the hustle glass `MOUSE_FILTER` doesn't eat tab-scroll drags that start in the strip.

## Appendix — file map (implementation reference)

| Purpose | Path |
|---------|------|
| Current ship UI | [`godot/scripts/ui/game_screen.gd`](godot/scripts/ui/game_screen.gd) |
| Pygame city reference | [`src/ui.py`](src/ui.py) `draw_scene`, `_draw_scene_atmosphere`, `draw_click_zone` |
| Theme tokens | [`godot/scripts/ui/game_theme.gd`](godot/scripts/ui/game_theme.gd) |
| Districts data | [`godot/scripts/systems/territory_system.gd`](godot/scripts/systems/territory_system.gd) (20 districts) |
| Phase 124 spec | [`PHASE124_REPORT.md`](PHASE124_REPORT.md) |
| P14 exit state | [`P14_REPORT.md`](P14_REPORT.md) |
| Screenshot/verify harness | [`godot/scripts/tools/screenshot.gd`](godot/scripts/tools/screenshot.gd) |
| Rustic wrap to retire (P15.4) | [`game_screen.gd`](godot/scripts/ui/game_screen.gd) `_apply_rustic_surfaces` / `_wrap_content_panel` / `_scroll_vis` (§14.1) |
| Left column to dissolve (P15.2/.5) | [`game_screen.gd`](godot/scripts/ui/game_screen.gd) `Root/VBox/Body/Left` (§14.2) |

---

## Decision log (owner)

| Date | Decision |
|------|----------|
| 2026-06-20 | Doc created; **implementation deferred**; recommended A (skyline strip) pending owner pick |
| 2026-06-20 | **Owner selected Concept A.** Plan locked to skyline strip + district-glow secondary (§6). P15.1–P15.3 ship code landed: `city_view` module, game_screen layout restructure, GameState binding. |
