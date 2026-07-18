# Gold-Remnant Theme Cleanup — Implementation Plan

> **For agentic workers:** Execute task-by-task. Checkbox steps for tracking.

**Goal:** Remove warm amber chrome leftovers so the live shell matches the violet hero
tokens, per `docs/superpowers/specs/2026-07-18-gold-remnant-cleanup-design.md`.

**Tech stack:** Godot 4.6.3, `shell_smoke.gd`, `ui_capture.ps1`, ink bake tool.

## Mapping

| Warm remnant | Violet replacement |
|--------------|-------------------|
| `Color(0.925, 0.792, 0.49[, 1])` | `Color(0.694, 0.549, 1.0[, 1])` (= `GOLD_BRIGHT`) |
| `Color(0.792, 0.639, 0.353[, 1])` | `Color(0.541, 0.361, 1.0[, 1])` (= `GOLD`) |
| `Color(0.784, 0.639, 0.353[, 1])` | `Color(0.541, 0.361, 1.0[, 1])` |
| Baker `#c8a35a` / `#ecca7d` | `#8a5cff` / `#b18cff` |

---

### Task 1: Hustle band + ink baker constants

**Files:** `godot/scripts/ui/hustle_band.gd`, `godot/scripts/ui/ink_texture_baker.gd`

- [ ] **Step 1:** In `hustle_band.gd`, replace the three warm constants with city_view's
  violet recipe:

```gdscript
const INK_GOLD := Color(0.541, 0.361, 1.0, 0.157)
const INK_GOLD_BRIGHT := Color(0.694, 0.549, 1.0)
const INK_GOLD_DEEP := Color(0.541, 0.361, 1.0, 0.314)
```

- [ ] **Step 2:** In `ink_texture_baker.gd`:

```gdscript
const GOLD := Color("8a5cff")
const GOLD_BRIGHT := Color("b18cff")
```

- [ ] **Step 3:** Re-bake ink textures:

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/bake_ink_ui_textures.gd
```

- [ ] **Step 4:** Commit `feat(ui): retint hustle + ink baker off warm gold onto violet`

---

### Task 2: Scene editor defaults

**Files:** `main_menu.tscn`, `game_screen.tscn`, `building_row.tscn`, `manager_row.tscn`,
`rival_row.tscn`, `territory_row.tscn`, `crew_row.tscn`, `operation_row.tscn`

- [ ] **Step 1:** Replace warm amber `theme_override_colors/font_color` literals per the
  mapping table above. Do **not** touch brownish `TEXT_MUTED`-like
  `Color(0.541, 0.502, 0.439)` neutrals.
- [ ] **Step 2:** Confirm `game_theme.gd` `building_neon("hq")` still returns
  `Color(0.925, 0.792, 0.49)`.
- [ ] **Step 3:** Commit `fix(ui): scene defaults use violet chrome, not warm brass`

---

### Task 3: Verify

- [ ] `shell_smoke` PASS
- [ ] Capture menu + tab 0; READ — no warm brass on hustle/chrome
- [ ] No further commit unless a fix is needed
