# Neon Noir Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the owner-picked Neon Noir direction study into the live main-screen shell — a whole-app `GameTheme` retint, the study's premium atmospheric moves added to `city_view`, and code-drawn gradient depth on business rows.

**Architecture:** Recolor, not rebuild. The live `city_view` is already a cool-noir reactive scene; the clash is the warm gilded chrome around it. Amend the shared `GameTheme` palette so every surface inherits Neon Noir, add three additive `_draw` moves the city lacks (rooftop signs, wet-street streaks, corner brackets), and paint the mock's opaque gradient card as the first layer of each row's existing `_draw`. Verification is headless SceneTree probes (structural assertions, not pixels) plus the shell capture matrix for visual judgment.

**Tech Stack:** Godot 4.6.3, GDScript. No unit-test framework — verification is headless probes (`godot --headless --path godot -s res://scripts/tools/<probe>.gd`, `quit(0)`=PASS, `quit(1)`=FAIL) modelled on `shell_smoke.gd` / `city_reaction_probe.gd`. Visual proof via `ui_capture.ps1 -Shell`.

**Spec:** `docs/superpowers/specs/2026-07-17-neon-noir-port-design.md` — read it first; its Constraints section is law.

## Global Constraints

- ART_POLICY: code-drawn only — `_draw`, `StyleBoxFlat`, real `GameFonts`. No generative assets.
- Preserve ALL reactive logic in `city_view.gd` (facade pulse, heat hostility `SIREN_RED/BLUE`, district flash, raid surge, searchlights) — recolor/additive only.
- Preserve row layering & beats in `building_row.gd`: gradient draws *behind* wax seal / afford underbar / unlock ink-wipe; purchase coin-arc + medallion flare untouched.
- No save-schema changes, no new settings, no balance changes, no new audio.
- Semantic colors keep meaning and values: `SIREN_RED`, `SIREN_BLUE`, `GREEN`, `RED`.
- `city_view.gd` house rule (from reactive-city plan): recolor existing `const`s and add new **named `const`s at the top**; never inline raw hex in `_draw`.
- Token lint (`ui_validators.ps1`) scans only `ui/shell`, `ui/screens`, `ui/components`. The three edited files (`game_theme.gd`, `city_view.gd`, `building_row.gd`) sit in `ui/` and are NOT lint-scanned — but must still pass the lint for the overlays edited in Task 5.
- Godot binary: `E:/Downloads/Godot_v4.6.3-stable_win64.exe` (or `$env:GODOT_BIN`). Commands below use the literal path.

---

### Task 1: The failing probe — Neon Noir does not exist yet

**Files:**
- Create: `godot/scripts/tools/neon_noir_probe.gd`

**Interfaces:**
- Consumes: `SoakAutoloads.install`, `game_shell.tscn`, `CityView` node (group/name), `GameState`.
- Produces (asserted, built in Tasks 2–4):
  - `GameTheme` constants `JEWEL_TEAL == Color("2fd6c6")`, `JEWEL_MAGENTA == Color("e5457e")`, `BG == Color("06070c")` — checked via `load(path).get_script_constant_map()` (no compile-time reference, so a missing token is a clean FAIL not a compile error).
  - `city_view.gd` has methods `_draw_rooftop_signs`, `_draw_neon_streaks`, `_draw_corner_brackets` (has_method).
  - `building_row.gd` has method `_draw_card_gradient` (has_method).
  - Regression: after `pulse_facade(key)` + `set_alert_level(2)`, `is_facade_pulsing(key)` is true and `alert_level() == 2` (reactive logic intact).

- [ ] **Step 1: Write the probe**

Create `godot/scripts/tools/neon_noir_probe.gd`. New scripts are read by **path** via `get_script_constant_map()` / `has_method`, never by `class_name` at the top level (the Task-7 lesson from the reactive-city plan: a compile-time reference to a not-yet-existing symbol kills the probe with a compile error instead of a clean FAIL).

```gdscript
extends SceneTree
## Headless probe: the Neon Noir port — palette tokens amended, city gains the
## three atmospheric moves, rows gain the gradient card, and the city stays
## reactive. Structural assertions only (pixels are judged from captures).
## Usage:
##   godot --headless --path godot -s res://scripts/tools/neon_noir_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

const THEME_PATH := "res://scripts/ui/game_theme.gd"
const CITY_PATH := "res://scripts/ui/city_view.gd"
const ROW_PATH := "res://scripts/ui/building_row.gd"

var _shell: Node
var _city: Node
var _frames := 0


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	var packed: PackedScene = load("res://scenes/game_shell.tscn")
	if packed == null:
		printerr("[neon_probe] FAIL: game_shell.tscn did not load")
		quit(1)
		return
	_shell = packed.instantiate()
	root.add_child(_shell)


func _fail(msg: String) -> bool:
	printerr("[neon_probe] FAIL: " + msg)
	quit(1)
	return true


func _has_const(map: Dictionary, key: String, want: Color) -> bool:
	if not map.has(key):
		return false
	return (map[key] as Color).is_equal_approx(want)


func _process(_delta: float) -> bool:
	_frames += 1
	if _city == null:
		_city = root.find_child("CityView", true, false)
	if _city == null:
		if _frames >= 15:
			return _fail("CityView not found after 15 frames")
		return false

	# 1. Theme tokens amended (read by constant map — no compile dependency).
	var theme_map: Dictionary = (load(THEME_PATH) as GDScript).get_script_constant_map()
	if not _has_const(theme_map, "JEWEL_TEAL", Color("2fd6c6")):
		return _fail("GameTheme.JEWEL_TEAL missing or wrong (want #2fd6c6)")
	if not _has_const(theme_map, "JEWEL_MAGENTA", Color("e5457e")):
		return _fail("GameTheme.JEWEL_MAGENTA missing or wrong (want #e5457e)")
	if not _has_const(theme_map, "BG", Color("06070c")):
		return _fail("GameTheme.BG not cooled to #06070c")

	# 2. City gained the three atmospheric moves.
	for m in ["_draw_rooftop_signs", "_draw_neon_streaks", "_draw_corner_brackets"]:
		if not _city.has_method(m):
			return _fail("CityView missing %s() — atmospheric move not ported" % m)

	# 3. Rows gained the gradient card.
	var row_script: GDScript = load(ROW_PATH)
	if not ("_draw_card_gradient" in row_script.get_script_method_list().map(
			func(d): return d.name)):
		return _fail("building_row missing _draw_card_gradient()")

	# 4. Reactive regression — recolor must not have broken the city.
	var key: String = str(root.get_node("GameState").buildings[0].icon_key)
	_city.call("pulse_facade", key)
	_city.call("set_alert_level", 2)
	if not bool(_city.call("is_facade_pulsing", key)):
		return _fail("pulse_facade no longer lights a facade — reactive logic broke")
	if int(_city.call("alert_level")) != 2:
		return _fail("set_alert_level/alert_level round-trip broke")

	print("[neon_probe] PASS — tokens amended, city + rows ported, reactive intact")
	quit(0)
	return true
```

- [ ] **Step 2: Run it — watch it fail for the right reason**

Run:
```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/neon_noir_probe.gd
```
Expected: `[neon_probe] FAIL: GameTheme.JEWEL_TEAL missing or wrong (want #2fd6c6)`, exit 1. (The first unmet assertion — tokens — fails first. Good: it proves the probe runs and the port is genuinely absent.)

- [ ] **Step 3: Commit the failing probe**

```bash
git add godot/scripts/tools/neon_noir_probe.gd
git commit -m "test(ui): probe proves the Neon Noir port does not exist yet"
```

---

### Task 2: Theme amendment — the whole app goes Neon Noir

**Files:**
- Modify: `godot/scripts/ui/game_theme.gd:10-13` (base blacks), add jewel tokens after `GOLD_BRIGHT`, retint chrome/row-bg constants (lines ~26-81).

**Interfaces:**
- Consumes: nothing new.
- Produces: `GameTheme.JEWEL_TEAL`, `GameTheme.JEWEL_MAGENTA`, cooled `BG/BG_PANEL/BG_CARD` and chrome/row-bg constants — consumed app-wide automatically.

- [ ] **Step 1: Cool the base blacks and add jewel tokens**

In `godot/scripts/ui/game_theme.gd`, edit lines 10-13:
```gdscript
const BG := Color("06070c")
const BG_PANEL := Color("0c0f18")
const BG_CARD := Color("11151f")
```
Immediately after `const GOLD_BRIGHT := Color("ecca7d")` (line 14), add:
```gdscript
# Neon Noir jewel accents (2026-07-17 kit amendment — direction study `b`).
const JEWEL_TEAL := Color("2fd6c6")
const JEWEL_MAGENTA := Color("e5457e")
```

- [ ] **Step 2: Retint the warm chrome + row-background constants cooler**

Still in `game_theme.gd`, change these constants to their cool Neon Noir values (keep names; keep `GOLD`, `SIREN_*`, `GREEN`, `RED` untouched):
```gdscript
const TAB_ACTIVE := Color("1e2130")
const TAB_IDLE := Color("0e111a")
const CHIP_BG := Color("141824")
const INK_DEEP := Color("0e101a")
const PLATE := Color("141824")
const ROW_BG_BUYABLE := Color("12161f")
const ROW_BG_LOCKED := Color("0e111a")
const ROW_BG_OWNED := Color("10141c")
const ROW_BG_PETE := Color("1c1810")
```
(The green cast on the buyable/owned rows is removed — the per-business gradient accent from Task 4 now carries row color; PETE stays faintly warm so the advisor pick still reads gold.)

- [ ] **Step 3: Run the probe — further along**

Run:
```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/neon_noir_probe.gd
```
Expected: now FAILs at `CityView missing _draw_rooftop_signs()` (token assertions pass; city move is the next unmet assertion).

- [ ] **Step 4: Eyeball the cooled chrome**

Run:
```bash
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 1080x1920
```
Expected: a capture is written; the sheet/rows/chrome read cooler (no warm gilded cast fighting the blue city). Look at it — confirm no unreadable text, no black-on-black.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/ui/game_theme.gd
git commit -m "feat(ui): Neon Noir palette — the whole app goes cool, gold demoted"
```

---

### Task 3: City neon punch-up — the three moves the scene lacks

**Files:**
- Modify: `godot/scripts/ui/city_view.gd` — retint consts (lines 11-26), add named consts, add three `_draw_*` helpers, call them in `_draw()` (lines 234-266).

**Interfaces:**
- Consumes: existing `_draw()` pipeline, `ground_y`, `_t`, `_top_building_keys`.
- Produces: `_draw_rooftop_signs(ground_y: float)`, `_draw_neon_streaks(ground_y: float, t: float)`, `_draw_corner_brackets()` — asserted by the probe.

- [ ] **Step 1: Retint the city palette constants cooler + teal neon**

In `godot/scripts/ui/city_view.gd`, edit the color constants (lines 11-26):
```gdscript
const INK := Color("06070c")
const SKY_BACK := Color8(14, 24, 38)
const SKY_MID := Color8(20, 30, 52)
const SKY_HAZE := Color8(38, 46, 72)
const NEON_COOL := Color8(47, 214, 198)
```
(Leave `INK_GOLD`, `INK_GOLD_BRIGHT`, `INK_CRIMSON`, `SKY_GLOW`, `STREET*`, `SILHOUETTE*`, `NEON_WARM`, `NEON_RED` as-is.) Add one new const beneath the neon block:
```gdscript
# Bright rooftop-sign / wet-street bloom (study `b` win teal).
const NEON_SIGN := Color8(79, 224, 208)
```

- [ ] **Step 2: Add the three draw helpers**

Append to `city_view.gd` (near the other `_draw_*` helpers). These mirror the study's `_Backdrop` rooftop/reflection/frame passes, using named consts only:
```gdscript
## Rooftop neon-sign blooms atop a few mid-skyline silhouettes — nightlife pop.
func _draw_rooftop_signs(ground_y: float) -> void:
	var w := VIRTUAL_SIZE.x
	var horizon := ground_y * 0.9
	var xs := [0.19, 0.44, 0.70]
	var hts := [0.52, 0.66, 0.58]
	for i in xs.size():
		var sx := w * float(xs[i]) + w * 0.06
		var sy := horizon - horizon * float(hts[i]) - 4.0
		for k in 4:
			draw_circle(Vector2(sx, sy), 10.0 - k * 2.0,
					Color(NEON_SIGN.r, NEON_SIGN.g, NEON_SIGN.b, 0.06))
		draw_circle(Vector2(sx, sy), 2.0, Color(NEON_SIGN, 0.9))


## Vertical neon streaks bleeding down the wet street under the brightest signs.
func _draw_neon_streaks(ground_y: float, t: float) -> void:
	var w := VIRTUAL_SIZE.x
	var xs := [0.19, 0.44, 0.70]
	var flick := 0.10 + 0.04 * sin(t * 2.3)
	for x in xs:
		var rx := w * float(x) + w * 0.06
		draw_line(Vector2(rx, ground_y), Vector2(rx, ground_y + VIRTUAL_SIZE.y * 0.06),
				Color(NEON_SIGN.r, NEON_SIGN.g, NEON_SIGN.b, flick), 3.0)


## Deco corner brackets — a thin double keyline at each frame corner.
func _draw_corner_brackets() -> void:
	var w := VIRTUAL_SIZE.x
	var h := VIRTUAL_SIZE.y
	var m := 6.0
	var bl := 26.0
	var g := INK_GOLD_BRIGHT
	for corner in [[m, m, 1.0, 1.0], [w - m, m, -1.0, 1.0],
			[m, h - m, 1.0, -1.0], [w - m, h - m, -1.0, -1.0]]:
		var cx: float = corner[0]
		var cy: float = corner[1]
		var sx: float = corner[2]
		var sy: float = corner[3]
		draw_line(Vector2(cx, cy), Vector2(cx + sx * bl, cy), Color(g, 0.6), 2.0)
		draw_line(Vector2(cx, cy), Vector2(cx, cy + sy * bl), Color(g, 0.6), 2.0)
		draw_line(Vector2(cx + sx * 5, cy + sy * 5),
				Vector2(cx + sx * (bl - 4), cy + sy * 5), Color(g, 0.3), 1.0)
```

- [ ] **Step 3: Call the helpers in `_draw()`**

In `city_view.gd` `_draw()`, add the calls in the existing pipeline. Rooftop signs go with the skyline (after `_draw_mid_skyline`); streaks go with reflections (after `_draw_reflections`); brackets go with the frame chrome (after `_draw_vignette`). Insert:
```gdscript
	_draw_mid_skyline(_total_buildings, tier, _top_building_keys, _top_building_counts, _t, ground_y)
	_draw_rooftop_signs(ground_y)          # <-- add
	_draw_horizon_glow(ground_y)
```
```gdscript
	_draw_reflections(ground_y, _t)
	_draw_neon_streaks(ground_y, _t)       # <-- add
```
```gdscript
	_draw_vignette()
	_draw_corner_brackets()                # <-- add
```

- [ ] **Step 4: Run the probe — reactive intact, city move present**

Run:
```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/neon_noir_probe.gd
```
Expected: now FAILs at `building_row missing _draw_card_gradient()` (city + reactive assertions pass).

- [ ] **Step 5: Look at the city at both sizes**

Run:
```bash
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 720x1280
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 1080x1920
```
Expected: captures written; teal rooftop signs + wet-street streaks + corner brackets visible; skyline reads Neon Noir; nothing clipped at either size.

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/ui/city_view.gd
git commit -m "feat(city): Neon Noir night — rooftop signs, wet-street streaks, deco brackets"
```

---

### Task 4: Gradient business rows — the mock's card depth

**Files:**
- Modify: `godot/scripts/ui/building_row.gd` — add `_draw_card_gradient()`, call it first in `_draw()` (lines 124-138).

**Interfaces:**
- Consumes: `GameTheme.building_neon(key: String) -> Color`, `_building.icon_key`, `_affordance`, `GameTheme.RowAffordance`.
- Produces: `_draw_card_gradient()` — asserted by the probe.

- [ ] **Step 1: Add the gradient card method**

In `godot/scripts/ui/building_row.gd`, add (mirrors the study's `_CardBg`; accent from the existing per-business color system; opaque so it overpaints the panel stylebox, its own accent border carries the affordance signal):
```gdscript
## Study `_CardBg`: a code-drawn vertical-gradient body + left accent bar, giving
## the row depth a flat StyleBox can't. Drawn FIRST (behind wax seal / underbar /
## ink-wipe). Opaque — it overpaints the panel stylebox; corners read square,
## matching the mock. Accent = the business signature color (same as the medallion).
func _draw_card_gradient() -> void:
	var w := size.x
	var h := size.y
	var buyable := _affordance != GameTheme.RowAffordance.LOCKED
	var accent := GameTheme.building_neon(_building.icon_key) if _building != null else GameTheme.GOLD
	var top := GameTheme.BG_CARD.lerp(Color.WHITE, 0.05 if buyable else 0.02)
	var bot := GameTheme.BG_CARD.lerp(GameTheme.BG, 0.55)
	var steps := 14
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, t * h, w, h / steps + 1.0), top.lerp(bot, t))
	draw_rect(Rect2(0, 0, 3.0, h), Color(accent, 0.9 if buyable else 0.3))
	if buyable:
		draw_rect(Rect2(0, 0, w, h), Color(accent.r, accent.g, accent.b, 0.03))
	draw_rect(Rect2(0, 0, w, h), Color(accent, 0.42 if buyable else 0.16), false, 1.0)
	draw_rect(Rect2(0, 0, w, 1.0), Color(accent, 0.20 if buyable else 0.07))
```

- [ ] **Step 2: Call it first in `_draw()`**

In `building_row.gd` `_draw()` (line 124), add the gradient as the first draw call, before the wax seal:
```gdscript
func _draw() -> void:
	if _building != null:
		_draw_card_gradient()
	GameTheme.draw_row_wax_seal(self, _affordance)
```
(Leave the afford underbar and ink-wipe blocks below unchanged — they now layer on top of the gradient.)

- [ ] **Step 3: Run the probe — it must now PASS**

Run:
```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/neon_noir_probe.gd
```
Expected: `[neon_probe] PASS — tokens amended, city + rows ported, reactive intact`, exit 0.

- [ ] **Step 4: Shell smoke — no regression**

Run:
```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
```
Expected: `[shell_smoke] PASS — 200 frames, no crash`, exit 0.

- [ ] **Step 5: Look at the rows**

Run:
```bash
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 1080x1920
```
Expected: rows show a top-lit → dark gradient with a per-business left accent bar; buyable rows brighter, locked rows flat/dim; wax seal, afford underbar, and BUY button still legible on top. Confirm the square corners read intentional, not broken (the one judgment call — if they read as an artifact against the sheet, note it for a follow-up round; do not block).

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/ui/building_row.gd
git commit -m "feat(ui): rows gain code-drawn gradient depth + per-business accent"
```

---

### Task 5: Off-token overlay sweep — kill the warm-on-cool clashes

**Files:**
- Modify: only the overlay/shell scripts whose hardcoded warm colors visibly clash (candidates: `godot/scripts/ui/dragon_patron_overlay.gd`, `gambling_overlay.gd`, and any `ui/shell/*` or `ui/screens/*` hit). Exact files determined by the grep in Step 1.

**Interfaces:**
- Consumes: `GameTheme` tokens (`BG`, `BG_PANEL`, `JEWEL_TEAL`, etc.).
- Produces: no new symbols — realigned colors only.

- [ ] **Step 1: Enumerate the hardcoded colors**

Run:
```bash
grep -rnE 'Color\("[0-9a-fA-F]{3,8}"|Color8\(' godot/scripts/ui/dragon_patron_overlay.gd godot/scripts/ui/gambling_overlay.gd godot/scripts/ui/shell godot/scripts/ui/screens
```
Expected: a list of literal-color sites. Classify each: **semantic** (heat/danger/win red, income green — leave), or **warm-neutral chrome** (browns/warm blacks that now clash against the cool ground — realign).

- [ ] **Step 2: Realign only the clashing warm-neutral chrome**

For each warm-neutral chrome hit, replace with the nearest `GameTheme` token (`BG_PANEL`, `BG_CARD`, `INK_DEEP`, `PLATE`, `CHIP_BG`) or a cool equivalent. Do NOT touch semantic colors. Do NOT introduce raw hex into `ui/shell` / `ui/screens` / `ui/components` — use tokens there (token-lint law).

- [ ] **Step 3: Token lint + overlay smoke**

Run:
```bash
powershell -File ui_validators.ps1 -TokenLintOnly
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
```
Expected: `V3 token lint: PASS`; `[shell_smoke] PASS`. Then capture with an overlay up if a capture flag exists; otherwise open the scene in-editor and pop the dragon/gambling/event overlays, confirming no warm-on-cool clash and all text legible.

- [ ] **Step 4: Commit**

```bash
git add -A godot/scripts/ui
git commit -m "fix(ui): realign warm overlay chrome to the Neon Noir ground"
```

---

### Task 6: Full verification + graph refresh + device checklist

**Files:**
- Modify: `godot/design/` device-pass checklist doc (the living-city / deco-motion checklist the branch already appends to — locate with the grep in Step 3).

- [ ] **Step 1: Full probe + smoke + lint sweep**

Run:
```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/neon_noir_probe.gd
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
powershell -File ui_validators.ps1
```
Expected: `[neon_probe] PASS`; `[shell_smoke] PASS`; validators `ALL PASS`.

- [ ] **Step 2: Capture matrix — the look, judged**

Run:
```bash
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 720x1280
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 1080x1920
```
Expected: both captures written and reviewed against `godot/design/premium_main.gd` direction `b`. The live shell should read as the Neon Noir study: cool ground, teal/magenta accents, atmospheric city, gradient rows. Note any gap for a follow-up polish round — do not silently accept a miss.

- [ ] **Step 3: Add device-checklist lines**

Locate the branch's device checklist:
```bash
grep -rniE "device.?pass|device checklist|living-city checks" godot/design docs | head
```
Append Neon Noir lines to that checklist file (mirror the existing bullet style): "whole-app cool retint reads premium on-device (not muddy on an OLED)", "rooftop signs + wet-street streaks legible at arm's length", "row gradient accents distinguish businesses at a glance".

- [ ] **Step 4: Refresh the knowledge graph + commit**

Run:
```bash
python -m graphify update .
```
Then:
```bash
git add -A
git commit -m "docs(device): Neon Noir port joins the device pass; graph refresh"
```

---

## Self-Review

**Spec coverage:**
- Theme amendment (spec edit 1) → Task 2 (+ off-token sweep in Task 5). ✓
- City neon punch-up (spec edit 2) → Task 3. ✓
- Gradient rows (spec edit 3) → Task 4. ✓
- Verification (shell_smoke, capture matrix, token lint, overlay smoke, graphify) → Tasks 4, 5, 6. ✓
- Out-of-scope (masthead, medallions, nav dock, study files) → not touched by any task. ✓

**Placeholder scan:** No TBD/TODO; every code step carries complete code; the only deferred item is the *set* of off-token hits in Task 5, which is correct — it is discovered by an exact grep, then classified by an explicit rule, not left vague.

**Type consistency:** Probe asserts `_draw_rooftop_signs`/`_draw_neon_streaks`/`_draw_corner_brackets` (Task 3 defines exactly these) and `_draw_card_gradient` (Task 4 defines exactly this). Token names `JEWEL_TEAL`/`JEWEL_MAGENTA`/`BG` match Task 2. `GameTheme.building_neon(key)` and `GameTheme.RowAffordance.LOCKED` match the existing signatures read from source. Consistent. ✓
