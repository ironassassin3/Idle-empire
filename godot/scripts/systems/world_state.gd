class_name WorldState
extends RefCounted
## Mid-game data factories.

const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
const _RivalSystem = preload("res://scripts/systems/rival_system.gd")
const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _OperationSystem = preload("res://scripts/systems/operation_system.gd")


static func make_territories() -> Array:
	return _TerritorySystem.make_territories()


static func make_rivals(rng: RandomNumberGenerator) -> Array:
	return _RivalSystem.make_rivals(rng)


static func default_crew() -> Dictionary:
	return _CrewSystem.default_crew()


static func make_operations() -> Array:
	return _OperationSystem.make_operations()
