# Header / Goal-Bar Polish — Implementation Plan

> Execute task-by-task. Godot: `E:\Downloads\Godot_v4.6.3-stable_win64.exe`.

**Goal:** Honest goal rail + masthead IPS cue per
`docs/superpowers/specs/2026-07-18-header-goal-bar-design.md`.

---

### Task 1: AttentionDirector — real goals first

**File:** `godot/scripts/ui/shell/attention_director.gd`

- [ ] In `_ambient_item()`, **before** the soft-hint block that calls
  `next_focus_hint`, insert:

```gdscript
	var goals: Array = _GoalSystem.current_goals(GameState, 1)
	if not goals.is_empty() and typeof(goals[0]) == TYPE_DICTIONARY:
		var g: Dictionary = goals[0]
		var prog: Dictionary = _GoalSystem.progress_for(GameState, g)
		var cur := float(prog.get("current", 0.0))
		var tgt := float(prog.get("target", 1.0))
		var frac := clampf(cur / tgt, 0.0, 1.0) if tgt > 0.0 else 0.0
		return {
			"kind": "goal", "prio": PRIO_GOAL_HINT,
			"text": str(g.get("label", "Goal")),
			"value": _format_goal_progress(g, cur, tgt),
			"progress": frac,
			"target": "",
		}
```

- [ ] Add helper `_format_goal_progress(g, cur, tgt) -> String`:
  - `balance` / `route` / `lifetime` kinds → `FormatUtil.format_money(cur) + "/" + FormatUtil.format_money(tgt)`
  - else → `"%d/%d" % [int(cur), int(tgt)]` when tgt >= 1, else `"%.0f%%" % (frac*100)` if useful, else `""`
- [ ] Change soft-hint returns:
  - `next_focus_hint` → `kind: "hint"`, `text: hint` (no `▸ GOAL —` prefix)
  - `next_purchase_hint` → keep `kind: "afford"`, `text: hint` (drop `▸ NEXT —` if present; optional `NEXT —` short prefix OK)

- [ ] Commit: `feat(ui): attention rail prefers real goals with progress`

---

### Task 2: AttentionRail — underbar + copy cleanup

**File:** `godot/scripts/ui/shell/attention_rail.gd`

- [ ] Add `@onready`-style field `var _bar: UiPrims.MiniBar` built in `_ready`
  under the HBox (inside `_panel`), height 2, full width via anchors or
  `custom_minimum_size.y = 2` at bottom of panel VBox.

  Structure change: wrap existing HBox in a VBox; append MiniBar.

- [ ] In `_on_attention`:
  - set `_bar.progress = float(item.get("progress", -1.0))` — hide bar when
    progress < 0
  - `kind == "hint"` uses `GameTheme.TEXT_MUTED` accent (or GOLD at 0.55);
    `goal` keeps GOLD; existing raid/op/etc. unchanged
  - ensure `_value` shows when non-empty (already does)

- [ ] Commit: `feat(ui): goal rail underbar + hint accent`

---

### Task 3: Masthead IPS cue

**File:** `godot/scripts/ui/shell/hud_masthead.gd`

- [ ] Where `_ips.text` is assigned in `refresh()`, use:
  `"▲  + %s / SEC" % FormatUtil.format_money(ips)` when ips > 0, else
  `"+ $0 / SEC"` (no triangle when idle).

- [ ] Commit: `feat(ui): masthead income line gains ▲ cue`

---

### Task 4: Verify

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd | Select-String "PASS|FAIL"
# early + mid stills
```

READ: early still shows real goal + fraction + underbar; no fake `GOAL — Open Upgrades`.
