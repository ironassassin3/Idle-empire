# Deco Motion — moment-to-moment juice pass

**Date:** 2026-07-15
**Status:** design approved (owner, 2026-07-15), pending implementation plan
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
- **Every effect gates on `GameTheme.ui_reduced_motion()` and headless**, exactly as
  `play_raid()` / `flash_building()` do. Reduced-motion keeps the *information* (state
  swap, balance pop) and drops the *travel* (arcs, ripples, sheens, wipes).
- **ADR-001 (ticker honesty) holds:** coins are cosmetic garnish on the existing ledger
  behavior. They never gate, delay, or inflate the displayed number.
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

static func press(btn: Control) -> void   # depress 0.96 + 1px down, release ease-out
```

### 2. `FxLayer` — one pooled immediate-mode canvas (`godot/scripts/ui/shell/fx_layer.gd`)

A single full-rect, mouse-ignoring Control added by `game_shell` **above** the deck and
masthead (coins must travel row → ledger across zone boundaries). It draws every
transient effect itself from fixed struct pools — **zero child nodes, ever**:

| Pool | Size | Effect |
|---|---|---|
| coins | 12 | gold discs arcing along a quadratic bezier, slight spin, fade at landing |
| sparks | 32 | short gold streaks with per-frame decay (click trail / crit burst) |
| ripples | 4 | expanding 1.5px gold rings from a tap point |

`_process` decays live entries and calls `queue_redraw()` only while any pool is active;
idle cost is zero. Public API (all no-op headless / reduced-motion):

```gdscript
func coin_burst(from: Vector2, n: int) -> void   # target = registered ledger point
func sparks(origin: Vector2, n: int, hot: bool) -> void
func ripple(at: Vector2) -> void
func set_ledger_target(global_pos: Vector2) -> void  # masthead registers on ready/resize
```

Discovery: `FxLayer` joins group `"fx_layer"`; call sites use
`get_tree().get_first_node_in_group("fx_layer")` with null-guards, so every effect
degrades to nothing if the layer is absent (design scenes, legacy screen).

## The five effects

| # | Effect | Integration point | Reduced-motion |
|---|---|---|---|
| 1 | **BUY press** — button depresses (`DecoMotion.press`), gold ring ripples from the button's global rect center (`pressed` carries no pointer position; center is deterministic and touch-agnostic) | `building_row.gd` `_buy1.pressed` (`:44`); same treatment offered to upgrade/manager rows if trivially shared via `apply_row_buy_button` | instant press, no ripple |
| 2 | **Purchase coin arc** — 1–3 coins arc from the row's BUY button to the masthead balance; existing balance pop reads as the "landing" | `building_row.gd` `_on_any_purchase` (`:56`) — already key-matched per row; origin = `_buy1` global rect center | skip arc; pop stays |
| 3 | **Balance sheen** — while the ledger is catching up (`_shown` chasing truth in `_tick_balance`), a soft gold band sweeps the digits; settles when caught | `hud_masthead.gd` `_tick_balance` (`:143`) sets a `_catching` flag; one preallocated sweep Control above `_balance` animates x while flagged | off |
| 4 | **Richer click float** — existing float (bounded `_MAX_FLOATS 24`) gains a spark trail; crits fire a brighter radial burst | `stage_layer.gd` `_spawn_click_float` (`:153`) additionally calls `FxLayer.sparks(pos, 3, crit)` | plain float only |
| 5 | **Row unlock ink-wipe** — LOCKED/APPROACHING→READY swaps via a left→right gold wipe drawn *by the row itself* instead of an instant recolor | `building_row.gd` `_refresh` (`:131-149`) tracks previous `can_primary`; on false→true starts a `_wipe` 0→1 decayed in `_process`, drawn in the existing `_draw` (`:89`) next to the wax seal + underbar | instant swap |

Effects 1–4 route through `FxLayer`/`DecoMotion`; effect 5 is drawn row-local state (a row
is a self-contained canvas already — same idiom as its afford underbar).

## Non-goals

- No event-ceremony work (rank-up, prestige, welcome-back) — that is the *next* slice.
- No balance, income, or save changes; no new audio (Phase 95/99 sounds stand).
- No intensity that reads cartoony: counts capped by the pools above, palette locked,
  nothing screen-filling. If it looks like a slot machine, it has failed the spec.

## Verification

- **New headless probe** `deco_fx_probe.gd` (modelled on `city_reaction_probe.gd`):
  fire a purchase burst + click storm; assert `FxLayer` child count stays 0 (drawn
  state), pools never exceed caps, and all APIs no-op headless.
- **`shell_smoke`** unchanged must stay green (regression).
- **Look:** `ui_capture.ps1 -Shell` with `-Frames` tuned to catch a mid-arc frame;
  before/after pair at 720×1280. Motion itself is judged in the running game + device
  pass (a still can't show travel — the probe proves the mechanics).
- **V3 token lint** green (fx_layer.gd is under `shell/`, lint applies automatically).
- Device checklist gains three lines under "Living city": press feel, coin arc lands on
  the ledger, no FPS dip at 20cps click storm.
