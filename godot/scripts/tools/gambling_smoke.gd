extends SceneTree
## Headless smoke for the Luck Wheel overlay — drives BOTH presentations the
## overlay owns and asserts their view contracts still fire:
##   1. Cash wager  -> Three-Card Monte reveal -> `landed` -> Phase.DONE
##   2. Free spin   -> wheel sweep -> stop_sweep() -> `stopped` -> Phase.DONE
##
## Exists because wager_probe.gd only covers the MODEL (place_wager); nothing
## else exercises gambling_wheel.gd, so the reveal/sweep animation paths could
## rot silently. Usage:
##   godot --headless --path godot -s res://scripts/tools/gambling_smoke.gd

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")
const FRAME_BUDGET := 4000  # generous: the Monte reveal is wall-clock timed

var _ov: Node
var _wheel: Node
var _gs: Node
var _frames := 0
var _stage := 0
var _fail := false
var _bal_before := 0.0
var _stake := 0.0


func _initialize() -> void:
	SoakAutoloads.install(self)
	_gs = root.get_node("GameState")
	_gs.reset_new_game()
	var packed: PackedScene = load("res://scenes/gambling_overlay.tscn")
	if packed == null:
		printerr("[gambling_smoke] failed to load gambling_overlay.tscn")
		quit(1)
		return
	_ov = packed.instantiate()
	root.add_child(_ov)
	_wheel = _ov.get_node("Panel/Margin/VBox/Wheel")
	# NOTE: open() is deferred to the first _process frame — the overlay's
	# @onready node refs are not resolved yet at _initialize time.
	print("[gambling_smoke] overlay instantiated OK")


func _bad(msg: String) -> void:
	printerr("[gambling_smoke] FAIL: %s" % msg)
	_fail = true


func _process(_delta: float) -> bool:
	_frames += 1
	if _fail:
		quit(1)
		return true
	if _frames > FRAME_BUDGET:
		_bad("frame budget exhausted at stage %d (reveal never landed?)" % _stage)
		quit(1)
		return true

	if _frames == 3:
		_ov.call("open")
		print("[gambling_smoke] overlay opened OK")
		return false

	# ── Stage 0: fire a cash wager, which must resolve instantly ───────────
	if _stage == 0 and _frames == 10:
		_gs.balance = 100_000.0
		_bal_before = _gs.balance
		_stake = 1000.0
		_ov.set("_stake", _stake)
		_ov.call("_on_bet_pressed")
		# Money must already have moved — the Monte reveal is cosmetic only.
		if is_equal_approx(float(_gs.balance), _bal_before):
			_bad("balance unchanged after BET; wager did not resolve at press")
			return false
		if int(_ov.get("_phase")) != 1:  # Phase.SWEEPING
			_bad("expected Phase.SWEEPING during the Monte reveal")
			return false
		print("[gambling_smoke] wager resolved at press (balance moved), reveal running")
		_stage = 1
		return false

	# ── Stage 1: wait for the Monte flip to emit `landed` -> Phase.DONE ────
	if _stage == 1:
		if int(_ov.get("_phase")) == 2:  # Phase.DONE
			var status: String = str(_ov.get_node("Panel/Margin/VBox/StatusLabel").text)
			if status.strip_edges().is_empty():
				_bad("landed fired but status line is empty (msg not shown)")
				return false
			print("[gambling_smoke] Monte reveal landed after %d frames -> %s" % [
				_frames, status.replace("\n", " / "),
			])
			_stage = 2
		return false

	# ── Stage 2: free spin — sweep must start, then stop and resolve ───────
	if _stage == 2:
		if not _gs.call("grant_gamble_ad_spin"):
			_bad("could not bank a free spin")
			return false
		_ov.call("_stage_free_round")
		if not _wheel.call("has_round"):
			_bad("free round staged but wheel has no segments")
			return false
		_ov.call("_on_spin_pressed")
		if not _wheel.call("is_sweeping"):
			_bad("start_sweep did not begin sweeping")
			return false
		print("[gambling_smoke] free-spin sweep started")
		_stage = 3
		return false

	# ── Stage 3: let it sweep a few frames, then stop it ───────────────────
	if _stage == 3 and _frames % 40 == 0:
		_wheel.call("stop_sweep")
		if _wheel.call("is_sweeping"):
			_bad("stop_sweep did not stop the sweep")
			return false
		if int(_ov.get("_phase")) != 2:  # Phase.DONE
			_bad("stopped did not drive the overlay to Phase.DONE")
			return false
		print("[gambling_smoke] free spin stopped + resolved")
		_stage = 4
		return false

	# ── Stage 4: reset() must clear both animation paths ───────────────────
	if _stage == 4:
		_wheel.call("reset")
		if _wheel.call("is_sweeping"):
			_bad("reset left the wheel sweeping")
			return false
		print("[gambling_smoke] PASS — Monte reveal + free sweep + reset all OK")
		quit(0)
		return true
	return false
