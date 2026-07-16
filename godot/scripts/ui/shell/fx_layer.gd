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
