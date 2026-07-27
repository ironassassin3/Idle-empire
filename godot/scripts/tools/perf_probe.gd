extends SceneTree
## Frame-cost probe for the Stage & Ledger shell (device pass 2026-07-27: 12-20 FPS
## on a moto g / Mali-G57). Answers ONE question with evidence instead of a guess:
## how much per-frame work does the shell issue, and how much of it is CityView?
##
##   godot --path godot -s res://scripts/tools/perf_probe.gd -- [--hide-city] [--reduced-motion]
##
## Must run WINDOWED. Under --headless the renderer is a dummy: draw calls read 0
## and CityView._draw() early-returns on _is_headless(), so the numbers would be
## a lie that says "no problem here".
##
## Draw-call counts are device-independent - they are work the CPU hands the GPU,
## identical on a 3070 Ti and a Mali-G57. So the A/B is meaningful on a desktop
## even though the desktop FPS is not.

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

# Mirrors the save pulled off the device after the 19-minute pass, so the city
# draws at its real tier-4 density rather than a fresh-save skyline.
const DEVICE_BUILDINGS := [48, 22, 36, 19, 16, 14, 1, 0, 0, 0, 0]
const VIEWPORT := Vector2i(1080, 1920)
const WARMUP := 45
const SAMPLE := 120

var _shell: Node
var _sv: SubViewport
var _frames := 0
var _hide_city := false
var _reduced := false
var _sim_only := false
var _bench := false

var _fps_sum := 0.0
var _proc_sum := 0.0
var _calls_sum := 0.0
var _prims_sum := 0.0
var _objs_sum := 0.0
var _calls_max := 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--hide-city":
			_hide_city = true
		elif a == "--reduced-motion":
			_reduced = true
		elif a == "--sim-only":
			_sim_only = true
		elif a == "--bench":
			_bench = true

	SoakAutoloads.install(self)
	var gs: Node = root.get_node("GameState")
	# GameState._ready queues reset_new_game() deferred. Applying the device
	# fixture synchronously here loses to that reset on the first idle flush
	# (tier-0 skyline, empty economy — useless for the Mali draw-call A/B).
	# Sync reset so buildings exist for shell _ready; then re-apply after the
	# autoload's deferred reset has run (FIFO with call_deferred below).
	gs.reset_new_game()
	_apply_device_fixture(gs)
	call_deferred("_reapply_fixture_after_autoload_reset")

	_sv = SubViewport.new()
	_sv.size = VIEWPORT
	_sv.disable_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.gui_embed_subwindows = true
	root.add_child(_sv)

	# --sim-only skips the shell entirely: whatever cost remains is GameState's
	# per-frame simulation, with no UI attributable to it.
	if not _sim_only:
		var packed: PackedScene = load("res://scenes/game_shell.tscn")
		if packed == null:
			printerr("[perf] FAIL: game_shell.tscn did not load")
			quit(1)
			return
		_shell = packed.instantiate()
		_sv.add_child(_shell)
	else:
		gs.set_simulation_active(true)
	print("[perf] mode=%s reduced_motion=%s viewport=%dx%d" % [
		_mode_name(), _reduced, VIEWPORT.x, VIEWPORT.y,
	])


func _apply_device_fixture(gs: Node) -> void:
	for i in mini(DEVICE_BUILDINGS.size(), gs.buildings.size()):
		gs.buildings[i].owned = DEVICE_BUILDINGS[i]
	gs.balance = 31_182_312.0
	gs.lifetime_earnings = 139_912_284.0
	gs.prestige_route_earnings = 126_272_513.0
	gs.heat = 52.0
	if _reduced:
		gs.show_particles = false  # GameTheme.ui_reduced_motion() gate


func _reapply_fixture_after_autoload_reset() -> void:
	var gs: Node = root.get_node("GameState")
	_apply_device_fixture(gs)
	# Shell may have cached a fresh-save skyline during _ready; force a redraw
	# at device-pass density before warmup samples start.
	if _shell != null and _shell.has_method("_refresh_all"):
		_shell.call("_refresh_all")
	print("[perf] device fixture applied (buildings=%s)" % str(DEVICE_BUILDINGS))


const BENCH_N := 2000


func _time_call(target: Node, method: String, args: Array) -> float:
	if target == null or not target.has_method(method):
		return -1.0
	var t0 := Time.get_ticks_usec()
	for i in BENCH_N:
		target.callv(method, args)
	return float(Time.get_ticks_usec() - t0) / float(BENCH_N)


func _run_bench() -> void:
	var stage: Node = root.find_child("StageLayer", true, false)
	var gs: Node = root.get_node("GameState")
	if stage == null:
		printerr("[perf] FAIL: StageLayer not found")
		return
	print("[perf] BENCH n=%d (per-call microseconds)" % BENCH_N)

	var t0 := Time.get_ticks_usec()
	for i in BENCH_N:
		stage.call("refresh", false)
	var stage_us := float(Time.get_ticks_usec() - t0) / float(BENCH_N)

	t0 = Time.get_ticks_usec()
	for i in BENCH_N:
		stage.call("_top_buildings")
	var top_us := float(Time.get_ticks_usec() - t0) / float(BENCH_N)

	t0 = Time.get_ticks_usec()
	for i in BENCH_N:
		stage.call("_district_slots")
	var slots_us := float(Time.get_ticks_usec() - t0) / float(BENCH_N)

	var shell: Node = root.find_child("GameShell", true, false)
	if shell == null:
		shell = _shell
	var overlays: Node = root.find_child("OverlayHost", true, false)
	var masthead: Node = root.find_child("Masthead", true, false)

	var over_us := _time_call(overlays, "refresh", [0.016])
	var tut_us := _time_call(shell, "_refresh_tutorial", [false])
	var gap_us := _time_call(shell, "_sync_gap_rect", [])
	var all_us := _time_call(shell, "_refresh_all", [])
	var mast_us := _time_call(masthead, "refresh", [])

	print("[perf]   -- per-frame shell calls --")
	print("[perf]   overlays.refresh()   %8.1f us" % over_us)
	print("[perf]   _refresh_tutorial()  %8.1f us" % tut_us)
	print("[perf]   _sync_gap_rect()     %8.1f us" % gap_us)
	print("[perf]   -- throttled (10Hz) --")
	print("[perf]   _refresh_all()       %8.1f us" % all_us)
	print("[perf]     masthead.refresh() %8.1f us" % mast_us)

	t0 = Time.get_ticks_usec()
	for i in BENCH_N:
		gs.call("_process", 0.016)
	var sim_us := float(Time.get_ticks_usec() - t0) / float(BENCH_N)

	t0 = Time.get_ticks_usec()
	for i in BENCH_N:
		gs.call("income_per_second")
	var ips_us := float(Time.get_ticks_usec() - t0) / float(BENCH_N)

	print("[perf]   stage.refresh()      %8.1f us/frame" % stage_us)
	print("[perf]     _top_buildings()   %8.1f us" % top_us)
	print("[perf]     _district_slots()  %8.1f us" % slots_us)
	print("[perf]   GameState._process() %8.1f us/frame  <== %.1f ms" % [sim_us, sim_us / 1000.0])
	print("[perf]     income_per_second()%8.1f us" % ips_us)
	_bench_subsystems(gs)


# Which tick inside GameState._process costs the 9.5 ms? Each is called once per
# frame with the whole game state.
func _bench_subsystems(gs: Node) -> void:
	var d := 0.016
	var rng := RandomNumberGenerator.new()
	var rows: Array = []

	rows.append(["_tick_building_specials", _time_call(gs, "_tick_building_specials", [d])])
	rows.append(["_tick_loan_interest", _time_call(gs, "_tick_loan_interest", [d])])
	rows.append(["_tick_golden_coin", _time_call(gs, "_tick_golden_coin", [d])])

	var systems := {
		"BuffSystem.tick_buffs": ["res://scripts/systems/buff_system.gd", "tick_buffs", [gs, d]],
		"EventSystem.update_events": ["res://scripts/systems/event_system.gd", "update_events", [gs, d, rng]],
		"TutorialSystem.tick_milestones": ["res://scripts/systems/tutorial_system.gd", "tick_milestones", [gs, d]],
		"TutorialSystem.tick_contextual": ["res://scripts/systems/tutorial_system.gd", "tick_contextual", [gs]],
		"TerritorySystem.tick_milestones": ["res://scripts/systems/territory_system.gd", "tick_milestones", [gs]],
		"ManagerSystem.tick_manager_effects": ["res://scripts/systems/manager_system.gd", "tick_manager_effects", [gs, d]],
		"OperationSystem.tick_smuggler_ops": ["res://scripts/systems/operation_system.gd", "tick_smuggler_ops", [gs, d]],
		"HeatSystem.update": ["res://scripts/systems/heat_system.gd", "update", [gs, d, rng]],
		"DragonSystem.dragon_update": ["res://scripts/systems/dragon_system.gd", "dragon_update", [gs, d, rng]],
		"RivalSystem.update_rivals": ["res://scripts/systems/rival_system.gd", "update_rivals", [gs, d, rng]],
		"PrestigeTree.tick_perk_effects": ["res://scripts/systems/prestige_tree.gd", "tick_perk_effects", [gs, d]],
		"GoalSystem.tick": ["res://scripts/systems/goal_system.gd", "tick", [gs, d]],
	}
	for label in systems:
		var spec: Array = systems[label]
		var scr = load(str(spec[0]))
		if scr == null or not scr.has_method(str(spec[1])):
			rows.append([label, -1.0])
			continue
		var t0 := Time.get_ticks_usec()
		for i in BENCH_N:
			scr.callv(str(spec[1]), spec[2])
		rows.append([label, float(Time.get_ticks_usec() - t0) / float(BENCH_N)])

	# stats_changed fires once per frame from _process. Every row type connects
	# its full _refresh() straight to it, bypassing the shell's 10Hz throttle.
	var conns: Array = gs.get_signal_connection_list("stats_changed")
	var by_target: Dictionary = {}
	for c in conns:
		var cb: Callable = c["callable"]
		var obj: Object = cb.get_object()
		var nm := "<lambda>" if str(cb.get_method()).begins_with("<") else str(cb.get_method())
		var key := "%s.%s" % [obj.get_class() if obj else "?", nm]
		if obj is Node:
			var scr = (obj as Node).get_script()
			if scr != null:
				key = "%s.%s" % [str(scr.resource_path).get_file(), nm]
		by_target[key] = int(by_target.get(key, 0)) + 1
	var emit_us := _time_call(gs, "emit_signal", ["stats_changed"])
	print("[perf]   -- stats_changed (emitted EVERY frame) --")
	print("[perf]   listeners total      %8d" % conns.size())
	for k in by_target:
		print("[perf]     %-40s x%d" % [k, int(by_target[k])])
	print("[perf]   one emit costs       %8.1f us  <== %.1f ms" % [emit_us, emit_us / 1000.0])

	rows.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	print("[perf]   -- inside GameState._process, hottest first --")
	for r in rows:
		if float(r[1]) < 0.0:
			print("[perf]   %-34s   (no such method)" % str(r[0]))
		else:
			print("[perf]   %-34s %8.1f us" % [str(r[0]), float(r[1])])


func _mode_name() -> String:
	if _sim_only:
		return "sim-only"
	return "hide-city" if _hide_city else "baseline"


func _process(_delta: float) -> bool:
	if _shell == null and not _sim_only:
		return false
	_frames += 1

	# Hide the city AFTER the shell has built its stage - the node does not
	# exist during _initialize.
	if _frames == 5 and _hide_city:
		var city: Node = root.find_child("CityView", true, false)
		if city == null:
			printerr("[perf] FAIL: CityView not found - cannot A/B")
			quit(1)
			return true
		(city as CanvasItem).visible = false
		print("[perf] CityView hidden")

	# Micro-bench: how much does one stage_layer.refresh() actually cost? It runs
	# unconditionally every frame from game_shell._process.
	if _frames == WARMUP and _bench:
		_run_bench()
		quit(0)
		return true

	if _frames <= WARMUP:
		return false

	_fps_sum += Performance.get_monitor(Performance.TIME_FPS)
	_proc_sum += Performance.get_monitor(Performance.TIME_PROCESS)
	var calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_calls_sum += calls
	_calls_max = maxf(_calls_max, calls)
	_prims_sum += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_objs_sum += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)

	if _frames < WARMUP + SAMPLE:
		return false

	var n := float(SAMPLE)
	print("[perf] RESULT mode=%s" % _mode_name())
	print("[perf]   fps            %8.1f" % (_fps_sum / n))
	print("[perf]   process_ms     %8.3f" % (_proc_sum / n * 1000.0))
	print("[perf]   draw_calls_avg %8.1f" % (_calls_sum / n))
	print("[perf]   draw_calls_max %8.1f" % _calls_max)
	print("[perf]   primitives_avg %8.1f" % (_prims_sum / n))
	print("[perf]   objects_avg    %8.1f" % (_objs_sum / n))
	print("[perf]   nodes          %8d" % int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	quit(0)
	return true
