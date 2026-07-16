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
