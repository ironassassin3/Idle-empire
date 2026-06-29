class_name SeededRNG
extends RefCounted

var _state: int = 1


static func from_seed(seed_value: int) -> SeededRNG:
	var rng := SeededRNG.new()
	rng._state = maxi(1, seed_value)
	return rng


func duplicate_rng() -> SeededRNG:
	var copy := SeededRNG.new()
	copy._state = _state
	return copy


func get_state() -> int:
	return _state


func set_state(state: int) -> void:
	_state = maxi(1, state)


func next_int(min_value: int, max_value: int) -> int:
	if min_value >= max_value:
		return min_value
	var span := max_value - min_value + 1
	return min_value + next_uint() % span


func next_uint() -> int:
	_state = int((int(_state) * 1103515245 + 12345) & 0x7fffffff)
	return _state


func next_float() -> float:
	return float(next_uint()) / float(0x7fffffff)
