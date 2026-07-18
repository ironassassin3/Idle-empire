# Identity Medallion Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give rivals, managers, turf, and crew the same code-drawn medallion identity the Buildings tab already has, per `docs/superpowers/specs/2026-07-18-identity-medallions-design.md`.

**Architecture:** A shared static glyph library (`SigilGlyphs`) absorbs `CountMedallion`'s 11 business glyphs verbatim and adds 14 new marks (5 faction crests, 4 district types, 5 crew roles). A thin `IdentityMedallion` Control renders disc+ring+glyph from `glyph_key`/`tint`/`dimmed`. Each row scene gains one medallion node; row scripts feed it from data the systems already carry (`faction_key`+`color`, `Manager.building_index`, `district_type`+`color`, crew `role_key`).

**Tech Stack:** Godot 4.6.3 GDScript, `ui_capture.ps1` still harness, `shell_smoke.gd` headless probe.

## Global Constraints

- Godot binary: `E:\Downloads\Godot_v4.6.3-stable_win64.exe`.
- ART_POLICY: primitives only; colors from existing tokens/data. No textures, no new palette entries.
- No per-frame allocation; `_draw` only; `queue_redraw` only on property change.
- `CountMedallion` public behavior unchanged — Buildings tab must be pixel-equivalent.
- No save/balance/signal changes.
- Note: `GameTheme.GOLD` is the violet hero `#8a5cff` (legacy name after the violet retheme) — "gold" in code identifiers means the violet accent.
- Visual work has no unit tests here: test cycle = `shell_smoke.gd` (compiles every scene script + 200-frame crash check) + `ui_capture.ps1` stills you actually read.
- Capture gotchas (from the city-stage-repair session): tutorial modals can pop mid-capture — dismiss with `"inputs": [{"at": 50, "type": "tap", "x": 360, "y": 668}, {"at": 65, "type": "tap", "x": 360, "y": 668}]` and `"frames": 90`; the ps1 wrapper hides engine prints (only JSON lines echo); `--tab` maps 0 bldgs, 2 turf, 3 rivals, 4 crew, 7 mgrs.

---

### Task 1: SigilGlyphs library + IdentityMedallion control + CountMedallion delegation

**Files:**
- Create: `godot/scripts/ui/sigil_glyphs.gd`
- Create: `godot/scripts/ui/identity_medallion.gd`
- Modify: `godot/scripts/ui/count_medallion.gd` (replace `_draw_business_glyph` body with delegation)
- Create (scratch, not committed): `godot/design/shots/medal_spec.json`

**Interfaces:**
- Consumes: `GameTheme` color constants; `GameFonts` (unchanged, still used by CountMedallion).
- Produces (later tasks rely on these exact names):
  - `SigilGlyphs.draw_glyph(canvas: CanvasItem, key: String, c: Vector2, radius: float, col: Color) -> void`
  - `SigilGlyphs.BUILDING_KEYS: Array[String]` — index-ordered building keys.
  - `IdentityMedallion` (class_name, extends Control) with properties `glyph_key: String`, `tint: Color`, `dimmed: bool`.

- [ ] **Step 1: Baseline stills (before any change)**

Write `godot/design/shots/medal_spec.json`:

```json
[
  {"shell": true, "tab": 0, "w": 720, "h": 1280, "cash": 5000000, "districts": 6, "prestige_tokens": 12, "city_tier": 3, "no_overlays": true, "frames": 90, "inputs": [{"at": 50, "type": "tap", "x": 360, "y": 668}, {"at": 65, "type": "tap", "x": 360, "y": 668}], "out": "D:/2d_game/godot/design/shots/medal_before_bldgs.png"},
  {"shell": true, "tab": 3, "w": 720, "h": 1280, "cash": 5000000, "districts": 6, "prestige_tokens": 12, "city_tier": 3, "no_overlays": true, "frames": 90, "inputs": [{"at": 50, "type": "tap", "x": 360, "y": 668}, {"at": 65, "type": "tap", "x": 360, "y": 668}], "out": "D:/2d_game/godot/design/shots/medal_before_rivals.png"},
  {"shell": true, "tab": 7, "w": 720, "h": 1280, "cash": 5000000, "districts": 6, "prestige_tokens": 12, "city_tier": 3, "no_overlays": true, "frames": 90, "inputs": [{"at": 50, "type": "tap", "x": 360, "y": 668}, {"at": 65, "type": "tap", "x": 360, "y": 668}], "out": "D:/2d_game/godot/design/shots/medal_before_mgrs.png"}
]
```

Run: `.\ui_capture.ps1 -Spec godot\design\shots\medal_spec.json` → expect `"ok":true`.

- [ ] **Step 2: Create `godot/scripts/ui/sigil_glyphs.gd`**

The 11 business `match` arms are MOVED VERBATIM from `count_medallion.gd::_draw_business_glyph` (lines 98–161) — copy them, do not retype. Skeleton with the 14 new marks in full:

```gdscript
class_name SigilGlyphs
extends RefCounted
## Shared code-drawn glyph library (ART_POLICY: primitives only). One dispatch
## for business, faction, district, and crew marks so every list screen's
## medallion draws from the same visual language.

## Canonical building key order — index-aligned with building_defs._RAW and
## Manager.building_index.
const BUILDING_KEYS: Array[String] = [
	"dealer", "racket", "chop", "betting", "pawn", "loan",
	"casino", "club", "dock", "arms", "hq",
]


static func draw_glyph(canvas: CanvasItem, key: String, c: Vector2, radius: float, col: Color) -> void:
	var g := radius * 0.56
	var lw := maxf(1.8, radius * 0.14)
	match key:
		# ---- business marks (moved verbatim from count_medallion.gd) ----
		# "dealer", "racket", "chop", "betting", "pawn", "loan", "casino",
		# "club", "dock", "arms", "hq" arms go here, with draw_* calls
		# rewritten as canvas.draw_* (same geometry, untouched numbers).

		# ---- faction crests ----
		"crimson_kings":  # flame
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.55, -g * 0.1),
				c + Vector2(g * 0.38, g * 0.72), c + Vector2(0, g * 0.4),
				c + Vector2(-g * 0.38, g * 0.72), c + Vector2(-g * 0.55, -g * 0.1)]), col)
		"silver_hand":  # open palm
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.5, -g * 0.05), Vector2(g, g * 0.75)), col)
			for i in 4:
				var fx := -g * 0.44 + float(i) * g * 0.3
				canvas.draw_rect(Rect2(c + Vector2(fx, -g * 0.85), Vector2(g * 0.2, g * 0.85)), col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.5, g * 0.1), c + Vector2(-g * 0.85, -g * 0.25),
				c + Vector2(-g * 0.62, -g * 0.42), c + Vector2(-g * 0.5, -g * 0.05)]), col)
		"iron_union":  # gear
			canvas.draw_arc(c, g * 0.55, 0, TAU, 20, col, lw * 1.4)
			for i in 6:
				var ang := TAU * float(i) / 6.0
				canvas.draw_line(c + Vector2(cos(ang), sin(ang)) * g * 0.62,
					c + Vector2(cos(ang), sin(ang)) * g * 0.95, col, lw * 1.6)
			canvas.draw_circle(c, g * 0.18, col)
		"network":  # eye
			canvas.draw_arc(c + Vector2(0, g * 0.55), g * 1.05, deg_to_rad(235), deg_to_rad(305), 14, col, lw)
			canvas.draw_arc(c + Vector2(0, -g * 0.55), g * 1.05, deg_to_rad(55), deg_to_rad(125), 14, col, lw)
			canvas.draw_circle(c, g * 0.3, col)
		"blackwater":  # triple wave
			for i in 3:
				var wy := -g * 0.5 + float(i) * g * 0.5
				canvas.draw_arc(c + Vector2(-g * 0.4, wy), g * 0.4, PI, TAU, 10, col, lw)
				canvas.draw_arc(c + Vector2(g * 0.4, wy + g * 0.0), g * 0.4, 0, PI, 10, col, lw)

		# ---- district types ----
		"residential":  # house
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.9, 0), c + Vector2(0, -g * 0.85), c + Vector2(g * 0.9, 0)]), col)
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.6, 0), Vector2(g * 1.2, g * 0.8)), col, false, lw)
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.14, g * 0.25), Vector2(g * 0.28, g * 0.55)), col)
		"commercial":  # awning storefront
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.85, -g * 0.7), Vector2(g * 1.7, g * 0.3)), col)
			for i in 3:
				var ax := -g * 0.57 + float(i) * g * 0.57
				canvas.draw_arc(c + Vector2(ax, -g * 0.4), g * 0.28, 0, PI, 10, col, lw)
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.6, -g * 0.05), Vector2(g * 1.2, g * 0.75)), col, false, lw)
		"industrial":  # sawtooth factory + stack
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.9, g * 0.8), c + Vector2(-g * 0.9, 0), c + Vector2(-g * 0.3, -g * 0.45),
				c + Vector2(-g * 0.3, 0), c + Vector2(g * 0.3, -g * 0.45), c + Vector2(g * 0.3, 0),
				c + Vector2(g * 0.9, -g * 0.45), c + Vector2(g * 0.9, g * 0.8)]), col)
			canvas.draw_rect(Rect2(c + Vector2(g * 0.45, -g * 0.95), Vector2(g * 0.24, g * 0.5)), col)
		"government":  # columned portico
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.95, -g * 0.35), c + Vector2(0, -g * 0.9), c + Vector2(g * 0.95, -g * 0.35)]), col)
			for i in 3:
				var px := -g * 0.55 + float(i) * g * 0.55
				canvas.draw_line(c + Vector2(px, -g * 0.25), c + Vector2(px, g * 0.55), col, lw * 1.4)
			canvas.draw_rect(Rect2(c + Vector2(-g * 0.95, g * 0.6), Vector2(g * 1.9, g * 0.22)), col)

		# ---- crew roles ----
		"crew_protection":  # shield (same silhouette family as racket)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.74, -g * 0.5),
				c + Vector2(g * 0.74, g * 0.18), c + Vector2(0, g),
				c + Vector2(-g * 0.74, g * 0.18), c + Vector2(-g * 0.74, -g * 0.5)]), col)
		"crew_collection":  # coin stack
			for i in 3:
				var sy := g * 0.55 - float(i) * g * 0.45
				canvas.draw_rect(Rect2(c + Vector2(-g * 0.7, sy - g * 0.16), Vector2(g * 1.4, g * 0.32)), col)
		"crew_smuggling":  # crate
			canvas.draw_rect(Rect2(c - Vector2(g * 0.75, g * 0.75), Vector2(g * 1.5, g * 1.5)), col, false, lw)
			canvas.draw_line(c + Vector2(-g * 0.75, -g * 0.75), c + Vector2(g * 0.75, g * 0.75), col, lw)
			canvas.draw_line(c + Vector2(g * 0.75, -g * 0.75), c + Vector2(-g * 0.75, g * 0.75), col, lw)
		"crew_territory":  # pennant flag
			canvas.draw_line(c + Vector2(-g * 0.55, -g), c + Vector2(-g * 0.55, g), col, lw)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-g * 0.45, -g * 0.95), c + Vector2(g * 0.8, -g * 0.55),
				c + Vector2(-g * 0.45, -g * 0.15)]), col)
		"crew_heat":  # droplet
			canvas.draw_circle(c + Vector2(0, g * 0.25), g * 0.6, col)
			canvas.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -g), c + Vector2(g * 0.5, g * 0.0), c + Vector2(-g * 0.5, g * 0.0)]), col)
		_:
			canvas.draw_circle(c, g * 0.5, col)
```

- [ ] **Step 3: Create `godot/scripts/ui/identity_medallion.gd`**

```gdscript
class_name IdentityMedallion
extends Control
## Identity disc for list rows without a count badge: dark tinted disc + ring +
## code-drawn glyph via SigilGlyphs. Same disc language as CountMedallion so all
## list screens read as one family. ART_POLICY: primitives only.

var glyph_key := "":
	set(v):
		if glyph_key != v:
			glyph_key = v
			queue_redraw()

var tint := Color("8a5cff"):
	set(v):
		if tint != v:
			tint = v
			queue_redraw()

var dimmed := false:
	set(v):
		if dimmed != v:
			dimmed = v
			queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	if radius <= 2.0:
		return
	if dimmed:
		draw_circle(c, radius, Color("161020"))
		draw_arc(c, radius, 0, TAU, 48, Color(GameTheme.CHIP_BORDER, 0.95), 2.0)
		draw_arc(c, radius - 4.0, 0, TAU, 48, Color(GameTheme.CHIP_BORDER, 0.3), 1.0)
		SigilGlyphs.draw_glyph(self, glyph_key, c, radius, GameTheme.TEXT_MUTED)
		return
	draw_circle(c, radius, tint.darkened(0.74))
	draw_arc(c, radius, 0, TAU, 48, Color(tint, 0.95), 2.0)
	draw_arc(c, radius - 4.0, 0, TAU, 48, Color(tint, 0.5), 1.0)
	SigilGlyphs.draw_glyph(self, glyph_key, c, radius, tint.lightened(0.35))
```

- [ ] **Step 4: Delegate in `count_medallion.gd`**

Replace the entire `_draw_business_glyph` function (lines 96–161, comment included) with:

```gdscript
## Business glyphs live in the shared SigilGlyphs library so every list
## screen's medallion draws from one visual language.
func _draw_business_glyph(key: String, c: Vector2, radius: float, col: Color) -> void:
	SigilGlyphs.draw_glyph(self, key, c, radius, col)
```

(The moved arms must call `canvas.draw_*`; when copying from `count_medallion.gd`, prefix every bare `draw_line`/`draw_rect`/`draw_arc`/`draw_circle`/`draw_colored_polygon` with `canvas.`.)

- [ ] **Step 5: Compile + regression check**

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd | Select-String "PASS|FAIL|ERROR"
```

Expected: `[shell_smoke] PASS — 200 frames, no crash`, no script errors.

- [ ] **Step 6: Buildings tab pixel check**

Edit `medal_spec.json` job-1 `out` to `medal_after1_bldgs.png` (keep only that job), run the capture, and READ both PNGs side by side. Expected: no visible difference in the business medallions.

- [ ] **Step 7: Commit**

```powershell
git add godot/scripts/ui/sigil_glyphs.gd godot/scripts/ui/identity_medallion.gd godot/scripts/ui/count_medallion.gd
git commit -m "feat(ui): shared SigilGlyphs library + IdentityMedallion control"
```

---

### Task 2: Rival rows — faction crest + full color theming

**Files:**
- Modify: `godot/scenes/rival_row.tscn`
- Modify: `godot/scripts/ui/rival_row.gd`

**Interfaces:**
- Consumes: `IdentityMedallion` (`glyph_key`, `tint`, `dimmed`); rival dict fields `faction_key: String`, `color: Color`, `name`, `status`.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Scene — insert medallion as first child of Top**

In `godot/scenes/rival_row.tscn`: change header to `load_steps=3`, add the ext_resource, and insert the Medal node between the `Top` block and `NameLabel` (tscn node order = child order):

```
[gd_scene load_steps=3 format=3 uid="uid://rivalrow001"]

[ext_resource type="Script" path="res://scripts/ui/rival_row.gd" id="1"]
[ext_resource type="Script" path="res://scripts/ui/identity_medallion.gd" id="2"]
```

and after the `[node name="Top" ...]` block:

```
[node name="Medal" type="Control" parent="Margin/VBox/Top"]
custom_minimum_size = Vector2(44, 44)
layout_mode = 2
script = ExtResource("2")
```

- [ ] **Step 2: Script — feed the medallion, strip the letter, tint name + accent**

In `rival_row.gd` add after the `_badge` onready:

```gdscript
@onready var _medal: IdentityMedallion = $Margin/VBox/Top/Medal
```

Add a field near `rival_index`:

```gdscript
var _accent := Color(0, 0, 0, 0)
```

In `_refresh()`, replace the `_name.text` line (which currently prefixes the symbol letter):

```gdscript
	_name.text = str(r.get("name", "?"))
	var fac_color: Color = r.get("color", GameTheme.GOLD)
	_medal.glyph_key = str(r.get("faction_key", ""))
	_medal.tint = fac_color
	_medal.dimmed = eliminated
	_name.add_theme_color_override(
		"font_color",
		GameTheme.TEXT_MUTED if eliminated else fac_color.lerp(Color.WHITE, 0.35))
	var new_accent := Color(GameTheme.CHIP_BORDER, 0.6) if eliminated else Color(fac_color, 0.9)
	if new_accent != _accent:
		_accent = new_accent
		queue_redraw()
```

Add at the end of the file (rival_row has no `_draw` yet):

```gdscript
func _draw() -> void:
	# Faction accent edge — same left-bar idiom as building rows' card accent.
	if _accent.a > 0.0:
		draw_rect(Rect2(0, 0, 3.0, size.y), _accent)
		draw_rect(Rect2(0, 0, size.x, size.y), Color(_accent, 0.16), false, 1.0)
```

- [ ] **Step 3: Verify**

Run shell_smoke (command from Task 1 Step 5) → PASS. Then capture tab 3 (`medal_after2_rivals.png`, same job shape as Task 1's rivals job) and READ it: crest medallions per faction, no letter prefix in names, name + left edge tinted per faction, all five factions tellable apart, Eliminated (if any) gray.

- [ ] **Step 4: Commit**

```powershell
git add godot/scenes/rival_row.tscn godot/scripts/ui/rival_row.gd
git commit -m "feat(rivals): faction crest medallion + full faction color theming"
```

---

### Task 3: Manager rows — business emblem

**Files:**
- Modify: `godot/scenes/manager_row.tscn`
- Modify: `godot/scripts/ui/manager_row.gd`

**Interfaces:**
- Consumes: `IdentityMedallion`; `SigilGlyphs.BUILDING_KEYS`; `Manager.building_index`, `Manager.hired`; `GameTheme.building_neon(key)`.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Scene — insert medallion as first child of Header**

In `godot/scenes/manager_row.tscn`: `load_steps=3`, add ext_resource id="2" for `res://scripts/ui/identity_medallion.gd` (exact lines as Task 2 Step 1), and insert after the `[node name="Header" ...]` block:

```
[node name="Medal" type="Control" parent="Margin/VBox/Header"]
custom_minimum_size = Vector2(40, 40)
layout_mode = 2
script = ExtResource("2")
```

- [ ] **Step 2: Script — key the emblem off the manager's building**

In `manager_row.gd` add after the `_name` onready:

```gdscript
@onready var _medal: IdentityMedallion = $Margin/VBox/Header/Medal
```

In `setup()` after `_bonus.text = m.bonus_desc`:

```gdscript
	var bkey := ""
	if m.building_index >= 0 and m.building_index < SigilGlyphs.BUILDING_KEYS.size():
		bkey = SigilGlyphs.BUILDING_KEYS[m.building_index]
	_medal.glyph_key = bkey
	_medal.tint = GameTheme.building_neon(bkey)
```

In `_refresh()` (find where hired/locked state is applied; add alongside):

```gdscript
	_medal.dimmed = not GameState.managers[manager_index].hired
```

Guard: if `_refresh` can run with `manager_index < 0`, keep the medallion line inside the existing early-return protection.

- [ ] **Step 3: Verify**

shell_smoke → PASS. Capture tab 7 (`medal_after3_mgrs.png`) and READ: each manager card opens with its business emblem in that business's neon; unhired managers dimmed; the three HQ-tier managers all show the crown.

- [ ] **Step 4: Commit**

```powershell
git add godot/scenes/manager_row.tscn godot/scripts/ui/manager_row.gd
git commit -m "feat(managers): business-emblem medallion keyed to building_index"
```

---

### Task 4: Territory rows — district glyph + holder tag colors

**Files:**
- Modify: `godot/scenes/territory_row.tscn`
- Modify: `godot/scripts/ui/territory_row.gd`

**Interfaces:**
- Consumes: `IdentityMedallion`; territory dict fields `district_type: String`, `color: Color`, `owner: String`.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Scene — insert medallion as first child of Top**

In `godot/scenes/territory_row.tscn`: `load_steps=3`, ext_resource id="2" for `res://scripts/ui/identity_medallion.gd`, and after the `[node name="Top" ...]` block:

```
[node name="Medal" type="Control" parent="Margin/VBox/Top"]
custom_minimum_size = Vector2(36, 36)
layout_mode = 2
script = ExtResource("2")
```

- [ ] **Step 2: Script — feed glyph + holder colors**

In `territory_row.gd` add after the `_name` onready:

```gdscript
@onready var _medal: IdentityMedallion = $Margin/VBox/Top/Medal
```

In `_refresh()` after `_name.text = ...`:

```gdscript
	_medal.glyph_key = str(t.get("district_type", ""))
	_medal.tint = t.get("color", GameTheme.GOLD)
	_medal.dimmed = not bool(t.get("unlocked", false)) and owner == "unclaimed"
```

NOTE: `owner` is read a few lines below in the current code — move the
`var owner := str(t.get("owner", "unclaimed"))` line up so it precedes the medallion
block, and update the holder-tag colors in the same pass:

```gdscript
	if owner == "player":
		_owner.text = "YOU"
		_owner.add_theme_color_override("font_color", GameTheme.GOLD)
	elif owner == "unclaimed":
		_owner.text = "UNCLAIMED"
		_owner.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	else:
		_owner.text = owner.substr(0, 14)
		_owner.add_theme_color_override("font_color", GameTheme.SIREN_RED)
```

(The rival-held branch's hardcoded `Color(0.86, 0.39, 0.31)` becomes `GameTheme.SIREN_RED`; the "Held by %s" status branch further down keeps its own color — change that one to `GameTheme.SIREN_RED` too for consistency.)

- [ ] **Step 3: Verify**

shell_smoke → PASS. Capture tab 2 (`medal_after4_turf.png`) and READ: district cards open with type glyphs (house/awning/factory/portico) tinted per district; YOU tags violet-accent, rival tags siren red, unclaimed muted.

- [ ] **Step 4: Commit**

```powershell
git add godot/scenes/territory_row.tscn godot/scripts/ui/territory_row.gd
git commit -m "feat(turf): district-type medallion + holder tag colors"
```

---

### Task 5: Crew rows — role glyphs replace letters

**Files:**
- Modify: `godot/scenes/crew_row.tscn`
- Modify: `godot/scripts/ui/crew_row.gd`

**Interfaces:**
- Consumes: `IdentityMedallion`; crew `role_key` (`protection`, `collection`, `smuggling`, `territory`, `heat`).
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Scene — replace IconLabel with the medallion**

In `godot/scenes/crew_row.tscn`: `load_steps=3`, ext_resource id="2" for `res://scripts/ui/identity_medallion.gd`, and replace the entire `IconLabel` node block with:

```
[node name="Medal" type="Control" parent="Margin/HBox"]
custom_minimum_size = Vector2(36, 36)
layout_mode = 2
size_flags_vertical = 4
script = ExtResource("2")
```

- [ ] **Step 2: Script — role tints; drop the letter**

In `crew_row.gd` replace the `_icon` onready with:

```gdscript
@onready var _medal: IdentityMedallion = $Margin/HBox/Medal
```

Add the tint map below the preload:

```gdscript
# Per-role identity hues from existing theme tokens (no new palette entries).
const ROLE_TINTS := {
	"protection": GameTheme.JEWEL_TEAL,
	"collection": GameTheme.GREEN,
	"smuggling": GameTheme.JEWEL_MAGENTA,
	"territory": GameTheme.GOLD,
	"heat": GameTheme.SIREN_BLUE,
}
```

In `setup()` replace `_icon.text = icon` with (the `icon` parameter stays in the
signature so `turf_screen.gd`'s call sites don't change, it is just unused):

```gdscript
	_medal.glyph_key = "crew_%s" % key
	_medal.tint = ROLE_TINTS.get(key, GameTheme.GOLD)
```

In `_apply_label_scale()` delete the `_icon` font-size line.

- [ ] **Step 3: Verify**

shell_smoke → PASS. Capture tab 4 (`medal_after5_crew.png`) and READ: five role medallions (shield/coins/crate/flag/droplet) in five distinct hues; no bare letters.

- [ ] **Step 4: Commit**

```powershell
git add godot/scenes/crew_row.tscn godot/scripts/ui/crew_row.gd
git commit -m "feat(crew): role-glyph medallions replace letter avatars"
```

---

### Task 6: Final verification sweep

**Files:**
- Modify (scratch only): `godot/design/shots/medal_spec.json`

- [ ] **Step 1: Full still matrix**

Set `medal_spec.json` to five jobs — tabs 0, 2, 3, 4, 7 — outputs
`medal_final_bldgs.png`, `medal_final_turf.png`, `medal_final_rivals.png`,
`medal_final_crew.png`, `medal_final_mgrs.png` (same job shape as Task 1 Step 1:
cash 5000000, districts 6, prestige_tokens 12, city_tier 3, no_overlays, frames 90,
the two dismiss taps). Run the capture; expect `"ok":true`.

- [ ] **Step 2: READ all five against the spec's acceptance list**

- Crests/tints distinct per faction; no letter prefixes.
- Manager emblems match their business neon (cross-check one against the same
  business's row medallion on the Buildings still).
- District glyphs legible at 36 px; holder tags colored (violet/red/muted).
- Crew roles tellable apart at a glance.
- Buildings tab unchanged vs `medal_before_bldgs.png`.

- [ ] **Step 3: Probes + graph refresh + cleanup**

```powershell
& "E:\Downloads\Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd | Select-String "PASS|FAIL"
python -m graphify update .
Remove-Item -Force godot\design\shots\medal_spec.json, godot\design\shots\medal_before_*.png, godot\design\shots\medal_after*.png -ErrorAction SilentlyContinue
```

Expected: PASS; graph updated. Keep the five `medal_final_*.png` for the owner report. No commit (Task 5 made the last code change).
