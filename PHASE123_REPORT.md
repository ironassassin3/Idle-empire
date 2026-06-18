# Phase 123 — Employee Roster Redesign

> **Historical — pygame prototype only.** Superseded by Godot Managers tab rows.

**Date:** 2026-06-15  
**Scope:** Managers tab presentation only — no gameplay, balance, or save changes.

---

## 1. Objective

Transform the Managers tab from upgrade cards into an **employee roster** that reflects the strength of the manager system after Phases 104–122.

---

## 2. Success questions

| Question | Before | After |
|----------|--------|-------|
| Does it feel like running an organization? | Mixed — "STREET CREW" list + stat lines | **Yes** — EMPLOYEE ROSTER, departments, payroll language |
| Who works for me? | Green bar + "✓ AUTOMATED" | **ACTIVE EMPLOYEES (N)** section + ON PAYROLL badges |
| What does each person do? | `bonus_desc` + flavor paragraphs | **Live status line** per manager (e.g. "Collecting coins") |
| Who is helping now? | Header chips only (Phase 122) | Status + AUTO / ACTIVE / READY badges on roster cards |

**Verdict:** Screen reads as **payroll roster**, not upgrade shop.

---

## 3. Roster structure

Managers are grouped by **employment state** (save order preserved within each section):

| Section | Contents |
|---------|----------|
| **ACTIVE EMPLOYEES** | All hired managers (street + executive) |
| **AVAILABLE FOR HIRE** | Unlocked, not yet hired |
| **LOCKED EMPLOYEES** | Early-tier gates not yet met |

Executive specialists (indices 6–12):

- **Before Made Man:** single teaser — `EXECUTIVE STAFF (LOCKED)`
- **After Made Man:** collapsed **by default** — `EXECUTIVE STAFF (N LOCKED) ▼ Expand`
- **Expanded:** exec cards appear in the three sections above + `▲ Collapse` toggle

---

## 4. Card redesign

Each employee card shows:

```
[Icon]  Name          [Role pill]              [ON PAYROLL | OPEN | LOCKED]
        Status line…                           [AUTO | ACTIVE | READY]
        Payroll: $X (available) + HIRE         (+inc/s subtle, building-linked only)
```

### Status lines (hired)

| Manager | Status example |
|---------|----------------|
| Lucky Sal | Collecting coins |
| The Mechanic | Managing Chop Shops |
| The Collector | Shield ready / Shield charging (N%) |
| Clean Carl | Forecast +Δ/2m / Monitoring heat |
| The Accountant | Empire automation active |
| The Promoter | Maintaining heat ≤ N% |
| The Smuggler | Monitoring operations / Operation ready |
| The Broker | Turf intel active |
| Rudy Riches | Prestige analysis — {recommendation} |
| Rob Revenue | Reviewing finances — {headline} |
| Maxine | Coordinating staff (+N%) |
| Sticky Pete | Marking best building buy |
| Consigliere | Prestige advisory active |

### Locked presentation (reduced clutter)

- Name + LOCKED badge + **one** unlock line
- Late tier: rank progress only (`Capo: 8/25 Inf (32%)`)
- Early tier: requirement text; flavor only on **hover**
- Premium fee hidden until rank gate opens (existing `display_hire_fee`)

---

## 5. Visual identity

| Element | Treatment |
|---------|-----------|
| Panel title | `EMPLOYEE ROSTER` (display font, gold) |
| Subtitle | "Payroll · departments · live status" |
| Icons | Initial letter on department color disk |
| Active cards | Green border + left bar + ON PAYROLL |
| Available cards | Gold pulse when affordable + OPEN badge |
| Locked cards | Dim icon, grey panel, minimal text |
| Section headers | Color-coded with employee counts |

---

## 6. Wireframe

```
┌─ EMPLOYEE ROSTER ─────────────────────────────────────────────┐
│ Payroll · departments · live status                          │
│ ACTIVE EMPLOYEES (3) ─────────────────────────────────────── │
│ ┌ [S] Lucky Sal    Bookmaker      ON PAYROLL  AUTO            │
│ │     Collecting coins                                        │
│ ┌ [M] The Mechanic Night Shift    ON PAYROLL  AUTO            │
│ │     Managing Chop Shops                                       │
│ AVAILABLE FOR HIRE (1) ─────────────────────────────────────  │
│ ┌ [A] The Accountant Fixer  OPEN   Payroll: $65K      [HIRE] │
│ LOCKED EMPLOYEES (2) ───────────────────────────────────────  │
│ ┌ [C] Clean Carl   LOCKED   Heat reaches 40%…                 │
│ ┌ EXECUTIVE STAFF (7 LOCKED)  ▼ Expand ─────────────────────  │
│ │   Next: Capo (8/25 Inf, 32%)                                │
└───────────────────────────────────────────────────────────────┘
```

---

## 7. Screenshots

`python phase123_capture.py` → `phase123_screenshots/`

| File | Scenario |
|------|----------|
| `01_early_roster.png` | Locked + available early tier |
| `02_mid_active_roster.png` | Active employees + mixed sections |
| `03_late_exec_collapsed.png` | Mid/late crew hired, exec collapsed |
| `04_late_exec_expanded.png` | Executive staff visible in sections |

### Before / after

| Before (Phase 117–122) | After (Phase 123) |
|------------------------|-------------------|
| STREET CREW + EXECUTIVE TEAM headers | ACTIVE / AVAILABLE / LOCKED |
| `[ Title ]` inline brackets | Role department pills |
| flavor + bonus_desc + specialty stack | Single status line |
| ✓ AUTOMATED generic | AUTO / ACTIVE / READY badges |
| 6+ locked exec rows by default | Collapsed exec strip (default) |
| 110px tall cards | 92px roster rows |

---

## 8. Implementation notes

### Files changed

| File | Change |
|------|--------|
| `src/managers.py` | `_panel_row_plan`, `_employee_status`, `_draw_manager_card`, roster `draw_panel` / `handle_click`, icon initials |
| `src/states.py` | `_mgr_late_collapsed = True` default |

### Key functions

- `_panel_row_plan()` — three employment sections + exec teaser/collapse
- `_employee_status(state, idx)` — live status text + badge kind
- `_draw_manager_card()` — unified roster card renderer
- `_draw_section_header()` — counted section labels

### Preserve checklist

- [x] Manager order unchanged (save indices 0–12)
- [x] `hire_fee`, unlock gates, behaviors unchanged
- [x] HIRE click + Promoter target click unchanged
- [x] Scroll + collapse click wiring preserved
- [x] No save field additions

### Portrait / icon audit (future art optional)

| Opportunity | Phase 123 interim |
|-------------|-------------------|
| Full portraits | Initial letter on hue disk |
| Department icons | Role pill uses `Manager.title` |
| Personality | Status line voice; flavor on locked hover |
| Badge colors | Per-status pill colors tied to behavior type |

Full illustrated portraits deferred to a future art pass — structure supports swapping `_get_icon()` without layout changes.

---

## 9. Re-run

```powershell
python phase123_capture.py
```
