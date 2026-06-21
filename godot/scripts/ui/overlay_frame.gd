extends PanelContainer
## P14.7 ledger modal frame — paper StyleBox + code-drawn corner brackets (shared overlays).

const _BRACKET_LEN := 16.0
const _INSET := 10.0


func _ready() -> void:
	add_theme_stylebox_override("panel", GameTheme.overlay_ledger_style())
	mouse_filter = MOUSE_FILTER_STOP
	if not GameTheme.is_city_v2_active():
		queue_redraw()


func _draw() -> void:
	if GameTheme.is_city_v2_active():
		return
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return
	var col := Color(GameTheme.GOLD, 0.6)
	var lw := 1.5
	var x0 := _INSET
	var y0 := _INSET
	var x1 := w - _INSET
	var y1 := h - _INSET
	var bl := _BRACKET_LEN
	draw_line(Vector2(x0, y0 + bl), Vector2(x0, y0), col, lw)
	draw_line(Vector2(x0, y0), Vector2(x0 + bl, y0), col, lw)
	draw_line(Vector2(x1 - bl, y0), Vector2(x1, y0), col, lw)
	draw_line(Vector2(x1, y0), Vector2(x1, y0 + bl), col, lw)
	draw_line(Vector2(x0, y1 - bl), Vector2(x0, y1), col, lw)
	draw_line(Vector2(x0, y1), Vector2(x0 + bl, y1), col, lw)
	draw_line(Vector2(x1 - bl, y1), Vector2(x1, y1), col, lw)
	draw_line(Vector2(x1, y1 - bl), Vector2(x1, y1), col, lw)
