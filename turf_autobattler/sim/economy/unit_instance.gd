class_name UnitInstance
extends RefCounted

var instance_id: int = -1
var def_id: String = ""
var stars: int = 1
var bench_slot: int = -1
var grid_pos: Vector2i = Vector2i(-1, -1)


func duplicate_unit() -> UnitInstance:
	var copy := UnitInstance.new()
	copy.instance_id = instance_id
	copy.def_id = def_id
	copy.stars = stars
	copy.bench_slot = bench_slot
	copy.grid_pos = grid_pos
	return copy


func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"def_id": def_id,
		"stars": stars,
		"bench_slot": bench_slot,
		"grid_pos": {"x": grid_pos.x, "y": grid_pos.y},
	}


static func from_dict(data: Dictionary) -> UnitInstance:
	var unit := UnitInstance.new()
	unit.instance_id = int(data.get("instance_id", -1))
	unit.def_id = String(data.get("def_id", ""))
	unit.stars = int(data.get("stars", 1))
	unit.bench_slot = int(data.get("bench_slot", -1))
	var pos = data.get("grid_pos", {"x": -1, "y": -1})
	unit.grid_pos = Vector2i(int(pos.get("x", -1)), int(pos.get("y", -1)))
	return unit
