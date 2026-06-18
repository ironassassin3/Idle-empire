# P7 — Mobile UX & Responsive Layout

**Started:** 2026-06-17  
**Status:** Code complete — device pass open (`DEVICE_TEST_CHECKLIST.md`)
**Nav model chosen:** Bottom bar + Turf subtabs (faithful to pygame Phase 100 IA)

## Audit (evidence)

- **Display:** was 900×720 landscape, `stretch=canvas_items`, no aspect/orientation/safe-area.
- **Layout:** `Body` was an HBoxContainer (two-column landscape) — won't fit portrait.
- **Nav:** 9 tabs in a horizontal-scroll bar (hidden off-screen). pygame already flattened
  to 5 top-level + Crew/Ops as Turf subtabs (Phase 100); the port had kept 9 flat.
- **Touch targets (min ≈44–48px):** tab btns 56×**32** ❌, crew steppers **32×32** ❌,
  op action **0×36** ❌, mgr hire/target **36/28** ❌; building buy 72×52 ✅.
- **Hover/right-click:** play loop is tap-driven. Prestige perk detail is a visible label (tooltip is bonus only).

## Delivered

### 7a — Foundation
- **Portrait + responsive** (`project.godot`): viewport 720×1280, `handheld/orientation=portrait`,
  `stretch/mode=canvas_items`, `stretch/aspect=expand` (adapts across phone aspect ratios).
- **Body reflow:** `Body` HBoxContainer → VBoxContainer — clicker/dragon column stacks above the
  tab content (which now expands to fill).
- **Safe-area insets:** `_apply_safe_area()` in `game_screen.gd` insets the Root margin by the
  device safe area (notch/home bar), scaled screen-px→viewport-px, re-applied on resize.
  No-op on desktop (safe area == screen).

### 7b — Nav IA (bottom bar + Turf subtabs)
- **Bottom bar** (`Root/VBox/BottomBar`): 5 primary tabs — Buildings, Upgrades, Managers, Turf,
  Stats — full-width, 56px tall, thumb-reachable.
- **Turf subtab bar** (`Root/VBox/Body/Right/TurfSubBar`, shown only on Turf): Territory, Rivals,
  Crew, Ops — 48px. Crew/Ops gated (Crew needs 5 buildings; Ops needs 2 districts or Made Man),
  shown with live `Crew n/5` / `Ops n/2` progress when locked.
- **Header gear (⚙)** → Config (moved off the main bar).
- **Badge roll-up:** Turf bottom button shows `★` (Broker) or `•` (ops ready); detailed badges
  live on the subtabs.
- **Routing:** `_set_tab` rewritten for the 5-tab model; `_open_turf` restores last subtab;
  `_set_turf_subtab` enforces locks; `_refresh_turf_subbar` handles subtab highlight/disable.

### Touch targets bumped
| Element | Before | After |
|---|---|---|
| Primary tabs | 56×32 | full-width × **56** |
| Turf subtabs | — | full-width × **48** |
| Crew +/- steppers | 32×32 | **48×48** |
| Operation action | 0×36 | **0×48** |
| Manager hire / target | 36 / 28 | **48 / 44** |
| Header gear | — | **44×44** |

## Verify

```bash
# Boot + 60s live soak (zero script errors) + income parity (UI must not move economy)
python sim_godot_soak.py --godot "E:/Downloads/Godot_v4.6.3-stable_win64.exe"
# → PASS: 60s soak clean; income parity 4/4 (2026-06-17)
```
- Scene boots clean after the restructure (all `@onready` paths resolve).
- A headless **nav probe** drove every path — 5 primary tabs, gear→Config, Stats build, Turf
  button, all 4 subtabs, subbar visibility toggle, badge refresh — **NAV PROBE PASS**, zero
  `game_screen.gd` errors. (Probe removed after.)
- Income parity unchanged (4/4) — layout changes don't touch the economy.

## P7 exit criteria

- [x] All interactive targets meet the minimum tap-size standard (≥44px).
- [x] No hover/right-click **reliance** in the play loop.
- [ ] Playable end-to-end in portrait on a real phone / device-sim, no clipped/unreachable UI.
  **Owner: user** — headless can verify structure/logic but not on-device visual layout. Run F5
  (now opens portrait) and walk the tabs. Captures across phone aspect ratios pending (P8 device matrix).

## Known gaps / follow-ups

- **Safe-area** uses screen→viewport scaling but is unverified on a real notch device → confirm in
  **P8 device pass** (`DEVICE_TEST_CHECKLIST.md` §B).
- **Left column compactness:** on very short aspect ratios the stacked clicker/dragon column may crowd
  content — revisit with device captures (P8).
- **Prestige perk detail:** now a visible label under each perk (not hover-only) — verify on small screens.
