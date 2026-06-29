class_name EventLog
extends RefCounted

var log_version: int = SimConstants.LOG_VERSION
var events: Array[Dictionary] = []


func clear() -> void:
	events.clear()


func emit(event_type: String, payload: Dictionary = {}) -> void:
	var entry := {"type": event_type}
	for key in payload.keys():
		entry[key] = payload[key]
	events.append(entry)


func get_events() -> Array[Dictionary]:
	return events


func duplicate_log() -> EventLog:
	var copy := EventLog.new()
	copy.log_version = log_version
	copy.events = events.duplicate(true)
	return copy


func to_dict() -> Dictionary:
	return {"log_version": log_version, "events": events.duplicate(true)}


static func from_dict(data: Dictionary) -> EventLog:
	var log := EventLog.new()
	log.log_version = int(data.get("log_version", SimConstants.LOG_VERSION))
	log.events = data.get("events", []).duplicate(true)
	return log
