class_name UnitRegistry
extends RefCounted

## Static unit definitions — copied into instances at creation time.

static var DEFS: Dictionary = {
	"corner_boy": {
		"id": "corner_boy",
		"display_name": "Corner Boy",
		"tier": 1,
		"cost": 1,
		"tags": ["street"],
		"base_stats": {"max_hp": 450, "attack": 45, "attack_speed": 0.7, "armor": 15, "range": 1},
		"ability_id": null,
		"sell_value": 1,
		"pool_count": 29,
	},
	"lookout": {
		"id": "lookout",
		"display_name": "Lookout",
		"tier": 1,
		"cost": 1,
		"tags": ["street"],
		"base_stats": {"max_hp": 380, "attack": 35, "attack_speed": 0.9, "armor": 10, "range": 2},
		"ability_id": null,
		"sell_value": 1,
		"pool_count": 29,
	},
	"dealer": {
		# Tier-1 Smuggler: cheap glass cannon. Completes the smuggler line
		# (Dealer -> Runner -> Courier) and makes the Smuggler 3-piece reachable.
		"id": "dealer",
		"display_name": "Dealer",
		"tier": 1,
		"cost": 1,
		"tags": ["smuggler"],
		"base_stats": {"max_hp": 360, "attack": 40, "attack_speed": 1.05, "armor": 8, "range": 1},
		"ability_id": null,
		"sell_value": 1,
		"pool_count": 29,
	},
	"thug": {
		# Tier-1 Enforcer: cheap bruiser. Gives the Enforcer line a tier-1 entry
		# (Thug -> Enforcer -> Heavy) so the Enforcer 3-piece is reachable.
		"id": "thug",
		"display_name": "Thug",
		"tier": 1,
		"cost": 1,
		"tags": ["enforcer", "street"],
		"base_stats": {"max_hp": 520, "attack": 42, "attack_speed": 0.7, "armor": 28, "range": 1},
		"ability_id": null,
		"sell_value": 1,
		"pool_count": 29,
	},
	"lawyer": {
		# Tier-1 Fixer: cheap backline support. Gives the Fixer line a tier-1
		# entry (Lawyer -> Fixer -> Medic) so the Fixer 3-piece is reachable.
		"id": "lawyer",
		"display_name": "Lawyer",
		"tier": 1,
		"cost": 1,
		"tags": ["fixer"],
		"base_stats": {"max_hp": 420, "attack": 32, "attack_speed": 0.85, "armor": 14, "range": 2},
		"ability_id": null,
		"sell_value": 1,
		"pool_count": 29,
	},
	"enforcer": {
		"id": "enforcer",
		"display_name": "Enforcer",
		"tier": 2,
		"cost": 2,
		"tags": ["enforcer", "street"],
		"base_stats": {"max_hp": 650, "attack": 55, "attack_speed": 0.65, "armor": 35, "range": 1},
		"ability_id": null,
		"sell_value": 2,
		"pool_count": 22,
	},
	"fixer": {
		"id": "fixer",
		"display_name": "Fixer",
		"tier": 2,
		"cost": 2,
		"tags": ["fixer"],
		"base_stats": {"max_hp": 520, "attack": 40, "attack_speed": 0.75, "armor": 20, "range": 2},
		"ability_id": null,
		"sell_value": 2,
		"pool_count": 22,
	},
	"runner": {
		"id": "runner",
		"display_name": "Runner",
		"tier": 2,
		"cost": 2,
		"tags": ["smuggler"],
		"base_stats": {"max_hp": 480, "attack": 50, "attack_speed": 1.0, "armor": 15, "range": 1},
		"ability_id": null,
		"sell_value": 2,
		"pool_count": 22,
	},
	"heavy": {
		"id": "heavy",
		"display_name": "Heavy",
		"tier": 3,
		"cost": 3,
		"tags": ["enforcer"],
		"base_stats": {"max_hp": 900, "attack": 65, "attack_speed": 0.55, "armor": 50, "range": 1},
		"ability_id": null,
		"sell_value": 3,
		"pool_count": 18,
	},
	"medic": {
		"id": "medic",
		"display_name": "Medic",
		"tier": 3,
		"cost": 3,
		"tags": ["fixer"],
		"base_stats": {"max_hp": 600, "attack": 35, "attack_speed": 0.8, "armor": 25, "range": 2},
		"ability_id": null,
		"sell_value": 3,
		"pool_count": 18,
	},
	"courier": {
		"id": "courier",
		"display_name": "Courier",
		"tier": 3,
		"cost": 3,
		"tags": ["smuggler", "street"],
		"base_stats": {"max_hp": 550, "attack": 60, "attack_speed": 1.1, "armor": 20, "range": 1},
		"ability_id": null,
		"sell_value": 3,
		"pool_count": 18,
	},
}


static func get_def(def_id: String) -> Dictionary:
	return DEFS.get(def_id, {}).duplicate(true)


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in DEFS.keys():
		ids.append(String(key))
	return ids
