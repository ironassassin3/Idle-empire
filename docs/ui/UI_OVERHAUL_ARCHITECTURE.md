# UI Overhaul Architecture — "Stage & Ledger"

**Date:** 2026-07-02
**Status:** IMPLEMENTED (M0–M4 v1, 2026-07-02) — shipped behind `GameConfig.UI_SHELL_V3` in `godot/scenes/game_shell.tscn` + `godot/scripts/ui/shell/` + `screens/` + `components/`; legacy `game_screen.tscn` retained as rollback. Remaining: building glyph/faction-crest SVGs (icon slots ready), owner taste gate on capture matrix (`godot/design/shots/shell_v3_*.png`).
**Scope:** Godot ship target (`godot/`). pygame untouched.
**Constraints honored:** [`ART_POLICY.md`](../../ART_POLICY.md) (code-built only), ink art-deco noir locked per [`STYLE_AUDIT.md`](STYLE_AUDIT.md), existing `GameTheme` / `GameFonts` / `GameIcons` token stack retained.

---

## 1. Diagnosis — why the current UI loses

From current builds (685×1218 captures, Bldgs / Upgrs / Stats):

| # | Problem | Evidence |
|---|---------|----------|
| D1 | **"Stack of strips" layout** — 8 stacked bordered bands (header / city / NEXT bar / coin+hustle / P0% chip / prestige text / content / raid ticker / nav) all compete; no focal point | Every screenshot |
| D2 | **Border noise = fake hierarchy** — nearly every element is boxed in the same gold hairline; hierarchy is expressed by borders instead of scale, weight, and contrast | Rows, chips, buttons, panels all share one border treatment |
| D3 | **Signature asset wasted** — the code-drawn city (our identity, per STYLE_AUDIT axis 4) is a thin dead band with a floating `$0` medallion covering it | Top third of screen |
| D4 | **CTA fragmentation** — Hustle band mid-screen, tiny outline BUY buttons right-aligned, `×1` multiplier in the header three zones away from the buy context | Bldgs tab |
| D5 | **Cryptic chips** — `P0%`, `×1`, `★ GOLDEN COIN ★`, `Ad → coin`, truncated `"Prestige 0 · Empire $0 / $50M · Empi…"` | Header + hustle row |
| D6 | **No progressive disclosure** — $2B upgrades and 11 buildings visible at $0 balance; heat meter shown before heat matters | Upgrs tab at fresh save |
| D7 | **Weak affordance** — BUY buttons are the same dark outline whether affordable or not; everything reads "locked" | Bldgs tab |
| D8 | **Placeholder icons** — `?` circles on every building row; lists are text-walls | Bldgs tab |
| D9 | **Stats tab is a dev dashboard** — raw labeled boxes (`Balance $0`, `Click value $1`), not a player-facing report | Stats tab |
| D10 | **Alarm ticker** — red full-width raid strip pinned above nav, permanently claiming space, truncating (`"hit you for $0!"`) | All tabs |
| D11 | **Dead letterbox** below nav dock at non-16:9 aspect | All tabs |
| D12 | **God-object shell** — `game_screen.gd` is 1,986 lines doing routing, theming, population, city state, badges, telemetry | code |

---

## 2. Market research — what the top of the store teaches

| Game | What players/designers praise | What they criticize | Our move |
|------|------------------------------|---------------------|----------|
| **Egg, Inc.** | Single anchoring world scene; progressive disclosure ("doesn't show you everything at once"); attention via animation/flash, not extra chrome; status bars everywhere; instant tap feedback (chickens visibly run) | Text too small / light weight; small touch targets | Adopt the world-anchor + attention-by-motion model; enforce type-size and touch-target floors they failed |
| **Idle Miner Tycoon** | Extremely polished, layered systems, steady visible progress | Interface density grows into clutter; floating coin indicators fragment feedback from function — critique: embed values **into** the scene objects | Feedback lives in the city stage (buildings appear/light up when bought), not in extra floating chrome |
| **AdVenture Capitalist** | Simple loop | Documented UX-designer critique of its UI rework: clutter, weak hierarchy, overwhelming resource management at scale | Hard cap on simultaneous persistent chrome (2 bands); one attention slot, never three |
| **Cookie Clicker** | Density-as-charm on desktop | Unreadable on mobile; players resort to UI mods for information clarity | Mobile-first zoning; information lives in one canonical place each |
| **2026 market direction** | "Smarter UI, cleaner menus, better explanations" is the stated player expectation; praised updates are "restructured UI — finally readable" | Monetization-heavy UIs (e.g. Cell: Idle Factory) actively drive players away | Monetization surfaces stay in their own overlay, never in the core loop chrome |

**Sources:** [Egg Inc usability analysis (Medium/Bootcamp)](https://medium.com/design-bootcamp/as-addictive-as-raising-chickens-1c59c804a5bf) · [Idle Miner Tycoon UX case study (ballmann.design)](https://www.ballmann.design/idle-miner) · [AdVCap UX critique thread (Kongregate)](https://www.kongregate.com/forums/9268-kongregate-published-games/topics/437328) · [Idle game design best practices (Mind Studios)](https://games.themindstudios.com/post/idle-clicker-game-design-and-monetization/) · [Best idle games 2026 (GameSpot)](https://www.gamespot.com/gallery/best-idle-games/2900-5676/) · [Pocket Gamer idle roundup](https://www.pocketgamer.com/best-games/idle-games-for-mobile/)

---

## 3. Design constitution (10 rules, testable)

1. **One stage, one ledger.** The city is the permanent world anchor (full-bleed background). All lists/menus live in a single content sheet over it. Nothing else owns screen real estate permanently except the masthead and nav dock.
2. **Two persistent chrome bands maximum** (masthead top, nav dock bottom). Everything else is stage, sheet, or overlay.
3. **Hierarchy by scale and fill, not borders.** Hairline borders are reserved for interactive affordances. Panels separate by tone/elevation (darker ink glass), not boxes-in-boxes.
4. **Every number has exactly one home.** Balance appears once (masthead). Income/s once. Heat once. No duplicated stats across zones.
5. **One attention slot.** Goals, events, raids, and offers rotate through a single priority-queued rail. Never stack alert strips.
6. **Attention by motion, not by chrome.** A thing that needs you pulses/animates in place (Egg Inc rule). Adding a new persistent widget to get attention is forbidden.
7. **Progressive disclosure is data-driven.** Every widget and list item has an unlock predicate. If the player can't interact with it meaningfully within ~2 purchases, it is hidden or shown as a silhouette teaser.
8. **Feedback in the world.** Purchases, raids, heat, and prestige visibly change the city stage. The stage is the progress bar.
9. **Touch floors:** ≥48 dp targets on all interactive elements, ≥14 sp body text, ≥12 sp captions, mono for all economy numbers. (Directly fixes Egg Inc's known weakness.)
10. **Three affordance states everywhere:** READY (solid gold fill), APPROACHING (outline + progress-to-afford underbar), LOCKED (dimmed silhouette). Same grammar on rows, buttons, tabs, and perk nodes.

---

## 4. Screen architecture — zones

```
┌─────────────────────────────────┐
│ Z1  MASTHEAD  (~9%)             │  rank chip · BALANCE (display) · +$X/s · heat pill · gear
├─────────────────────────────────┤
│                                 │
│ Z2  STAGE  (full-bleed,         │  city_view fills EVERYTHING behind Z3–Z4
│     visible ~28% when sheet     │  • tap anywhere = hustle (floating numbers, crits)
│     at rest)                    │  • bought buildings appear here (feedback-in-world)
│                                 │  • raids/heat/events play as city FX
│ ┌─────────────────────────────┐ │
│ │ Z3  ATTENTION RAIL (1 slot) │ │  priority queue: raid > event > goal > afford hint
│ ├─────────────────────────────┤ │
│ │ Z4  CONTENT SHEET (~55%)    │ │  translucent ink glass over stage
│ │   sheet header: title +     │ │  snap states: PEEK / REST / FULL (city never
│ │   context controls (×1/×10/ │ │  fully hidden except FULL)
│ │   MAX lives HERE)           │ │
│ │   scrolling list/screen     │ │
│ ├─────────────────────────────┤ │
│ │ Z5  NAV DOCK (~8%)          │ │  5 tabs · icons+labels · badge dots
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
Z6  OVERLAY STACK (modal ceremonies, gambling wheel, prestige tree, shop)
```

Zone rules:

- **Z1 Masthead.** Balance is the single largest text on screen (Limelight/display), income/s directly beneath it (Space Mono). Rank chip left, heat pill + settings right. Heat pill hidden until heat unlocks (rule 7). The cryptic `P0%` chip dies; prestige progress becomes a thin gold progress filament along the masthead's bottom rule — tap opens prestige overlay.
- **Z2 Stage.** `city_view.gd` promoted from a strip to the app background. The dedicated Hustle band is deleted; the stage itself is the tap target (with an initial tutorial halo). `$/tap` and buff state shown as a small floating chip only while a buff/tutorial is relevant. Golden-coin / ad entry becomes a diegetic object in the city (glinting coin/billboard), not a bordered button.
- **Z3 Attention rail.** One 40 dp slot fed by `AttentionDirector` (§6). Raid ticker (D10) becomes a 4-second rail takeover + city FX, then collapses into a Stats-tab log entry.
- **Z4 Content sheet.** One `ContentDeck` hosting per-tab screens. Sheet header owns tab title + contextual controls (buy multiplier for Bldgs — fixes D4). Three snap heights; drag or tap-handle to move between them.
- **Z5 Nav dock.** Keeps the 5-tab IA (Bldgs / Upgrs / Mgrs / Turf / Stats — Phase 100 decision stands). Badges become the affordance grammar's READY dot. Locked Turf subtabs keep Phase 102 visible-dimmed treatment.
- **Z6 Overlays.** Existing overlay queue + `modal_panel_rect` clamping (Phase 92) unchanged. Prestige climax ceremony (Phase 101) unchanged.

---

## 5. Component architecture (Godot scene decomposition)

Kills D12. `game_screen.gd` (1,986 lines) becomes a thin coordinator; target < 300 lines.

```
scenes/
  game_shell.tscn              # was game_screen.tscn — routing + composition only
  shell/
    stage_layer.tscn           # city_view + tap input + FX hooks + parallax
    hud_masthead.tscn          # rank/balance/ips/heat/gear + prestige filament
    attention_rail.tscn        # single-slot priority display
    content_deck.tscn          # sheet container, snap states, header slot
    nav_dock.tscn              # 5 tabs, badges
  screens/                     # one self-contained scene per tab
    buildings_screen.tscn
    upgrades_screen.tscn
    managers_screen.tscn
    turf_screen.tscn           # hosts Turf/Rivals/Crew/Ops subtabs
    stats_screen.tscn          # "Empire Report" (§8)
  components/                  # shared, theme-token-driven
    row_card.tscn              # unified list row: icon slot · title · desc · action slot
    action_button.tscn         # 3-state affordance button (READY/APPROACHING/LOCKED)
    resource_pill.tscn         # icon + mono value (heat, influence, respect, coins)
    segmented_control.tscn     # ×1/×10/×100/MAX
    progress_underbar.tscn     # 2px progress filament (afford-progress, rank, prestige)
    sheet_header.tscn          # title + contextual control slot
    stat_tile.tscn             # Empire Report tiles
```

Script responsibilities:

| Script | Owns | Must NOT own |
|--------|------|--------------|
| `game_shell.gd` | tab routing, screen lifecycle, safe area | theming, list population, city logic |
| `screens/*_screen.gd` | own populate/refresh/input for that tab | other tabs' state, global chrome |
| `stage_layer.gd` | city rendering, tap→hustle, world FX API (`play_raid()`, `flash_building(key)`, `set_heat_ambience()`) | economy math |
| `attention_director.gd` (autoload or shell child) | priority queue, badge fan-out | rendering |
| `ui_events.gd` (autoload signal hub) | typed UI signals | state mutation |

Row unification: `building_row / upgrade_row / manager_row / territory_row / rival_row / crew_row / operation_row` (7 scenes) collapse onto one `row_card.tscn` with a small per-type adapter script each. One place to fix layout, affordance, and icon slots (D8's icon work then lands once).

---

## 6. Attention & disclosure systems (the two engines)

### 6.1 AttentionDirector

Single source of truth for "what should the player look at."

- Input: signals from systems (`raid_started`, `event_ready`, `goal_completed`, `affordable(item)`, `operation_complete`, `dragon_request`).
- Priority table (high→low): raid → syndicate event → operation collect → goal complete → rank progress → afford hint → ad/coin offer.
- Outputs, in order of preference (rule 6):
  1. **World FX** on the stage (sirens, glow on a district),
  2. **Rail message** (Z3, one at a time, min 4 s dwell, queue drains by priority),
  3. **Badge dot** on nav dock tab (persistent until visited — existing badge telemetry hooks reused).
- Hard rule: the director may never spawn a new persistent widget.

### 6.2 Disclosure schedule

Declarative visibility matrix (single data file, e.g. `ui/disclosure_defs.gd`), consumed by masthead, rail, screens, and dock:

| Element | Appears when |
|---------|--------------|
| Heat pill | heat system unlocked (first racket) |
| Prestige filament | ≥ 25% of prestige gate (Phase 17 precedent) |
| Buy multiplier control | ≥ 10 total buildings |
| Upgrades tab | first upgrade affordable-horizon reached |
| Upgrade list items | owned tier + next 2 horizon items; rest = count footer ("14 more discovered as you grow") |
| Building list items | owned + next 2 lockable silhouettes (name hidden → "???" + cost class) |
| Turf subtabs | Phase 102 rules (visible-dimmed with live requirements) |
| Ad/coin diegetic object | monetization consent + first session ≥ 5 min |

This turns D6 from a judgment call into data.

---

## 7. Theming architecture

Keep the locked ink-noir tokens; add a **semantic layer** so components never reference raw colors:

```
game_theme.gd (raw tokens)          semantic layer (new)            components
#08070a / #0c0c14  ────────────►    surface.field / surface.sheet ─► row_card, deck
#c8a35a gold       ────────────►    accent.primary                 ─► READY fill, filaments
green buyable      ────────────►    state.ready / state.approach / state.locked
#e8e0d4 bone       ────────────►    text.primary / text.muted
red                ────────────►    state.danger (raid, heat crit)
```

- **Elevation replaces borders (D2):** `surface.field` (stage scrim) → `surface.sheet` (deck) → `surface.raised` (cards) → `surface.overlay` (modals). Each step = tone + MM grain texture, no added outlines.
- Type roles: `display` (Limelight — balance, ceremonies), `heading` (Cinzel — row titles, sheet headers), `body` (Cormorant — descriptions), `data` (Space Mono — every number). Row titles move to `heading` (STYLE_AUDIT P1 item, absorbed here).
- Icon plan per STYLE_AUDIT ADD backlog: 11 building glyphs, 5 faction crests, 4 branch glyphs — thin gold strokes, Phosphor-style, hand/code SVG only. `row_card` ships with the icon slot from day one so art lands without layout churn.
- Existing `UI_GILDED` / MM 9-slice pipeline and `bake_ink_ui_textures.gd` unchanged.

---

## 8. Per-screen architecture notes

- **Buildings.** Row = icon · name(heading) · one-line hook · owned count medallion · full-height `action_button` (≥48 dp) showing cost + afford underbar. Multiplier segmented control in sheet header. Milestone progress (25/50/100) as `progress_underbar` on the row.
- **Upgrades.** Grouped by target (Click / per-building / global) with sticky group headers; horizon filtering per §6.2. READY items sort to top of their group.
- **Managers.** Keep identity work; rows gain portrait-silhouette glyph slot.
- **Turf.** Subtab bar inside sheet header; map/district visuals should reuse stage-layer district strip rather than duplicate a second map metaphor.
- **Stats → "Empire Report."** Kills D9. Three sections: *Tonight's numbers* (net-worth stat tiles + trend filament), *The street* (rivals/heat/territory summary with faction crests), *Career* (achievements, ranks, prestige history). Raid/event log lives here (rail's archive).
- **Menu → game.** Menu ledger already coherent (STYLE_AUDIT); shell change must not regress the `#0c0c14` field continuity.

---

## 9. Migration plan (phased, each gate = design_preview renders + capture matrix + owner taste gate)

| Phase | Content | Risk | Visual change |
|-------|---------|------|---------------|
| **M0 — Decompose** | Extract 5 screen scenes + shell from `game_screen.gd`; introduce `ui_events` hub. Zero visual change; capture-matrix diff must be pixel-identical | Low | None |
| **M1 — Shell** | Stage full-bleed, masthead rebuild, content sheet (fixed REST height only — no gestures yet), nav dock restyle, delete hustle band (stage tap), kill strip borders → elevation | High (touch input, perf) | The overhaul moment |
| **M2 — Engines** | AttentionDirector + rail; disclosure matrix; raid ticker → rail takeover + log | Med | Chrome count drops |
| **M3 — Affordance & ergonomics** | 3-state `action_button` + `row_card` unification; multiplier into sheet header; touch/type floors audit | Med | Lists transform |
| **M4 — Sheet gestures + Empire Report** | PEEK/FULL snap states with drag; stats redesign; icon slots filled as SVGs land | Low-Med | Polish |

Explicit non-goals: no balance changes, no save-schema changes, no pygame work, no new monetization surfaces.

---

## 10. Risks & open questions

| Risk | Mitigation |
|------|------------|
| Full-bleed city redraw cost on low-end (Moto G gate) | Stage renders at capped internal rate; sheet scrim occludes most of it at REST; reuse existing reduced-motion flag |
| Stage-tap hustle conflicts with sheet drag | M1 ships fixed sheet (tap-only zones); gestures deferred to M4 with 3 snap points, no free drag |
| Row unification breaks 7 tabs at once | Adapter-per-type keeps old data contracts; migrate one tab per commit behind `UI_SHELL_V3` flag (mirrors `UI_CITY_V2` precedent) |
| Diegetic ad-coin discoverability | AttentionDirector may glint it via world FX; ad revenue telemetry compared pre/post |
| Disclosure hiding something a returning player owns | Predicates always OR with `owned > 0` |

Open questions for owner:
1. Sheet at REST shows ~28% city — acceptable list density on 720×1280, or bias REST taller?
2. Does the golden-coin ad entry as a diegetic city object pass the taste gate, or keep a masthead affordance?
3. Empire Report: worth a Phase of writing (Phase 55–57 narrative ROI lessons apply — faction crest + death-log lines land here)?

---

## 11. What "better than the market" means, concretely

| Their failure | Our structural answer |
|---------------|----------------------|
| Egg Inc's tiny/light text | Type floors are theme-enforced (roles carry min sizes), not per-screen choices |
| Idle Miner's clutter growth | Chrome cap (2 bands) + one attention slot are architectural invariants, so density physically can't creep |
| AdVCap's hierarchy collapse at scale | Disclosure matrix scales list length with progress; horizon filtering is data, not judgment |
| Genre-wide floating-indicator fragmentation | Feedback-in-world API on the stage layer (`flash_building`, `play_raid`) is the default channel |
| Monetization-forward UIs driving churn | Ads/IAP surfaces are Z6 overlays + one diegetic object; forbidden in Z1/Z3/Z5 by rule |
