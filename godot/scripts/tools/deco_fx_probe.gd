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
