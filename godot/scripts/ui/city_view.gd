extends Control
class_name CityView
## P15.1 — code-drawn skyline strip (pygame draw_scene parity). ART_POLICY: no textures.

signal hustle_pressed

const PrestigeScript = preload("res://scripts/systems/prestige.gd")

const VIRTUAL_SIZE := Vector2(404.0, 320.0)
const REDRAW_INTERVAL := 1.0 / 30.0
const MIN_HUSTLE_SIZE := 48.0

# Noir palette — mirrors src/theme.py Phase 127 / pygame draw_scene.
const INK := Color(0.031, 0.039, 0.098)
const INK_GOLD := Color(0.784, 0.639, 0.353, 0.157)
const INK_GOLD_BRIGHT := Color(0.925, 0.792, 0.49)
const INK_GOLD_DEEP := Color(0.541, 0.439, 0.235, 0.314)
const INK_GLASS := Color(0.102, 0.118, 0.157)
const INK_BONE := Color(0.91, 0.878, 0.831)
const INK_BONE_DIM := Color(0.541, 0.502, 0.451)
const INK_CRIMSON := Color(0.608, 0.157, 0.157)
const ACCENT_DIM := Color(0.29, 0.416, 0.541)
const BG_DARK := Color(0.078, 0.086, 0.125)

@onready var _empire_label: Label = $EmpireLabel
@onready var _hustle_overlay: Button = $HustleOverlay

var _t: float = 0.0
var _anim_accum: float = 0.0
var _dirty: bool = true
var _overlay_occluded: bool = false

var _total_buildings: int = 0
var _heat: float = 0.0
var _districts_owned: int = 0
var _rank_idx: int = 0
var _click_value: float = 0.0
var _income_per_second: float = 0.0
var _hustle_active: bool = false
var _hustle_mult: float = 1.0
var _click_scale: float = 1.0
var _hustle_hover: bool = false

var _last_buildings: int = -1
var _last_heat: float = -1.0
var _last_districts: int = -1
var _last_rank_idx: int = -1


func _ready() -> void:
	clip_contents = true
	_hustle_overlay.flat = true
	_hustle_overlay.text = ""
	_hustle_overlay.pressed.connect(func(): hustle_pressed.emit())
	_hustle_overlay.mouse_entered.connect(func(): _set_hustle_hover(true))
	_hustle_overlay.mouse_exited.connect(func(): _set_hustle_hover(false))
	_empire_label.text = "YOUR EMPIRE"
	_empire_label.add_theme_color_override("font_color", Color(INK_GOLD_BRIGHT, 0.55))
	_empire_label.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	resized.connect(_layout_hustle)
	call_deferred("_layout_hustle")
	if not _is_headless():
		queue_redraw()


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _set_hustle_hover(on: bool) -> void:
	if _hustle_hover == on:
		return
	_hustle_hover = on
	_mark_dirty()


func set_click_scale(scale: float) -> void:
	_click_scale = scale
	_layout_hustle()


func set_overlay_occluded(occluded: bool) -> void:
	if _overlay_occluded == occluded:
		return
	_overlay_occluded = occluded
	if occluded:
		_hustle_overlay.visible = false
	else:
		_hustle_overlay.visible = true
		_mark_dirty()


func get_hustle_rect_global() -> Rect2:
	return _hustle_overlay.get_global_rect()


func get_hustle_center_global() -> Vector2:
	return _hustle_overlay.get_global_rect().get_center()


func refresh(
	total_buildings: int,
	heat: float,
	districts_owned: int,
	prestige_tokens: int,
	click_value: float,
	income_per_second: float,
	hustle_active: bool,
	hustle_mult: float
) -> void:
	var rank_name := PrestigeScript.get_rank(prestige_tokens)
	var rank_idx := PrestigeScript.rank_index(rank_name)
	var state_changed := (
		total_buildings != _last_buildings
		or absf(heat - _last_heat) > 0.5
		or districts_owned != _last_districts
		or rank_idx != _last_rank_idx
	)
	_last_buildings = total_buildings
	_last_heat = heat
	_last_districts = districts_owned
	_last_rank_idx = rank_idx

	_total_buildings = total_buildings
	_heat = heat
	_districts_owned = districts_owned
	_rank_idx = rank_idx
	_click_value = click_value
	_income_per_second = income_per_second
	_hustle_active = hustle_active
	_hustle_mult = hustle_mult

	if state_changed:
		_mark_dirty()


func _mark_dirty() -> void:
	_dirty = true


func _process(delta: float) -> void:
	if _is_headless() or _overlay_occluded:
		return
	_anim_accum += delta
	if _anim_accum < REDRAW_INTERVAL:
		return
	_anim_accum = 0.0
	_t += REDRAW_INTERVAL
	var animating := not GameTheme.ui_reduced_motion()
	if animating or _dirty:
		queue_redraw()
		_dirty = false


func _layout_hustle() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var scale := size / VIRTUAL_SIZE
	var cx := size.x * 0.5
	var cy := size.y * 0.78
	var bw := maxf(MIN_HUSTLE_SIZE, 120.0 * scale.x * _click_scale)
	var bh := maxf(MIN_HUSTLE_SIZE, 56.0 * scale.y * _click_scale)
	_hustle_overlay.position = Vector2(cx - bw * 0.5, cy - bh * 0.5)
	_hustle_overlay.size = Vector2(bw, bh)
	_mark_dirty()


func _draw() -> void:
	if _is_headless():
		return
	var scale := size / VIRTUAL_SIZE
	draw_set_transform(Vector2.ZERO, 0.0, scale)
	_draw_frame()
	_draw_skyline(_total_buildings, _t)
	_draw_atmosphere(_heat, _districts_owned, _rank_idx, _t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hustle_glass()


func _draw_frame() -> void:
	var sr := Rect2(Vector2.ZERO, VIRTUAL_SIZE)
	draw_rect(sr, INK)
	draw_rect(sr, INK_GOLD, false, 1.0)
	# Gold corner accents (draw_left_empire_frame parity).
	for corner in [sr.position, Vector2(sr.end.x, sr.position.y),
			Vector2(sr.position.x, sr.end.y), sr.end]:
		draw_line(corner + Vector2(-4, 0), corner + Vector2(4, 0), INK_GOLD_BRIGHT, 1.0)
		draw_line(corner + Vector2(0, -4), corner + Vector2(0, 4), INK_GOLD_BRIGHT, 1.0)


func _draw_skyline(total_buildings: int, t: float) -> void:
	var sx := 0.0
	var sy := 0.0
	var sw := VIRTUAL_SIZE.x
	var sh := VIRTUAL_SIZE.y
	var ground_y := sy + sh - 20.0
	var sky_h := ground_y - sy
	var band0_h := sky_h * 0.40
	var band1_h := sky_h * 0.20
	var band2_h := sky_h - band0_h - band1_h
	draw_rect(Rect2(sx, sy, sw, band0_h), Color8(8, 10, 25))
	draw_rect(Rect2(sx, sy + band0_h, sw, band1_h), Color8(15, 18, 40))
	draw_rect(Rect2(sx, sy + band0_h + band1_h, sw, band2_h), Color8(20, 22, 30))
	draw_rect(Rect2(sx, ground_y, sw, 20.0), Color8(22, 24, 34))
	draw_line(Vector2(sx, ground_y + 4.0), Vector2(sx + sw, ground_y + 4.0), Color8(35, 37, 52), 1.0)

	if total_buildings < 5:
		var stars0: Array[Vector2] = [
			Vector2(20, 8), Vector2(55, 5), Vector2(90, 14),
			Vector2(135, 7), Vector2(190, 12), Vector2(250, 6),
		]
		for i in stars0.size():
			_draw_star(stars0[i].x, stars0[i].y, i, t)
		draw_rect(Rect2(sx + sw - 55.0, sy, 55.0, ground_y - sy), Color8(10, 10, 18))
		_lamppost(sx + 50.0, ground_y)
		_figure(sx + 90.0, ground_y, Color8(100, 95, 115))
	elif total_buildings < 15:
		var stars1: Array[Vector2] = [Vector2(15, 6), Vector2(60, 9), Vector2(190, 5), Vector2(230, 12)]
		for i in stars1.size():
			_draw_star(stars1[i].x, stars1[i].y, i, t)
		_storefront(sx + 35.0, 80.0, 50.0, ground_y, Color8(35, 38, 55), true, ACCENT_DIM)
		draw_rect(Rect2(sx + 46.0, ground_y - 62.0, 58.0, 10.0), BG_DARK)
		_lamppost(sx + 18.0, ground_y)
		_figure(sx + 145.0, ground_y, Color8(110, 105, 125))
		_figure(sx + 163.0, ground_y, Color8(90, 90, 110))
	elif total_buildings < 35:
		var stars2: Array[Vector2] = [Vector2(10, 5), Vector2(180, 8), Vector2(240, 6)]
		for i in stars2.size():
			_draw_star(stars2[i].x, stars2[i].y, i, t)
		_storefront(sx + 4.0, 70.0, 60.0, ground_y, Color8(36, 40, 58), true, Color8(180, 55, 55))
		_storefront(sx + 82.0, 80.0, 70.0, ground_y, Color8(30, 34, 52), true, GameTheme.BLUE_BRIGHT)
		_storefront(sx + 172.0, 64.0, 55.0, ground_y, Color8(38, 42, 60), true, Color8(55, 170, 75))
		_lamppost(sx + sw - 22.0, ground_y)
		var car_x := sx + fmod(t * 25.0, sw + 60.0) - 30.0
		_car(car_x, ground_y - 22.0)
		_figure(sx + 255.0, ground_y, Color8(110, 105, 125))
	elif total_buildings < 80:
		var bldefs := [
			[sx + 2.0, 50.0, 80.0, Color8(34, 38, 56)],
			[sx + 56.0, 60.0, 100.0, Color8(28, 32, 50)],
			[sx + 122.0, 48.0, 80.0, Color8(36, 40, 58)],
			[sx + 176.0, 58.0, 95.0, Color8(32, 36, 54)],
			[sx + 240.0, 44.0, 72.0, Color8(38, 42, 60)],
		]
		for def in bldefs:
			var bx2: float = def[0]
			var bw: float = def[1]
			var bh: float = def[2]
			var col: Color = def[3]
			_storefront(bx2, bw, bh, ground_y, col)
			draw_rect(Rect2(bx2 + bw * 0.5 - 1.0, ground_y - bh - 10.0, 2.0, 10.0), Color8(55, 58, 75))
			for wy in 2:
				for wx in 2:
					var seed := int(bx2) / 10 + wx * 3 + wy * 7
					var lit := sin(t * (1.2 + seed % 3 * 0.4) + float(seed)) > -0.3
					var wc := Color8(245, 210, 90) if lit else Color8(20, 22, 32)
					draw_rect(Rect2(bx2 + 6.0 + wx * 18.0, ground_y - bh + 26.0 + wy * 22.0, 10.0, 10.0), wc)
		var nv := int(180.0 + 70.0 * sin(t * 2.2))
		draw_rect(Rect2(sx + 58.0, ground_y - 73.0, 30.0, 6.0), Color8(nv, 35, 35))
		draw_rect(Rect2(sx + 124.0, ground_y - 62.0, 22.0, 5.0), GameTheme.BLUE_BRIGHT)
		_lamppost(sx + 110.0, ground_y)
		var fig_x := sx + 10.0 + fmod(t * 22.0, sw - 25.0)
		_figure(fig_x, ground_y, Color8(110, 105, 125))
	else:
		var stars3: Array[Vector2] = [
			Vector2(18, 5), Vector2(52, 8), Vector2(98, 4), Vector2(148, 10),
			Vector2(198, 6), Vector2(242, 9), Vector2(278, 4),
		]
		for i in stars3.size():
			_draw_star(stars3[i].x, stars3[i].y, i, t)
		draw_circle(Vector2(sx + sw - 22.0, sy + 18.0), 10.0, Color8(210, 215, 200))
		draw_circle(Vector2(sx + sw - 18.0, sy + 15.0), 8.0, Color8(8, 10, 25))
		var towers: Array = [
			[sx, 38.0, 130.0], [sx + 42.0, 55.0, 150.0], [sx + 104.0, 44.0, 145.0],
			[sx + 156.0, 62.0, 155.0], [sx + 226.0, 36.0, 120.0], [sx + 268.0, 20.0, 100.0],
		]
		for tower in towers:
			var tx: float = tower[0]
			var tw: float = tower[1]
			var th: float = tower[2]
			draw_rect(Rect2(tx, ground_y - th, tw, th), Color8(24, 28, 44))
			draw_rect(Rect2(tx + tw * 0.5 - 1.0, ground_y - th - 8.0, 2.0, 8.0), Color8(46, 50, 70))
			var wy := 0.0
			while wy < th - 6.0:
				var wx := 4.0
				while wx < tw - 4.0:
					var seed := int(tx) / 5 + int(wx) + int(wy)
					var flicker := sin(t * (1.4 + seed % 3 * 0.5) + float(seed)) > -0.25
					var wc := Color8(245, 215, 90) if flicker else Color8(18, 20, 32)
					draw_rect(Rect2(tx + wx, ground_y - th + wy + 7.0, 6.0, 6.0), wc)
					wx += 10.0
				wy += 13.0
		_lamppost(sx + 88.0, ground_y)
		_lamppost(sx + 200.0, ground_y)
		var car_x2 := sx + fmod(t * 28.0, sw + 50.0) - 50.0
		_car(car_x2, ground_y - 22.0, Color8(28, 90, 170))
		if sw > 200.0:
			var car2 := sx + fmod(t * 20.0 + sw * 0.4, sw + 40.0) - 20.0
			_car(car2, ground_y - 22.0, Color8(140, 30, 35))


func _draw_atmosphere(heat: float, districts_owned: int, rank_idx: int, t: float) -> void:
	var sw := VIRTUAL_SIZE.x
	var sh := VIRTUAL_SIZE.y
	if heat >= 25.0:
		var haze_a := minf(90.0, (heat - 25.0) * 1.4)
		draw_rect(Rect2(0, 0, sw, sh), Color(INK_CRIMSON.r, INK_CRIMSON.g, INK_CRIMSON.b, haze_a / 255.0 * 0.35))
	if heat >= 40.0:
		for i in 3:
			var wx := fmod(sw * (0.2 + i * 0.28) + t * 12.0 * (i + 1), sw)
			var wy := sh - 30.0 - 20.0 * sin(t * 0.8 + i * 2.1)
			draw_circle(Vector2(wx, wy), 8.0, Color(0.314, 0.314, 0.353, 0.137))
	if heat >= 60.0 and (GameTheme.ui_reduced_motion() or int(t * 3.0) % 2 == 0):
		draw_rect(Rect2(0, 0, sw, sh), Color(0.157, 0.235, 0.706, 0.071))
	var crime_lord_idx := PrestigeScript.rank_index("Crime Lord")
	if rank_idx >= crime_lord_idx:
		draw_rect(Rect2(0, sh - 44.0, sw, 24.0), Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.098))
	if districts_owned >= 5:
		for i in mini(districts_owned, 12):
			var lx := 8.0 + fmod(float(i * 17), maxf(1.0, sw - 16.0))
			var ly := sh - 28.0 - float(i % 3) * 8.0
			draw_circle(Vector2(lx, ly), 2.0, Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.471))


func _draw_hustle_glass() -> void:
	if _overlay_occluded:
		return
	var rect := _hustle_overlay.get_rect()
	if rect.size.x < 1.0:
		return
	var cx := rect.position.x + rect.size.x * 0.5
	var cy := rect.position.y + rect.size.y * 0.5
	var bw := rect.size.x
	var bh := rect.size.y
	var br := maxf(12.0, bw / 5.0)

	if _income_per_second > 0.0 and not GameTheme.ui_reduced_motion():
		var pulse := 40.0 + 35.0 * (0.5 + 0.5 * sin(_t * 2.2))
		draw_arc(Vector2(cx, cy), bw * 0.5 + 12.0, 0.0, TAU, 32, Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, pulse / 255.0), 2.0)

	var fill_a := 0.647 if _hustle_hover else 0.471
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
	draw_string(font, Vector2(cx - lbl_size.x * 0.5, cy - 8.0), hustle_lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK_BONE if not _hustle_hover else INK_GOLD_BRIGHT)
	var hint := "+%s" % FormatUtil.format_money(_click_value)
	var hint_size := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size - 1)
	draw_string(font, Vector2(cx - hint_size.x * 0.5, cy + 14.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, INK_GOLD_BRIGHT)


func _draw_star(rx: float, ry: float, i: int, t: float) -> void:
	var a := 120.0 + 100.0 * sin(t * 0.7 + i * 1.7)
	draw_rect(Rect2(rx, ry, 2.0, 2.0), Color(0.863, 0.863, 1.0, a / 255.0))


func _lamppost(lx: float, ground_y: float) -> void:
	var pole_top := ground_y - 70.0
	draw_rect(Rect2(lx, pole_top, 3.0, 70.0), Color8(80, 82, 100))
	draw_rect(Rect2(lx - 1.0, pole_top, 14.0, 3.0), Color8(80, 82, 100))
	draw_circle(Vector2(lx + 12.0, pole_top), 5.0, Color8(255, 220, 100))
	draw_circle(Vector2(lx, ground_y - 2.0), 12.0, Color(1.0, 0.863, 0.314, 0.196))


func _figure(fx: float, fy: float, col: Color) -> void:
	draw_circle(Vector2(fx, fy - 15.0), 5.0, col)
	draw_rect(Rect2(fx - 4.0, fy - 10.0, 8.0, 13.0), col)
	draw_rect(Rect2(fx - 4.0, fy + 3.0, 3.0, 10.0), col)
	draw_rect(Rect2(fx + 1.0, fy + 3.0, 3.0, 10.0), col)


func _car(car_x: float, car_y: float, col: Color = Color8(120, 25, 25)) -> void:
	draw_rect(Rect2(car_x, car_y, 40.0, 16.0), col)
	var body_top := Color(minf(1.0, col.r + 0.118), minf(1.0, col.g + 0.118), minf(1.0, col.b + 0.118))
	draw_rect(Rect2(car_x + 6.0, car_y - 9.0, 26.0, 10.0), body_top)
	draw_rect(Rect2(car_x + 8.0, car_y - 7.0, 10.0, 7.0), Color8(160, 190, 210))
	draw_rect(Rect2(car_x + 20.0, car_y - 7.0, 10.0, 7.0), Color8(160, 190, 210))
	draw_circle(Vector2(car_x + 9.0, car_y + 16.0), 5.0, Color8(50, 50, 50))
	draw_circle(Vector2(car_x + 31.0, car_y + 16.0), 5.0, Color8(50, 50, 50))
	draw_circle(Vector2(car_x + 9.0, car_y + 16.0), 3.0, Color8(85, 85, 85))
	draw_circle(Vector2(car_x + 31.0, car_y + 16.0), 3.0, Color8(85, 85, 85))


func _storefront(bx2: float, bw: float, bh: float, ground_y: float, col: Color,
		door: bool = true, sign_col: Color = Color.TRANSPARENT) -> void:
	draw_rect(Rect2(bx2, ground_y - bh, bw, bh), col)
	var trim := Color(minf(1.0, col.r + 0.071), minf(1.0, col.g + 0.071), minf(1.0, col.b + 0.071))
	draw_rect(Rect2(bx2, ground_y - bh, bw, 7.0), trim)
	if door:
		var dw := maxf(8.0, bw / 4.0)
		draw_rect(Rect2(bx2 + bw * 0.5 - dw * 0.5, ground_y - 30.0, dw, 30.0), Color8(8, 8, 16))
	for wi in 2:
		var wlx := bx2 + 6.0 + wi * (bw - 20.0) / 2.0
		if wlx + 16.0 < bx2 + bw:
			draw_rect(Rect2(wlx, ground_y - bh + 14.0, 16.0, 12.0), Color8(255, 220, 120))
	if sign_col.a > 0.01:
		draw_rect(Rect2(bx2 + 4.0, ground_y - bh - 7.0, bw - 8.0, 6.0), sign_col)
