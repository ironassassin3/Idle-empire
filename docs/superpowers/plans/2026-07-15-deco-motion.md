# Deco Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the five most-repeated interaction beats (BUY press, purchase payoff, windfall, click, row unlock) premium code-drawn motion in the existing noir/deco palette — richer motion, same skin.

**Architecture:** A `DecoMotion` static vocabulary (timing tokens + press primitive, `GameTheme`/`GameFonts` pattern) plus one pooled immediate-mode `FxLayer` canvas mounted by `game_shell` above the chrome column and below `OverlayHost`. Every transient visual is a slot in a preallocated pool that `_draw` paints — zero child nodes per event. Two effects (sheen, ink-wipe) are drawn state local to the masthead/row, same idiom as the afford underbar.

**Tech Stack:** Godot 4.6.3 GDScript. Headless probes via `SceneTree` scripts (`godot --headless --path godot -s res://scripts/tools/<probe>.gd`), modelled on `city_reaction_probe.gd`.

**Spec:** `docs/superpowers/specs/2026-07-15-deco-motion-design.md` — read it first; its Constraints section is law.

## Global Constraints

- ART_POLICY: code-drawn only; `GameTheme` tokens only (fx_layer.gd is under `shell/` — V3 token lint enforces this).
- Zero allocation per event: pools preallocated in `_ready` (coins 12 / sparks 32 / ripples 4); pool full → skip, never grow; `FxLayer` never gains a child node.
- Headless gates **rendering, not state** (`_process`/`_draw` only) — a headless probe must be able to prove the pools. Reduced-motion (`not GameState.show_particles`) gates the **API** (garnish dropped, information stays).
- ADR-001 untouched: no changes to `_tick_balance` number logic; coins arc ledger→medallion (a purchase is a spend), never into the ledger.
- No save-schema changes, no new settings, no new audio, no balance changes.
- `DecoMotion` reads `GameState.show_particles` directly, NOT `GameTheme.ui_reduced_motion()` — `GameTheme → DecoMotion → GameTheme` must never form a class_name cycle.
- Godot binary: `E:/Downloads/Godot_v4.6.3-stable_win64.exe` (or `$env:GODOT_BIN`).

---

### Task 1: The failing probe — deco fx cannot exist yet

**Files:**
- Create: `godot/scripts/tools/deco_fx_probe.gd`

**Interfaces:**
- Consumes: `SoakAutoloads.install`, `game_shell.tscn`, `UiEvents.building_purchased`, `StageLayer.handle_tap(pos)`.
- Produces (asserted, built in Tasks 2–4): `DecoMotion.attach_press(btn)`; `FxLayer` node (group `"fx_layer"`, child of shell) with `coin_arc(from, to, n)`, `sparks(origin, n, hot)`, `ripple(at)`, `ledger_point() -> Vector2`, `live_counts() -> Dictionary {coins, sparks, ripples}`.

- [ ] **Step 1: Write the probe**

Create `godot/scripts/tools/deco_fx_probe.gd`. Note both new scripts are loaded **by path at runtime**, never by class_name at the probe's top level — a compile-time reference to a not-yet-existing class (or one whose dependencies need installed autoloads) kills the probe with a compile error instead of a clean FAIL (the Task-7 lesson from the reactive-city plan).

```gdscript
extends SceneTree
## Headless probe: the deco moment-to-moment layer — press primitive, pooled
## FxLayer (zero nodes, capped, reduced-motion no-op), purchase->coin and
## tap->spark wiring. Usage:
##   godot --headless --path godot -s res://scripts/tools/deco_fx_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _fx: Node
var _stage: Node
var _DM: GDScript = null
var _frames := 0


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	root.add_child(load("res://scenes/game_shell.tscn").instantiate())


func _fail(msg: String) -> bool:
	printerr("[deco_probe] FAIL: " + msg)
	quit(1)
	return true


func _counts() -> Dictionary:
	return _fx.call("live_counts")


func _process(_delta: float) -> bool:
	_frames += 1
	if _stage == null:
		_stage = root.find_child("StageLayer", true, false)
	if _fx == null:
		_fx = root.find_child("FxLayer", true, false)
	var gs: Node = root.get_node("GameState")

	if _frames == 10:
		if _stage == null:
			return _fail("StageLayer not found")
		_DM = load("res://scripts/ui/deco_motion.gd")
		if _DM == null:
			return _fail("deco_motion.gd does not exist — the vocabulary is missing")
		gs.show_particles = true  # reduced-motion OFF for the active-path stages

	elif _frames == 14:
		# Press primitive, unit level: button_down must visibly sink the button.
		var btn := Button.new()
		btn.size = Vector2(100, 50)
		root.add_child(btn)
		_DM.attach_press(btn)
		btn.button_down.emit()
		var sunk: bool = btn.scale.x < 1.0
		btn.button_up.emit()
		btn.queue_free()
		if not sunk:
			return _fail("attach_press: button_down did not depress the button")

	elif _frames == 18:
		if _fx == null:
			return _fail("FxLayer not found in shell")
		for m in ["coin_arc", "sparks", "ripple", "ledger_point", "live_counts"]:
			if not _fx.has_method(m):
				return _fail("FxLayer missing method: " + m)
		if _fx.get_child_count() != 0:
			return _fail("FxLayer has child nodes at rest — must be a pure canvas")

	elif _frames == 22:
		# Purchase -> coin arc, end to end through the row's handler.
		gs.balance = 1000.0
		root.get_node("UiEvents").building_purchased.emit(str(gs.buildings[0].icon_key))

	elif _frames == 24:
		if int(_counts()["coins"]) <= 0:
			return _fail("purchase did not arc coins (row handler -> FxLayer broken)")
		if _fx.get_child_count() != 0:
			return _fail("coin arc allocated a node — must be pooled drawn state")

	elif _frames == 28:
		# Click -> spark trail, end to end through the stage tap path.
		_stage.call("handle_tap", Vector2(240, 500))
		if int(_counts()["sparks"]) <= 0:
			return _fail("stage tap did not spawn sparks")

	elif _frames == 32:
		# Pool caps are the burst governor: flood every pool, nothing may grow.
		_fx.call("sparks", Vector2(100, 100), 100, true)
		for i in 8:
			_fx.call("ripple", Vector2(50.0 + i, 50.0))
		_fx.call("coin_arc", Vector2.ZERO, Vector2(300, 300), 50)
		var c: Dictionary = _counts()
		if int(c["coins"]) > 12 or int(c["sparks"]) > 32 or int(c["ripples"]) > 4:
			return _fail("pool cap exceeded: %s" % str(c))

	elif _frames == 36:
		# Reduced-motion: the API must no-op (state unchanged).
		gs.show_particles = false
		var before: Dictionary = _counts()
		_fx.call("sparks", Vector2(10, 10), 5, false)
		_fx.call("ripple", Vector2(10, 10))
		_fx.call("coin_arc", Vector2.ZERO, Vector2(10, 10), 3)
		var after: Dictionary = _counts()
		gs.show_particles = true
		if str(before) != str(after):
			return _fail("reduced-motion did not no-op the FxLayer API")
		if _fx.get_child_count() != 0:
			return _fail("FxLayer grew a child node — zero-alloc rule broken")
		print("[deco_probe] PASS — press sinks, pools capped, zero nodes, reduced-motion honored")
		quit(0)
		return true

	elif _frames >= 120:
		return _fail("timed out")
	return false
```

- [ ] **Step 2: Run it — watch it fail for the right reason**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/deco_fx_probe.gd
```

Expected: `FAIL: deco_motion.gd does not exist — the vocabulary is missing`, exit 1.

- [ ] **Step 3: Commit the failing probe**

```bash
git add godot/scripts/tools/deco_fx_probe.gd
git commit -m "test(fx): probe proves the deco moment-to-moment layer doesn't exist"
```

---

### Task 2: DecoMotion — the vocabulary + the press feel

**Files:**
- Create: `godot/scripts/ui/deco_motion.gd`
- Modify: `godot/scripts/ui/game_theme.gd` (`apply_row_buy_button` at `:1145`)

**Interfaces:**
- Consumes: `GameState.show_particles` (autoload — safe, no class_name cycle).
- Produces: `DecoMotion` class_name — `T_FAST/T_MED/T_ARC/EASE/TRANS` tokens and `attach_press(btn: BaseButton)`. Task 4's coin timing and Task 5/6 durations reference these tokens.

- [ ] **Step 1: Write `deco_motion.gd`**

```gdscript
class_name DecoMotion
extends RefCounted
## Deco motion vocabulary — timing tokens + tween primitives shared by every
## moment-to-moment effect, so motion composes instead of scattering ad-hoc
## tweens. Spec: docs/superpowers/specs/2026-07-15-deco-motion-design.md.
## Reads GameState.show_particles directly (NOT GameTheme.ui_reduced_motion):
## GameTheme calls attach_press, so GameTheme -> DecoMotion -> GameTheme would
## be a class_name cycle.

const T_FAST := 0.12  # press, flash — sub-perception "snap"
const T_MED := 0.25   # state wipes, sheens
const T_ARC := 0.45   # travel (coin arc)
const EASE := Tween.EASE_OUT
const TRANS := Tween.TRANS_CUBIC


static func _reduced() -> bool:
	return not GameState.show_particles


## Depress on button_down (scale 0.96), release ease-out on button_up.
## `pressed` fires on RELEASE — hooking it would mean the button never
## visibly sinks. Pivot must be centered or container buttons scale lopsided.
## Idempotent: apply_row_buy_button runs on every row rebuild.
static func attach_press(btn: BaseButton) -> void:
	if btn == null or btn.has_meta("deco_press"):
		return
	btn.set_meta("deco_press", true)
	btn.pivot_offset = btn.size * 0.5
	btn.resized.connect(DecoMotion._press_pivot.bind(btn))
	btn.button_down.connect(DecoMotion._press_down.bind(btn))
	btn.button_up.connect(DecoMotion._press_up.bind(btn))


static func _press_pivot(btn: BaseButton) -> void:
	btn.pivot_offset = btn.size * 0.5


static func _press_down(btn: BaseButton) -> void:
	if _reduced():
		return
	btn.scale = Vector2(0.96, 0.96)


static func _press_up(btn: BaseButton) -> void:
	if btn.scale.is_equal_approx(Vector2.ONE):
		return
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2.ONE, T_FAST).set_ease(EASE).set_trans(TRANS)
```

- [ ] **Step 2: Wire it into every buy button in one line**

In `game_theme.gd`, `apply_row_buy_button` (`:1145`) — append as the final statement, so buildings/upgrades/managers rows all inherit the press feel with zero row-script changes:

```gdscript
static func apply_row_buy_button(btn: Button) -> void:
	if btn == null:
		return
	btn.add_theme_font_size_override("font_size", scaled_font(12))
	# Gilded: affordable = chunky gold bevel with dark text (inverted CTA);
	# disabled = flat dark with a faint gold keyline so lists never go dead.
	btn.add_theme_stylebox_override("normal", make_game_button_flat(GOLD))
	btn.add_theme_stylebox_override("hover", make_game_button_flat(GOLD_BRIGHT))
	btn.add_theme_stylebox_override("pressed", make_game_button_flat(GOLD, true))
	btn.add_theme_stylebox_override("disabled", make_game_button_disabled_flat())
	btn.add_theme_color_override("font_color", GOLD_TEXT_DARK)
	btn.add_theme_color_override("font_hover_color", GOLD_TEXT_DARK)
	btn.add_theme_color_override("font_pressed_color", GOLD_TEXT_DARK)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	DecoMotion.attach_press(btn)
```

- [ ] **Step 3: Run the probe — further along**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/deco_fx_probe.gd
```

Expected: passes frames 10–14 (press sinks), then `FAIL: FxLayer not found in shell`, exit 1.

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/ui/deco_motion.gd godot/scripts/ui/game_theme.gd
git commit -m "feat(fx): DecoMotion vocabulary — every buy button gains the press feel"
```

---

### Task 3: FxLayer — one pooled canvas for all transient garnish

**Files:**
- Create: `godot/scripts/ui/shell/fx_layer.gd`
- Modify: `godot/scripts/ui/shell/game_shell.gd` (mount after `add_child(_director)` at `:132`)
- Modify: `godot/scripts/ui/shell/hud_masthead.gd` (`_balance` joins group `"ledger_balance"`, built near `:75-84`)

**Interfaces:**
- Consumes: `GameTheme.GOLD`, `GameTheme.GOLD_BRIGHT`; `GameState.show_particles`.
- Produces: `FxLayer` node named `"FxLayer"` in group `"fx_layer"` with `coin_arc(from: Vector2, to: Vector2, n: int)`, `sparks(origin: Vector2, n: int, hot: bool)`, `ripple(at: Vector2)`, `ledger_point() -> Vector2`, `live_counts() -> Dictionary` (`{coins: int, sparks: int, ripples: int}`). Tasks 4–6 call these via `get_tree().get_first_node_in_group("fx_layer")` with null-guards.

- [ ] **Step 1: Write `fx_layer.gd`**

```gdscript
extends Control
## FxLayer — one pooled immediate-mode canvas for transient deco garnish
## (coin arcs, click sparks, press ripples). Zero child nodes EVER: every
## effect is a slot in a preallocated pool that _draw paints.
## State updates are never headless-gated (a headless probe must be able to
## prove the pools — the Stage A lesson); only _process/_draw rendering is.
## Reduced-motion gates the API: garnish is dropped, information stays.
## Spec: docs/superpowers/specs/2026-07-15-deco-motion-design.md.

const COIN_MAX := 12
const SPARK_MAX := 32
const RIPPLE_MAX := 4
const COIN_LIFE := 0.45  # = DecoMotion.T_ARC
const SPARK_LIFE := 0.35
const RIPPLE_LIFE := 0.3

var _coins: Array = []
var _sparks: Array = []
var _ripples: Array = []


func _ready() -> void:
	name = "FxLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("fx_layer")
	for i in COIN_MAX:
		_coins.append({"live": false, "t": 0.0, "from": Vector2.ZERO,
				"to": Vector2.ZERO, "ctrl": Vector2.ZERO, "spin": 0.0})
	for i in SPARK_MAX:
		_sparks.append({"live": false, "t": 0.0, "pos": Vector2.ZERO,
				"vel": Vector2.ZERO, "hot": false})
	for i in RIPPLE_MAX:
		_ripples.append({"live": false, "t": 0.0, "at": Vector2.ZERO})
	set_process(false)  # idle cost is zero; _wake() arms it


func _reduced() -> bool:
	return not GameState.show_particles


func _first_dead(pool: Array) -> int:
	for i in pool.size():
		if not bool(pool[i]["live"]):
			return i
	return -1


func _wake() -> void:
	set_process(true)


## Coins arc from -> to along a quadratic bezier. Pool full -> skip: the
## 12-coin pool IS the burst governor for manager purchase-order storms.
func coin_arc(from: Vector2, to: Vector2, n: int) -> void:
	if _reduced():
		return
	for i in n:
		var idx := _first_dead(_coins)
		if idx < 0:
			return
		var e: Dictionary = _coins[idx]
		e["live"] = true
		e["t"] = -0.08 * i  # slight stagger so a x10 buy reads as a stream
		e["from"] = from
		e["to"] = to
		e["ctrl"] = (from + to) * 0.5 + Vector2(randf_range(-36.0, 36.0), -72.0)
		e["spin"] = randf() * TAU
	_wake()


func sparks(origin: Vector2, n: int, hot: bool) -> void:
	if _reduced():
		return
	for i in n:
		var idx := _first_dead(_sparks)
		if idx < 0:
			return
		var e: Dictionary = _sparks[idx]
		e["live"] = true
		e["t"] = 0.0
		e["pos"] = origin
		var speed := randf_range(90.0, 190.0) * (1.4 if hot else 1.0)
		e["vel"] = Vector2.from_angle(randf_range(-PI * 0.8, -PI * 0.2)) * speed
		e["hot"] = hot
	_wake()


func ripple(at: Vector2) -> void:
	if _reduced():
		return
	var idx := _first_dead(_ripples)
	if idx < 0:
		return
	var e: Dictionary = _ripples[idx]
	e["live"] = true
	e["t"] = 0.0
	e["at"] = at
	_wake()


## Where coins launch from: the masthead balance center, looked up lazily so
## layout/resize can never stale a cached point. Once per buy action — cheap.
func ledger_point() -> Vector2:
	var lbl: Control = get_tree().get_first_node_in_group("ledger_balance")
	if lbl == null:
		return Vector2(get_viewport_rect().size.x * 0.5, 90.0)
	return lbl.get_global_rect().get_center()


func live_counts() -> Dictionary:
	var c := 0
	var s := 0
	var r := 0
	for e in _coins:
		if e["live"]:
			c += 1
	for e in _sparks:
		if e["live"]:
			s += 1
	for e in _ripples:
		if e["live"]:
			r += 1
	return {"coins": c, "sparks": s, "ripples": r}


func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var any := false
	for e in _coins:
		if e["live"]:
			e["t"] = float(e["t"]) + delta / COIN_LIFE
			if float(e["t"]) >= 1.0:
				e["live"] = false
			else:
				any = true
	for e in _sparks:
		if e["live"]:
			e["t"] = float(e["t"]) + delta / SPARK_LIFE
			e["pos"] = Vector2(e["pos"]) + Vector2(e["vel"]) * delta
			e["vel"] = Vector2(e["vel"]) * 0.92  # drag
			if float(e["t"]) >= 1.0:
				e["live"] = false
			else:
				any = true
	for e in _ripples:
		if e["live"]:
			e["t"] = float(e["t"]) + delta / RIPPLE_LIFE
			if float(e["t"]) >= 1.0:
				e["live"] = false
			else:
				any = true
	queue_redraw()
	if not any:
		set_process(false)


func _draw() -> void:
	for e in _coins:
		if not bool(e["live"]) or float(e["t"]) < 0.0:
			continue
		var t := clampf(float(e["t"]), 0.0, 1.0)
		var from: Vector2 = e["from"]
		var to: Vector2 = e["to"]
		var ctrl: Vector2 = e["ctrl"]
		var p := from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t)
		var a := 1.0 - smoothstep(0.75, 1.0, t)
		draw_circle(p, 5.0, Color(GameTheme.GOLD_BRIGHT, 0.95 * a))
		draw_arc(p, 5.0, 0.0, TAU, 20, Color(GameTheme.GOLD, a), 1.2)
		# Spinning glint line — the "coin" read without sprite art.
		var g := Vector2.from_angle(float(e["spin"]) + t * 9.0) * 3.0
		draw_line(p - g, p + g, Color(1.0, 0.97, 0.85, 0.6 * a), 1.0)
	for e in _sparks:
		if not bool(e["live"]):
			continue
		var t := float(e["t"])
		var pos: Vector2 = e["pos"]
		var tail: Vector2 = pos - Vector2(e["vel"]) * 0.06
		var col: Color = GameTheme.GOLD_BRIGHT if bool(e["hot"]) else GameTheme.GOLD
		draw_line(pos, tail, Color(col, (1.0 - t) * 0.8), 1.5)
	for e in _ripples:
		if not bool(e["live"]):
			continue
		var t := float(e["t"])
		draw_arc(Vector2(e["at"]), 6.0 + t * 32.0, 0.0, TAU, 32,
				Color(GameTheme.GOLD_BRIGHT, (1.0 - t) * 0.5), 1.5)
```

- [ ] **Step 2: Mount it in the shell — above the chrome column, below OverlayHost**

In `game_shell.gd`: add the preload next to the other shell script preloads (`:6-12`):

```gdscript
const FxLayerScript = preload("res://scripts/ui/shell/fx_layer.gd")
```

and immediately after `add_child(_director)` (`:132`) insert:

```gdscript
	# Transient deco garnish (coin arcs, sparks, ripples). Sits above the
	# chrome column so coins can travel deck -> masthead, and BEFORE the
	# notification/tutorial/overlay children so garnish never draws over a
	# modal scrim (spec: below OverlayHost).
	add_child(FxLayerScript.new())
```

(Child order is z-order: notifications `:155`, tutorial `:175`, and `OverlayHost` `:209` are added later, so they draw above it.)

- [ ] **Step 3: Register the ledger point**

In `hud_masthead.gd`, where `_balance` is built (after `_balance.resized.connect(...)` at `:83`), add:

```gdscript
	_balance.add_to_group("ledger_balance")  # FxLayer.ledger_point() launch pad
```

- [ ] **Step 4: Run the probe — further along**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/deco_fx_probe.gd
```

Expected: passes frames 10–18 (FxLayer found, methods present, zero children), then `FAIL: purchase did not arc coins (row handler -> FxLayer broken)`, exit 1.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/ui/shell/fx_layer.gd godot/scripts/ui/shell/game_shell.gd godot/scripts/ui/shell/hud_masthead.gd
git commit -m "feat(fx): FxLayer — one pooled canvas for coins, sparks, ripples"
```

---

### Task 4: Wire the beats — press ripple, coin arc, spark trail

**Files:**
- Modify: `godot/scripts/ui/building_row.gd` (`_on_any_purchase` at `:56`, `_on_buy_primary` at `:153`)
- Modify: `godot/scripts/ui/shell/stage_layer.gd` (`_spawn_click_float` at `:153`)

**Interfaces:**
- Consumes: `FxLayer.coin_arc/sparks/ripple/ledger_point` (Task 3), group `"fx_layer"`; `GameState.buy_mult_mode` (0=×1, 1=×10, 2=Max).
- Produces: nothing new — this task closes the probe.

- [ ] **Step 1: Coin arc — ledger → medallion, with the offscreen guard**

Replace `building_row.gd` `_on_any_purchase` (`:55-63`) with:

```gdscript
## Same beat as the city facade: this row's medallion acknowledges the purchase.
## NEW: the spend arcs as coins from the ledger down INTO this business —
## direction matters, a purchase is a spend (the masthead dips; ADR-001).
## The medallion flare below is the coins' landing beat.
func _on_any_purchase(key: String) -> void:
	if _building == null or str(_building.icon_key) != key:
		return
	# Arc only when this row is actually on screen: manager purchase orders
	# fire while the row may be scrolled away or on a hidden tab. State-only
	# under headless (probe-able); FxLayer gates reduced-motion itself.
	if is_visible_in_tree() and get_global_rect().intersects(get_viewport_rect()):
		var fx: Node = get_tree().get_first_node_in_group("fx_layer")
		if fx != null:
			var n: int = clampi(GameState.buy_mult_mode + 1, 1, 3)  # x1/x10/Max -> 1/2/3 coins
			fx.call("coin_arc", fx.call("ledger_point"),
					_medal.get_global_rect().get_center(), n)
	if DisplayServer.get_name() == "headless" or GameTheme.ui_reduced_motion():
		return
	var tw := create_tween()
	tw.tween_property(_medal, "modulate", GameTheme.GOLD_BRIGHT, 0.12)
	tw.tween_property(_medal, "modulate", Color.WHITE, 0.45).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 2: Press ripple from the BUY button center**

Replace `_on_buy_primary` (`:153-156`) with (`pressed` carries no pointer position — the button's rect center is deterministic and touch-agnostic):

```gdscript
func _on_buy_primary() -> void:
	var fx: Node = get_tree().get_first_node_in_group("fx_layer")
	if fx != null:
		fx.call("ripple", _buy1.get_global_rect().get_center())
	var qty := GameState.effective_buy_qty(building_index)
	if qty > 0:
		buy_pressed.emit(building_index, qty)
```

- [ ] **Step 3: Spark trail on the click float**

In `stage_layer.gd` `_spawn_click_float` (`:153`), insert the sparks call **above** the existing headless return — FxLayer state must be settable headless (probe), and it gates reduced-motion itself:

```gdscript
func _spawn_click_float(amount: float, crit: bool, origin: Vector2) -> void:
	var fx: Node = get_tree().get_first_node_in_group("fx_layer")
	if fx != null:
		fx.call("sparks", origin, 6 if crit else 3, crit)
	if DisplayServer.get_name() == "headless":
		return
```

(The rest of the function is unchanged.)

- [ ] **Step 4: Run the probe — it must now PASS**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/deco_fx_probe.gd
```

Expected: `PASS — press sinks, pools capped, zero nodes, reduced-motion honored`, exit 0.

- [ ] **Step 5: Shell smoke — no regression**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/shell_smoke.gd
```

Expected: `PASS — 200 frames, no crash`.

- [ ] **Step 6: Look at it**

```bash
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 720x1280 -Cash 50000
```

A still can't show travel — this checks nothing broke visually. The arc itself is judged in the running game (F5: buy a building, coins fall from the balance into the row's medallion and the medallion flares as they land).

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/ui/building_row.gd godot/scripts/ui/shell/stage_layer.gd
git commit -m "feat(fx): the spend lands in the business — coins arc ledger to medallion

Press ripple on BUY, spark trail on clicks, and 1-3 coins (x1/x10/Max) that
arc from the balance down into the bought row's medallion, whose existing
flare becomes the landing beat. Direction is deliberate: a purchase is a
spend (the ledger dips, ADR-001) — coins INTO the ledger are reserved for
the income slice. Offscreen rows never arc (manager purchase-order storms)."
```

---

### Task 5: Windfall sheen — the ledger glints when money lands

**Files:**
- Create: `godot/scripts/tools/deco_sheen_probe.gd`
- Modify: `godot/scripts/ui/shell/hud_masthead.gd` (fields near `:26-34`; `_balance` build at `:75-84`; `_process` at `:138`; `_tick_balance` windfall branch at `:159-163`)

**Interfaces:**
- Consumes: existing windfall detector (`jump > expected * 4.0 + 1.0`); `DecoMotion.T_ARC` for the sweep duration.
- Produces: `HudMasthead.is_sheen_active() -> bool` (probe query).

- [ ] **Step 1: Write the failing probe**

Create `godot/scripts/tools/deco_sheen_probe.gd`:

```gdscript
extends SceneTree
## Headless probe: a windfall (not passive accrual) sweeps a sheen across the
## balance; passive income alone must NOT trigger it. Usage:
##   godot --headless --path godot -s res://scripts/tools/deco_sheen_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _mast: Node
var _frames := 0


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	root.add_child(load("res://scenes/game_shell.tscn").instantiate())


func _fail(msg: String) -> bool:
	printerr("[sheen_probe] FAIL: " + msg)
	quit(1)
	return true


func _process(_delta: float) -> bool:
	_frames += 1
	if _mast == null:
		_mast = root.find_child("Masthead", true, false)
	if _mast == null:
		if _frames >= 10:
			return _fail("Masthead not found")
		return false
	var gs: Node = root.get_node("GameState")

	if _frames == 10:
		if not _mast.has_method("is_sheen_active"):
			return _fail("Masthead has no is_sheen_active() — sheen not implemented")
		gs.show_particles = true
		gs.balance = 50.0  # seed truth so the windfall detector arms (_last_truth > 0)

	elif _frames == 25:
		if bool(_mast.call("is_sheen_active")):
			return _fail("sheen active without a windfall — it would run forever")
		gs.balance = 9000.0  # discrete jump >> 4x expected accrual -> windfall

	elif _frames == 28:
		if not bool(_mast.call("is_sheen_active")):
			return _fail("windfall did not start the sheen")
		print("[sheen_probe] PASS — sheen fires on windfall only")
		quit(0)
		return true

	elif _frames >= 120:
		return _fail("timed out")
	return false
```

- [ ] **Step 2: Run it — watch it fail**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/deco_sheen_probe.gd
```

Expected: `FAIL: Masthead has no is_sheen_active() — sheen not implemented`, exit 1.

- [ ] **Step 3: Implement the sheen in `hud_masthead.gd`**

Add fields next to `_pop_tween` (`:34`):

```gdscript
## Windfall sheen: normalized sweep progress, -1 = idle. Keyed to the SAME
## windfall detector as _pulse_gain — NEVER to "_shown < truth", which is true
## every frame under passive income and would run the sweep permanently.
var _sheen_t := -1.0
var _sheen: Control
const _SHEEN_TIME := 0.45  # = DecoMotion.T_ARC
```

Where `_balance` is built (after the `add_to_group("ledger_balance")` line from Task 3), add the one preallocated overlay (allowed by spec — preallocated once, not per-event):

```gdscript
	_sheen = Control.new()
	_sheen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheen.draw.connect(_draw_sheen)
	_balance.add_child(_sheen)
```

In `_tick_balance`, extend the windfall branch (`:162-163`) — currently:

```gdscript
	if _synced and jump > expected * 4.0 + 1.0 and _last_truth > 0.0:
		_pulse_gain()
```

becomes (reduced-motion gates the garnish; headless does not — the probe proves the state):

```gdscript
	if _synced and jump > expected * 4.0 + 1.0 and _last_truth > 0.0:
		_pulse_gain()
		if not GameTheme.ui_reduced_motion():
			_sheen_t = 0.0
```

In `_process` (`:138`), add the decay after `_tick_income_breath(delta)`:

```gdscript
	if _sheen_t >= 0.0:
		_sheen_t += delta / _SHEEN_TIME
		_sheen.queue_redraw()
		if _sheen_t >= 1.0:
			_sheen_t = -1.0
```

Add the draw handler and probe query at the end of the file:

```gdscript
func is_sheen_active() -> bool:
	return _sheen_t >= 0.0


## Gold parallelogram band sweeping left -> right across the digits — the
## deco glint of money landing. Drawn on the overlay child, clipped by alpha
## falloff at the edges of the sweep window.
func _draw_sheen() -> void:
	if _sheen_t < 0.0:
		return
	var w := _sheen.size.x
	var h := _sheen.size.y
	var band := w * 0.18
	var x := lerpf(-band, w + band, _sheen_t)
	var skew := h * 0.35
	var a := 0.16 * sin(PI * clampf(_sheen_t, 0.0, 1.0))
	var col := GameTheme.GOLD_BRIGHT
	_sheen.draw_colored_polygon(PackedVector2Array([
		Vector2(x + skew, 0.0), Vector2(x + band + skew, 0.0),
		Vector2(x + band, h), Vector2(x, h),
	]), Color(col.r, col.g, col.b, a))
```

- [ ] **Step 4: Run the probe — it must PASS**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/deco_sheen_probe.gd
```

Expected: `PASS — sheen fires on windfall only`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/tools/deco_sheen_probe.gd godot/scripts/ui/shell/hud_masthead.gd
git commit -m "feat(fx): the ledger glints when money lands — windfall sheen

Keyed to the existing windfall detector (jump > 4x expected accrual), NOT to
the ticker catching up — passive income keeps _shown chasing truth every
frame, and that trigger would run the sweep permanently."
```

---

### Task 6: Row unlock ink-wipe — affordability arrives, it doesn't pop

**Files:**
- Create: `godot/scripts/tools/deco_wipe_probe.gd`
- Modify: `godot/scripts/ui/building_row.gd` (fields near `:86`; `_ready` at `:33`; `_refresh` end at `:131-150`; `_draw` at `:89`; new `_process`)

**Interfaces:**
- Consumes: existing `can_primary` computation in `_refresh`; `GameTheme.GOLD/GOLD_BRIGHT`.
- Produces: `BuildingRow.is_unlock_wiping() -> bool` (probe query).

- [ ] **Step 1: Write the failing probe**

Create `godot/scripts/tools/deco_wipe_probe.gd`:

```gdscript
extends SceneTree
## Headless probe: a row crossing to affordable ink-wipes; a row that is
## MERELY INSTANTIATED affordable does not (tab rebuilds must not wipe).
## Usage: godot --headless --path godot -s res://scripts/tools/deco_wipe_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _row: Node
var _frames := 0


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	root.add_child(load("res://scenes/game_shell.tscn").instantiate())


func _fail(msg: String) -> bool:
	printerr("[wipe_probe] FAIL: " + msg)
	quit(1)
	return true


func _process(_delta: float) -> bool:
	_frames += 1
	if _row == null:
		_row = root.find_child("BuildingRow*", true, false)
	if _row == null:
		if _frames >= 10:
			return _fail("no BuildingRow found in shell (tab 0)")
		return false
	var gs: Node = root.get_node("GameState")

	if _frames == 10:
		if not _row.has_method("is_unlock_wiping"):
			return _fail("row has no is_unlock_wiping() — wipe not implemented")
		gs.show_particles = true
		gs.balance = 0.0
		gs.emit_signal("stats_changed")  # row refreshes: firmly unaffordable

	elif _frames == 20:
		if bool(_row.call("is_unlock_wiping")):
			return _fail("row wipes while unaffordable / on instantiation")
		gs.balance = 100000.0
		gs.emit_signal("stats_changed")  # false -> true transition

	elif _frames == 22:
		if not bool(_row.call("is_unlock_wiping")):
			return _fail("affordability transition did not start the ink-wipe")
		print("[wipe_probe] PASS — wipe on transition only, not on instantiation")
		quit(0)
		return true

	elif _frames >= 120:
		return _fail("timed out")
	return false
```

- [ ] **Step 2: Run it — watch it fail**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/deco_wipe_probe.gd
```

Expected: `FAIL: row has no is_unlock_wiping() — wipe not implemented`, exit 1.

- [ ] **Step 3: Implement the wipe in `building_row.gd`**

Add fields next to `_afford` (`:86`):

```gdscript
## Unlock ink-wipe: normalized progress, -1 = idle. Starts ONLY on a genuine
## false->true affordability transition during play — never on row
## instantiation (rows are rebuilt on every tab entry).
var _wipe := -1.0
var _prev_ready := false
var _ready_init := false
const _WIPE_TIME := 0.35
```

In `_ready` (`:33`), first line:

```gdscript
	set_process(false)  # armed only while a wipe runs
```

Add the process/query functions after `_draw`:

```gdscript
func _process(delta: float) -> void:
	if _wipe < 0.0:
		set_process(false)
		return
	_wipe = minf(_wipe + delta / _WIPE_TIME, 1.0)
	queue_redraw()
	if _wipe >= 1.0:
		_wipe = -1.0


func is_unlock_wiping() -> bool:
	return _wipe >= 0.0
```

In `_refresh`, after the `can_primary` computation (`var can_primary := GameState.can_buy_building(building_index, qty)` at `:131`), insert the transition tracker:

```gdscript
	if not _ready_init:
		_ready_init = true
		_prev_ready = can_primary
	elif can_primary and not _prev_ready:
		_prev_ready = true
		if not GameTheme.ui_reduced_motion():
			_wipe = 0.0
			set_process(true)
	elif not can_primary:
		_prev_ready = false
```

In `_draw` (`:89-93`), append after the underbar block:

```gdscript
	if _wipe >= 0.0 and _wipe < 1.0:
		# Left -> right gold ink-wipe: faint fill behind a bright leading edge,
		# both fading as the wipe completes (same drawn-state idiom as the
		# afford underbar above).
		var lead_x := size.x * _wipe
		draw_rect(Rect2(0.0, 0.0, lead_x, size.y),
				Color(GameTheme.GOLD.r, GameTheme.GOLD.g, GameTheme.GOLD.b, 0.08 * (1.0 - _wipe)))
		draw_rect(Rect2(lead_x - 6.0, 0.0, 6.0, size.y),
				Color(GameTheme.GOLD_BRIGHT.r, GameTheme.GOLD_BRIGHT.g, GameTheme.GOLD_BRIGHT.b,
						0.35 * (1.0 - _wipe * 0.5)))
```

- [ ] **Step 4: Run the probe — it must PASS**

```bash
"E:/Downloads/Godot_v4.6.3-stable_win64.exe" --headless --path godot -s res://scripts/tools/deco_wipe_probe.gd
```

Expected: `PASS — wipe on transition only, not on instantiation`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/tools/deco_wipe_probe.gd godot/scripts/ui/building_row.gd
git commit -m "feat(fx): affordability arrives as an ink-wipe, not a pop

LOCKED/APPROACHING -> READY sweeps a gold wipe across the row instead of an
instant recolor. Transition-only: previous state initializes from the current
state on first refresh, so tab rebuilds never wipe."
```

---

### Task 7: Regression, look, device checklist

**Files:**
- Modify: `DEVICE_TEST_CHECKLIST.md` ("Living city" section)

- [ ] **Step 1: Full probe + validator sweep**

```bash
GB="E:/Downloads/Godot_v4.6.3-stable_win64.exe"
for p in deco_fx_probe deco_sheen_probe deco_wipe_probe city_reaction_probe city_share_probe city_alert_probe city_district_probe shell_smoke; do
  echo "=== $p ==="
  "$GB" --headless --path godot -s res://scripts/tools/$p.gd 2>&1 | grep -iE "PASS|FAIL" | head -3
done
powershell -File ui_validators.ps1
```

Expected: all eight PASS; `validators: ALL PASS` (V3 token lint covers `fx_layer.gd` automatically).

- [ ] **Step 2: Look — seeded capture + live judgment**

```bash
powershell -File ui_capture.ps1 -Shell -Tab 0 -Size 720x1280 -Cash 50000
```

Then run the game (F5 in Godot, or launch the exe): buy a building and confirm — button sinks on press, gold ring ripples, 1–3 coins fall from the balance into the row's medallion, medallion flares as they land, the balance sweeps a glint on a coin-collect windfall, and a row crossing to affordable wipes gold left→right. If any beat reads cartoony or mistimed, tune the constant (pool sizes, lifetimes, alphas are all named constants) — do not add intensity.

- [ ] **Step 3: Device checklist lines**

In `DEVICE_TEST_CHECKLIST.md`, append to the "Living city" section's checklist (before its **Fail:** line):

```markdown
- [ ] BUY press → button visibly sinks and springs back; a gold ring ripples from the button
- [ ] Purchase → 1–3 coins fall from the balance INTO the bought row's medallion (never into the ledger — a purchase is a spend)
- [ ] 20cps click storm → spark trails stay bounded, FPS stays green ≥30
```

- [ ] **Step 4: Commit**

```bash
git add DEVICE_TEST_CHECKLIST.md
git commit -m "docs(device): deco-motion beats join the living-city device pass"
```
