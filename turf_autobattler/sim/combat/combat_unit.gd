class_name CombatUnit
extends RefCounted

var instance_id: int = -1
var def_id: String = ""
var team_id: int = SimConstants.TeamId.PLAYER
var grid_pos: Vector2i = Vector2i.ZERO
var stars: int = 1
var max_hp: int = 0
var current_hp: int = 0
var attack: int = 0
var attack_speed: float = 1.0
var armor: int = 0
var range_cells: int = 1
var attack_progress: float = 0.0
var alive: bool = true
var tags: Array[String] = []


func can_act() -> bool:
	return alive and current_hp > 0


static func from_unit_instance(
	unit: UnitInstance,
	team_id: int,
	pos: Vector2i,
	round_scale: float = 1.0,
) -> CombatUnit:
	var def := UnitRegistry.get_def(unit.def_id)
	var stats: Dictionary = def.get("base_stats", {})
	var combat := CombatUnit.new()
	combat.instance_id = unit.instance_id
	combat.def_id = unit.def_id
	combat.team_id = team_id
	combat.grid_pos = pos
	combat.stars = unit.stars
	var hp := int(round(float(stats.get("max_hp", 100)) * round_scale))
	combat.max_hp = hp
	combat.current_hp = hp
	combat.attack = int(round(float(stats.get("attack", 10)) * round_scale))
	combat.attack_speed = float(stats.get("attack_speed", 1.0))
	combat.armor = int(stats.get("armor", 0))
	combat.range_cells = int(stats.get("range", 1))
	for tag in def.get("tags", []):
		combat.tags.append(String(tag))
	return combat
