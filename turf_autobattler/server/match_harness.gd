class_name MatchHarness
extends RefCounted

## Shared headless match runners for CI and cross-process determinism checks.

const BOT_COUNT := 8
const MAX_MATCH_STEPS := 512


static func run_local_bot_match(server: MatchServer, bot_count: int = BOT_COUNT) -> Dictionary:
	server.reset_match()
	for peer_id in range(2, 2 + bot_count):
		server.join_peer(peer_id)
		server.set_peer_ready(peer_id, true)
	server.lock_and_start_match(true)
	var steps := 0
	while server.lobby.phase == LobbyState.Phase.MATCH_RUNNING and steps < MAX_MATCH_STEPS:
		server.run_bot_round_step(Callable(MatchBotAi, "auto_buy_and_place"))
		steps += 1
	return {
		"result": server.get_match_result(),
		"steps": steps,
		"finished": server.lobby.phase == LobbyState.Phase.MATCH_ENDED,
	}


static func fingerprint(result: Dictionary) -> int:
	return str(result["lobby_dto"]).hash()


static func run_determinism_check(bot_count: int = BOT_COUNT) -> bool:
	var server_a := MatchServer.new()
	var run_a := run_local_bot_match(server_a, bot_count)
	if not run_a["finished"]:
		return false
	var server_b := MatchServer.new()
	var run_b := run_local_bot_match(server_b, bot_count)
	if not run_b["finished"]:
		return false
	return fingerprint(run_a["result"]) == fingerprint(run_b["result"])
