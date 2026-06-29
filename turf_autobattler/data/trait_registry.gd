class_name TraitRegistry
extends RefCounted

static var DEFS: Dictionary = {
	"enforcer": {
		"id": "enforcer",
		"display_name": "Enforcer",
		"tag_filter": "enforcer",
		"breakpoints": [
			{"count": 2, "effects": [{"effect_id": "armor_bonus", "params": {"amount": 25}}]},
			{"count": 4, "effects": [{"effect_id": "armor_bonus", "params": {"amount": 60}}]},
		],
	},
	"fixer": {
		"id": "fixer",
		"display_name": "Fixer",
		"tag_filter": "fixer",
		"breakpoints": [
			{"count": 2, "effects": [{"effect_id": "heal_on_combat_start", "params": {"amount": 80}}]},
			{"count": 4, "effects": [{"effect_id": "heal_on_combat_start", "params": {"amount": 200}}]},
		],
	},
	"smuggler": {
		"id": "smuggler",
		"display_name": "Smuggler",
		"tag_filter": "smuggler",
		"breakpoints": [
			{"count": 2, "effects": [{"effect_id": "attack_speed_bonus", "params": {"mult": 1.15}}]},
			{"count": 3, "effects": [{"effect_id": "attack_speed_bonus", "params": {"mult": 1.3}}]},
		],
	},
	"street": {
		"id": "street",
		"display_name": "Street",
		"tag_filter": "street",
		"breakpoints": [
			{"count": 2, "effects": [{"effect_id": "max_hp_bonus", "params": {"amount": 120}}]},
			{"count": 4, "effects": [{"effect_id": "max_hp_bonus", "params": {"amount": 300}}]},
		],
	},
}


static func get_def(trait_id: String) -> Dictionary:
	return DEFS.get(trait_id, {}).duplicate(true)
