# City Stage Repair — Design

**Date:** 2026-07-17
**Status:** Approved (owner, this session)
**Scope:** `godot/scripts/ui/city_view.gd` only. Drawn-state changes; no balance, save, signal, or layout changes.

## Context

The 2026-07-17 feature-by-feature UI audit (batch `ui_capture.ps1` stills of all 8 shell
surfaces at 720×1280, heat 65, tier 3) found the city stage — visible behind every tab —
is the worst visual offender. Four confirmed defects:

1. **Blank hero towers.** `_draw_building_signature` computes `win_rows = 1 + tier`
   (max ~5 rows at a fixed 16 px pitch), but hero facade heights reach ~277 virtual px
   (log growth × tier bonus × 1.3 hero multiplier). Windows cover only the crown; the
   remaining ~80% of the tower is a flat, washed-out slab that reads as a rendering bug
   in every screenshot.
2. **Floating windows.** Back-parallax anchor/far towers draw bodies so dark against
   `SKY_BACK` that they are invisible, while their lit windows (NEON_WARM, α 0.28–0.35)
   are not — the windows read as orphaned orange squares in the sky.
3. **Heat unreadable in a still.** At heat 65 (raid range) the hunted-city treatment
   barely registers: crimson sky bands are subtle and the animated red/blue patrol flash
   cannot read in a static frame.
4. **Street-level cues occluded.** `stage_layer.gd` ends the city canvas 56 px *below*
   the sheet's top edge (`_city.offset_bottom = rect.end.y + 56.0`), and the ground line
   sits at 292/320 of canvas height — so the patrol cruiser (ground_y+14), raid surge
   band (ground_y−6 down), and district strip (ground_y+10) are almost entirely hidden
   behind the content sheet in portrait play. The reactive-city street cues shipped in
   Stage B physically cannot be seen where players play.

## Changes

### 1. Height-derived window grids

- `win_rows` becomes height-derived: `clampi(int((bh - 24.0) / 16.0), 1, 16)`.
- `win_cols` gains a width-derived cap so wider facades get more columns:
  `clampi(2 + tier / 2, 2, int(bw / 14.0))` (floor 2).
- Hash-flicker selection, window size, alpha, and the existing ground-overlap guard
  (`wyp + 8.0 > ground_y - 6.0 → skip`) are unchanged.
- Add a subtle vertical side-shade on facades taller than ~120 virtual px: one darker
  column (~20% of bw, low-alpha black) along one edge so tall towers read as massed
  volumes instead of flat slabs.
- Perf: worst case ≈ 5 facades × 16 rows × 4–5 cols ≈ 350 extra `draw_rect` calls per
  redraw at the existing 30 fps cap — negligible for the immediate-mode canvas.

### 2. Attach the distant windows

- Anchor skyscrapers + far-ridge towers: raise body contrast slightly (lighter fill
  toward `SILHOUETTE_BACK`, and a 1 px rim line on anchor crowns) so silhouettes are
  visible against the sky.
- Drop their window alpha slightly (≈0.35 → ≈0.25) so windows sit *in* the silhouette
  rather than floating in front of nothing.

### 3. Heat readable in the visible band

The visible stage band in portrait is skyline, not street. Warn-state cues move up:

- **Band ≥ 1 (warn):**
  - Rooftop aviation beacons (anchor towers + hero crowns) switch from lazy blink to an
    urgent fast blink in `NEON_RED`.
  - A fraction of facade windows go dark — the city lying low. Deterministic from the
    existing hash (e.g. skip windows whose hash falls below a band-scaled threshold);
    scales with band so critical reads darker than warn.
  - Crimson sky bands strengthen: bump the existing heat-scaled alpha so 60+ heat is
    unmistakable in a still frame.
- **Band ≥ 2 (critical):**
  - Existing blue searchlight sweep unchanged.
  - Tower rim lines pick up a faint alternating SIREN_RED/SIREN_BLUE edge glow
    (time-alternating like the cruiser bar; static single color under reduced motion).
- **Raid surge:** extend the band's top from `ground_y − 6` to `ground_y − 20` so its
  top edge clears the sheet occlusion and is visible in portrait.
- **Patrol cruiser:** unchanged (still valuable in landscape/tall viewports).

## Constraints (all pre-existing, all preserved)

- Reactions are drawn STATE on the immediate-mode canvas — never nodes layered over it.
- Never a wash over the player's balance/sheet; cues live in the world.
- All new motion respects `GameTheme.ui_reduced_motion()` (beacons/rim glow degrade to
  static single-state).
- Headless-safe: no new node lookups; `_draw` already exits headless.
- 30 fps redraw cap (`REDRAW_INTERVAL`) and `_dirty` discipline unchanged.
- ART_POLICY: primitives only, colors from existing tokens (`GameTheme.SIREN_RED/BLUE`,
  `NEON_RED`, existing palette constants). No new assets.

## Verification

- `city_alert_probe.gd`, `city_share_probe.gd`, `city_district_probe.gd`, and
  `shell_smoke.gd` all still pass (headless).
- Re-capture stills via `ui_capture.ps1` batch at heat 0 / 65 / 90 (720×1280, tier 3,
  overlays off) and visually confirm: towers windowed full-height, distant windows
  attached to visible silhouettes, warn/critical unmistakable in a still, raid surge
  edge visible above the sheet.
- Compare heat-0 shot against pre-change capture to confirm the calm city did not get
  noisier (windows-go-dark must not fire at band 0).

## Out of scope

Identity medallion pass (rivals/turf/crew/managers), gold-remnant theme cleanup,
header/goal-bar polish, achievement toast placement — items 2–4 of the audit plan,
each its own spec.
