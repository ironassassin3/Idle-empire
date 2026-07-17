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
