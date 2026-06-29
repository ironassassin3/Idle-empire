extends Control

## Code-drawn isometric turf board (handoff §14–§15, ART_POLICY-safe).

signal cell_clicked(pos: Vector2i)
signal cell_released(pos: Vector2i)
signal cell_drag_started(pos: Vector2i)
signal cell_dropped(from_pos: Vector2i, to_pos: Vector2i)

const HOME_COLOR := Color(0.28, 0.36, 0.32, 1.0)
const NEUTRAL_COLOR := Color(0.18, 0.20, 0.24, 1.0)
const ENEMY_TURF_COLOR := Color(0.32, 0.22, 0.24, 1.0)
const HIGHLIGHT_COLOR := Color(0.45, 0.62, 0.78, 0.55)
const UNIT_PLAYER_COLOR := Color(0.55, 0.82, 0.68, 1.0)
const UNIT_ENEMY_COLOR := Color(0.82, 0.45, 0.48, 1.0)
const SHADOW_COLOR := Color(0.02, 0.03, 0.05, 0.45)

var presenter: IsoBoardPresenter = IsoBoardPresenter.new()
var _cells: Array = []
var _highlight_pos: Vector2i = Vector2i(-1, -1)
var _flash_pos: Vector2i = Vector2i(-1, -1)
var _flash_timer: float = 0.0
var _combat_mode: bool = false
var _float_texts: Array = []
var _drag_from: Vector2i = Vector2i(-1, -1)
var _dragging: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(360, 260)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_board_dto(dto: Dictionary, combat_mode: bool = false) -> void:
	_cells = dto.get("cells", [])
	_combat_mode = combat_mode


func flash_cell(pos: Vector2i) -> void:
	_flash_pos = pos
	_flash_timer = 0.25


func spawn_damage_text(instance_id: int, amount: int) -> void:
	var pos := _pos_for_instance(instance_id)
	if pos.x < 0:
		return
	_float_texts.append({"pos": pos, "text": "-%d" % amount, "timer": 0.9})


func mark_unit_dead(instance_id: int) -> void:
	for cell in _cells:
		var unit = cell.get("unit")
		if unit != null and int(unit.get("instance_id", -1)) == instance_id:
			unit["alive"] = false


func _process(delta: float) -> void:
	var dirty := false
	if _flash_timer > 0.0:
		_flash_timer -= delta
		dirty = true
	for entry in _float_texts:
		entry["timer"] = float(entry["timer"]) - delta
		dirty = true
	_float_texts = _float_texts.filter(func(e): return float(e["timer"]) > 0.0)
	if dirty:
		queue_redraw()


func _draw() -> void:
	var origin := size * 0.5 + Vector2(0, -20)
	var draw_items: Array = []
	for cell in _cells:
		var pos: Vector2i = cell["pos"]
		var center := origin + presenter.grid_to_world(pos.x, pos.y)
		var turf := int(cell.get("turf", SimConstants.TurfCellType.NEUTRAL))
		var fill := HOME_COLOR
		if _combat_mode and pos.y >= SimConstants.BOARD_HEIGHT / 2:
			fill = ENEMY_TURF_COLOR
		elif turf == SimConstants.TurfCellType.NEUTRAL:
			fill = NEUTRAL_COLOR
		if pos == _highlight_pos:
			fill = fill.lerp(HIGHLIGHT_COLOR, 0.45)
		if pos == _flash_pos and _flash_timer > 0.0:
			fill = fill.lerp(Color.WHITE, 0.35)
		draw_items.append({"z": presenter.depth_sort_key(pos.x, pos.y), "kind": "tile", "center": center, "fill": fill})
		var unit = cell.get("unit")
		if unit != null and unit.get("alive", true):
			var team := int(unit.get("team", SimConstants.TeamId.PLAYER))
			draw_items.append({
				"z": presenter.depth_sort_key(pos.x, pos.y) + 0.5,
				"kind": "unit",
				"center": center,
				"unit": unit,
				"team": team,
			})
	draw_items.sort_custom(func(a, b): return float(a["z"]) < float(b["z"]))
	for item in draw_items:
		if item["kind"] == "tile":
			_draw_diamond(item["center"], presenter.tile_size(), item["fill"])
		else:
			_draw_unit(item["center"], item["unit"], int(item["team"]))
	for entry in _float_texts:
		var center := origin + presenter.grid_to_world(entry["pos"].x, entry["pos"].y)
		var alpha := clampf(float(entry["timer"]) / 0.9, 0.0, 1.0)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-12, -36 - (1.0 - alpha) * 20.0),
			String(entry["text"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			Color(1.0, 0.45, 0.4, alpha),
		)


func _draw_unit(center: Vector2, unit: Dictionary, team: int) -> void:
	var shadow := Rect2(center + Vector2(-16, 6), Vector2(32, 10))
	draw_rect(shadow, SHADOW_COLOR, true)
	var unit_color := UNIT_PLAYER_COLOR if team == SimConstants.TeamId.PLAYER else UNIT_ENEMY_COLOR
	var rect := Rect2(center + Vector2(-14, -28), Vector2(28, 36))
	draw_rect(rect, unit_color)
	draw_rect(rect, Color(0.05, 0.05, 0.08), false, 2.0)
	var label := String(unit.get("display_name", "?")).substr(0, 1)
	draw_string(ThemeDB.fallback_font, center + Vector2(-5, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.08, 0.1, 0.12))


func _draw_diamond(center: Vector2, tile_size: Vector2, fill: Color) -> void:
	var hw := tile_size.x * 0.5
	var hh := tile_size.y * 0.5
	var points := PackedVector2Array([
		center + Vector2(0, -hh),
		center + Vector2(hw, 0),
		center + Vector2(0, hh),
		center + Vector2(-hw, 0),
	])
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0.08, 0.1, 0.12), 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var pos := _pick_cell(event.position)
			if pos.x >= 0 and _instance_at(pos) >= 0:
				_drag_from = pos
				_dragging = true
				cell_drag_started.emit(pos)
			elif pos.x >= 0:
				cell_clicked.emit(pos)
		elif _dragging:
			var to_pos := _pick_cell(event.position)
			if to_pos.x >= 0:
				if _drag_from.x >= 0:
					cell_dropped.emit(_drag_from, to_pos)
				else:
					cell_released.emit(to_pos)
			_dragging = false
			_drag_from = Vector2i(-1, -1)


func _pick_cell(local_pos: Vector2) -> Vector2i:
	var origin := size * 0.5 + Vector2(0, -20)
	var best := Vector2i(-1, -1)
	var best_dist := 999999.0
	for cell in _cells:
		var pos: Vector2i = cell["pos"]
		var center := origin + presenter.grid_to_world(pos.x, pos.y)
		var dist := local_pos.distance_to(center)
		if dist < best_dist and dist < 36.0:
			best_dist = dist
			best = pos
	return best


func _pos_for_instance(instance_id: int) -> Vector2i:
	for cell in _cells:
		var unit = cell.get("unit")
		if unit != null and int(unit.get("instance_id", -1)) == instance_id:
			return cell["pos"]
	return Vector2i(-1, -1)


func _instance_at(pos: Vector2i) -> int:
	for cell in _cells:
		if cell["pos"] == pos:
			var unit = cell.get("unit")
			if unit != null and unit.get("alive", true):
				return int(unit.get("instance_id", -1))
	return -1
