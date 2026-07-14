extends SceneTree
## Headless probe: a purchase must light THAT facade, and must not allocate a
## node to do it. Usage:
##   godot --headless --path godot -s res://scripts/tools/city_reaction_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _shell: Node
var _city: Node
var _stage: Node
var _frames := 0
var _stage_children_before := -1


func _initialize() -> void:
	SoakAutoloads.install(self)
	var gs: Node = root.get_node("GameState")
	gs.reset_new_game()
	var packed: PackedScene = load("res://scenes/game_shell.tscn")
	if packed == null:
		push_error("[city_probe] failed to load game_shell.tscn")
		quit(1)
		return
	_shell = packed.instantiate()
	root.add_child(_shell)


func _process(_delta: float) -> bool:
	_frames += 1
	var events: Node = root.get_node_or_null("UiEvents")
	if events == null:
		return false
	# Resolve shell descendants lazily — like shell_smoke, they are reliably
	# found once frames are pumping, not the instant _initialize adds the shell.
	if _stage == null:
		_stage = root.find_child("StageLayer", true, false)
	if _city == null:
		_city = root.find_child("CityView", true, false)
	if _stage == null or _city == null:
		if _frames >= 10:
			printerr("[city_probe] FAIL: StageLayer or CityView not found")
			quit(1)
			return true
		return false

	if _frames == 20:
		# Own a business so it has a facade to light.
		var gs: Node = root.get_node("GameState")
		gs.balance = 1_000_000.0
		gs.buy_building(0, 1)
		gs.emit_signal("stats_changed")

	elif _frames == 40:
		if not _city.has_method("is_facade_pulsing"):
			printerr("[city_probe] FAIL: CityView has no is_facade_pulsing() — the city cannot be addressed")
			quit(1)
			return true
		_stage_children_before = _stage.get_child_count()
		var key: String = str(root.get_node("GameState").buildings[0].icon_key)
		events.emit_signal("building_purchased", key)

	elif _frames == 45:
		var key: String = str(root.get_node("GameState").buildings[0].icon_key)
		if not bool(_city.call("is_facade_pulsing", key)):
			printerr("[city_probe] FAIL: bought '%s' but its facade is not lit" % key)
			quit(1)
			return true
		if _stage.get_child_count() != _stage_children_before:
			printerr("[city_probe] FAIL: reaction allocated %d node(s) — reactions must be drawn state, not stacked nodes" % [
				_stage.get_child_count() - _stage_children_before,
			])
			quit(1)
			return true
		print("[city_probe] PASS — purchase lit its own facade, zero nodes allocated")
		quit(0)
		return true

	elif _frames >= 120:
		printerr("[city_probe] FAIL: timed out before assertions ran")
		quit(1)
		return true
	return false
