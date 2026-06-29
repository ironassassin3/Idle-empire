class_name RivalCompRegistry
extends RefCounted

## Scripted enemy lineups by round band.

static var COMPS: Array[Dictionary] = [
	{
		# Round 1: single weak creep — a gentle TFT-style opening the player
		# can clear with their level-1 board instead of being outnumbered.
		"round_min": 1, "round_max": 1,
		"units": [
			{"def_id": "lookout", "stars": 1, "grid_pos": Vector2i(1, 1)},
		],
	},
	{
		"round_min": 2, "round_max": 2,
		"units": [
			{"def_id": "corner_boy", "stars": 1, "grid_pos": Vector2i(1, 0)},
			{"def_id": "lookout", "stars": 1, "grid_pos": Vector2i(2, 1)},
		],
	},
	{
		"round_min": 3, "round_max": 3,
		"units": [
			{"def_id": "enforcer", "stars": 1, "grid_pos": Vector2i(1, 0)},
			{"def_id": "corner_boy", "stars": 1, "grid_pos": Vector2i(0, 1)},
			{"def_id": "lookout", "stars": 1, "grid_pos": Vector2i(3, 2)},
		],
	},
	{
		"round_min": 4, "round_max": 4,
		"units": [
			{"def_id": "enforcer", "stars": 1, "grid_pos": Vector2i(1, 0)},
			{"def_id": "fixer", "stars": 1, "grid_pos": Vector2i(2, 2)},
			{"def_id": "runner", "stars": 1, "grid_pos": Vector2i(0, 1)},
		],
	},
	{
		"round_min": 5, "round_max": 5,
		"units": [
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(1, 0)},
			{"def_id": "enforcer", "stars": 1, "grid_pos": Vector2i(0, 1)},
			{"def_id": "lookout", "stars": 1, "grid_pos": Vector2i(3, 2)},
		],
	},
	{
		"round_min": 6, "round_max": 7,
		"units": [
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(1, 0)},
			{"def_id": "medic", "stars": 1, "grid_pos": Vector2i(2, 2)},
			{"def_id": "runner", "stars": 1, "grid_pos": Vector2i(0, 1)},
			{"def_id": "courier", "stars": 1, "grid_pos": Vector2i(3, 1)},
		],
	},
	{
		"round_min": 8, "round_max": 9,
		"units": [
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(1, 0)},
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(2, 0)},
			{"def_id": "medic", "stars": 1, "grid_pos": Vector2i(0, 2)},
			{"def_id": "courier", "stars": 1, "grid_pos": Vector2i(3, 1)},
		],
	},
	{
		"round_min": 10, "round_max": 11,
		"units": [
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(0, 0)},
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(2, 0)},
			{"def_id": "enforcer", "stars": 1, "grid_pos": Vector2i(1, 1)},
			{"def_id": "medic", "stars": 1, "grid_pos": Vector2i(3, 2)},
			{"def_id": "courier", "stars": 1, "grid_pos": Vector2i(0, 2)},
		],
	},
	{
		"round_min": 12, "round_max": 13,
		"units": [
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(0, 0)},
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(2, 0)},
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(1, 1)},
			{"def_id": "medic", "stars": 1, "grid_pos": Vector2i(3, 2)},
			{"def_id": "courier", "stars": 1, "grid_pos": Vector2i(0, 2)},
		],
	},
	{
		# Final comp: keep 6 units of pressure, but the 6th is a Runner (DPS),
		# not a 4th enforcer-tag — otherwise 3 Heavies + Enforcer trip the
		# Enforcer 4-piece (+60 armor) and the wall becomes unbreakable.
		"round_min": 14, "round_max": 99,
		"units": [
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(0, 0)},
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(2, 0)},
			{"def_id": "heavy", "stars": 1, "grid_pos": Vector2i(1, 1)},
			{"def_id": "medic", "stars": 1, "grid_pos": Vector2i(3, 2)},
			{"def_id": "courier", "stars": 1, "grid_pos": Vector2i(0, 2)},
			{"def_id": "runner", "stars": 1, "grid_pos": Vector2i(3, 0)},
		],
	},
]


static func get_comp_for_round(round_num: int) -> Dictionary:
	for comp in COMPS:
		if round_num >= int(comp["round_min"]) and round_num <= int(comp["round_max"]):
			return comp.duplicate(true)
	return COMPS.back().duplicate(true)
