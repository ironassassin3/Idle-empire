class_name BenchState
extends RefCounted

var slots: Array = []


func _init() -> void:
	reset()


func reset() -> void:
	slots.clear()
	for _i in SimConstants.BENCH_SLOTS:
		slots.append(null)


func first_empty_slot() -> int:
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1


func count_units() -> int:
	var count := 0
	for slot in slots:
		if slot != null:
			count += 1
	return count


func duplicate_bench() -> BenchState:
	var copy := BenchState.new()
	copy.slots = slots.duplicate()
	return copy
