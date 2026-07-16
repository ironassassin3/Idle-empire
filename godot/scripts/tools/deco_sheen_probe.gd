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
