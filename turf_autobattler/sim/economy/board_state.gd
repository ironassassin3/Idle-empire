class_name BoardState
extends RefCounted

var width: int = SimConstants.BOARD_WIDTH
var height: int = SimConstants.BOARD_HEIGHT
var slots: Dictionary = {}
var turf_map: Array = []
var max_units: int = 1


func _init() -> void:
	reset_turf()


func reset_turf() -> void:
	slots.clear()
	turf_map.clear()
	for row in height:
		var row_cells: Array = []
		for col in width:
			row_cells.append(SimConstants.TurfCellType.HOME if row < 2 else SimConstants.TurfCellType.NEUTRAL)
		turf_map.append(row_cells)


func set_max_units_for_level(level: int) -> void:
	var idx := clampi(level, 0, SimConstants.BOARD_CAP_BY_LEVEL.size() - 1)
	max_units = SimConstants.BOARD_CAP_BY_LEVEL[idx]


func count_units() -> int:
	return slots.size()


func get_unit_at(pos: Vector2i):
	var key := SimGrid.pos_key(pos)
	return slots.get(key)


func set_unit_at(pos: Vector2i, instance_id) -> void:
	var key := SimGrid.pos_key(pos)
	if instance_id == null:
		slots.erase(key)
	else:
		slots[key] = instance_id


func duplicate_board() -> BoardState:
	var copy := BoardState.new()
	copy.width = width
	copy.height = height
	copy.slots = slots.duplicate()
	copy.turf_map = turf_map.duplicate(true)
	copy.max_units = max_units
	return copy


func get_turf_type(pos: Vector2i) -> int:
	if not SimGrid.is_in_bounds(pos, width, height):
		return SimConstants.TurfCellType.NEUTRAL
	return int(turf_map[pos.y][pos.x])
