extends SceneTree
## Headless probe: crossing a heat band emits heat_crossed ONCE (not per frame),
## and the city stores the alert level with zero node allocation. Usage:
##   godot --headless --path godot -s res://scripts/tools/city_alert_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _city: Node
var _stage: Node
var _frames := 0
var _last_level := -99
var _emit_count := 0
var _spam_baseline := -1
var _stage_baseline := -1


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	root.add_child(load("res://scenes/game_shell.tscn").instantiate())
	root.get_node("UiEvents").heat_crossed.connect(_on_heat_crossed)


func _on_heat_crossed(level: int) -> void:
	_last_level = level
	_emit_count += 1


func _fail(msg: String) -> bool:
	printerr("[alert_probe] FAIL: " + msg)
	quit(1)
	return true


func _process(_delta: float) -> bool:
	_frames += 1
	if _city == null:
		_city = root.find_child("CityView", true, false)
		_stage = root.find_child("StageLayer", true, false)
	if _city == null or _stage == null:
		if _frames >= 10:
			return _fail("StageLayer or CityView not found")
		return false
	var gs: Node = root.get_node("GameState")

	if _frames == 18:
		# Baseline BEFORE any alert activity, so the no-alloc check has meaning.
		_stage_baseline = _stage.get_child_count()
	elif _frames == 20:
		if not _city.has_method("alert_level"):
			return _fail("CityView has no alert_level() — heat cannot address the city")
		gs.heat = 75.0  # -> band 1; a raid drops 15 to 60, still band 1 (raid-proof)
	elif _frames == 24:
		if _last_level != 1:
			return _fail("crossing to warn heat did not emit heat_crossed(1); last=%d" % _last_level)
		if int(_city.call("alert_level")) != 1:
			return _fail("city alert_level != 1 after warn crossing")
		gs.heat = 100.0  # -> band 2; a raid drops to 85, still band 2 (raid-proof)
	elif _frames == 26:
		if _last_level != 2:
			return _fail("crossing to critical heat did not emit heat_crossed(2); last=%d" % _last_level)
		gs.heat = 5.0  # -> band 0 (calm); no raids possible below 60
	elif _frames == 30:
		if _last_level != 0:
			return _fail("dropping to calm heat did not emit heat_crossed(0); last=%d" % _last_level)
		_spam_baseline = _emit_count  # heat now stable at band 0
	elif _frames == 70:
		# Band unchanged for 40 frames: not a single extra emit may have fired.
		if _emit_count != _spam_baseline:
			return _fail("heat_crossed fired %d extra time(s) with no band change — must emit on CHANGE only" % (_emit_count - _spam_baseline))
		if _stage.get_child_count() != _stage_baseline:
			return _fail("alert reaction allocated a node — must be drawn state")
		print("[alert_probe] PASS — band crossings emit once each, city stores the level, zero nodes")
		quit(0)
		return true
	elif _frames >= 120:
		return _fail("timed out")
	return false
