extends PanelContainer

signal action_pressed(index: int)

const _OperationSystem = preload("res://scripts/systems/operation_system.gd")

var operation_index: int = -1

@onready var _icon: Label = $VBox/Top/IconLabel
@onready var _name: Label = $VBox/Top/NameLabel
@onready var _desc: Label = $VBox/DescLabel
@onready var _req: Label = $VBox/ReqLabel
@onready var _status: Label = $VBox/StatusLabel
@onready var _action: Button = $VBox/ActionBtn


func setup(index: int) -> void:
	operation_index = index
	_refresh()


func _ready() -> void:
	_action.pressed.connect(func(): action_pressed.emit(operation_index))
	GameState.stats_changed.connect(_refresh)


func _refresh() -> void:
	if operation_index < 0 or operation_index >= GameState.operations.size():
		return
	var op: Dictionary = GameState.operations[operation_index]
	_icon.text = str(op.get("icon", "?"))
	_name.text = str(op.get("name", "?"))
	_desc.text = str(op.get("desc", ""))
	var heat_gain: float = float(op.get("heat_gain", 0.0))
	var heat_txt: String = "+%.0f heat on collect" % heat_gain if heat_gain >= 0.0 else "%.0f heat on collect" % heat_gain
	_req.text = "Crew: %d  ·  Cost: %s  ·  Turf: %d  ·  %s" % [
		int(op.get("crew_cost", 0)),
		FormatUtil.format_money(float(op.get("money_cost", 0.0))),
		int(op.get("turf_needed", 0)),
		heat_txt,
	]
	if not _OperationSystem.is_unlocked(GameState):
		_status.text = _OperationSystem.unlock_requirement_text(GameState)
		_action.text = "Locked"
		_action.disabled = true
		return
	if bool(op.get("active", false)) and not bool(op.get("collected", false)):
		if _OperationSystem.is_ready(GameState, op):
			_status.text = "READY — tap to collect"
			_action.text = "Collect\n%s" % FormatUtil.format_money(float(op.get("reward", 0.0)))
			_action.disabled = false
		else:
			var remain: float = _OperationSystem.time_remaining(GameState, op)
			var pct: int = int(_OperationSystem.progress(GameState, op) * 100.0)
			_status.text = "%d%% complete — %s left" % [pct, _OperationSystem.fmt_duration(remain)]
			_action.text = "Running"
			_action.disabled = true
		return
	var gate: Dictionary = _OperationSystem.can_start(GameState, op)
	if gate.get("ok", false):
		_status.text = "Ready to launch"
		_action.text = "Start"
		_action.disabled = false
	else:
		_status.text = str(gate.get("reason", "Cannot start"))
		_action.text = "Start"
		_action.disabled = true
