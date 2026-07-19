extends SceneTree
## Headless validation of the cash-wager casino through the real GameState path.
##   "<godot>" --headless --path godot -s res://scripts/tools/wager_probe.gd
## Confirms: balance never goes negative, stake is always debited, the exact
## payout invariant payout == stake * band * WAGER_RTP holds, and the fixed
## house edge (RTP ~0.90) holds across many pure-RNG wagers.

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
	var trials := 200000
	var total_staked := 0.0
	var total_net := 0.0
	var min_balance: float = gs.balance
	var neg := false
	var bad_payout := false
	for i in trials:
		if gs.balance < 1000.0:
			gs.balance += 1_000_000.0
		var stake := 100.0
		var before: float = gs.balance
		var res: Dictionary = gs.place_wager(stake)
		var net: float = gs.balance - before
		# Exact-payout invariant: payout == stake * band * WAGER_RTP (0.90).
		var expect_net: float = stake * (float(res.get("band", 0.0)) * 0.90 - 1.0)
		if absf(net - expect_net) > 0.001:
			bad_payout = true
		total_staked += stake
		total_net += net
		min_balance = minf(min_balance, gs.balance)
		if gs.balance < 0.0:
			neg = true
	var rtp := (total_staked + total_net) / total_staked
	print("trials=%d  staked=%.0f  net=%.0f" % [trials, total_staked, total_net])
	print("effective RTP = %.4f  (expect ~0.90)" % rtp)
	print("house edge = %.2f%%" % [(1.0 - rtp) * 100.0])
	print("min balance seen = %.0f   negative-balance? %s" % [min_balance, str(neg)])
	print("exact-payout invariant holds? %s" % str(not bad_payout))
	var ok := not neg and not bad_payout and rtp < 1.0 and absf(rtp - 0.90) < 0.01
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	return true
