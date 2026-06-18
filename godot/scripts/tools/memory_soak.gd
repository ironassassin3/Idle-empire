extends SceneTree
## Headless memory/leak soak (ROADMAP P8). Loads game_screen, runs the live sim,
## simulates periodic clicks, and samples memory / object / node counts over time.
## Node-count growth is the clearest leak signal (objects/mem fluctuate with GC).
## Usage: godot --path godot --headless -s res://scripts/tools/memory_soak.gd [-- --seconds 120]

const GAME_SCREEN := "res://scenes/game_screen.tscn"
const SAMPLE_EVERY := 10.0
const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _screen: Node
var _elapsed := 0.0
var _target := 120.0
var _next_sample := 0.0
var _click_accum := 0.0
var _samples: Array = []


func _initialize() -> void:
	var arg := _arg_after("--seconds")
	_target = float(arg) if not arg.is_empty() else 120.0
	# A `-s` SceneTree run does not init project autoloads; game_screen depends on
	# GameState/GameConfig/etc., so install them before instantiating it.
	SoakAutoloads.install(self)
	_screen = (load(GAME_SCREEN) as PackedScene).instantiate()
	root.add_child(_screen)


func _process(delta: float) -> bool:
	_elapsed += delta
	# ~10 clicks/sec to exercise click path + notification churn.
	_click_accum += delta
	while _click_accum >= 0.1:
		_click_accum -= 0.1
		_screen.call("_on_hustle")

	if _elapsed >= _next_sample:
		_next_sample += SAMPLE_EVERY
		_samples.append({
			"t": _elapsed,
			"mem": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
			"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		})

	if _elapsed < _target:
		return false

	_report()
	return true


func _report() -> void:
	for s in _samples:
		print("t=%5.0fs  mem=%8d KB  objects=%6d  nodes=%5d" % [
			s.t, int(s.mem / 1024), s.objects, s.nodes,
		])
	# Compare post-warmup baseline (2nd sample) to last.
	var fails := 0
	if _samples.size() >= 3:
		var base: Dictionary = _samples[1]
		var last: Dictionary = _samples[_samples.size() - 1]
		var node_growth: int = last.nodes - base.nodes
		var mem_growth_kb: int = int((last.mem - base.mem) / 1024)
		print("--- growth (base t=%.0fs -> last t=%.0fs) ---" % [base.t, last.t])
		print("nodes: %+d   mem: %+d KB" % [node_growth, mem_growth_kb])
		if node_growth > 50:
			print("FAIL: node count grew by %d (possible leak)" % node_growth); fails += 1
		if mem_growth_kb > 4096:
			print("FAIL: static memory grew by %d KB" % mem_growth_kb); fails += 1
	print("MEMORY SOAK %s" % ("PASS" if fails == 0 else "FAIL(%d)" % fails))
	quit(fails)


func _arg_after(flag: String) -> String:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for i in pack.size():
			if pack[i] == flag and i + 1 < pack.size():
				return pack[i + 1]
	return ""
