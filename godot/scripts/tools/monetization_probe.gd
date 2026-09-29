extends SceneTree
## Deterministic desktop regression probe for the player-initiated rewarded-ad
## contract. Native SDK fill/show still requires an Android device test.

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

var _monetization: Node
var _rewards: Array[String] = []
var _failures: Array[String] = []


func _initialize() -> void:
	SoakAutoloads.install(self)
	_monetization = root.get_node("Monetization")
	var state: Node = root.get_node("GameState")
	state.reset_new_game()
	state.remove_ads = false
	# Monetization intentionally disables itself in headless mode. Re-enable the
	# mock seam explicitly so this probe exercises the signal/reward wiring.
	_monetization.ad_reward_granted.connect(func(p: String): _rewards.append(p))
	_monetization.ad_failed.connect(func(p: String, r: String): _failures.append("%s:%s" % [p, r]))
	call_deferred("_run")


func _run() -> void:
	_monetization.set("_enabled", true)
	_monetization.call("_pick_backend")
	var placements: Array[String] = [
		_monetization.PLACEMENT_OFFLINE_DOUBLE,
		_monetization.PLACEMENT_FREE_COIN,
		_monetization.PLACEMENT_TIME_SKIP,
		_monetization.PLACEMENT_GAMBLE_SPIN,
	]
	for placement in placements:
		_monetization.show_rewarded(placement)
	if not _failures.is_empty():
		_fail("reward flow failed: %s" % str(_failures))
		return
	for placement in placements:
		if placement not in _rewards:
			_fail("missing reward signal for %s" % placement)
			return
	if _monetization.has_method("maybe_show_interstitial"):
		_fail("Fair Play violation: interstitial entry point still exists")
		return
	print("[monetization_probe] PASS — all rewarded placements grant; no interstitial path")
	quit(0)


func _fail(message: String) -> void:
	printerr("[monetization_probe] FAIL — %s" % message)
	quit(1)
