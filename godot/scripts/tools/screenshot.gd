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
##   --districts N    Unlock first N territories (district strip)
##   --prestige-tokens N  Seed prestige tokens (e.g. 75 = Crime Lord rank glow)
##   --offline-overlay    Force offline return overlay (city dimmed behind scrim)
##   --prestige-tree      Open prestige tree overlay for capture

const GAME_SCREEN := "res://scenes/game_screen.tscn"
const MAIN_MENU := "res://scenes/main_menu.tscn"
const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

const _TIER_BUILDINGS := [0, 5, 15, 35, 80]

var _frame := 0
var _settle := 45
var _tab := 0
var _out := "user://shot.png"
var _screen: Node = null
var _menu_mode := false
var _offline_overlay_mode := false
var _prestige_tree_mode := false


func _initialize() -> void:
	_settle = int(_arg_after("--frames", "45"))
	_tab = int(_arg_after("--tab", "0"))
	_out = _resolve_out_path(_arg_after("--out", "user://shot.png"))
	var w := int(_arg_after("--w", "720"))
	var h := int(_arg_after("--h", "1280"))
	_menu_mode = _has_flag("--menu")
	_offline_overlay_mode = _has_flag("--offline-overlay")
	_prestige_tree_mode = _has_flag("--prestige-tree")

	SoakAutoloads.install(self)
	var gs: Node = root.get_node_or_null("GameState")
	if gs != null and gs.has_method("reset_new_game") and not _menu_mode:
		gs.reset_new_game()
		var cash := float(_arg_after("--cash", "0"))
		if cash > 0.0:
			gs.balance = cash
		_apply_city_matrix_seed(gs)
		_apply_overlay_seed(gs)

	root.set_content_scale_size(Vector2i(w, h))
	DisplayServer.window_set_size(Vector2i(w, h))

	var scene_path := MAIN_MENU if _menu_mode else GAME_SCREEN
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Failed to load %s" % scene_path)
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
	var districts_arg := _arg_after("--districts", "")
	if not districts_arg.is_empty() and gs.get("territories") != null:
		var districts: Array = gs.territories
		var unlock_count := clampi(int(districts_arg), 0, districts.size())
		for i in districts.size():
			var t = districts[i]
			if t != null and t.has_method("set"):
				t.unlocked = i < unlock_count
		if gs.has_signal("stats_changed"):
			gs.stats_changed.emit()
	var prestige_arg := _arg_after("--prestige-tokens", "")
	if not prestige_arg.is_empty():
		gs.prestige_tokens = maxi(0, int(prestige_arg))
	if gs.has_signal("stats_changed"):
		gs.stats_changed.emit()


func _apply_overlay_seed(gs: Node) -> void:
	if _offline_overlay_mode:
		gs.show_offline_overlay = true
		gs.show_daily_overlay = false
		gs.offline_gain = 12500.0
		gs.offline_secs_away = 7200.0
		gs.offline_capped = false
		var rival_lines: Array[String] = [
			"The Vipers expanded into Downtown",
			"Blood Moon Syndicate took a hit",
		]
		gs.offline_rival_events = rival_lines
	if _prestige_tree_mode:
		gs.prestige_tokens = maxi(gs.prestige_tokens, 12)
		if gs.has_signal("stats_changed"):
			gs.stats_changed.emit()


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
	if not _menu_mode and _frame == 5 and _screen != null:
		if _screen.has_method("_set_tab"):
			_screen.call("_set_tab", _tab)
		if _prestige_tree_mode:
			var tree := _screen.get_node_or_null("PrestigeTreeOverlay")
			if tree != null and tree.has_method("open"):
				tree.call("open")
		elif _offline_overlay_mode and _screen.has_method("_refresh_overlays"):
			_screen.call("_refresh_overlays")
	if _frame < _settle:
		return false
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(_out)
	if err != OK:
		printerr("screenshot: save_png failed (%d) for %s" % [err, _out])
		quit(1)
		return true
	var payload := {"ok": true, "out": ProjectSettings.globalize_path(_out)}
	if not _menu_mode:
		payload["tab"] = _tab
		if _offline_overlay_mode:
			payload["offline_overlay"] = true
		if _prestige_tree_mode:
			payload["prestige_tree"] = true
	else:
		payload["menu"] = true
	print(JSON.stringify(payload))
	quit(0)
	return true


func _resolve_out_path(path: String) -> String:
	var p := path.replace("\\", "/")
	if p.begins_with("docs/"):
		return "../" + p
	return p


func _has_flag(flag: String) -> bool:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		if pack.has(flag):
			return true
	return false


func _arg_after(flag: String, fallback: String) -> String:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for i in pack.size():
			if pack[i] == flag and i + 1 < pack.size():
				return pack[i + 1]
	return fallback
