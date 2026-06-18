# Phase 125 — Turf Sub-Tab Badges

> **Historical — pygame prototype only.** Godot P7 turf badges live in `game_screen.gd`.

**Date:** 2026-06-17  
**Scope:** Presentation only — tab labels and indicators. No gameplay, balance, or save changes.

---

## 1. Objective

Surface **actionable turf state** on the tab bar so players notice ops ready and Broker intel
without opening every sub-panel. Matches Godot P7 roll-up badges (`game_screen.gd`).

---

## 2. Delivered (pygame)

### Main Turf tab roll-up
| Condition | Label |
|-----------|-------|
| The Broker hired | `Turf ★` |
| Ops unlocked + ≥1 ready to collect | `Turf •` |
| Otherwise | `Turf` |

Broker takes priority over ops dot (same priority as Godot).

### Turf sub-tabs
| Sub-tab | Locked | Unlocked |
|---------|--------|----------|
| **Crew** | `Crew n/5` | `Crew` |
| **Ops** | `Ops n/2` | `Ops*` when ready, else `Ops` |

### Ops ready pulse
- Green pulsing dot on the **Ops sub-tab** when `ready_ops > 0` (count shown when >1).
- Removed dead code that drew an ops dot on a non-existent main-tab `operations` key.

### Implementation
- `ui._turf_tab_badges(state)` — single source of truth for labels.
- `main_tab_rects()` / `subtab_rects()` consume badges so click hitboxes match drawn text.

---

## 3. Godot touch fix (P7 cleanup)

- `prestige_tree_overlay.gd`: perk detail text now renders as a visible muted label under the
  buy button (tooltip retained for desktop hover). Closes P7 “hover-only perk detail” gap.

---

## 4. Verify

```bash
python main.py   # hire Broker / complete an op → Turf ★ / Ops* / pulse
python sim_smoke.py
```

Godot: `_refresh_tab_badges()` already matched; DEVICE_TEST_CHECKLIST Turf ★/• item applies.

---

## 5. Presentation saga status *(pygame track — archived)*

| Phase | Status |
|-------|--------|
| 125 | Done (pygame) — Godot equivalent in P7 `game_screen.gd` badges |
| 126 | Done (Godot) — `PHASE126_REPORT.md`, `stats_dashboard.gd` |
| 128 | Partial (Godot P6) — motion + audio in `audio_manager.gd` / `game_screen.gd` |
