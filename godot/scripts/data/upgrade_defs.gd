class_name UpgradeDefs
extends RefCounted

const _RAW: Array = [
	["Quick Hands", "2x click value", 100.0, "double_click"],
	["Iron Knuckles", "4x click value", 150_000.0, "quad_click"],
	["God Finger", "8x click value", 20_000_000.0, "octo_click"],
	["Phantom Touch", "16x click value", 2_000_000_000.0, "hex_click"],
	["Hustle Harder", "2x Corner Dealer income", 300.0, "bld0_2x"],
	["Iron Grip", "2x Protection Racket income", 3_000.0, "bld1_2x"],
	["Better Tools", "2x Chop Shop income", 30_000.0, "bld2_2x"],
	["Loaded Dice", "2x Betting Ring income", 250_000.0, "bld3_2x"],
	["Premium Junk", "2x Pawn Shop income", 2_000_000.0, "bld4_2x"],
	["Higher Interest", "2x Loan Shark income", 15_000_000.0, "bld5_2x"],
	["High Roller Tables", "2x Casino income", 120_000_000.0, "bld6_2x"],
	["VIP Section", "2x Nightclub income", 900_000_000.0, "bld7_2x"],
	["Faster Ships", "2x Dock income", 7_000_000_000.0, "bld8_2x"],
	["Black Market Bulk", "2x Arms Broker income", 50_000_000_000.0, "bld9_2x"],
	["Shadow Franchise", "2x Syndicate HQ income", 400_000_000_000.0, "bld10_2x"],
	["Shadow Step", "4x Corner Dealer income", 8_000_000.0, "bld0_4x"],
	["Concrete Reputation", "4x Protection Racket income", 50_000_000.0, "bld1_4x"],
	["Chop Shop Pro", "4x Chop Shop income", 500_000_000.0, "bld2_4x"],
	["Fixed Fights", "4x Betting Ring income", 5_000_000_000.0, "bld3_4x"],
	["Hot Goods Network", "4x Pawn Shop income", 40_000_000_000.0, "bld4_4x"],
	["Kneecap Special", "4x Loan Shark income", 300_000_000_000.0, "bld5_4x"],
	["Stacked Deck", "4x Casino income", 2_000_000_000_000.0, "bld6_4x"],
	["Grand Reinvestment", "2x ALL building income", 10_000_000_000.0, "all_2x"],
	["Crime Conglomerate", "4x ALL building income", 20_000_000_000_000.0, "all_4x"],
	["Prestige Mastery", "Income up to +150%, scales with tokens", 500_000.0, "prestige_boost"],
]


static func make_upgrades() -> Array[Upgrade]:
	var out: Array[Upgrade] = []
	for row in _RAW:
		out.append(Upgrade.new(row[0], row[1], row[2], row[3]))
	return out


static func effective_cost(u: Upgrade, state) -> float:
	var discount := BuildingDefs.pawn_cost_reduction(state.buildings)
	return u.cost * (1.0 - discount)


static func apply_effect(u: Upgrade, state) -> void:
	var key := u.effect_key
	if key.begins_with("bld") and ("_2x" in key or "_4x" in key):
		var idx := _building_index_from_key(key)
		var mult := 2.0 if key.ends_with("_2x") else 4.0
		if idx >= 0 and idx < state.buildings.size():
			state.buildings[idx].income_multiplier *= mult
	elif key == "all_2x":
		for b in state.buildings:
			b.income_multiplier *= 2.0
	elif key == "all_4x":
		for b in state.buildings:
			b.income_multiplier *= 4.0
	# click / prestige_boost handled dynamically in GameState


static func _building_index_from_key(key: String) -> int:
	if not key.begins_with("bld"):
		return -1
	var rest := key.substr(3)
	var under := rest.find("_")
	if under < 0:
		return -1
	return int(rest.substr(0, under))


static func click_multiplier(upgrades: Array[Upgrade]) -> float:
	var mult := 1.0
	for u in upgrades:
		if not u.purchased:
			continue
		match u.effect_key:
			"double_click":
				mult *= 2.0
			"quad_click":
				mult *= 4.0
			"octo_click":
				mult *= 8.0
			"hex_click":
				mult *= 16.0
	return mult


static func has_prestige_boost(upgrades: Array[Upgrade]) -> bool:
	for u in upgrades:
		if u.purchased and u.effect_key == "prestige_boost":
			return true
	return false
