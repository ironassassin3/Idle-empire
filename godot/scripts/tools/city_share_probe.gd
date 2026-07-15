extends SceneTree
## Headless probe: a business's share of income/sec reaches the city, so the
## skyline can breathe hardest on the real earner. Usage:
##   godot --headless --path godot -s res://scripts/tools/city_share_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _city: Node
var _frames := 0


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	var packed: PackedScene = load("res://scenes/game_shell.tscn")
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _city == null:
		_city = root.find_child("CityView", true, false)
	if _city == null:
		if _frames >= 10:
			printerr("[share_probe] FAIL: CityView not found")
			quit(1)
			return true
		return false

	if _frames == 20:
		var gs: Node = root.get_node("GameState")
		gs.balance = 1_000_000.0
		gs.buy_building(0, 5)
		gs.emit_signal("stats_changed")

	elif _frames == 45:
		if not _city.has_method("income_share"):
			printerr("[share_probe] FAIL: CityView has no income_share() — shares never reached the city")
			quit(1)
			return true
		var key: String = str(root.get_node("GameState").buildings[0].icon_key)
		var share: float = float(_city.call("income_share", key))
		if share < 0.99:
			printerr("[share_probe] FAIL: sole earner '%s' share = %.3f, expected ~1.0" % [key, share])
			quit(1)
			return true
		if float(_city.call("income_share", "no_such_key")) != 0.0:
			printerr("[share_probe] FAIL: unowned key must read 0.0 share")
			quit(1)
			return true
		print("[share_probe] PASS — income share reaches the city (sole earner %.3f)" % share)
		quit(0)
		return true

	elif _frames >= 120:
		printerr("[share_probe] FAIL: timed out")
		quit(1)
		return true
	return false
