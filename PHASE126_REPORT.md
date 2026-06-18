# Phase 126 — Stats Tab Polish (Godot 1.0)

**Date:** 2026-06-17  
**Scope:** Presentation only — Stats tab in Godot. pygame prototype not updated.

---

## Objective

Replace the flat text dump with a **tiered above-fold dashboard**: session cards, resources, rank progress, goals, then deeper sections (Rob, heat, city, lifetime). Prominent **achievement entry** at the top of the scroll.

---

## Delivered

### New module: `godot/scripts/ui/stats_dashboard.gd`
- `StatsDashboard.rebuild(host, state)` — builds sectioned UI into `StatsDashboard` VBox
- **Tier 1 (above fold):** SESSION 2×2 cards, RESOURCES, RANK + bar, ACTIVE GOALS (≤3)
- **Tier 2 (scroll):** Rob's dashboard (share bars), HEAT, CITY DOMINATION, LIFETIME grid
- Noir card styling via `GameTheme` (`BG_CARD`, gold accents, section headers)

### `game_screen.gd` / `game_screen.tscn`
- Removed monolithic `Body` Label
- **AchBtn** moved to top of Stats scroll — `★ Achievements  n / total  ·  +X% income`, 48px tap target
- Achievements panel unchanged (expand below dashboard)

---

## Verify

```bash
# Godot F5 → Stats tab — cards, bars, achievement button at top
python sim_godot_soak.py --godot "<path-to-godot>"
```

---

## Presentation saga (Godot)

| Phase | Status |
|-------|--------|
| 126 | **Done** (this report) |
| 128 | Queued — motion P0 (partial in P6) |
