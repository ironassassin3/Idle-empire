extends Control
class_name HustleBand
## Dedicated hustle tap band between city skyline and tab body (P15.6).
## ART_POLICY: code-drawn glass styling — no textures.

signal hustle_pressed

const MIN_BAND_H := 64.0
const MIN_TAP_H := 48.0

const INK := Color(0.031, 0.039, 0.098)
const INK_GOLD := Color(0.784, 0.639, 0.353, 0.157)
const INK_GOLD_BRIGHT := Color(0.925, 0.792, 0.49)
const INK_GOLD_DEEP := Color(0.541, 0.439, 0.235, 0.314)
const INK_GLASS := Color(0.102, 0.118, 0.157)
const INK_BONE := Color(0.91, 0.878, 0.831)

@onready var _row: HBoxContainer = $Row
@onready var _coin_col: HBoxContainer = $Row/CoinCol
@onready var _hustle_btn: Button = $Row/HustleBtn
@onready var _spacer: Control = $Row/Spacer

var _click_value: float = 0.0
var _income_per_second: float = 0.0
var _hustle_active: bool = false
var _hustle_mult: float = 1.0
var _click_scale: float = 1.0
var _hustle_hover: bool = false
var _overlay_occluded: bool = false
var _t: float = 0.0


func _ready() -> void:
	custom_minimum_size.y = MIN_BAND_H
	_hustle_btn.flat = true
	_hustle_btn.text = ""
	_hustle_btn.custom_minimum_size = Vector2(120.0, MIN_TAP_H)
	_hustle_btn.pressed.connect(func(): hustle_pressed.emit())
	_hustle_btn.mouse_entered.connect(func(): _set_hustle_hover(true))
	_hustle_btn.mouse_exited.connect(func(): _set_hustle_hover(false))
	resized.connect(_sync_layout)
	call_deferred("_sync_layout")
	if not _is_headless():
		queue_redraw()


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func get_coin_column() -> Control:
	return _coin_col


func get_hustle_center_global() -> Vector2:
	return _hustle_btn.get_global_rect().get_center()


func get_hustle_rect_global() -> Rect2:
	return _hustle_btn.get_global_rect()


func set_click_scale(scale: float) -> void:
	_click_scale = scale
	_sync_layout()


func set_overlay_occluded(occluded: bool) -> void:
	if _overlay_occluded == occluded:
		return
	_overlay_occluded = occluded
	_hustle_btn.visible = not occluded
	queue_redraw()


func refresh(
	click_value: float,
	income_per_second: float,
	hustle_active: bool,
	hustle_mult: float,
	click_scale: float = 1.0
) -> void:
	_click_value = click_value
	_income_per_second = income_per_second
	_hustle_active = hustle_active
	_hustle_mult = hustle_mult
	_click_scale = click_scale
	_sync_layout()
	queue_redraw()


func _set_hustle_hover(on: bool) -> void:
	if _hustle_hover == on:
		return
	_hustle_hover = on
	queue_redraw()


func _sync_layout() -> void:
	if _hustle_btn == null:
		return
	var band_h := maxf(MIN_BAND_H, size.y)
	var tap_h := maxf(MIN_TAP_H, (band_h - 8.0) * _click_scale)
	_hustle_btn.custom_minimum_size = Vector2(120.0, tap_h)
	if _spacer:
		_spacer.custom_minimum_size.x = _coin_col.size.x


func _process(delta: float) -> void:
	if _is_headless() or _overlay_occluded:
		return
	_t += delta
	if not GameTheme.ui_reduced_motion() or _hustle_hover:
		queue_redraw()


func _draw() -> void:
	if _is_headless():
		return
	var band := Rect2(Vector2.ZERO, size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = INK
	bg.border_color = INK_GOLD
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bg.draw(get_canvas_item(), band)
	if _overlay_occluded or _hustle_btn == null:
		return
	_draw_hustle_glass(_hustle_btn.get_rect())


func _draw_hustle_glass(rect: Rect2) -> void:
	if rect.size.x < 1.0:
		return
	var cx := rect.position.x + rect.size.x * 0.5
	var cy := rect.position.y + rect.size.y * 0.5
	var bw := rect.size.x
	var bh := rect.size.y
	var br := maxf(12.0, bw / 5.0)

	if not GameTheme.ui_reduced_motion():
		for ring in 2:
			var phase := _t * 1.8 - ring * 0.55
			var max_ring_r := minf(bw * 0.34, bh * 0.55)
			var radius := minf(max_ring_r * (0.55 + ring * 0.35) + 3.0 * sin(phase), max_ring_r)
			var alpha := 0.04 + 0.06 * (0.5 + 0.5 * sin(phase))
			if _income_per_second > 0.0:
				alpha *= 1.25
			draw_arc(Vector2(cx, cy), radius, 0.0, TAU, 24,
					Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, alpha), 1.0)
		var refl_y := cy + bh * 0.45
		draw_line(Vector2(cx - bw * 0.28, refl_y), Vector2(cx + bw * 0.28, refl_y),
				Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.14), 1.5)

	var fill_a := 0.647 if _hustle_hover else 0.314
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color(INK_GLASS.r, INK_GLASS.g, INK_GLASS.b, fill_a)
	glass.set_corner_radius_all(int(br))
	glass.draw(get_canvas_item(), rect)
	var border_col := INK_GOLD_BRIGHT if _hustle_hover else INK_GOLD
	var border_a := 0.863 if _hustle_hover else 0.588
	var border := StyleBoxFlat.new()
	border.bg_color = Color.TRANSPARENT
	border.border_color = Color(border_col.r, border_col.g, border_col.b, border_a)
	border.set_border_width_all(2)
	border.set_corner_radius_all(int(br))
	border.draw(get_canvas_item(), rect)

	var inset := maxf(8.0, bw / 8.0)
	var inner := Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(inset, inset) * 2.0)
	var inner_box := StyleBoxFlat.new()
	inner_box.bg_color = Color.TRANSPARENT
	inner_box.border_color = Color(INK_GOLD_DEEP.r, INK_GOLD_DEEP.g, INK_GOLD_DEEP.b, 0.314)
	inner_box.set_border_width_all(1)
	inner_box.set_corner_radius_all(maxi(0, int(br) - 4))
	inner_box.draw(get_canvas_item(), inner)

	var hustle_lbl := "HUSTLE"
	if _hustle_active:
		hustle_lbl = "HUSTLE ×%.2f" % _hustle_mult
	var font := ThemeDB.fallback_font
	var font_size := GameTheme.scaled_font(14 if _hustle_active else 13)
	var lbl_size := font.get_string_size(hustle_lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, Vector2(cx - lbl_size.x * 0.5, cy - 8.0), hustle_lbl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK_BONE if not _hustle_hover else INK_GOLD_BRIGHT)
	var hint := "+%s" % FormatUtil.format_money(_click_value)
	var hint_size := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size - 1)
	draw_string(font, Vector2(cx - hint_size.x * 0.5, cy + 14.0), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, INK_GOLD_BRIGHT)
