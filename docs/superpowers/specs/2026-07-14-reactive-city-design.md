# Reactive City — steady-state UI overhaul

**Date:** 2026-07-14
**Status:** design approved, pending implementation plan
**Scope:** the idle screen (city stage + masthead + content rows). Not an IA change, not a reskin.

## Problem

The game reads as a spreadsheet wearing a noir palette. The complaint is not layout and not
palette — it is that the steady state (95% of play time) has no menace and the city does not
feel alive.

The root cause is in the code, not the art. `stage_layer.gd:185`:

```gdscript
func flash_building(_key: String) -> void:
```

The `_key` is unused. Every purchase — Chop Shop, Casino, anything — fades one gold
`ColorRect` across the **entire screen**. `play_raid()` has the same shape: a full-screen red
wash. The city is not inert because nobody animated it; it is inert because **every reaction is
an undifferentiated full-screen tint**. A flash over everything reads as a UI blip. It can never
read as a city responding, no matter how much it is polished.

> **The project, in one line: give the city an address space, and route events to places
> instead of washing the screen.**

This also gives "the surfaces must mesh" a precise, enforceable meaning. One event fans out to
the facade, the row, and the masthead as a single orchestrated beat. They agree because they
read the same addressed event — not because three scenes were styled to match.

## Constraints (discovered, non-negotiable)

- **`city_view.gd` is an immediate-mode canvas**: one `_draw()` over a 404×320 virtual space,
  redraw-capped at 30fps behind a `_dirty` flag. **You cannot animate it by spawning tweened
  nodes over it** — a child node layered on the canvas does not know where anything is, which
  is precisely how today's full-screen wash happened. Reactions must be *state the canvas
  draws*.
- **Zero allocation per event.** The reaction table is fixed-size and preallocated. This is
  strictly better than today's per-purchase `ColorRect.new()`, which now fires in bursts since
  manager purchase orders landed.
- **Every reaction gates on `GameTheme.ui_reduced_motion()` and headless**, exactly as
  `play_raid()` and `flash_building()` already do.
- **The 30fps redraw cap stays.** We change *what* the canvas paints, not how often.
- **ART_POLICY:** code-drawn only. No generated assets.
- **Device floor:** ≥30fps on the Moto G.

## Architecture

Reuse what exists. Do **not** build a second bus.

1. **`UiEvents` (existing autoload) gains an addressed empire-signal set.** It is already the
   typed UI hub and already "owns signals only, never mutates state", so this is additive and
   in-pattern. Signals carry a **location**, never a bare "something happened".

2. **`city_view` gains a reaction layer.** A small fixed table of live reactions
   (`facade_pulse[key] → t`, `siren → t`, `block_state[i] → t`). `_process` decays them and
   sets `_dirty`; `_draw` renders each at its facade's virtual rect. **The address space
   already exists** — the city already maps `_top_building_keys[i]` to facade `i`. Nobody was
   using it.

3. **`stage_layer` stops washing the screen.** `flash_building(key)` finally uses its `key` and
   routes to that facade. `play_raid()` becomes patrol lights on the street, not a red tint over
   the player's balance.

4. **Rows and masthead subscribe to the same signals**, so a purchase is one beat across three
   surfaces.

### Reaction set (YAGNI enforced)

**Three discrete `UiEvents` signals** — each fires once, carries a location, decays:

| Signal | Where it lands | What the player learns |
|---|---|---|
| `building_purchased(key)` | Windows light on **that facade**; its row medallion flares; masthead ticks | "That's mine now" |
| `heat_crossed(level)` | Patrol cars sweep **the street**; searchlight at critical | You are being hunted — in the world, not in a number |
| `district_changed(idx, holder)` | That **block** lights (yours) or goes dark (rival took it) | Turf is territory you can see |

**Plus one continuous ambient**, which is **not** a signal — do not emit it per frame. Each
facade breathes at a rate proportional to **its share of income/sec**, read straight from the
shares array on the existing `refresh()` path. It is state the canvas already has, animated by
`_process`. This is what tells the player which businesses actually carry the empire.

The city needs one new input: a **per-facade income share** array. It currently receives owned
*counts*, which cannot distinguish a Chop Shop's contribution from a Casino's. This is one array
appended to the existing `stage_layer.refresh()` → `city_view.refresh()` call. No new plumbing.

## Out of scope (anti-creep)

Nav dock; the six screens' internals; information architecture; overlays; the palette; peak
moments (prestige climax, rank-up, ceremonies — a different project); the dragon chip; the
golden coin. Also out: `city_view`'s local raw `Color8` constants, which predate token
discipline. That is real debt, but fixing it here would balloon the change.

## Design phase

Three reaction *looks* get designed as `godot-design` scenes before any port:
facade-light, patrol-street, dark-block. Rendered against the **real** city and masthead (not a
stub), critiqued ≥2 rounds, exact-px finals through `ui_capture.ps1`.

## Verification

- `ui_validators.ps1` token lint.
- Shell capture-matrix regression (existing tooling).
- `memory_soak` — the 30fps cap holds.
- **Frame time must not regress on the Moto G.** This is a claim to prove, not assert: the
  fixed reaction table replaces per-event `ColorRect` allocation, so it should improve.
- A new "living city" block in `DEVICE_TEST_CHECKLIST.md`: buy a business → *that* facade
  lights (not the whole screen); raise heat → patrols appear on the street; take a district →
  that block lights.

## Open (not blocking)

`GameTheme.RED` (#9a4a4a) reads as a **ledger red — loss, not sirens** on near-black. Two
independent design agents concluded this without conferring. The patrol/siren work will need a
hotter alert token; propose it as a `GameTheme` amendment with rendered evidence rather than
inventing a literal in the city.
