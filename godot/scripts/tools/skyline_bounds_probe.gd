extends SceneTree
## Headless probe: the skyline never grows out of its stage bounds (P1 #6).
## Usage:
##   godot --headless --path godot -s res://scripts/tools/skyline_bounds_probe.gd

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
			printerr("[skyline_bounds] FAIL: CityView not found")
			quit(1)
			return true
		return false

	if _frames != 20:
		if _frames >= 30:
			printerr("[skyline_bounds] FAIL: timed out")
			quit(1)
			return true
		return false

	var ground_y: float = float(_city.VIRTUAL_SIZE.y) - 28.0
	var margin: float = float(_city.SKYLINE_TOP_MARGIN)
	var failures: Array = []
	# Realistic max tier/total (see _tier()) crossed with an extreme owned
	# count — the case that used to run the tower clean off the top.
	for owned in [1, 6, 20, 1000, 1_000_000]:
		for is_hero in [false, true]:
			var h: float = float(_city.call("facade_height", owned, 4, 500, is_hero, 0, ground_y))
			if h > ground_y - margin + 0.01:
				failures.append("owned=%d hero=%s -> h=%.1f exceeds cap %.1f" % [owned, is_hero, h, ground_y - margin])
			if h <= 0.0:
				failures.append("owned=%d hero=%s -> h=%.1f is non-positive" % [owned, is_hero, h])

	if not failures.is_empty():
		for f in failures:
			printerr("[skyline_bounds] FAIL: %s" % f)
		quit(1)
		return true

	print("[skyline_bounds] PASS — facade height stays within stage bounds at every owned count")
	quit(0)
	return true
