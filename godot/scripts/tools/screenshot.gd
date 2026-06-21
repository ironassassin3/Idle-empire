extends SceneTree
## Screenshot harness — boot game_screen windowed, capture a tab to PNG.
## Godot 4 cannot read back a viewport under --headless, so run WITHOUT it:
##   godot --path godot -s res://scripts/tools/screenshot.gd -- --tab 0 --out shot.png
## Args (after the `--`):
##   --tab N          Tab enum index (0 BLDGS … 8 CONFIG)
##   --out PATH       Output PNG path (default user://shot.png)
##   --frames N       Frames to settle before capture (default 45)
##   --cash N         Seed GameState.balance so affordance states populate
##   --w / --h        Window size override (default project 720x1280)
##   --city-tier N    Skyline tier preset 0–4 (buildings 0/5/15/35/80)
##   --buildings N    Override total buildings owned (all on index 0)
##   --heat N         Set heat 0–100

const GAME_SCREEN := "res://scenes/game_screen.tscn"
const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

const _TIER_BUILDINGS := [0, 5, 15, 35, 80]

var _frame := 0
var _settle := 45
var _tab := 0
var _out := "user://shot.png"
var _screen: Node = null


func _initialize() -> void:
	_settle = int(_arg_after("--frames", "45"))
	_tab = int(_arg_after("--tab", "0"))
	_out = _arg_after("--out", "user://shot.png")
	var w := int(_arg_after("--w", "720"))
	var h := int(_arg_after("--h", "1280"))

	SoakAutoloads.install(self)
	var gs: Node = root.get_node_or_null("GameState")
	if gs != null and gs.has_method("reset_new_game"):
		gs.reset_new_game()
		var cash := float(_arg_after("--cash", "0"))
		if cash > 0.0:
			gs.balance = cash
		_apply_city_matrix_seed(gs)

	root.set_content_scale_size(Vector2i(w, h))
	DisplayServer.window_set_size(Vector2i(w, h))

	var packed: PackedScene = load(GAME_SCREEN) as PackedScene
	if packed == null:
		push_error("Failed to load %s" % GAME_SCREEN)
		quit(1)
		return
	_screen = packed.instantiate()
	root.add_child(_screen)


func _apply_city_matrix_seed(gs: Node) -> void:
	var tier_arg := _arg_after("--city-tier", "")
	if not tier_arg.is_empty():
		var tier := clampi(int(tier_arg), 0, _TIER_BUILDINGS.size() - 1)
		_seed_buildings(gs, _TIER_BUILDINGS[tier])
	var buildings_arg := _arg_after("--buildings", "")
	if not buildings_arg.is_empty():
		_seed_buildings(gs, maxi(0, int(buildings_arg)))
	var heat_arg := _arg_after("--heat", "")
	if not heat_arg.is_empty():
		gs.heat = clampf(float(heat_arg), 0.0, 100.0)


func _seed_buildings(gs: Node, count: int) -> void:
	if not gs.has_method("get") or gs.get("buildings") == null:
		return
	var buildings: Array = gs.buildings
	if buildings.is_empty():
		return
	for b in buildings:
		if b != null and b.has_method("set"):
			b.owned = 0
	var first = buildings[0]
	if first != null:
		first.owned = count
	if gs.has_signal("stats_changed"):
		gs.stats_changed.emit()


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 5 and _screen != null and _screen.has_method("_set_tab"):
		_screen.call("_set_tab", _tab)
	if _frame < _settle:
		return false
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(_out)
	if err != OK:
		printerr("screenshot: save_png failed (%d) for %s" % [err, _out])
		quit(1)
		return true
	print(JSON.stringify({"ok": true, "out": ProjectSettings.globalize_path(_out), "tab": _tab}))
	quit(0)
	return true


func _arg_after(flag: String, fallback: String) -> String:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for i in pack.size():
			if pack[i] == flag and i + 1 < pack.size():
				return pack[i + 1]
	return fallback
