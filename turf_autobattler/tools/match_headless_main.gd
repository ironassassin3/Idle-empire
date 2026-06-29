extends Node

## Headless harness — 8-bot authoritative match + optional ENet RPC smoke + fingerprint export.

func _ready() -> void:
	var args := _parse_args()
	var run_enet := args.has("enet-smoke")
	if args.has("print-fingerprint"):
		var server := MatchServer.new()
		var run := MatchHarness.run_local_bot_match(server)
		print("MATCH_FINGERPRINT=%d" % MatchHarness.fingerprint(run["result"]))
		get_tree().quit(0 if run["finished"] else 1)
		return
	var local_ok := MatchHarness.run_determinism_check()
	print("MatchHeadless local determinism %s" % ["OK" if local_ok else "FAIL"])
	var enet_ok := true
	if run_enet:
		enet_ok = await _test_enet_rpc_smoke()
		print("MatchHeadless enet RPC smoke %s" % ["OK" if enet_ok else "FAIL"])
	get_tree().quit(0 if local_ok and enet_ok else 1)


func _test_enet_rpc_smoke() -> bool:
	var server := MatchServer.new()
	add_child(server)
	server.configure_headless(MatchServer.DEFAULT_PORT)
	if server.start_enet_server(MatchServer.DEFAULT_PORT) != OK:
		return false
	await get_tree().process_frame
	var bot := MatchBot.new()
	add_child(bot)
	bot.configure(server.get_path(), Callable(MatchBotAi, "auto_buy_and_place"))
	if bot.connect_to_server(MatchServer.DEFAULT_PORT) != OK:
		return false
	for _i in 120:
		await get_tree().process_frame
		if server.lobby.get_player_count() >= 1:
			break
	if server.lock_and_start_match(true) != OK:
		return false
	bot.play_planning_round()
	await get_tree().process_frame
	server.stop_enet()
	bot.disconnect_from_server()
	return server.lobby.phase == LobbyState.Phase.MATCH_RUNNING


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var body := arg.substr(2)
			var eq := body.find("=")
			if eq >= 0:
				result[body.substr(0, eq)] = body.substr(eq + 1)
			else:
				result[body] = "1"
	return result
