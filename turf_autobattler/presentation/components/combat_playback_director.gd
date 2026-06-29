extends Node

## Consumes combat EventLog for cosmetic playback (handoff §11, §14).

signal event_played(event: Dictionary)
signal playback_finished

var speed_multiplier: float = 1.0

var _events: Array[Dictionary] = []
var _index: int = 0
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_tick)


func start(events: Array) -> void:
	_events.clear()
	for event in events:
		_events.append(event)
	_index = 0
	_schedule_next()


func skip_to_end() -> void:
	_timer.stop()
	_events.clear()
	_index = 0
	playback_finished.emit()


func is_playing() -> bool:
	return _index < _events.size()


func _schedule_next() -> void:
	if _index >= _events.size():
		playback_finished.emit()
		return
	var event := _events[_index]
	event_played.emit(event)
	_index += 1
	var delay := 0.08 / maxf(speed_multiplier, 0.1)
	match event.get("type", ""):
		"DAMAGE", "UNIT_DIED":
			delay = 0.12 / maxf(speed_multiplier, 0.1)
		"COMBAT_START", "COMBAT_END":
			delay = 0.2 / maxf(speed_multiplier, 0.1)
	_timer.start(delay)


func _on_tick() -> void:
	_schedule_next()
