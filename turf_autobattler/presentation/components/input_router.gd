extends Node

## Maps drag-drop gestures to PlayerIntent commands (handoff §14 InputRouter).

signal placement_rejected(reason: String)

var _drag_instance_id: int = -1
var _drag_from_board: Vector2i = Vector2i(-1, -1)
var _board_view: Control
var _bench_container: HBoxContainer
var _dragging: bool = false


func setup(board_view: Control, bench_container: HBoxContainer) -> void:
	_board_view = board_view
	_bench_container = bench_container
	if _board_view.has_signal("cell_clicked"):
		_board_view.cell_clicked.connect(_on_cell_clicked)
	if _board_view.has_signal("cell_released"):
		_board_view.cell_released.connect(_on_cell_released)
	if _board_view.has_signal("cell_drag_started"):
		_board_view.cell_drag_started.connect(_on_board_drag_started)
	if _board_view.has_signal("cell_dropped"):
		_board_view.cell_dropped.connect(_on_board_dropped)


func register_bench_button(button: Button, instance_id: int) -> void:
	button.gui_input.connect(_on_bench_gui_input.bind(instance_id))


func clear_bench_handlers() -> void:
	pass


func _on_bench_gui_input(event: InputEvent, instance_id: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_instance_id = instance_id
			_drag_from_board = Vector2i(-1, -1)
			_dragging = true
		elif _dragging and _drag_instance_id == instance_id:
			_dragging = false


func _on_cell_clicked(pos: Vector2i) -> void:
	if _drag_instance_id < 0:
		return
	_submit_move(_drag_instance_id, pos)
	_reset_drag()


func _on_cell_released(pos: Vector2i) -> void:
	if _drag_instance_id < 0 or _drag_from_board.x >= 0:
		return
	_submit_move(_drag_instance_id, pos)
	_reset_drag()


func _on_board_drag_started(pos: Vector2i) -> void:
	var instance_id := _instance_at(pos)
	if instance_id < 0:
		return
	_drag_instance_id = instance_id
	_drag_from_board = pos
	_dragging = true


func _on_board_dropped(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if from_pos == to_pos:
		_reset_drag()
		return
	if _instance_at(to_pos) >= 0:
		var reason := RunBridge.submit_intent(PlayerIntent.make("SWAP_ON_BOARD", {"a": from_pos, "b": to_pos}))
		if reason != SimConstants.RejectReason.OK:
			placement_rejected.emit(_reason_text(reason))
	else:
		_submit_move(_instance_at(from_pos), to_pos)
	_reset_drag()


func _submit_move(instance_id: int, pos: Vector2i) -> void:
	if instance_id < 0:
		return
	var reason := RunBridge.submit_intent(PlayerIntent.make("MOVE_TO_BOARD", {
		"instance_id": instance_id,
		"grid_pos": pos,
	}))
	if reason != SimConstants.RejectReason.OK:
		placement_rejected.emit(_reason_text(reason))


func _instance_at(pos: Vector2i) -> int:
	for cell in RunBridge.get_board_dto()["cells"]:
		if cell["pos"] == pos:
			var unit = cell.get("unit")
			if unit != null:
				return int(unit["instance_id"])
	return -1


func _reset_drag() -> void:
	_drag_instance_id = -1
	_drag_from_board = Vector2i(-1, -1)
	_dragging = false


func _reason_text(reason: int) -> String:
	match reason:
		SimConstants.RejectReason.NOT_ENOUGH_GOLD:
			return "Not enough gold."
		SimConstants.RejectReason.BENCH_FULL:
			return "Bench is full."
		SimConstants.RejectReason.BOARD_FULL:
			return "Board is full."
		SimConstants.RejectReason.INVALID_SLOT:
			return "Invalid slot."
		_:
			return "Action rejected."
