class_name TraitCalculator
extends RefCounted

static func count_tags(units: Array[CombatUnit]) -> Dictionary:
	var counts := {}
	for unit in units:
		for tag in unit.tags:
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


static func apply_combat_start_traits(units: Array[CombatUnit], team_id: int, log: EventLog) -> void:
	var team_units: Array[CombatUnit] = []
	for unit in units:
		if unit.team_id == team_id:
			team_units.append(unit)
	var tag_counts := count_tags(team_units)
	for trait_id in TraitRegistry.DEFS.keys():
		var def := TraitRegistry.get_def(String(trait_id))
		var tag := String(def.get("tag_filter", ""))
		var count := int(tag_counts.get(tag, 0))
		var active_bp: Dictionary = {}
		for bp in def.get("breakpoints", []):
			if count >= int(bp.get("count", 999)):
				active_bp = bp
		if active_bp.is_empty():
			continue
		for effect in active_bp.get("effects", []):
			_apply_effect(String(effect.get("effect_id", "")), effect.get("params", {}), team_units, log)


static func _apply_effect(effect_id: String, params: Dictionary, units: Array[CombatUnit], log: EventLog) -> void:
	match effect_id:
		"armor_bonus":
			var amount := int(params.get("amount", 0))
			for unit in units:
				unit.armor += amount
		"attack_speed_bonus":
			var mult := float(params.get("mult", 1.0))
			for unit in units:
				if unit.tags.has("smuggler"):
					unit.attack_speed *= mult
		"max_hp_bonus":
			var amount := int(params.get("amount", 0))
			for unit in units:
				if unit.tags.has("street"):
					unit.max_hp += amount
					unit.current_hp += amount
		"heal_on_combat_start":
			var amount := int(params.get("amount", 0))
			for unit in units:
				if unit.tags.has("fixer"):
					var healed := mini(amount, unit.max_hp - unit.current_hp)
					if healed > 0:
						unit.current_hp += healed
						log.emit("HEAL", {
							"source_id": unit.instance_id,
							"target_id": unit.instance_id,
							"amount": healed,
						})


static func active_traits_for_units(units: Array[UnitInstance]) -> Array[Dictionary]:
	var tag_counts := {}
	for unit in units:
		var def := UnitRegistry.get_def(unit.def_id)
		for tag in def.get("tags", []):
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
	var active: Array[Dictionary] = []
	for trait_id in TraitRegistry.DEFS.keys():
		var def := TraitRegistry.get_def(String(trait_id))
		var tag := String(def.get("tag_filter", ""))
		var count := int(tag_counts.get(tag, 0))
		var tier := 0
		for bp in def.get("breakpoints", []):
			if count >= int(bp.get("count", 999)):
				tier = int(bp.get("count", 0))
		if tier > 0:
			active.append({
				"id": def.get("id"),
				"display_name": def.get("display_name"),
				"count": count,
				"tier": tier,
			})
	return active
