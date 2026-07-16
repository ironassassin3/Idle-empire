extends SceneTree
## Headless probe: a district changing hands emits district_changed(idx, holder)
## and the city flashes THAT block, zero nodes allocated. Usage:
##   godot --headless --path godot -s res://scripts/tools/city_district_probe.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _city: Node
var _stage: Node
# Loaded by PATH, not the `TerritorySystem` class_name: naming the class here would
# force territory_system.gd to compile at THIS script's compile time — before
# SoakAutoloads.install() registers the FormatUtil singleton it references.
var _TS: GDScript = null
var _frames := 0
var _last_idx := -1
var _last_holder := ""
var _stage_baseline := -1


func _initialize() -> void:
	SoakAutoloads.install(self)
	root.get_node("GameState").reset_new_game()
	root.add_child(load("res://scenes/game_shell.tscn").instantiate())
	root.get_node("UiEvents").district_changed.connect(_on_district_changed)
	_TS = load("res://scripts/systems/territory_system.gd")  # after install(): FormatUtil resolves


func _on_district_changed(idx: int, holder: String) -> void:
	_last_idx = idx
	_last_holder = holder


func _fail(msg: String) -> bool:
	printerr("[district_probe] FAIL: " + msg)
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
	var events: Node = root.get_node("UiEvents")

	if _frames == 20:
		if not _city.has_method("is_district_pulsing"):
			return _fail("CityView has no is_district_pulsing() — turf cannot be addressed")
		_stage_baseline = _stage.get_child_count()
		events.district_changed.emit(3, "player")
		events.district_changed.emit(4, "rival")
	elif _frames == 24:
		if not bool(_city.call("is_district_pulsing", 3)):
			return _fail("player block 3 not pulsing after emit")
		if not bool(_city.call("is_district_pulsing", 4)):
			return _fail("rival block 4 not pulsing after emit")
		if _stage.get_child_count() != _stage_baseline:
			return _fail("district reaction allocated a node — must be drawn state")
	elif _frames == 30:
		# Deterministic rival-claim emitter (no rng).
		_last_holder = ""
		_TS.rival_claim_preferred(gs.territories, "TestRival")
		if _last_holder != "rival":
			return _fail("rival_claim_preferred did not emit district_changed(_, 'rival')")
		if str(gs.territories[_last_idx].get("owner", "")) != "TestRival":
			return _fail("claimed block %d owner is not TestRival" % _last_idx)
	elif _frames == 36:
		# Player-capture emitter via _seize_territory (bounded to kill rng flake).
		# Force district 5 unclaimed first: some districts start rival-held, and
		# perform_action rejects negotiate on those before it can seize. We are
		# testing the capture→emit path, not new-game ownership.
		gs.territories[5]["owner"] = "unclaimed"
		gs.territories[5]["unlocked"] = false
		gs.prestige_tokens = 1000
		_last_holder = ""
		var rng := RandomNumberGenerator.new()
		var ok := false
		for _attempt in 200:
			if bool(gs.territories[5].get("unlocked", false)):
				ok = true
				break
			_TS.perform_action(gs, 5, "negotiate", rng)
		if not ok:
			return _fail("could not capture district 5 in 200 negotiate attempts")
		if _last_holder != "player" or _last_idx != 5:
			return _fail("player capture emitted (%d, '%s'), expected (5, 'player')" % [_last_idx, _last_holder])
		print("[district_probe] PASS — captures and claims flash their own block, zero nodes")
		quit(0)
		return true
	elif _frames >= 120:
		return _fail("timed out")
	return false
