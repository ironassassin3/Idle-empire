# Rooftop-Sign Identity + Overlay Surface Polish — Design

**Date:** 2026-07-18
**Status:** Approved for implementation (final audit-queue items)
**Scope:** (1) City rooftop neon carries owned-business `SigilGlyphs`. (2) Casino /
dragon / prestige overlay chrome retires warm-brass remnants onto violet ink.

## A — Rooftop-sign identity

**Problem:** `_draw_rooftop_signs` / `_draw_neon_streaks` paint generic `NEON_SET`
dots unrelated to the player's empire. Marquees on owned towers use neon color
but letter-segment filler, not the shared glyph language.

**Decisions:**
1. Rooftop signs (up to 3) keyed to `_top_building_keys` — glow + dark disc +
   `SigilGlyphs.draw_glyph` in `GameTheme.building_neon(key)`. Empty empire falls
   back to `NEON_SET` dots.
2. Wet-street streaks use the same keys/colors.
3. Shoulder marquees draw the business glyph instead of stacked letter bars when
   height allows; otherwise keep segments.

## B — Casino / dragon / prestige surfaces

**Problem:** Overlay `.tscn` titles still use warm `Color(1, 0.84, 0.49)`; prestige
confirm pulse modulates warm amber; dragon overlay never applies ledger ink theme;
gambling wheel track uses warm brown fills.

**Decisions:**
1. Remap warm title colors in `gambling_overlay.tscn`, `dragon_patron_overlay.tscn`,
   `prestige_tree_overlay.tscn` to violet `GOLD_BRIGHT` floats.
2. Prestige dialog pulse → `Color(GameTheme.GOLD_BRIGHT, pulse)` (no warm tint).
3. Dragon overlay gets `_apply_ink_theme()` (ledger panel, fonts, CTAs) like gambling.
4. Wheel: cool track/bust/filler colors into ink-violet neutrals; keep GREEN/GOLD
   tokens for skill meter.

## Out of scope

game_screen.tscn legacy path warm gold (shell V3 is live), renaming `GOLD` ids,
new dragon card art beyond theme tokens.

## Verification

- Mid-tier city still: rooftop discs show dealer/shield/etc glyphs matching towers.
- Open prestige / dragon / luck-wheel: no warm brass titles; ink ledger panels.
- `shell_smoke` PASS.
