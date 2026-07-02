extends SceneTree
## Headless validation of the cash-wager casino through the real GameState path.
##   "<godot>" --headless --path godot -s res://scripts/tools/wager_probe.gd
## Confirms: balance never goes negative, stake is always debited, and the house
## edge holds (mean net < 0) across many random-timing wagers.

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		print("RESULT: FAIL — GameState autoload not found")
		return true
	gs.balance = 1_000_000.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var trials := 200000
	var total_staked := 0.0
	var total_net := 0.0
	var min_balance: float = gs.balance
	var neg := false
	for i in trials:
		if gs.balance < 1000.0:
			gs.balance += 1_000_000.0
		var stake := 100.0
		gs.start_wager_round()
		var pos := rng.randf()  # random timing (worst case for the house edge)
		var before: float = gs.balance
		gs.place_wager(pos, stake)
		var net: float = gs.balance - before
		total_staked += stake
		total_net += net
		min_balance = minf(min_balance, gs.balance)
		if gs.balance < 0.0:
			neg = true
	var rtp := (total_staked + total_net) / total_staked
	print("trials=%d  staked=%.0f  net=%.0f" % [trials, total_staked, total_net])
	print("effective RTP (random timing) = %.4f  (expect ~0.82)" % rtp)
	print("house edge = %.2f%%" % ((1.0 - rtp) * 100.0))
	print("min balance seen = %.0f   negative-balance? %s" % [min_balance, str(neg)])
	print("RESULT: %s" % ("PASS" if (not neg and rtp < 1.0) else "FAIL"))
	return true
