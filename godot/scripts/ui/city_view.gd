extends Control
class_name CityView
## P15.3b — Godot-native city viewport (inspired by pygame tiers, not pixel-parity). ART_POLICY: no textures.

signal hustle_pressed

const PrestigeScript = preload("res://scripts/systems/prestige.gd")

const VIRTUAL_SIZE := Vector2(404.0, 320.0)
const REDRAW_INTERVAL := 1.0 / 30.0
const MIN_HUSTLE_SIZE := 48.0
const HUSTLE_GROUND_Y := VIRTUAL_SIZE.y - 28.0
const HUSTLE_SIZE_SCALE := 0.85
const HUSTLE_COIN_RESERVE := 38.0

const INK := Color(0.031, 0.039, 0.098)
const INK_GOLD := Color(0.784, 0.639, 0.353, 0.157)
const INK_GOLD_BRIGHT := Color(0.925, 0.792, 0.49)
const INK_GOLD_DEEP := Color(0.541, 0.439, 0.235, 0.314)
const INK_GLASS := Color(0.102, 0.118, 0.157)
const INK_BONE := Color(0.91, 0.878, 0.831)
const INK_CRIMSON := Color(0.608, 0.157, 0.157)
const SKY_BACK := Color8(6, 8, 22)
const SKY_MID := Color8(12, 16, 38)
const SKY_HAZE := Color8(28, 32, 52)
const STREET := Color8(18, 20, 30)
const STREET_LINE := Color8(42, 44, 62)
const SILHOUETTE := Color8(14, 16, 28)
const NEON_WARM := Color8(255, 180, 70)
const NEON_COOL := Color8(70, 180, 255)
const NEON_RED := Color8(220, 60, 70)

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
var _top_building_keys: Array = []
var _district_slots: Array = []

var _last_buildings: int = -1
var _last_heat: float = -1.0
var _last_districts: int = -1
var _last_rank_idx: int = -1
var _last_building_sig: String = ""


func _ready() -> void:
	clip_contents = true
	_hustle_overlay.flat = true
	_hustle_overlay.text = ""
	_hustle_overlay.pressed.connect(func(): hustle_pressed.emit())
	_hustle_overlay.mouse_entered.connect(func(): _set_hustle_hover(true))
	_hustle_overlay.mouse_exited.connect(func(): _set_hustle_hover(false))
	_empire_label.visible = false
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


func get_hustle_rect() -> Rect2:
	return get_hustle_rect_global()


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
	hustle_mult: float,
	top_building_keys: Array = [],
	district_slots: Array = []
) -> void:
	var rank_name := PrestigeScript.get_rank(prestige_tokens)
	var rank_idx := PrestigeScript.rank_index(rank_name)
	var sig := _building_sig(top_building_keys)
	var state_changed := (
		total_buildings != _last_buildings
		or absf(heat - _last_heat) > 0.5
		or districts_owned != _last_districts
		or rank_idx != _last_rank_idx
		or sig != _last_building_sig
	)
	_last_buildings = total_buildings
	_last_heat = heat
	_last_districts = districts_owned
	_last_rank_idx = rank_idx
	_last_building_sig = sig

	_total_buildings = total_buildings
	_heat = heat
	_districts_owned = districts_owned
	_rank_idx = rank_idx
	_click_value = click_value
	_income_per_second = income_per_second
	_hustle_active = hustle_active
	_hustle_mult = hustle_mult
	_top_building_keys = top_building_keys
	_district_slots = district_slots

	if state_changed:
		_mark_dirty()


func _building_sig(keys: Array) -> String:
	return "|".join(keys)


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
	var bw := maxf(MIN_HUSTLE_SIZE, 120.0 * scale.x * _click_scale * HUSTLE_SIZE_SCALE)
	var bh := maxf(MIN_HUSTLE_SIZE, 56.0 * scale.y * _click_scale * HUSTLE_SIZE_SCALE)
	# Sidewalk placement: center on street plane (ground_y+), not mid-skyline.
	var ground_y_px := size.y * (HUSTLE_GROUND_Y / VIRTUAL_SIZE.y)
	var street_cy := ground_y_px + bh * 0.22
	var max_cy := size.y - HUSTLE_COIN_RESERVE - bh * 0.5
	var cy := minf(street_cy, max_cy)
	_hustle_overlay.position = Vector2(cx - bw * 0.5, cy - bh * 0.5)
	_hustle_overlay.size = Vector2(bw, bh)
	_mark_dirty()


func _tier(total: int) -> int:
	if total < 5:
		return 0
	if total < 15:
		return 1
	if total < 35:
		return 2
	if total < 80:
		return 3
	return 4


func _draw() -> void:
	if _is_headless():
		return
	var scale := size / VIRTUAL_SIZE
	draw_set_transform(Vector2.ZERO, 0.0, scale)
	var tier := _tier(_total_buildings)
	var ground_y := VIRTUAL_SIZE.y - 28.0
	_draw_frame()
	_draw_back_parallax(_t, tier)
	_draw_mid_skyline(_total_buildings, tier, _top_building_keys, _t, ground_y)
	_draw_front_street(ground_y, _t)
	_draw_district_strip(ground_y, _district_slots)
	_draw_atmosphere(_heat, _rank_idx, _t, tier)
	if not GameTheme.ui_reduced_motion():
		_draw_scanlines()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hustle_glass()


func _draw_frame() -> void:
	var sr := Rect2(Vector2.ZERO, VIRTUAL_SIZE)
	draw_rect(sr, INK)
	draw_rect(sr, INK_GOLD, false, 1.0)
	# Art-deco corner chevrons (Godot identity — not pygame bracket ticks).
	for corner in [sr.position, Vector2(sr.end.x, sr.position.y),
			Vector2(sr.position.x, sr.end.y), sr.end]:
		var inward := Vector2(-1, -1)
		if corner.x >= sr.end.x:
			inward.x = 1
		if corner.y >= sr.end.y:
			inward.y = 1
		var c: Vector2 = corner + inward * 6.0
		draw_line(c, c + Vector2(inward.x * 10.0, 0), INK_GOLD_BRIGHT, 1.0)
		draw_line(c, c + Vector2(0, inward.y * 10.0), INK_GOLD_BRIGHT, 1.0)
		draw_line(c + Vector2(inward.x * 3.0, inward.y * 3.0),
				c + Vector2(inward.x * 8.0, inward.y * 3.0), INK_GOLD, 1.0)
		draw_line(c + Vector2(inward.x * 3.0, inward.y * 3.0),
				c + Vector2(inward.x * 3.0, inward.y * 8.0), INK_GOLD, 1.0)


func _draw_back_parallax(t: float, tier: int) -> void:
	var sw := VIRTUAL_SIZE.x
	var sh := VIRTUAL_SIZE.y
	var drift := t * 4.0 if not GameTheme.ui_reduced_motion() else 0.0
	# Layer 0 — deep haze gradient bands (wider portrait read).
	draw_rect(Rect2(0, 0, sw, sh * 0.45), SKY_BACK)
	draw_rect(Rect2(0, sh * 0.35, sw, sh * 0.25), SKY_MID)
	draw_rect(Rect2(0, sh * 0.55, sw, sh * 0.25), SKY_HAZE)
	# Moon + haze disc (tier 4+).
	if tier >= 4:
		var moon_x := sw - 36.0 + sin(t * 0.15) * 2.0
		draw_circle(Vector2(moon_x, 22.0), 11.0, Color8(200, 205, 195))
		draw_circle(Vector2(moon_x + 4.0, 19.0), 9.0, SKY_BACK)
	# Sparse stars — hash twinkle, not pygame sin grid.
	var star_count := 8 if tier < 2 else 5
	for i in star_count:
		var sx := fmod(float(i * 47 + 13) + drift * 0.2, sw - 8.0) + 4.0
		var sy := 8.0 + float(i * 11 % 40)
		var tw := 0.35 + 0.65 * _hash01(i * 17, t * 0.5)
		draw_rect(Rect2(sx, sy, 2.0, 2.0), Color(0.82, 0.84, 1.0, tw * 0.7))
	# Distant mid-parallax silhouettes (always present, density grows with tier).
	var back_h := 40.0 + tier * 18.0
	var back_y := sh * 0.58 - back_h
	var back_drift := fmod(drift * 0.35, sw)
	for i in 6 + tier * 2:
		var bw := 18.0 + float(i % 4) * 14.0
		var bh := back_h * (0.55 + float(i % 3) * 0.15)
		var bx := fmod(float(i * 53) + back_drift, sw + bw) - bw * 0.5
		draw_rect(Rect2(bx, back_y + back_h - bh, bw, bh), Color(SILHOUETTE, 0.55))


func _draw_mid_skyline(total: int, tier: int, keys: Array, t: float, ground_y: float) -> void:
	var sw := VIRTUAL_SIZE.x
	var drift := t * 6.0 if not GameTheme.ui_reduced_motion() else 0.0
	var count := mini(maxi(keys.size(), 1 if tier > 0 else 0), 3)
	var slot_w := sw / maxf(1.0, float(count))
	var neon_keys: Array = keys if not keys.is_empty() else (["dealer"] if tier > 0 else [])
	for i in count:
		var key: String = neon_keys[i] if i < neon_keys.size() else "dealer"
		var cx := slot_w * (float(i) + 0.5) + sin(t * 0.4 + i) * 1.5
		var base_h := 36.0 + tier * 22.0 + float(i % 2) * 12.0
		if total >= 80:
			base_h += 40.0
		elif total >= 35:
			base_h += 24.0
		_draw_building_signature(key, cx, ground_y, base_h, tier, i, t)
	# Tier 2+ — vertical neon signs between facades.
	if tier >= 2:
		for i in count - 1:
			var sx := slot_w * (float(i) + 1.0) + fmod(drift * 0.1, 4.0)
			var sign_h := 28.0 + tier * 8.0
			var pulse := 0.6 + 0.4 * sin(t * 2.5 + i * 1.3)
			var col := NEON_WARM if i % 2 == 0 else NEON_COOL
			draw_rect(Rect2(sx - 2.0, ground_y - sign_h - 8.0, 4.0, sign_h),
					Color(col, pulse * 0.85))
			draw_rect(Rect2(sx - 5.0, ground_y - sign_h - 12.0, 10.0, 4.0), Color(col, pulse * 0.5))
	# Tier 3+ — bridge connector.
	if tier >= 3 and count >= 2:
		var bx0 := slot_w * 0.5
		var bx1 := slot_w * 1.5
		var by := ground_y - 48.0 - tier * 6.0
		draw_line(Vector2(bx0 + 20.0, by), Vector2(bx1 - 20.0, by), Color8(55, 58, 78), 2.0)
		for px in 5:
			var fx := lerpf(bx0 + 20.0, bx1 - 20.0, float(px) / 4.0)
			draw_line(Vector2(fx, by), Vector2(fx, by + 6.0), Color8(70, 74, 95), 1.0)
	# Tier 4 — helicopter blink.
	if tier >= 4:
		var hx := fmod(t * 18.0 + sw * 0.2, sw + 40.0) - 20.0
		var hy := 28.0 + sin(t * 1.1) * 3.0
		draw_rect(Rect2(hx, hy, 14.0, 5.0), Color8(40, 44, 58))
		draw_line(Vector2(hx + 7.0, hy), Vector2(hx + 7.0, hy - 4.0), Color8(60, 64, 80), 1.0)
		if _hash01(99, t * 2.0) > 0.45:
			draw_circle(Vector2(hx + 2.0, hy + 2.0), 2.0, Color8(255, 60, 50))
	# Syndicate crown watermark at max tier.
	if tier >= 4 and total >= 80:
		_draw_crown_watermark(sw * 0.5, ground_y - 120.0, t)


func _draw_building_signature(key: String, cx: float, ground_y: float, bh: float,
		tier: int, seed: int, t: float) -> void:
	var bw := 52.0 + float(seed % 3) * 10.0
	var bx := cx - bw * 0.5
	var by := ground_y - bh
	var body := SILHOUETTE
	var neon := NEON_WARM
	match key:
		"dealer":
			bw = 44.0
			draw_rect(Rect2(bx, by + bh * 0.15, bw, bh * 0.85), body)
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx, by + bh * 0.15), Vector2(bx + bw * 0.5, by),
				Vector2(bx + bw, by + bh * 0.15),
			]), Color(body, 0.95))
			neon = NEON_WARM
		"racket":
			draw_rect(Rect2(bx, by, bw, bh), body)
			draw_rect(Rect2(bx + 4.0, by - 6.0, bw - 8.0, 6.0), Color8(50, 54, 72))
			neon = NEON_RED
		"chop":
			draw_rect(Rect2(bx, by + bh * 0.2, bw, bh * 0.8), body)
			for stripe in 3:
				var sy := by + bh * 0.25 + stripe * 14.0
				draw_line(Vector2(bx + 4.0, sy), Vector2(bx + bw - 4.0, sy + 8.0), Color8(45, 48, 65), 2.0)
			neon = Color8(255, 140, 50)
		"betting":
			draw_rect(Rect2(bx + 6.0, by + 8.0, bw - 12.0, bh - 8.0), body)
			draw_rect(Rect2(bx, by, bw, 10.0), Color8(48, 52, 70))
			neon = NEON_COOL
		"pawn":
			draw_rect(Rect2(bx + 8.0, by, bw - 16.0, bh), body)
			for pi in 3:
				draw_circle(Vector2(bx + bw * (0.25 + pi * 0.25), by + 18.0), 4.0, Color8(35, 38, 55))
			neon = NEON_WARM
		"loan":
			bw = 38.0
			bx = cx - bw * 0.5
			draw_rect(Rect2(bx, by, bw, bh), body)
			draw_rect(Rect2(bx + bw * 0.5 - 2.0, by + 10.0, 4.0, bh - 20.0), Color8(200, 180, 60, 120))
			neon = Color8(200, 190, 80)
		"casino":
			draw_rect(Rect2(bx, by + 16.0, bw, bh - 16.0), body)
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx, by + 16.0), Vector2(bx + bw * 0.5, by - 4.0), Vector2(bx + bw, by + 16.0),
			]), Color8(38, 42, 60))
			neon = Color8(255, 80, 180)
		"club":
			draw_rect(Rect2(bx + 4.0, by + 12.0, bw - 8.0, bh - 12.0), body)
			draw_arc(Vector2(cx, by + 12.0), bw * 0.45, PI, TAU, 12, Color8(42, 46, 64), 3.0)
			neon = Color8(180, 80, 255)
		"dock":
			draw_rect(Rect2(bx, by + bh * 0.35, bw, bh * 0.65), body)
			draw_line(Vector2(bx + bw * 0.7, by), Vector2(bx + bw * 0.7, by + bh * 0.35), Color8(55, 60, 78), 2.0)
			draw_line(Vector2(bx + bw * 0.7, by + 4.0), Vector2(bx + bw * 0.45, by + 14.0), Color8(55, 60, 78), 2.0)
			neon = NEON_COOL
		"arms":
			draw_rect(Rect2(bx + 10.0, by + 20.0, bw - 20.0, bh - 20.0), body)
			draw_line(Vector2(cx, by), Vector2(cx, by + 16.0), Color8(60, 64, 82), 2.0)
			draw_circle(Vector2(cx, by), 3.0, Color8(70, 74, 92))
			neon = NEON_RED
		"hq":
			draw_rect(Rect2(bx + 6.0, by + 24.0, bw - 12.0, bh - 24.0), body)
			draw_rect(Rect2(bx + bw * 0.5 - 4.0, by, 8.0, 28.0), Color8(46, 50, 68))
			_draw_crown_watermark(cx, by - 6.0, t, 0.5)
			neon = INK_GOLD_BRIGHT
		_:
			draw_rect(Rect2(bx, by, bw, bh), body)
	# Neon facade trim + hash flicker windows.
	var win_rows := 1 + tier
	var win_cols := 2 + tier / 2
	for wy in win_rows:
		for wx in win_cols:
			var wseed := seed * 31 + wx * 7 + wy * 13
			if not _hash_flicker(wseed, t):
				continue
			var wxp := bx + 8.0 + wx * ((bw - 16.0) / maxf(1.0, float(win_cols - 1)))
			var wyp := by + 14.0 + wy * 16.0
			if wyp + 8.0 > ground_y - 6.0:
				continue
			draw_rect(Rect2(wxp, wyp, 7.0, 9.0), Color(neon, 0.75))
	draw_rect(Rect2(bx, ground_y - bh - 5.0, bw, 4.0), Color(neon, 0.55 + 0.25 * sin(t * 2.0 + seed)))


func _draw_crown_watermark(cx: float, cy: float, t: float, scale: float = 1.0) -> void:
	var s := scale
	var col := Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.12 + 0.04 * sin(t * 0.8))
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 18.0 * s, cy + 10.0 * s), Vector2(cx, cy - 14.0 * s), Vector2(cx + 18.0 * s, cy + 10.0 * s),
	]), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 12.0 * s, cy + 10.0 * s), Vector2(cx - 6.0 * s, cy - 4.0 * s),
		Vector2(cx, cy + 10.0 * s),
	]), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx, cy + 10.0 * s), Vector2(cx + 6.0 * s, cy - 4.0 * s), Vector2(cx + 12.0 * s, cy + 10.0 * s),
	]), col)


func _draw_front_street(ground_y: float, t: float) -> void:
	var sw := VIRTUAL_SIZE.x
	draw_rect(Rect2(0, ground_y, sw, VIRTUAL_SIZE.y - ground_y), STREET)
	draw_line(Vector2(0, ground_y + 5.0), Vector2(sw, ground_y + 5.0), STREET_LINE, 1.0)
	# Wet-street center reflection shimmer.
	if not GameTheme.ui_reduced_motion():
		var shimmer_x := fmod(t * 30.0, sw + 60.0) - 30.0
		draw_rect(Rect2(shimmer_x, ground_y + 8.0, 40.0, 2.0), Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.15))


func _draw_district_strip(ground_y: float, slots: Array) -> void:
	if slots.is_empty():
		return
	var sw := VIRTUAL_SIZE.x
	var count := mini(slots.size(), 12)
	var pad := 6.0
	var block_w := (sw - pad * 2.0) / float(count) - 2.0
	var by := ground_y + 10.0
	for i in count:
		var slot: Dictionary = slots[i]
		var bx := pad + float(i) * (block_w + 2.0)
		var unlocked: bool = bool(slot.get("unlocked", false))
		var col: Color = slot.get("color", Color8(60, 60, 80))
		var shell := Color8(22, 24, 36) if unlocked else Color8(14, 15, 22)
		draw_rect(Rect2(bx, by, block_w, 12.0), shell)
		if unlocked:
			draw_rect(Rect2(bx + 1.0, by + 1.0, block_w - 2.0, 4.0), Color(col, 0.85))
			if _hash_flicker(i * 23 + 5, _t):
				draw_rect(Rect2(bx + 2.0, by + 6.0, maxf(2.0, block_w * 0.35), 3.0), Color(col, 0.55))
			var short_lbl: String = str(slot.get("short", ""))
			if short_lbl.length() > 0 and block_w >= 14.0:
				var font := ThemeDB.fallback_font
				var fs := 7
				draw_string(font, Vector2(bx + 1.0, by + 11.0), short_lbl.substr(0, 3),
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.7))


func _draw_atmosphere(heat: float, rank_idx: int, t: float, tier: int) -> void:
	var sw := VIRTUAL_SIZE.x
	var sh := VIRTUAL_SIZE.y
	# Full-width crimson top gradient (replaces pygame flat wash + ellipses).
	if heat >= 15.0:
		var steps := 6
		for i in steps:
			var frac := float(i) / float(steps)
			var intensity := clampf((heat - 15.0) / 85.0, 0.0, 1.0) * (1.0 - frac * 0.65)
			var band_h := sh * 0.12
			draw_rect(Rect2(0, band_h * frac, sw, band_h),
					Color(INK_CRIMSON.r, INK_CRIMSON.g, INK_CRIMSON.b, intensity * 0.22))
	# Rotating blue siren slice at 60%+ (not pygame full-rect flash).
	if heat >= 60.0:
		if GameTheme.ui_reduced_motion() or int(t * 3.0) % 2 == 0:
			var angle := t * 2.8 if not GameTheme.ui_reduced_motion() else 0.0
			var cx := sw * 0.5
			var cy := 8.0
			var r := sw * 0.95
			var wedge := 0.55
			var p0 := Vector2(cx, cy)
			var p1 := p0 + Vector2(cos(angle), sin(angle)) * r
			var p2 := p0 + Vector2(cos(angle + wedge), sin(angle + wedge)) * r
			draw_colored_polygon(PackedVector2Array([p0, p1, p2]),
					Color(0.157, 0.235, 0.706, 0.09))
	var crime_lord_idx := PrestigeScript.rank_index("Crime Lord")
	if rank_idx >= crime_lord_idx:
		draw_rect(Rect2(0, sh - 52.0, sw, 18.0),
				Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.11))


func _draw_scanlines() -> void:
	var sw := VIRTUAL_SIZE.x
	var sh := VIRTUAL_SIZE.y
	var y := 0.0
	while y < sh:
		draw_line(Vector2(0, y), Vector2(sw, y), Color(0, 0, 0, 0.04), 1.0)
		y += 4.0


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

	# Radial pulse rings + street reflection under disc.
	if not GameTheme.ui_reduced_motion():
		for ring in 3:
			var phase := _t * 1.8 - ring * 0.45
			var radius := bw * (0.52 + ring * 0.14) + 6.0 * sin(phase)
			var alpha := 0.08 + 0.12 * (0.5 + 0.5 * sin(phase))
			if _income_per_second > 0.0:
				alpha *= 1.4
			draw_arc(Vector2(cx, cy), radius, 0.0, TAU, 32,
					Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, alpha), 1.5)
		var refl_y := cy + bh * 0.55
		draw_line(Vector2(cx - bw * 0.35, refl_y), Vector2(cx + bw * 0.35, refl_y),
				Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.25), 2.0)
		draw_line(Vector2(cx - bw * 0.15, refl_y + 3.0), Vector2(cx + bw * 0.15, refl_y + 3.0),
				Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.12), 1.0)

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


func _hash01(seed: int, t: float) -> float:
	var h := (seed * 1103515245 + int(t * 1000.0)) & 0x7FFFFFFF
	return float(h % 1000) / 1000.0


func _hash_flicker(seed: int, t: float) -> bool:
	return _hash01(seed, t) > 0.35
