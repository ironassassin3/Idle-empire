extends SceneTree
## Regression guard for the 2026-07-27 device-pass framerate blocker (12-20 FPS
## on a moto g / Mali-G57).
##
##   godot --headless --path godot -s res://scripts/tools/stats_emit_rate_probe.gd
##
## Root cause it guards: GameState._process emitted `stats_changed` on EVERY
## frame, and 79 listeners connect a full _refresh() straight to it - 20 territory
## rows, 13 upgrade rows, 13 manager rows, 11 building rows, 5 rival/crew/op rows
## each - most of them on tabs that are not even visible. One emit measured
## 9.3 ms of a 10.3 ms _process; the whole simulation was 26 us. The shell had a
## 10 Hz throttle (_STATS_UI_INTERVAL) but the rows bypassed it by connecting
## direct to the signal.
##
## Two independent assertions, because either regression alone brings the stutter
## back:
##   1. the passive income tick may not emit faster than PASSIVE_EMIT_HZ
##   2. discrete player actions (a purchase) MUST still emit immediately - a
##      throttle that also delays those would make every buy feel broken

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

const FRAME := 1.0 / 60.0
const FRAMES := 120                  # 2 seconds of simulated frames
const PASSIVE_EMIT_HZ := 12.0        # 10 Hz target + slack for timer phase
const MAX_PASSIVE_EMITS := int(PASSIVE_EMIT_HZ * 2.0) + 2

var _emits := 0


func _initialize() -> void:
	SoakAutoloads.install(self)
	var gs: Node = root.get_node("GameState")
	gs.reset_new_game()
	gs.set_simulation_active(true)
	# Enough cash and buildings that the sim has real work to do each tick.
	gs.balance = 5_000_000.0
	for i in mini(6, gs.buildings.size()):
		gs.buildings[i].owned = 20

	gs.stats_changed.connect(func(): _emits += 1)

	# ---- assertion 1: the passive tick must not emit every frame ----
	_emits = 0
	for i in FRAMES:
		gs._process(FRAME)
	var passive_emits := _emits
	var ok := true
	if passive_emits > MAX_PASSIVE_EMITS:
		printerr("[stats_rate] FAIL passive tick emitted %d times in %d frames (max %d)" % [
			passive_emits, FRAMES, MAX_PASSIVE_EMITS,
		])
		ok = false
	else:
		print("[stats_rate] passive tick: %d emits over %d frames (max %d) OK" % [
			passive_emits, FRAMES, MAX_PASSIVE_EMITS,
		])

	# ---- assertion 2: a discrete purchase must still emit immediately ----
	_emits = 0
	var bought: bool = gs.buy_building(0, 1)
	if not bought:
		printerr("[stats_rate] FAIL could not buy a building - test setup is wrong")
		ok = false
	elif _emits < 1:
		printerr("[stats_rate] FAIL purchase did not emit stats_changed immediately")
		ok = false
	else:
		print("[stats_rate] purchase emitted immediately OK")

	if ok:
		print("[stats_rate] PASS")
		quit(0)
	else:
		quit(1)


func _process(_delta: float) -> bool:
	return true
