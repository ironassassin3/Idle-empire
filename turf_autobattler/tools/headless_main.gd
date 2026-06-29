extends Node

func _ready() -> void:
	var args := _parse_args()
	var seed_value := int(args.get("seed", 12345))
	var iterations := int(args.get("iterations", 100))
	var verbose := args.has("per-round") or args.has("verbose")
	var wins := 0
	var total_ticks := 0
	var total_rounds := 0
	var max_round := 0
	var round_played := {}
	var round_won := {}
	var round_draw := {}
	var round_timeout := {}
	var round_level := {}
	var round_fielded := {}
	var round_enemy := {}
	var round_gold := {}
	for i in iterations:
		var result := _simulate_run(seed_value + i)
		if result["won"]:
			wins += 1
		total_ticks += result["combat_ticks"]
		total_rounds += int(result["round_reached"])
		max_round = max(max_round, int(result["round_reached"]))
		for rr in result["per_round"]:
			var r := int(rr["round"])
			round_played[r] = int(round_played.get(r, 0)) + 1
			if rr["won"]:
				round_won[r] = int(round_won.get(r, 0)) + 1
			if rr["draw"]:
				round_draw[r] = int(round_draw.get(r, 0)) + 1
			if rr["timeout"]:
				round_timeout[r] = int(round_timeout.get(r, 0)) + 1
			round_level[r] = float(round_level.get(r, 0.0)) + float(rr["level"])
			round_fielded[r] = float(round_fielded.get(r, 0.0)) + float(rr["fielded"])
			round_gold[r] = float(round_gold.get(r, 0.0)) + float(rr["gold"])
			round_enemy[r] = int(rr["enemy"])
	print("HeadlessRunner seed=%d iterations=%d win_rate=%.2f avg_ticks=%.1f avg_round=%.1f max_round=%d" % [
		seed_value,
		iterations,
		float(wins) / float(iterations),
		float(total_ticks) / float(iterations),
		float(total_rounds) / float(iterations),
		max_round,
	])
	if verbose:
		print("Per-round diagnostics (board=avg units fielded, enemy=enemy units, draws=tick-cap draws):")
		print("  rnd  win%  avg_lvl  board  enemy  avg_gold  draws")
		for r in range(1, SimConstants.MAX_ROUNDS + 1):
			var played := int(round_played.get(r, 0))
			if played == 0:
				continue
			var won := int(round_won.get(r, 0))
			print("  %3d  %4.2f  %7.1f  %5.1f  %5d  %8.1f  %5d" % [
				r,
				float(won) / float(played),
				float(round_level.get(r, 0.0)) / float(played),
				float(round_fielded.get(r, 0.0)) / float(played),
				int(round_enemy.get(r, 0)),
				float(round_gold.get(r, 0.0)) / float(played),
				int(round_draw.get(r, 0)),
			])
	var lobby_ok := _test_lobby_state()
	var match_ok := _test_match_local_bots()
	var golden_ok := _test_golden_replays()
	get_tree().quit(0 if lobby_ok and match_ok and golden_ok else 1)


func _simulate_run(run_seed: int) -> Dictionary:
	var director := RunDirector.new()
	director.start_run(run_seed)
	var final_won := false
	var per_round: Array = []
	while director.state.phase != SimConstants.RunPhase.RUN_END and director.state.round <= SimConstants.MAX_ROUNDS:
		_auto_buy_and_place(director)
		var played_round := director.state.round
		var fielded := director.state.board.count_units()
		var lvl := director.state.level
		var gold_left := director.state.gold
		director.submit_intent(PlayerIntent.make("LOCK_BOARD"))
		director.finish_playback()
		var combat := director.state.last_combat
		per_round.append({
			"round": played_round,
			"won": director.state.last_combat_won,
			"hp": director.state.player_hp,
			"level": lvl,
			"fielded": fielded,
			"enemy": _enemy_size_for_round(played_round),
			"gold": gold_left,
			"draw": combat != null and combat.outcome == SimConstants.CombatOutcome.DRAW,
			"timeout": combat != null and combat.tick >= SimConstants.MAX_COMBAT_TICKS,
		})
		final_won = director.state.last_combat_won
		if director.state.phase == SimConstants.RunPhase.RUN_END:
			final_won = director.state.run_won
			break
	var ticks := 0
	if director.state.last_combat != null:
		ticks = director.state.last_combat.tick
	return {
		"won": final_won,
		"combat_ticks": ticks,
		"round_reached": director.state.round,
		"per_round": per_round,
	}


const MAX_REROLLS_PER_ROUND := 4
const REROLL_GOLD_RESERVE := 1
const LEVEL_PUSH_GOLD_RESERVE := 6


func _auto_buy_and_place(director: RunDirector) -> void:
	var state := director.state
	# Option B "competent baseline": TFT-style leveling + reroll/tier-greedy
	# buying + keep-best placement spread across rows. Combat targeting is
	# row-based (the `range` stat is unused), so units are distributed across
	# rows; with no unit merges in v1, surplus units are sold back for gold.

	# 1. Level toward the enemy's board size so we are not outnumbered.
	var target_size := _enemy_size_for_round(state.round)
	while state.board.max_units < target_size \
			and state.level < SimConstants.MAX_LEVEL \
			and state.gold >= SimConstants.XP_BUY_COST:
		if director.submit_intent(PlayerIntent.make("BUY_XP")) != SimConstants.RejectReason.OK:
			break

	# 1b. With surplus gold, push level further for better shop odds (TFT-style
	#     "level for power"); keep a reserve so we can still buy units.
	var odds_target_level: int = mini(2 + state.round / 2, SimConstants.MAX_LEVEL)
	while state.level < odds_target_level \
			and state.gold >= SimConstants.XP_BUY_COST + LEVEL_PUSH_GOLD_RESERVE:
		if director.submit_intent(PlayerIntent.make("BUY_XP")) != SimConstants.RejectReason.OK:
			break

	# 2. Buy the strongest affordable offers; reroll surplus gold to dig for
	#    higher-tier units (they only appear once level >= their tier).
	_buy_affordable(director)
	var rerolls := 0
	while rerolls < MAX_REROLLS_PER_ROUND \
			and state.bench.first_empty_slot() >= 0 \
			and state.gold >= SimConstants.REROLL_COST + REROLL_GOLD_RESERVE:
		if director.submit_intent(PlayerIntent.make("REROLL_SHOP")) != SimConstants.RejectReason.OK:
			break
		_buy_affordable(director)
		rerolls += 1

	# 3. Field the strongest `cap` units (spread across rows); sell the rest.
	_field_strongest(director)


func _buy_affordable(director: RunDirector) -> void:
	var state := director.state
	var order: Array = []
	for i in state.shop.offers.size():
		if state.shop.offers[i] != null:
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _def_strength(String(state.shop.offers[a])) > _def_strength(String(state.shop.offers[b])))
	for i in order:
		if state.shop.offers[i] == null or state.bench.first_empty_slot() < 0:
			continue
		var def := UnitRegistry.get_def(String(state.shop.offers[i]))
		if state.gold >= int(def.get("cost", 0)):
			director.submit_intent(PlayerIntent.make("BUY_FROM_SHOP", {"index": i}))


func _field_strongest(director: RunDirector) -> void:
	var state := director.state
	var cap: int = state.board.max_units
	var owned: Array = state.units.keys()
	owned.sort_custom(func(a: int, b: int) -> bool:
		return _def_strength(state.units[a].def_id) > _def_strength(state.units[b].def_id))
	var keepers: Dictionary = {}
	for idx in range(mini(cap, owned.size())):
		keepers[owned[idx]] = true
	# No merges in v1, so anything we will not field is just gold.
	for iid in owned:
		if not keepers.has(iid):
			director.submit_intent(PlayerIntent.make("SELL", {"instance_id": iid}))
	# Place each keeper not already on the board into the next spread cell.
	for iid in keepers.keys():
		var unit: UnitInstance = state.units[iid]
		if unit.grid_pos.x >= 0:
			continue
		var cell := _first_empty_spread_cell(state.board)
		if cell.x < 0:
			break
		director.submit_intent(PlayerIntent.make("MOVE_TO_BOARD", {"instance_id": iid, "grid_pos": cell}))


func _first_empty_spread_cell(board: BoardState) -> Vector2i:
	# Column-major: fill rows 0..H-1 of a column before moving right, so a small
	# board still spans multiple rows (row-based targeting matches more enemies).
	for col in range(SimConstants.BOARD_WIDTH):
		for row in range(SimConstants.BOARD_HEIGHT):
			var cell := Vector2i(col, row)
			if board.get_unit_at(cell) == null:
				return cell
	return Vector2i(-1, -1)


func _def_strength(def_id: String) -> int:
	var def := UnitRegistry.get_def(def_id)
	var stats: Dictionary = def.get("base_stats", {})
	return int(def.get("tier", 0)) * 100000 + int(def.get("cost", 0)) * 10000 + int(stats.get("max_hp", 0))


func _enemy_size_for_round(round_num: int) -> int:
	return RivalCompRegistry.get_comp_for_round(round_num).get("units", []).size()


func _test_match_local_bots() -> bool:
	var ok := MatchHarness.run_determinism_check()
	print("MatchLocal8Bot determinism %s" % ["OK" if ok else "FAIL"])
	return ok


func _test_lobby_state() -> bool:
	var all_ok := true
	all_ok = _assert_lobby("lifecycle_waiting_to_running", _lobby_test_lifecycle()) and all_ok
	all_ok = _assert_lobby("match_seed_deterministic", _lobby_test_match_seed()) and all_ok
	all_ok = _assert_lobby("snapshot_roundtrip", _lobby_test_snapshot()) and all_ok
	all_ok = _assert_lobby("invalid_transitions", _lobby_test_invalid_transitions()) and all_ok
	all_ok = _assert_lobby("player_rng_derivation", _lobby_test_player_rng()) and all_ok
	all_ok = _assert_lobby("eight_player_lock", _lobby_test_eight_player_lock()) and all_ok
	return all_ok


func _assert_lobby(name: String, ok: bool) -> bool:
	print("LobbyStateTest %s %s" % [name, "OK" if ok else "FAIL"])
	return ok


func _lobby_test_lifecycle() -> bool:
	var lobby := LobbyState.new()
	if lobby.phase != LobbyState.Phase.LOBBY_WAITING:
		return false
	if lobby.add_player(2) != LobbyState.LobbyRejectReason.OK:
		return false
	if lobby.set_ready(2, true) != LobbyState.LobbyRejectReason.OK:
		return false
	if lobby.lock_lobby(true) != LobbyState.LobbyRejectReason.OK:
		return false
	if lobby.phase != LobbyState.Phase.LOBBY_LOCKED or lobby.match_seed <= 0:
		return false
	if lobby.start_match() != LobbyState.LobbyRejectReason.OK:
		return false
	if lobby.phase != LobbyState.Phase.MATCH_RUNNING or lobby.round != 1:
		return false
	if lobby.run_phase != SimConstants.RunPhase.PLANNING:
		return false
	if lobby.eliminate_player(0) != LobbyState.LobbyRejectReason.OK:
		return false
	if lobby.phase != LobbyState.Phase.MATCH_ENDED:
		return false
	if lobby.reset_to_lobby() != LobbyState.LobbyRejectReason.OK:
		return false
	return lobby.phase == LobbyState.Phase.LOBBY_WAITING and lobby.match_seed == 0


func _lobby_test_match_seed() -> bool:
	var lobby_a := LobbyState.new()
	var lobby_b := LobbyState.new()
	var peer_ids := [2, 5, 3, 9, 4, 7, 6, 8]
	for peer_id in peer_ids:
		if lobby_a.add_player(peer_id) != LobbyState.LobbyRejectReason.OK:
			return false
		if lobby_b.add_player(peer_id) != LobbyState.LobbyRejectReason.OK:
			return false
	if lobby_a.lock_lobby(true) != LobbyState.LobbyRejectReason.OK:
		return false
	if lobby_b.lock_lobby(true) != LobbyState.LobbyRejectReason.OK:
		return false
	if lobby_a.match_seed != lobby_b.match_seed:
		return false
	var expected := LobbyState.derive_match_seed(peer_ids)
	return lobby_a.match_seed == expected


func _lobby_test_snapshot() -> bool:
	var lobby := LobbyState.new()
	for peer_id in [2, 3, 4]:
		lobby.add_player(peer_id)
		lobby.set_ready(peer_id, true)
	lobby.lock_lobby(true)
	lobby.start_match()
	var before := lobby.dto_fingerprint()
	var copy := lobby.duplicate_state()
	if copy.dto_fingerprint() != before:
		return false
	copy.eliminate_player(1)
	return lobby.dto_fingerprint() == before


func _lobby_test_invalid_transitions() -> bool:
	var lobby := LobbyState.new()
	if lobby.start_match() != LobbyState.LobbyRejectReason.WRONG_PHASE:
		return false
	if lobby.add_player(2) != LobbyState.LobbyRejectReason.OK:
		return false
	if lobby.lock_lobby(false) != LobbyState.LobbyRejectReason.NOT_ALL_READY:
		return false
	if lobby.start_match() != LobbyState.LobbyRejectReason.WRONG_PHASE:
		return false
	if lobby.lock_lobby(true) != LobbyState.LobbyRejectReason.OK:
		return false
	if lobby.add_player(3) != LobbyState.LobbyRejectReason.WRONG_PHASE:
		return false
	if lobby.reset_to_lobby() != LobbyState.LobbyRejectReason.WRONG_PHASE:
		return false
	return true


func _lobby_test_player_rng() -> bool:
	var match_seed := 424242
	var player_id := 3
	var expected := LobbyState.derive_player_rng_seed(match_seed, player_id)
	return expected == maxi(1, match_seed ^ player_id)


func _lobby_test_eight_player_lock() -> bool:
	var lobby := LobbyState.new()
	for peer_id in range(2, 10):
		if lobby.add_player(peer_id) != LobbyState.LobbyRejectReason.OK:
			return false
	if lobby.add_player(10) != LobbyState.LobbyRejectReason.LOBBY_FULL:
		return false
	if lobby.lock_lobby(false) != LobbyState.LobbyRejectReason.OK:
		return false
	var dto: Dictionary = lobby.to_dto()
	return int(dto["players"].size()) == 8 and lobby.match_seed > 0


func _test_golden_replays() -> bool:
	var file := FileAccess.open("res://tests/golden_replays/cases.json", FileAccess.READ)
	if file == null:
		push_error("Missing golden replay cases.json")
		return false
	var cases: Array = JSON.parse_string(file.get_as_text())
	var all_ok := true
	for case in cases:
		var built := {
			"seed": int(case.get("seed", 0)),
			"player": [],
			"enemy": [],
		}
		for entry in case.get("player", []):
			built["player"].append({
				"def_id": entry[0] if entry is Array else entry.get("def_id", ""),
				"pos": Vector2i(int(entry[1][0]), int(entry[1][1])) if entry is Array else Vector2i(int(entry["pos"][0]), int(entry["pos"][1])),
			})
		for entry in case.get("enemy", []):
			built["enemy"].append({
				"def_id": entry[0] if entry is Array else entry.get("def_id", ""),
				"pos": Vector2i(int(entry[1][0]), int(entry[1][1])) if entry is Array else Vector2i(int(entry["pos"][0]), int(entry["pos"][1])),
			})
		var hash_value := int(_combat_hash(built))
		var expected := int(case.get("expected_hash", -1))
		var ok := hash_value == expected
		all_ok = all_ok and ok
		print("GoldenReplay %s seed=%d hash=%d expected=%d %s" % [
			case.get("name", "?"), built["seed"], hash_value, expected, "OK" if ok else "FAIL",
		])
	return all_ok


func _combat_hash(case: Dictionary) -> String:
	var rng := SeededRNG.from_seed(int(case["seed"]))
	var player_entries: Array = []
	var next_id := 1
	for entry in case["player"]:
		var unit := UnitInstance.new()
		unit.instance_id = next_id
		unit.def_id = String(entry["def_id"])
		player_entries.append({"unit": unit, "pos": entry["pos"]})
		next_id += 1
	var enemy_entries: Array = []
	for entry in case["enemy"]:
		var unit := UnitInstance.new()
		unit.instance_id = next_id
		unit.def_id = String(entry["def_id"])
		enemy_entries.append({"unit": unit, "pos": entry["pos"]})
		next_id += 1
	var board := BoardState.new()
	var combat := CombatResolver.build_combat_state(player_entries, enemy_entries, board, rng, 1)
	combat = CombatResolver.resolve(combat, board)
	var joined := ""
	for event in combat.event_log.events:
		joined += "%s:%s|" % [event.get("type", ""), str(event)]
	return str(joined.hash())


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var body := arg.substr(2)
			var eq := body.find("=")
			if eq >= 0:
				result[body.substr(0, eq)] = body.substr(eq + 1)
	return result
