# Phase 122 — Command Center Header Redesign

**Date:** 2026-06-15  
**Scope:** Presentation only — header + ticker styling. No gameplay, save, or tab changes.

---

## 1. Objective

Begin the Presentation Saga by transforming the header from a flat statistics bar into a **criminal empire command center**: fantasy, hierarchy, and automation visible at a glance.

---

## 2. Success question

| Before (Phase 121) | After (Phase 122) |
|--------------------|-------------------|
| "A row of statistics" — mono type, flat navy panel, heat hints as inline text | "Mission control" — noir glass panels, labeled strips, shield pips, employee chips |
| Automation hidden in tabs / header micro-text | **SAL · MECH · ACC · PROM · SMUG** chips when hired |
| Rank progress verbose (`→ Capo 28/45 (62%)`) | **RANK** medallion + compact bar (detail on hover) |
| Goals only in left column panel | **NEXT GOAL** single line in command strip |

**Verdict:** Header now reads as syndicate command center for silent viewers; full fantasy still depends on Phase 124 (city weight).

---

## 3. Header v2 structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ STRIP 1 — COMMAND                                                           │
│  [◉ $ balance]   INCOME 4.5M/sec ×1.2   │ NEXT GOAL … │ RANK CAPO ▓▓░░  │
├─────────────────────────────────────────────────────────────────────────────┤
│ STRIP 2 — STATUS                                                            │
│  HEAT ▓▓▓▓ 67% RAIDS   SHIELD ●●●   OP READY   ≤50%  [SAL][MECH][ACC]…      │
├─────────────────────────────────────────────────────────────────────────────┤
│ TICKER  ◆ syndicate news scroll…                                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Strip | Height (900×720) | Contents |
|-------|------------------|----------|
| Command | 50px | Money (glass), income (mono), one goal, rank badge |
| Status | 32px | Heat, Carl forecast, shield pips, ops chip, automation badges |
| Ticker | 22px | Flavor news (display font, noir dim) |
| **Total** | **104px** | Was 116px — slightly tighter, more information density |

---

## 4. Automation strip

**Purpose:** Answer *"Who is currently helping me?"*

| Chip | Manager | Shown when |
|------|---------|------------|
| `SAL` | Lucky Sal | Hired |
| `MECH` | The Mechanic | Hired |
| `ACC` | The Accountant | Hired |
| `PROM` | The Promoter | Hired |
| `SMUG` | The Smuggler | Hired |

- Chips are **right-aligned** in strip 2 with color-coded glass badges.
- Hover shows specialty tooltip (e.g. *"Lucky Sal — active. * Bookmaker — coins find you"*).
- **Collector shield** is separate: `SHIELD` label + 3 pips (fill = charge fraction, pulse at 100%).
- **Operations:** `OP READY` (pulsing green) or `OP 42s` countdown when a job is running.
- **Promoter:** `≤N%` heat target left of chip row.
- **Clean Carl:** compact `+Δ/2m` forecast beside heat bar.

Non-automation advisors (Broker, Rudy, Rob, Consigliere) remain tab-deep — avoids chip clutter.

---

## 5. Goal visibility

- Command strip shows **one** emphasized objective via `_header_primary_goal()`:
  1. First incomplete goal (`narrative` or `label`)
  2. Else `next_focus_hint()`
  3. Else `Reach {next rank}`
- Left-column goals panel **unchanged** (still shows up to 3 rows for detail).
- Header goal truncates with ellipsis when space is tight.

---

## 6. Styling

| Element | Treatment |
|---------|-----------|
| Palette | `NOIR_*` tokens in `theme.py` — aligned with `landing/index.html` |
| Labels | `disp_xs` / `disp_sm` — serif/display (Times/Georgia fallback) |
| Numbers | `lg` / `sm` / `xs` — Consolas mono |
| Panels | `_draw_glass_panel()` — dark glass + gold hairline + drop shadow |
| Dividers | Vertical gold hairlines between command sections |
| Ticker | `◆` separator, bone-dim display type |

---

## 7. Screenshots

Captured with `python phase122_capture.py` → `phase122_screenshots/`

| File | Scenario |
|------|----------|
| `01_early_header.png` | Fresh run, low heat, starter goal |
| `02_mid_automation_header.png` | Sal + Mechanic + Accountant + Collector hired |
| `03_late_ops_heat_header.png` | High heat, shield, op timer, full automation row |
| `*_full.png` | Full 900×720 frame for context |

### Before / after

| Before | After |
|--------|-------|
| Single flat `BG_PANEL` block | Layered noir ink + smoke gradient |
| All Consolas | Display labels + mono numbers |
| Heat + shield + promoter as inline text on one row | Dedicated status strip |
| No automation visibility | Employee abbrev chips |
| Rank text + long progress string top-right | RANK block + hover tooltip |

*No before PNG was archived pre-change; before state documented in Phase 121 / 120 reports.*

---

## 8. Implementation notes

### Files changed

| File | Change |
|------|--------|
| `src/theme.py` | Noir palette; `make_fonts()` adds `disp_xs`, `disp_sm` |
| `src/ui.py` | `STRIP1_H`, `STRIP2_H`; `draw_stats()` rewrite; automation helpers; ticker styling |
| `src/states.py` | `make_fonts(config.SCREEN_HEIGHT)` on init |

### Key functions (`src/ui.py`)

- `draw_stats()` — orchestrates command + status strips
- `_draw_command_strip()` — money / income / goal / rank (right-anchored layout)
- `_draw_status_strip()` — heat, shield, ops, chips
- `_header_primary_goal()` — single goal text
- `_automation_chip_list()` — active automation managers
- `_draw_glass_panel()`, `_draw_status_chip()`, `_draw_shield_indicator()`

### Layout globals

```python
STRIP1_H = 50   # command
STRIP2_H = 32   # status
TICKER_H = 22
HEADER_H = STRIP1_H + STRIP2_H + TICKER_H  # 104 at 720p
TICKER_Y = STRIP1_H + STRIP2_H
```

`reinit_layout()` scales all three; downstream `CONTENT_Y`, click zone, tabs unchanged in behavior.

### Preserve checklist

- [x] No mechanic changes
- [x] Save fields untouched
- [x] Tab structure unchanged
- [x] Manager identities unchanged
- [x] Heat tooltip still works on hover
- [x] Performance: no new per-frame surface allocation in hot paths (chips reuse `_draw_status_chip` pattern)

### Known limitations

- Extreme late-game numbers truncate in money/income columns (by design).
- Portrait mode: header scales; chip row may compress on very narrow widths (<480).
- Pete / Broker / exec advisors not in chip row (future: optional second row or icon strip).

---

## 9. Wireframe (target — implemented)

```
┌──────────────────────────────────────────────────────────────────┐
│ [◉ $12.4M]  INCOME 86.4K/sec     NEXT GOAL: Hire Manager  RANK  │
│                                              ASSOCIATE ▓▓░░      │
├──────────────────────────────────────────────────────────────────┤
│ HEAT ▓▓░░ 42%    SHIELD ●●○    OP 128s         SAL MECH ACC     │
├──────────────────────────────────────────────────────────────────┤
│ ◆ Rival Black Hand spotted in Industrial District…               │
└──────────────────────────────────────────────────────────────────┘
```

---

## 10. Next steps (Presentation Saga)

| Phase | Focus |
|-------|-------|
| 123 | Manager card portraits + collapse locked exec |
| 124 | City-first left column |
| 125 | Turf sub-tab badges (ops ready on Turf tab) |
| 128 | Shield pulse / auto-buy attribution toasts |

---

## 11. Re-run captures

```powershell
python phase122_capture.py
```
