# City Grading + Dark-City Density Floor — Design

**Date:** 2026-07-18
**Status:** Approved (owner, this session)
**Scope:** Two draw functions in `godot/scripts/ui/city_view.gd` — sky/window grading
plus an always-populated skyline where owned businesses light their towers. Closes the
stage-density gap flagged in the post-Neon-Noir "70% premium" check.

## Context

The Neon Noir port (spec `2026-07-17-neon-noir-port-design.md`) delivered the palette,
city punch-up, and gradient rows. A seeded 720×1280 still (35 dealers, tier 3) shows the
stage is now the weakest surface:

- **Washed sky** — `_draw_back_parallax` paints three flat rects (`SKY_BACK/MID/HAZE`);
  at phone scale the seams read as pale bands, not night depth. The study
  (`premium_main.gd::_Backdrop`) uses a stepped gradient.
- **Amber monoculture** — every lit window is `NEON_WARM` orange; the hero tower becomes
  a wall of warm squares fighting the violet/magenta/teal identity everywhere else.
- **Sparse skyline in low-variety states** — `_draw_mid_skyline` draws one hero facade
  per *owned business type*. One-type empires (every early player) get a single lonely
  tower against empty sky.

## The three edits (all in `city_view.gd`)

### 1. Sky grading — `_draw_back_parallax`

- Replace the three flat sky rects with a ~24-step banded vertical gradient
  `SKY_BACK → SKY_MID → SKY_HAZE` over the top ~55% of the band (study idiom, ~10
  lines). Horizon-glow rows stay on top unchanged.
- Tame the pale wash: reduce `SKY_HAZE`'s weight in the gradient tail / its band alpha —
  keep the layer, kill the wash.
- Redraw is already throttled (`REDRAW_INTERVAL` 1/30); ~24 `draw_rect` calls are free.

### 2. Window neon mix — parallax layers + `_draw_building_signature`

- Distant/far towers: window color drawn from a **seeded per-tower mix** — ~1/3 stay
  `NEON_WARM`, the rest pull from `NEON_SET` (violet `8a5cff` / magenta `e5457e` /
  teal `2fd6c6`) at the same low alphas used today. Seed = tower index, so the mix is
  stable frame-to-frame (no color flicker).
- Owned-business hero facades: window tint biases toward
  `GameTheme.building_neon(key)` so each tower reads as *its* business at a glance —
  the same signal the rooftop SigilGlyphs already carry.

### 3. Dark-city density floor — `_draw_mid_skyline`

- Before the hero facades, always draw a fixed rank of ~7 **unowned towers** across the
  band: near-black silhouettes (`SILHOUETTE_BACK`-family), unlit or 1–2 dim windows,
  heights varied by slot seed.
- Hero facades for owned types render on top exactly as today (grow/breath/pulse logic
  untouched). A slot occupied by a hero facade **suppresses its dark understudy** —
  owning a new business type visibly converts a dark block into a lit one. The buy loop,
  drawn on the skyline.

## Constraints (law)

- **All reactive behavior untouched:** facade pulse, heat/alert cues (warn/critical),
  district flash, raid surge, aviation beacons, rooftop sign glyphs, searchlights,
  reduced-motion branches.
- No new nodes, no per-frame allocation; `_draw`-only changes inside the existing
  30fps redraw throttle.
- Colors via existing tokens / `NEON_SET` / `building_neon` — no new palette entries.
- ART_POLICY: primitives only.
- No save/balance/signal changes.

## Verification

1. `shell_smoke.gd` headless — PASS, no script errors.
2. Seeded 720×1280 stills, read and judged:
   - (a) 35 dealers / 1 type — the state that exposed the problem: full skyline, no
     lonely tower, no washed band.
   - (b) 5 types mid-game — five lit towers in five business neons over dark understudies.
   - (c) heat 75 — warn/critical cues still read against the new grading.
3. Before/after against `godot/design/shots/premium_check_bldgs.png` and the study.

## Out of scope

- Life/motion pass (traffic/pedestrian density, flicker rhythms) — deferred to the
  device pass; judged in motion, not stills.
- Goal-rail left-padding nit — shell layer, separate micro-fix.
- Any `game_screen.gd` legacy path work.
