# Deco Motion — moment-to-moment juice pass

**Date:** 2026-07-15
**Status:** design approved (owner, 2026-07-15) · self-review hardened same day
**Scope:** the five most-repeated interaction beats on the idle screen. Not an aesthetic change, not an event-ceremony pass, not a balance change.

## Problem

Market research (2026 idle top-grossers) shows the one axis where restraint reads as
*absence* rather than *premium*: moment-to-moment feedback. Market leaders make every tap
perform; our BUY press, purchase payoff, and click feedback are functional but flat. The
owner's direction: **keep the noir/art-deco skin, upgrade the motion** — a healthy mix of
"premium lane" and "market juice."

The unifying idea is a **deco motion language**: gold light sweeps, coin arcs, ink wipes —
all code-drawn in the existing palette, so richer motion cannot drift into cartoony
particle spam. Same skin, more life.

## Constraints (non-negotiable)

- **ART_POLICY:** code-drawn only. No textures, no imported particle assets.
- **Palette-locked:** `GameTheme` tokens only (`GOLD`, `GOLD_BRIGHT`, ink neutrals). The
  fx layer lives under `shell/`, so the V3 token lint enforces this mechanically.
- **Zero allocation per event.** All transient visuals come from fixed, preallocated
  pools drawn by one immediate-mode canvas (the reactive-city lesson: reactions are
  *state the canvas draws*, never per-event nodes). Pool full → skip, never grow.
- **Headless gates rendering, not state.** The Stage A handoff documented this exact
  trap: an API that no-ops headless can never be proven by a headless probe. FxLayer's
  pool state updates unconditionally (cheap struct writes); only `_process` redraw and
  `_draw` gate on headless — the same split `pulse_facade` shipped with.
- **Reduced-motion is a user intent, so it gates the API**, exactly as
  `flash_building()` does: keep the *information* (state swap, spend dip, pop) and drop
  the *travel* (arcs, ripples, sheens, wipes).
- **ADR-001 (ticker honesty) holds.** Purchases are *spends*: the masthead already lands
  them instantly with a bone-white dip (`_tick_balance:149-152`). Nothing in this pass
  touches, delays, or contradicts the displayed number.
- No save-schema changes. No new settings (reduced-motion toggle already exists).

## Architecture

Two new pieces, both small:

### 1. `DecoMotion` — the shared vocabulary (`godot/scripts/ui/deco_motion.gd`, `class_name DecoMotion`)

Static helper in the `GameTheme`/`GameFonts` pattern. Owns the timing tokens and the
tween-based primitives, so the five effects share one vocabulary and future motion work
composes instead of scattering ad-hoc tweens:

```gdscript
const T_FAST := 0.12   # press, flash — sub-perception "snap"
const T_MED  := 0.25   # state wipes, sheens
const T_ARC  := 0.45   # travel (coin arc)
const EASE   := Tween.EASE_OUT
const TRANS  := Tween.TRANS_CUBIC

## Depress on button_down (scale 0.96 + 1px sink), release ease-out on button_up.
## `pressed` fires on release, so the press half MUST hook button_down or the
## button never visibly sinks. Sets pivot_offset = size/2 (buttons in containers
## default to a top-left pivot and would scale lopsided).
static func attach_press(btn: BaseButton) -> void
```

`attach_press` is called once from `GameTheme.apply_row_buy_button` — every buy button
in every row type (buildings, upgrades, managers) inherits the press feel from one line,
and no row script changes for effect 1's press half.

### 2. `FxLayer` — one pooled immediate-mode canvas (`godot/scripts/ui/shell/fx_layer.gd`)

A single full-rect, mouse-ignoring Control added by `game_shell` above the masthead and
deck but **below `OverlayHost`** — transient garnish must never draw over a modal scrim.
It draws every effect itself from fixed struct pools — **zero child nodes, ever**:

| Pool | Size | Effect |
|---|---|---|
| coins | 12 | gold discs arcing along a quadratic bezier, slight spin, fade at landing |
| sparks | 32 | short gold streaks with per-frame decay (click trail / crit burst) |
| ripples | 4 | expanding 1.5px gold rings from a tap point |

Idle cost is literally zero: `set_process(true)` on the first live entry,
`set_process(false)` when all pools empty. Public API (state always updates; reduced-
motion no-ops; headless skips only the redraw):

```gdscript
func coin_arc(from: Vector2, to: Vector2, n: int) -> void
func sparks(origin: Vector2, n: int, hot: bool) -> void
func ripple(at: Vector2) -> void
func ledger_point() -> Vector2   # masthead registers its balance center on ready/resize
```

Discovery: `FxLayer` joins group `"fx_layer"`; call sites use
`get_tree().get_first_node_in_group("fx_layer")` with null-guards, so every effect
degrades to nothing if the layer is absent (design scenes, legacy screen).

## The five effects

| # | Effect | Integration point | Reduced-motion |
|---|---|---|---|
| 1 | **BUY press** — `attach_press` depress/release + gold ring ripple from the button's global rect center (`pressed` carries no pointer position; center is deterministic and touch-agnostic) | press: `GameTheme.apply_row_buy_button`; ripple: `building_row.gd` `_on_buy_primary` (`:153`) | instant press, no ripple |
| 2 | **Purchase coin arc — ledger → medallion.** 1/2/3 coins (×1/×10/MAX) arc *from* the masthead balance *down to* the row's `CountMedallion`; the existing Task 4 medallion flare is the landing beat. Direction matters: a purchase is a spend — your cash visibly lands **in** the business. (Coins *into* the ledger are the income fiction — reserved for the event-moment slice: coin collect, offline, jackpots.) | `building_row.gd` `_on_any_purchase` (`:56`) — already key-matched per row | skip arc; medallion flare + spend dip stay |
| 3 | **Balance sheen** — gold band sweeps the digits **on windfall only**, keyed to the existing detector (`_tick_balance:160-163`, `jump > 4× expected accrual`), settling with the catch-up. It must NOT key on mere `_shown < truth`: passive income keeps the ticker chasing truth every frame, and that trigger would run the sheen permanently. | `hud_masthead.gd` — one preallocated sweep Control above `_balance`, animated only while the windfall flag decays | off |
| 4 | **Richer click float** — existing float (bounded `_MAX_FLOATS 24`) gains a spark trail; crits fire a brighter radial burst | `stage_layer.gd` `_spawn_click_float` (`:153`) additionally calls `FxLayer.sparks(pos, 3, crit)` | plain float only |
| 5 | **Row unlock ink-wipe** — LOCKED/APPROACHING→READY swaps via a left→right gold wipe drawn *by the row itself* (same idiom as its afford underbar), not an instant recolor | `building_row.gd` `_refresh` (`:131-149`) tracks previous `can_primary`; on false→true starts `_wipe` 0→1, decayed in `_process` (enabled only while wiping), drawn in the existing `_draw` (`:89`) | instant swap |

### Emission guards (the bits that bite)

- **Offscreen / burst safety (effect 2):** manager purchase orders fire
  `building_purchased` in rapid bursts, including while the buildings tab is hidden or
  the row is scrolled away. A row requests an arc only if
  `is_visible_in_tree()` **and** its global rect intersects the viewport rect; the
  12-coin pool is the burst governor beyond that (full → skip, by design).
- **No wipe on first refresh (effect 5):** rows are rebuilt on tab entry; the previous
  `can_primary` initializes from the *current* state in `setup()`, so an already-
  affordable row doesn't wipe on instantiation — only a genuine false→true transition
  during play does.
- **One beat per action:** effect 2 keys off `building_purchased` (once per buy action,
  any quantity), never per-unit — a MAX buy is one arc of 3 coins, not N arcs.

## Non-goals

- No event-ceremony work (rank-up, prestige, welcome-back, income-into-ledger arcs) —
  that is the *next* slice.
- No balance, income, or save changes; no new audio (Phase 95/99 sounds stand).
- No intensity that reads cartoony: counts capped by the pools above, palette locked,
  nothing screen-filling. If it looks like a slot machine, it has failed the spec.

## Verification

- **New headless probe** `deco_fx_probe.gd` (modelled on `city_reaction_probe.gd`):
  fire a purchase burst + click storm; assert `FxLayer` child count stays 0 (drawn
  state), pool state is set and capped (provable headless because state is not
  headless-gated — see Constraints), and reduced-motion no-ops the APIs.
- **`shell_smoke`** unchanged must stay green (regression).
- **Look:** `ui_capture.ps1 -Shell` with `-Frames` tuned to catch a mid-arc frame;
  before/after pair at 720×1280. Motion itself is judged in the running game + device
  pass (a still can't show travel — the probe proves the mechanics).
- **V3 token lint** green (fx_layer.gd is under `shell/`, lint applies automatically).
- Device checklist gains three lines under "Living city": press feel, coins land on the
  bought business's medallion (not the ledger), no FPS dip at 20cps click storm.
