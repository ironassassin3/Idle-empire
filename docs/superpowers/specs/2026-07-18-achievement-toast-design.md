# Achievement Toast Placement — Design

**Date:** 2026-07-18
**Status:** Approved for implementation (audit queue after header/goal-bar)
**Scope:** Reposition shell toasts so they never cover list rows; give achievements
clearer presence. No save/balance changes.

## Problem

`game_shell.gd` pins `_notif_shell` at fixed `CENTER_BOTTOM` offsets (`-150…-118`).
That lands the toast on top of the content sheet footer ("6 more discovered…") and
just above the nav dock — covering actionable rows. Tutorial already solved this by
floating in the **stage gap** above the sheet (`_position_tutorial`).

Achievements (`"Achievement: %s"`) share the same thin toast as buy/hire noise, so
they read as clutter rather than a beat.

## Decisions

1. **All toasts float in the stage gap** — same coordinate recipe as the tutorial
   banner (sheet-top + 12px). Reposition whenever the gap rect changes and when a
   toast is shown.
2. **Stack above tutorial when both visible** — toast sits one banner-height above
   the tutorial so neither overlaps.
3. **Achievements get a distinct beat:** detect `message.begins_with("Achievement:")`;
   use a brighter violet border style, +2 font size, 3.5s dwell (goals/autobuy stay
   at 4.0s; generic stay 2.5s).
4. **Toast is non-blocking** — `mouse_filter = IGNORE` so city taps still land.
5. **Out of scope:** toast queue/stack of multiple messages, particle flourish,
   Stats deep-link, renaming notification bus.

## Verification

- Seed that fires `Achievement: First Hire` (or First Dollar): toast sits in the
  city band above the sheet, rows fully readable, nav clear.
- `shell_smoke` PASS.
