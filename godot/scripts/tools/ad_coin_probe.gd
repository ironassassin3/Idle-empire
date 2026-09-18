extends SceneTree
## A golden coin granted by a rewarded ad must survive after a natural coin
## expired (stale lifetime used to despawn it on the next tick).
##
##   godot --headless --path godot -s res://scripts/tools/ad_coin_probe.gd

const Autoloads = preload("res://scripts/tools/soak_autoloads.gd")


func _initialize() -> void:
	Autoloads.install(self)


func _process(_delta: float) -> bool:
	var gs := root.get_node("GameState")
	gs.golden_coin_active = false
	gs.golden_coin_lifetime = 999.0
	gs.grant_free_golden_coin()
	gs._tick_golden_coin(0.1)
	if not gs.golden_coin_active:
		printerr("AD_COIN FAIL — ad-granted coin despawned on the first tick")
		quit(1)
		return true
	print("AD_COIN PASS — ad-granted coin survives a stale lifetime")
	quit(0)
	return true
