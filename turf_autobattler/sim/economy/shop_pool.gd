class_name ShopPool
extends RefCounted

var remaining: Dictionary = {}


static func create_default() -> ShopPool:
	var pool := ShopPool.new()
	for def_id in UnitRegistry.all_ids():
		var def := UnitRegistry.get_def(def_id)
		pool.remaining[def_id] = int(def.get("pool_count", 0))
	return pool


func buy(def_id: String) -> bool:
	if not remaining.has(def_id) or int(remaining[def_id]) <= 0:
		return false
	remaining[def_id] = int(remaining[def_id]) - 1
	return true


func return_unit(def_id: String) -> void:
	if not remaining.has(def_id):
		remaining[def_id] = 0
	remaining[def_id] = int(remaining[def_id]) + 1


func roll(player_level: int, rng: SeededRNG, slot_count: int = SimConstants.SHOP_SLOTS) -> Array:
	var offers: Array = []
	for _i in slot_count:
		offers.append(_roll_one(player_level, rng))
	return offers


# TFT-style shop odds: probability weights (out of 100) for tiers [1, 2, 3]
# by player level. Higher levels shift the roll toward stronger units, so
# spending gold on XP is a real "dig for power" decision, not just a board cap.
const TIER_ODDS_BY_LEVEL := {
	1: [100, 0, 0],
	2: [75, 25, 0],
	3: [55, 35, 10],
	4: [45, 35, 20],
	5: [35, 35, 30],
	6: [25, 40, 35],
	7: [20, 35, 45],
	8: [15, 30, 55],
}


func _roll_one(player_level: int, rng: SeededRNG):
	# Group remaining stock by tier (deterministic: keys sorted before use).
	var by_tier := {}
	for def_id in remaining.keys():
		if int(remaining[def_id]) <= 0:
			continue
		var def := UnitRegistry.get_def(String(def_id))
		var tier := int(def.get("tier", 1))
		if not by_tier.has(tier):
			by_tier[tier] = []
		by_tier[tier].append(String(def_id))
	if by_tier.is_empty():
		return null
	var odds: Array = TIER_ODDS_BY_LEVEL[clampi(player_level, 1, 8)]
	# Weighted tier selection over tiers that have stock and nonzero odds.
	var tiers: Array = by_tier.keys()
	tiers.sort()
	var weighted: Array = []
	var total := 0
	for tier in tiers:
		var w: int = int(odds[tier - 1]) if tier - 1 < odds.size() else 0
		if w > 0:
			weighted.append({"tier": tier, "weight": w})
			total += w
	var chosen_tier := -1
	if total > 0:
		var roll := rng.next_int(0, total - 1)
		var acc := 0
		for entry in weighted:
			acc += int(entry["weight"])
			if roll < acc:
				chosen_tier = int(entry["tier"])
				break
	if chosen_tier < 0:
		chosen_tier = int(tiers[0])  # fallback: lowest tier still in stock
	var pool_list: Array = by_tier[chosen_tier]
	pool_list.sort()
	return pool_list[rng.next_int(0, pool_list.size() - 1)]
