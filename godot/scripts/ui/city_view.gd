extends Control
class_name CityView
## P15.3b — Godot-native city viewport (inspired by pygame tiers, not pixel-parity). ART_POLICY: no textures.

const PrestigeScript = preload("res://scripts/systems/prestige.gd")
const GameFonts = preload("res://scripts/ui/game_fonts.gd")

const VIRTUAL_SIZE := Vector2(404.0, 320.0)
const REDRAW_INTERVAL := 1.0 / 30.0

const INK := Color("06070c")
const INK_GOLD := Color(0.541, 0.361, 1.0, 0.157)
const INK_GOLD_BRIGHT := Color(0.694, 0.549, 1.0)
const INK_CRIMSON := Color(0.608, 0.157, 0.157)
const SKY_BACK := Color8(14, 24, 38)
const SKY_MID := Color8(20, 30, 52)
const SKY_HAZE := Color8(38, 46, 72)
const SKY_GLOW := Color8(72, 82, 118)
const STREET := Color8(26, 28, 42)
const STREET_LINE := Color8(58, 62, 84)
const SILHOUETTE := Color8(52, 58, 88)
const SILHOUETTE_RIM := Color8(78, 86, 118)
const SILHOUETTE_BACK := Color8(36, 42, 68)
const NEON_WARM := Color8(255, 180, 70)
const NEON_COOL := Color8(47, 214, 198)
const NEON_RED := Color8(220, 60, 70)
# Bright rooftop-sign / wet-street bloom (study `b` win teal).
const NEON_SIGN := Color8(79, 224, 208)
# Cyberpunk mixed-neon skyline: violet lead, magenta + cyan support.
const NEON_SET := [Color8(138, 92, 255), Color8(229, 69, 126), Color8(47, 214, 198)]
# Distant lit-window mix — warm amber is one voice among the city's neon,
# not the only one. Seeded per tower, so the mix is stable frame-to-frame.
const WINDOW_MIX := [
	Color8(255, 180, 70), Color8(138, 92, 255), Color8(47, 214, 198),
	Color8(229, 69, 126), Color8(255, 180, 70), Color8(138, 92, 255),
]

@onready var _empire_label: Label = $EmpireLabel

## Stage & Ledger shell promotes the city to the app background (Z2). Full-bleed
## drops the framed-viewport chrome (border chevrons + caption) that only makes
## sense when the city is a strip inside other chrome.
@export var full_bleed := false

var _t: float = 0.0
var _anim_accum: float = 0.0
var _dirty: bool = true
var _overlay_occluded: bool = false

var _total_buildings: int = 0
var _heat: float = 0.0
var _districts_owned: int = 0
var _rank_idx: int = 0
var _top_building_keys: Array = []
var _top_building_counts: Array = []
var _top_building_shares: Array = []
var _district_slots: Array = []
## Heat danger read as drawn STATE (0 calm, 1 warn, 2 critical) — the street
## turns hostile, never a wash over the player's balance.
var _alert_level: int = 0
var _raid_pulse: float = 0.0
## How long a purchase keeps its facade lit (seconds).
const FACADE_PULSE_TIME := 1.6
## key -> remaining seconds. Reactions are drawn STATE, never stacked nodes:
## this canvas is immediate-mode, so a node layered over it cannot know where
## anything is — which is exactly how the old full-screen wash happened.
var _facade_pulse: Dictionary = {}
## How long a captured/claimed block stays flashing (seconds).
const DISTRICT_PULSE_TIME := 1.4
## territory idx -> {"t": seconds_left, "holder": String}. Drawn state, like the
## facade pulses — never a node stacked over the immediate-mode canvas.
var _district_pulse: Dictionary = {}
# Neon reflection anchors collected during the skyline pass, painted into the
# wet street afterwards (street is drawn on top of the buildings).
var _reflect_points: Array = []

var _last_buildings: int = -1
var _last_heat: float = -1.0
var _last_districts: int = -1
var _last_rank_idx: int = -1
var _last_building_sig: String = ""


func _ready() -> void:
	clip_contents = true
	_empire_label.visible = false
	if not _is_headless():
		queue_redraw()


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func set_overlay_occluded(occluded: bool) -> void:
	if _overlay_occluded == occluded:
		return
	_overlay_occluded = occluded


func refresh(
	total_buildings: int,
	heat: float,
	districts_owned: int,
	career_tokens: int,
	top_building_keys: Array = [],
	district_slots: Array = [],
	building_counts: Array = [],
	building_shares: Array = []
) -> void:
	var rank_name := PrestigeScript.get_rank(career_tokens)
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
	_top_building_keys = top_building_keys
	_top_building_counts = building_counts
	_top_building_shares = building_shares
	_district_slots = district_slots

	if state_changed:
		_mark_dirty()


func _building_sig(keys: Array) -> String:
	return "|".join(keys)


func _mark_dirty() -> void:
	_dirty = true


## A business was bought — light ITS facade. No-op if that business has no
## facade on screen (only the top 5 owned types get one).
func pulse_facade(key: String) -> void:
	if not _top_building_keys.has(key):
		return
	_facade_pulse[key] = FACADE_PULSE_TIME
	_dirty = true


func is_facade_pulsing(key: String) -> bool:
	return float(_facade_pulse.get(key, 0.0)) > 0.0


## A district changed hands — flash THAT block (gold for a capture, siren red for
## a rival claim). Drawn state; no-op-safe headless like the facade pulses.
func set_district(idx: int, holder: String) -> void:
	_district_pulse[idx] = {"t": DISTRICT_PULSE_TIME, "holder": holder}
	_dirty = true


func is_district_pulsing(idx: int) -> bool:
	return _district_pulse.has(idx) and float(_district_pulse[idx].get("t", 0.0)) > 0.0


func set_alert_level(level: int) -> void:
	if _alert_level == level:
		return
	_alert_level = level
	_dirty = true


func alert_level() -> int:
	return _alert_level


## A raid hits the street — a hot siren surge low in the frame, not a wash over
## the player's balance. Decays in _process like the facade pulses.
func play_raid_flash() -> void:
	if GameTheme.ui_reduced_motion():
		return
	_raid_pulse = 1.0
	_dirty = true


func income_share(key: String) -> float:
	var idx := _top_building_keys.find(key)
	if idx < 0 or idx >= _top_building_shares.size():
		return 0.0
	return float(_top_building_shares[idx])


func _process(delta: float) -> void:
	if _is_headless() or _overlay_occluded:
		return
	_anim_accum += delta
	if _anim_accum < REDRAW_INTERVAL:
		return
	_anim_accum = 0.0
	_t += REDRAW_INTERVAL
	if not _facade_pulse.is_empty():
		for k in _facade_pulse.keys():
			var left: float = float(_facade_pulse[k]) - REDRAW_INTERVAL
			if left <= 0.0:
				_facade_pulse.erase(k)
			else:
				_facade_pulse[k] = left
		_dirty = true
	if _raid_pulse > 0.0:
		_raid_pulse = maxf(0.0, _raid_pulse - REDRAW_INTERVAL)
		_dirty = true
	if not _district_pulse.is_empty():
		for k in _district_pulse.keys():
			var left: float = float(_district_pulse[k]["t"]) - REDRAW_INTERVAL
			if left <= 0.0:
				_district_pulse.erase(k)
			else:
				_district_pulse[k]["t"] = left
		_dirty = true
	var animating := not GameTheme.ui_reduced_motion()
	if animating or _dirty:
		queue_redraw()
		_dirty = false


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
	_reflect_points.clear()
	if full_bleed:
		draw_rect(Rect2(Vector2.ZERO, VIRTUAL_SIZE), INK)
	else:
		_draw_frame()
	_draw_back_parallax(_t, tier)
	_draw_searchlights(_t, _alert_level)
	_draw_mid_skyline(_total_buildings, tier, _top_building_keys, _top_building_counts, _t, ground_y)
	_draw_rooftop_signs(ground_y)
	_draw_horizon_glow(ground_y)
	if tier == 0:
		_draw_tier0_street_detail(ground_y, _t)
	_draw_front_street(ground_y, _t)
	_draw_reflections(ground_y, _t)
	_draw_neon_streaks(ground_y, _t)
	_draw_pedestrians(ground_y, _t, tier)
	_draw_traffic(ground_y, _t, _alert_level)
	if _raid_pulse > 0.0:
		_draw_raid_surge(ground_y)
	_draw_district_strip(ground_y, _district_slots)
	_draw_atmosphere(_heat, _rank_idx, _t, tier)
	_draw_vignette()
	_draw_corner_brackets()
	_draw_rain(_t, _heat)
	if not full_bleed:
		_draw_caption(tier, _total_buildings)
	if not GameTheme.ui_reduced_motion():
		_draw_scanlines()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
	# Layer 0 — stepped night gradient (study idiom). No flat-band seams, and
	# the haze tail is damped to 60% so the sky stays deep, not washed.
	var grad_h := sh * 0.8
	var grad_steps := 24
	for gi in grad_steps:
		var gt := float(gi) / float(grad_steps - 1)
		var gcol := SKY_BACK.lerp(SKY_MID, clampf(gt / 0.55, 0.0, 1.0))
		if gt > 0.55:
			gcol = gcol.lerp(SKY_HAZE, (gt - 0.55) / 0.45 * 0.6)
		draw_rect(Rect2(0, grad_h * float(gi) / float(grad_steps), sw,
				grad_h / float(grad_steps) + 1.0), gcol)
	# Distant city glow banked on the horizon — warms the empty upper sky so
	# even a tier-0 empire reads as "a city at night," not a flat void.
	var glow_y := sh * 0.5
	for gi in 4:
		var ga := 0.05 - gi * 0.011
		if ga <= 0.0:
			continue
		draw_rect(Rect2(0, glow_y - gi * 8.0, sw, 8.0),
				Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, ga))
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
	# Far skyline ridge — a distant, dim row high in the frame gives the sky
	# depth before the empire owns anything (fills the tier-0 dead zone).
	var far_base := sh * 0.52
	var far_h := 26.0 + tier * 8.0
	var far_drift := fmod(drift * 0.18, sw)
	var far_col := Color(SILHOUETTE_BACK.r * 1.15, SILHOUETTE_BACK.g * 1.15, SILHOUETTE_BACK.b * 1.2, 0.85)
	for i in 11 + tier * 2:
		var fw := 12.0 + float(i % 5) * 9.0
		var fh := far_h * (0.4 + float((i * 7) % 4) * 0.18)
		var fx := fmod(float(i * 37) + far_drift, sw + fw) - fw * 0.5
		draw_rect(Rect2(fx, far_base - fh, fw, fh), far_col)
		# Faint lit windows scattered through the distant towers.
		if (i * 13) % 3 == 0:
			draw_rect(Rect2(fx + fw * 0.35, far_base - fh * 0.55, 2.0, 2.0),
					Color(WINDOW_MIX[(i * 7) % WINDOW_MIX.size()], 0.22))
	# Three tall distant skyscrapers punching into the upper sky — gives the
	# empty top third a believable downtown ridge even at tier 0.
	var anchor_x := [sw * 0.2, sw * 0.52, sw * 0.82]
	var anchor_top := [sh * 0.3, sh * 0.24, sh * 0.33]
	for a in 3:
		var ax: float = anchor_x[a] + sin(t * 0.12 + a) * 0.6
		var atop: float = anchor_top[a]
		var aw := 16.0 + float(a % 2) * 6.0
		draw_rect(Rect2(ax - aw * 0.5, atop, aw, far_base - atop), far_col)
		draw_line(Vector2(ax - aw * 0.5, atop), Vector2(ax + aw * 0.5, atop), Color(SILHOUETTE_RIM, 0.5), 1.0)
		# Slim antenna mast + red aviation blip on the crown.
		draw_line(Vector2(ax, atop), Vector2(ax, atop - 10.0), Color(SILHOUETTE_RIM, 0.4), 1.0)
		var beacon_on := _hash01(a * 41 + 3, t * 1.5) > 0.5
		if _alert_level >= 1 and not GameTheme.ui_reduced_motion():
			beacon_on = int(t * 5.0 + float(a)) % 2 == 0
		if beacon_on:
			var beacon_a := 0.5 if _alert_level == 0 else 0.9
			draw_rect(Rect2(ax - 1.0, atop - 11.0, 2.0, 2.0), Color(NEON_RED, beacon_a))
		# A sparse column of lit windows so the tower reads as inhabited.
		for wy in 4:
			if _hash_flicker(a * 19 + wy * 7, t):
				draw_rect(Rect2(ax - aw * 0.25, atop + 10.0 + wy * 14.0, 2.0, 3.0),
						Color(WINDOW_MIX[(a * 5 + wy) % WINDOW_MIX.size()], 0.24))
	# Distant mid-parallax silhouettes (always present, density grows with tier).
	var back_h := 44.0 + tier * 18.0
	var back_y := sh * 0.58 - back_h
	var back_drift := fmod(drift * 0.35, sw)
	for i in 8 + tier * 2:
		var bw := 18.0 + float(i % 4) * 14.0
		var bh := back_h * (0.55 + float(i % 3) * 0.15)
		var bx := fmod(float(i * 53) + back_drift, sw + bw) - bw * 0.5
		draw_rect(Rect2(bx, back_y + back_h - bh, bw, bh), Color(SILHOUETTE_BACK, 0.92))
		# A few nearer distant towers carry a dim warm window so the ridge lives.
		if i % 3 == 1:
			draw_rect(Rect2(bx + bw * 0.4, back_y + back_h - bh + 4.0, 2.0, 3.0),
					Color(WINDOW_MIX[(i * 11 + 2) % WINDOW_MIX.size()], 0.35))


func _draw_mid_skyline(total: int, tier: int, keys: Array, counts: Array, t: float, ground_y: float) -> void:
	var sw := VIRTUAL_SIZE.x
	# One hero facade per owned business type (up to 5), so owning more types
	# widens the skyline. Always show at least one so tier 0 is not a void.
	var count := mini(maxi(keys.size(), 1), 5)
	var slot_w := sw / maxf(1.0, float(count))
	var neon_keys: Array = keys if not keys.is_empty() else ["dealer"]
	for i in count:
		var key: String = neon_keys[i] if i < neon_keys.size() else "dealer"
		var owned: int = int(counts[i]) if i < counts.size() else 1
		var cx := slot_w * (float(i) + 0.5) + sin(t * 0.4 + i) * 1.5
		# Each unit invested climbs the facade (log-damped so it never runs
		# away): +0 at 1 owned, ~+34 at 6, ~+57 at 20. This is what makes the
		# city keep growing every purchase, not just at tier thresholds.
		var grow := log(float(maxi(owned, 1))) / log(6.0)
		var base_h := 34.0 + tier * 18.0 + grow * 34.0 + float(i % 2) * 10.0
		if total >= 80:
			base_h += 40.0
		elif total >= 35:
			base_h += 24.0
		# Dominant business (most owned) towers as the empire's hero landmark.
		if i == 0 and not keys.is_empty():
			base_h *= 1.3
		var breath := 1.0
		if not GameTheme.ui_reduced_motion():
			var share: float = float(_top_building_shares[i]) if i < _top_building_shares.size() else 0.0
			breath = 1.0 + sin(t * 1.4 + float(i) * 1.7) * 0.10 * share
		_draw_building_signature(key, cx, ground_y, base_h, tier, i, t, breath)
		var pulse: float = float(_facade_pulse.get(key, 0.0))
		if pulse > 0.0:
			_draw_facade_pulse(cx, ground_y, base_h, i, pulse)
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
		tier: int, seed: int, t: float, breath: float = 1.0) -> void:
	var bw := 52.0 + float(seed % 3) * 10.0
	var bx := cx - bw * 0.5
	var by := ground_y - bh
	var body := SILHOUETTE
	# Facade neon is single-sourced in GameTheme so the tower and its row
	# medallion (count_medallion.gd) always light up the same colour.
	var neon := GameTheme.building_neon(key)
	match key:
		"dealer":
			bw = 44.0
			draw_rect(Rect2(bx, by + bh * 0.15, bw, bh * 0.85), body)
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx, by + bh * 0.15), Vector2(bx + bw * 0.5, by),
				Vector2(bx + bw, by + bh * 0.15),
			]), Color(body, 0.95))
		"racket":
			draw_rect(Rect2(bx, by, bw, bh), body)
			draw_rect(Rect2(bx + 4.0, by - 6.0, bw - 8.0, 6.0), Color8(50, 54, 72))
		"chop":
			draw_rect(Rect2(bx, by + bh * 0.2, bw, bh * 0.8), body)
			for stripe in 3:
				var sy := by + bh * 0.25 + stripe * 14.0
				draw_line(Vector2(bx + 4.0, sy), Vector2(bx + bw - 4.0, sy + 8.0), Color8(45, 48, 65), 2.0)
		"betting":
			draw_rect(Rect2(bx + 6.0, by + 8.0, bw - 12.0, bh - 8.0), body)
			draw_rect(Rect2(bx, by, bw, 10.0), Color8(48, 52, 70))
		"pawn":
			draw_rect(Rect2(bx + 8.0, by, bw - 16.0, bh), body)
			for pi in 3:
				draw_circle(Vector2(bx + bw * (0.25 + pi * 0.25), by + 18.0), 4.0, Color8(35, 38, 55))
		"loan":
			bw = 38.0
			bx = cx - bw * 0.5
			draw_rect(Rect2(bx, by, bw, bh), body)
			draw_rect(Rect2(bx + bw * 0.5 - 2.0, by + 10.0, 4.0, bh - 20.0), Color8(200, 180, 60, 120))
		"casino":
			draw_rect(Rect2(bx, by + 16.0, bw, bh - 16.0), body)
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx, by + 16.0), Vector2(bx + bw * 0.5, by - 4.0), Vector2(bx + bw, by + 16.0),
			]), Color8(38, 42, 60))
		"club":
			draw_rect(Rect2(bx + 4.0, by + 12.0, bw - 8.0, bh - 12.0), body)
			draw_arc(Vector2(cx, by + 12.0), bw * 0.45, PI, TAU, 12, Color8(42, 46, 64), 3.0)
		"dock":
			draw_rect(Rect2(bx, by + bh * 0.35, bw, bh * 0.65), body)
			draw_line(Vector2(bx + bw * 0.7, by), Vector2(bx + bw * 0.7, by + bh * 0.35), Color8(55, 60, 78), 2.0)
			draw_line(Vector2(bx + bw * 0.7, by + 4.0), Vector2(bx + bw * 0.45, by + 14.0), Color8(55, 60, 78), 2.0)
		"arms":
			draw_rect(Rect2(bx + 10.0, by + 20.0, bw - 20.0, bh - 20.0), body)
			draw_line(Vector2(cx, by), Vector2(cx, by + 16.0), Color8(60, 64, 82), 2.0)
			draw_circle(Vector2(cx, by), 3.0, Color8(70, 74, 92))
		"hq":
			draw_rect(Rect2(bx + 6.0, by + 24.0, bw - 12.0, bh - 24.0), body)
			draw_rect(Rect2(bx + bw * 0.5 - 4.0, by, 8.0, 28.0), Color8(46, 50, 68))
			_draw_crown_watermark(cx, by - 6.0, t, 0.5)
		_:
			draw_rect(Rect2(bx, by, bw, bh), body)
	# Tall towers get a shaded edge so they read as massed volume, not slab.
	if bh > 120.0:
		draw_rect(Rect2(bx + bw * 0.8, by, bw * 0.2, bh), Color(0.0, 0.0, 0.0, 0.18))
	# Neon facade trim + hash flicker windows. Rows follow the facade's real
	# height (a fixed 1+tier left tall hero towers 80% blank wall).
	var win_rows := clampi(int((bh - 24.0) / 16.0), 1, 16)
	var win_cols := clampi(2 + tier / 2, 2, maxi(2, int(bw / 14.0)))
	for wy in win_rows:
		for wx in win_cols:
			var wseed := seed * 31 + wx * 7 + wy * 13
			if not _hash_flicker(wseed, t):
				continue
			# The city lies low when the police circle: a deterministic share of
			# windows goes dark at warn (25%) and critical (50%). Never at calm.
			if _alert_level > 0 and _hash01(wseed * 7 + 1, 0.0) < 0.25 * float(_alert_level):
				continue
			var wxp := bx + 8.0 + wx * ((bw - 16.0) / maxf(1.0, float(win_cols - 1)))
			var wyp := by + 14.0 + wy * 16.0
			if wyp + 8.0 > ground_y - 6.0:
				continue
			draw_rect(Rect2(wxp, wyp, 7.0, 9.0), Color(neon, clampf(0.92 * breath, 0.0, 1.0)))
	# Rim light — separates facades from haze band at small portrait sizes.
	draw_line(Vector2(bx, by), Vector2(bx, ground_y - bh), Color(SILHOUETTE_RIM, 0.35), 1.0)
	draw_rect(Rect2(bx, ground_y - bh - 5.0, bw, 4.0), Color(neon, 0.65 + 0.3 * sin(t * 2.0 + seed)))
	# Warn+: a hot aviation beacon on the crown — danger reads in a still frame.
	if _alert_level >= 1:
		var bk_on := true if GameTheme.ui_reduced_motion() else int(t * 5.0 + float(seed)) % 2 == 0
		if bk_on:
			draw_circle(Vector2(cx, ground_y - bh - 9.0), 2.0, Color(NEON_RED, 0.85))
	# Critical: the dragnet's light catches the towers — alternating siren rim.
	if _alert_level >= 2:
		var siren := GameTheme.SIREN_RED
		if not GameTheme.ui_reduced_motion() and int(t * 4.0 + float(seed)) % 2 == 1:
			siren = GameTheme.SIREN_BLUE
		draw_rect(Rect2(bx, ground_y - bh, bw, bh), Color(siren.r, siren.g, siren.b, 0.28), false, 2.0)
	# Remember this facade's neon so it can bleed into the wet street later.
	_reflect_points.append([cx, neon])
	# Neon marquee on the building's shoulder — a framed blade sign lit in the
	# business's own colour. Static (no drift/flicker) so it reads as signage.
	if tier >= 2:
		_draw_marquee(bx + bw + 1.0, by + maxf(5.0, bh * 0.22), minf(18.0, bh * 0.4), neon, bx + bw, key)


## The bought business's facade lights up — the empire acknowledging a purchase
## in the world, not a tint over the player's whole screen.
func _draw_facade_pulse(cx: float, ground_y: float, bh: float, seed: int, pulse: float) -> void:
	if GameTheme.ui_reduced_motion():
		return
	var a := clampf(pulse / FACADE_PULSE_TIME, 0.0, 1.0)
	var bw := 52.0 + float(seed % 3) * 10.0
	var rect := Rect2(cx - bw * 0.5, ground_y - bh, bw, bh)
	var glow := INK_GOLD_BRIGHT
	draw_rect(rect, Color(glow.r, glow.g, glow.b, 0.10 * a), true)
	draw_rect(rect, Color(glow.r, glow.g, glow.b, 0.55 * a), false, 1.5)


func _draw_marquee(mq_x: float, mq_y: float, mq_h: float, col: Color, wall_x: float, key: String = "") -> void:
	var mq_w := 8.0
	# Bracket arm tying the blade to the wall.
	draw_line(Vector2(wall_x, mq_y + 3.0), Vector2(mq_x, mq_y + 3.0), Color(SILHOUETTE_RIM, 0.6), 1.0)
	# Soft glow halo, dark sign panel, glowing neon frame.
	draw_rect(Rect2(mq_x - 1.5, mq_y - 1.5, mq_w + 3.0, mq_h + 3.0), Color(col, 0.16))
	draw_rect(Rect2(mq_x, mq_y, mq_w, mq_h), Color8(14, 16, 26))
	draw_rect(Rect2(mq_x, mq_y, mq_w, mq_h), Color(col, 0.95), false, 1.0)
	# Business glyph when the blade is tall enough; else stacked letter segments.
	if not key.is_empty() and mq_h >= 12.0:
		SigilGlyphs.draw_glyph(self, key, Vector2(mq_x + mq_w * 0.5, mq_y + mq_h * 0.5),
			minf(mq_w, mq_h) * 0.48, Color(col, 0.95))
		return
	var seg_n := maxi(1, int((mq_h - 3.0) / 5.0))
	for s in seg_n:
		var sy := mq_y + 3.0 + float(s) * 5.0
		if sy + 2.0 <= mq_y + mq_h - 1.0:
			draw_rect(Rect2(mq_x + 2.0, sy, mq_w - 4.0, 2.0), Color(col, 0.9))


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


func _draw_horizon_glow(ground_y: float) -> void:
	var sw := VIRTUAL_SIZE.x
	var band_h := 14.0
	draw_rect(Rect2(0, ground_y - band_h, sw, band_h), Color(SKY_GLOW, 0.22))
	draw_line(Vector2(0, ground_y - 1.0), Vector2(sw, ground_y - 1.0), Color(SKY_GLOW, 0.45), 1.0)


func _draw_tier0_street_detail(ground_y: float, t: float) -> void:
	var sw := VIRTUAL_SIZE.x
	var post_x := sw * 0.18
	# Lamppost + warm pool so tier-0 empty lot reads on dark phones.
	draw_line(Vector2(post_x, ground_y - 52.0), Vector2(post_x, ground_y), Color8(58, 62, 82), 2.0)
	draw_circle(Vector2(post_x, ground_y - 54.0), 4.0, Color8(255, 210, 120))
	var pool_a := 0.18 + 0.06 * sin(t * 1.6) if not GameTheme.ui_reduced_motion() else 0.2
	draw_circle(Vector2(post_x, ground_y + 6.0), 22.0, Color(1.0, 0.82, 0.45, pool_a))
	draw_rect(Rect2(post_x - 18.0, ground_y + 2.0, 36.0, 3.0), Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.12))
	# Lone figure loitering in the lamplight — fedora, hands in coat, barely shifting.
	var sway := sin(t * 0.8) * 0.6 if not GameTheme.ui_reduced_motion() else 0.0
	_draw_person(sw * 0.62, ground_y + 1.0, 1.05, 4, sway, true)


func _draw_front_street(ground_y: float, t: float) -> void:
	var sw := VIRTUAL_SIZE.x
	draw_rect(Rect2(0, ground_y, sw, VIRTUAL_SIZE.y - ground_y), STREET)
	draw_line(Vector2(0, ground_y + 5.0), Vector2(sw, ground_y + 5.0), STREET_LINE, 1.0)
	# Wet-street center reflection shimmer.
	if not GameTheme.ui_reduced_motion():
		var shimmer_x := fmod(t * 30.0, sw + 60.0) - 30.0
		draw_rect(Rect2(shimmer_x, ground_y + 8.0, 40.0, 2.0), Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.15))


func _draw_reflections(ground_y: float, t: float) -> void:
	# Neon facades bleed down into the rain-slicked street.
	var reduced := GameTheme.ui_reduced_motion()
	for pt in _reflect_points:
		var x: float = pt[0]
		var col: Color = pt[1]
		var shimmer: float = 1.0 if reduced else (0.65 + 0.35 * sin(t * 3.0 + x * 0.12))
		for s in 3:
			var a := (0.20 - s * 0.06) * shimmer
			if a <= 0.0:
				continue
			draw_rect(Rect2(x - 1.5 - s * 0.5, ground_y + 6.0 + s * 4.0, 3.0 + s, 3.0), Color(col, a))


func _draw_person(px: float, base_y: float, scale: float, seed: int, phase: float, standing: bool = false) -> void:
	# Noir silhouette: fedora, long coat, walking stride. base_y is the feet line.
	var h := (15.0 + float(seed % 3) * 2.5) * scale
	var w := h * 0.32
	var col := Color(SILHOUETTE.r * 0.78, SILHOUETTE.g * 0.78, SILHOUETTE.b * 0.9, 0.94)
	var leg_w := maxf(1.5, w * 0.22)
	var hip_y := base_y - h * 0.44
	var stride := (w * 0.18) if standing else (sin(phase) * w * 0.55)
	draw_line(Vector2(px, hip_y), Vector2(px - stride, base_y), col, leg_w)
	draw_line(Vector2(px, hip_y), Vector2(px + stride, base_y), col, leg_w)
	# Long coat — trapezoid flaring slightly to the hem.
	var shoulder_y := base_y - h * 0.80
	draw_colored_polygon(PackedVector2Array([
		Vector2(px - w * 0.5, shoulder_y), Vector2(px + w * 0.5, shoulder_y),
		Vector2(px + w * 0.62, hip_y + 1.5), Vector2(px - w * 0.62, hip_y + 1.5),
	]), col)
	# Head + fedora (brim wider than the head, low crown).
	var head_y := shoulder_y - h * 0.07
	draw_circle(Vector2(px, head_y), w * 0.34, col)
	var brim_y := head_y - w * 0.34
	draw_rect(Rect2(px - w * 0.6, brim_y, w * 1.2, maxf(1.0, w * 0.16)), col)
	draw_rect(Rect2(px - w * 0.3, brim_y - w * 0.34, w * 0.6, w * 0.36), col)


func _draw_pedestrians(ground_y: float, t: float, tier: int) -> void:
	# Street life — lonelier when small, bustling once the empire grows.
	var sw := VIRTUAL_SIZE.x
	var reduced := GameTheme.ui_reduced_motion()
	var count := mini(1 + tier, 6)
	for i in count:
		var dir := 1.0 if i % 2 == 0 else -1.0
		var speed := 9.0 + float(i % 3) * 4.0
		var span := sw + 30.0
		var move := 0.0 if reduced else t * speed
		var prog := fmod(move + float(i) * 61.0, span)
		var px: float = (prog - 15.0) if dir > 0.0 else (sw + 15.0 - prog)
		var depth := float(i % 2)  # two sidewalk lanes for a little parallax
		var feet := ground_y + 2.0 + depth * 4.0
		var person_scale := 0.85 + depth * 0.3
		var phase := 0.0 if reduced else (t * 7.0 + float(i) * 1.7) * dir
		_draw_person(px, feet, person_scale, i * 5 + 1, phase, reduced)


func _draw_traffic(ground_y: float, t: float, alert_level: int = 0) -> void:
	# Headlight streaks crossing the foreground street — the city is awake.
	# At warn+ one lane becomes a police cruiser (alternating red/blue bar); it
	# slows to a prowl at critical. The red+blue flash — not the red hue — is what
	# reads as "police", so it never muddies into the static red aviation blips.
	if GameTheme.ui_reduced_motion():
		return
	var sw := VIRTUAL_SIZE.x
	for i in 2:
		var patrol := alert_level >= 1 and i == 0
		var dir := 1.0 if i == 0 else -1.0
		var speed := 64.0 + float(i) * 28.0
		if patrol and alert_level >= 2:
			speed *= 0.6  # they slow and sweep at critical
		var span := sw + 48.0
		var prog := fmod(t * speed + float(i) * 150.0, span)
		var cx: float = (prog - 24.0) if dir > 0.0 else (sw + 24.0 - prog)
		var cy := ground_y + 14.0 + float(i) * 6.0
		draw_rect(Rect2(cx - 7.0, cy - 3.0, 14.0, 5.0), Color8(28, 30, 44))
		if patrol:
			var bar := GameTheme.SIREN_RED if int(t * 6.0) % 2 == 0 else GameTheme.SIREN_BLUE
			draw_rect(Rect2(cx - 3.0, cy - 6.0, 6.0, 3.0), bar)
			draw_circle(Vector2(cx, cy - 5.0), 5.0, Color(bar.r, bar.g, bar.b, 0.25))
		var lead := cx + dir * 7.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(lead, cy - 1.0), Vector2(lead + dir * 20.0, cy - 3.5),
			Vector2(lead + dir * 20.0, cy + 3.5),
		]), Color(1.0, 0.92, 0.6, 0.10))
		draw_circle(Vector2(lead, cy), 2.4, Color(1.0, 0.94, 0.66, 0.55))
		draw_circle(Vector2(cx - dir * 7.0, cy), 1.5, Color(0.92, 0.22, 0.2, 0.6))


## Street-level raid surge — hot siren red below the ground line only, never a
## tint over the player's whole screen (the flash_building fix, applied to raids).
func _draw_raid_surge(ground_y: float) -> void:
	var a := clampf(_raid_pulse, 0.0, 1.0)
	var col := GameTheme.SIREN_RED
	draw_rect(Rect2(0.0, ground_y - 20.0, VIRTUAL_SIZE.x, VIRTUAL_SIZE.y - ground_y + 20.0),
			Color(col.r, col.g, col.b, 0.28 * a))


func _draw_vignette() -> void:
	var sw := VIRTUAL_SIZE.x
	var sh := VIRTUAL_SIZE.y
	var depth := 32.0
	var steps := 6
	for i in steps:
		var t := float(i) / float(steps)
		var a := (1.0 - t) * 0.14
		var band := depth * (float(i) + 1.0) / float(steps)
		draw_rect(Rect2(0.0, 0.0, sw, band), Color(0.0, 0.0, 0.0, a))
		draw_rect(Rect2(0.0, sh - band, sw, band), Color(0.0, 0.0, 0.0, a))
		draw_rect(Rect2(0.0, 0.0, band, sh), Color(0.0, 0.0, 0.0, a))
		draw_rect(Rect2(sw - band, 0.0, band, sh), Color(0.0, 0.0, 0.0, a))


func _draw_rain(t: float, heat: float) -> void:
	# Light noir drizzle that thickens with heat — tension you can feel.
	if GameTheme.ui_reduced_motion():
		return
	var sw := VIRTUAL_SIZE.x
	var sh := VIRTUAL_SIZE.y
	var drops := 12 + int(clampf(heat, 0.0, 100.0) / 100.0 * 28.0)
	var col := Color(0.62, 0.68, 0.86, 0.09)
	for i in drops:
		var x := fmod(float(i * 71 + 17), sw)
		var y := fmod(t * (150.0 + float(i % 5) * 32.0) + float(i) * 53.0, sh + 40.0) - 20.0
		draw_line(Vector2(x, y), Vector2(x - 3.0, y + 10.0), col, 1.0)


func _draw_searchlights(t: float, alert_level: int) -> void:
	# Sweeping police beams once they're actively hunting you (critical heat).
	# Was gated on RANK (a triumphant gold sweep) — meaningless to the player;
	# now it's a cold blue dragnet that only appears when the city is after you.
	if alert_level < 2 or GameTheme.ui_reduced_motion():
		return
	var sw := VIRTUAL_SIZE.x
	var base_y := VIRTUAL_SIZE.y * 0.56
	var beam := GameTheme.SIREN_BLUE
	for i in 2:
		var ox := sw * (0.26 + 0.48 * float(i))
		var ang := -PI * 0.5 + sin(t * 0.5 + float(i) * 2.1) * 0.55
		var length := VIRTUAL_SIZE.y * 0.6
		var tip := Vector2(ox + cos(ang) * length, base_y + sin(ang) * length)
		draw_colored_polygon(PackedVector2Array([
			Vector2(ox - 6.0, base_y), Vector2(ox + 6.0, base_y), tip,
		]), Color(beam.r, beam.g, beam.b, 0.07))
		draw_circle(Vector2(ox, base_y), 3.0, Color(beam.r, beam.g, beam.b, 0.45))


func _draw_caption(tier: int, total: int) -> void:
	# At-a-glance empire state — readable over the busy skyline.
	var font := GameFonts.heading()
	var txt := "TIER %d · %d SPOTS" % [tier, total]
	var col := Color(INK_GOLD_BRIGHT.r, INK_GOLD_BRIGHT.g, INK_GOLD_BRIGHT.b, 0.6)
	draw_string(font, Vector2(9.0, 16.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, 0.55))
	draw_string(font, Vector2(8.0, 15.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)


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
				var font := GameFonts.mono(false)
				var fs := 7
				draw_string(font, Vector2(bx + 1.0, by + 11.0), short_lbl.substr(0, 3),
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, 0.7))
		if _district_pulse.has(i):
			var dp: float = float(_district_pulse[i]["t"])
			if dp > 0.0:
				var holder := str(_district_pulse[i]["holder"])
				var fc := GameTheme.SIREN_RED if holder == "rival" else INK_GOLD_BRIGHT
				var da := clampf(dp / DISTRICT_PULSE_TIME, 0.0, 1.0)
				draw_rect(Rect2(bx, by, block_w, 12.0), Color(fc.r, fc.g, fc.b, 0.18 * da), true)
				draw_rect(Rect2(bx, by, block_w, 12.0), Color(fc.r, fc.g, fc.b, 0.55 * da), false, 1.5)


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
			var band_a := 0.22 if heat < 60.0 else 0.30
			draw_rect(Rect2(0, band_h * frac, sw, band_h),
					Color(INK_CRIMSON.r, INK_CRIMSON.g, INK_CRIMSON.b, intensity * band_a))
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
		draw_line(Vector2(0, y), Vector2(sw, y), Color(0, 0, 0, 0.07), 1.0)
		y += 3.0


func _hash01(seed: int, t: float) -> float:
	var h := (seed * 1103515245 + int(t * 1000.0)) & 0x7FFFFFFF
	return float(h % 1000) / 1000.0


func _hash_flicker(seed: int, t: float) -> bool:
	return _hash01(seed, t) > 0.35


## Rooftop neon signs — empire identity on the skyline (SigilGlyphs + building neon).
func _draw_rooftop_signs(ground_y: float) -> void:
	var w := VIRTUAL_SIZE.x
	var horizon := ground_y * 0.9
	var xs := [0.19, 0.44, 0.70]
	var hts := [0.52, 0.66, 0.58]
	for i in xs.size():
		var sx := w * float(xs[i]) + w * 0.06
		var sy := horizon - horizon * float(hts[i]) - 4.0
		var key := str(_top_building_keys[i]) if i < _top_building_keys.size() else ""
		var neon: Color = GameTheme.building_neon(key) if not key.is_empty() else NEON_SET[i % NEON_SET.size()]
		for k in 4:
			draw_circle(Vector2(sx, sy), 10.0 - k * 2.0,
					Color(neon.r, neon.g, neon.b, 0.07))
		if key.is_empty():
			draw_circle(Vector2(sx, sy), 2.0, Color(neon, 0.95))
			continue
		draw_circle(Vector2(sx, sy), 7.5, Color8(14, 16, 26, 230))
		draw_arc(Vector2(sx, sy), 7.5, 0, TAU, 24, Color(neon, 0.95), 1.3)
		SigilGlyphs.draw_glyph(self, key, Vector2(sx, sy), 7.5, neon.lightened(0.2))


## Vertical neon streaks bleeding down the wet street under the brightest signs.
func _draw_neon_streaks(ground_y: float, t: float) -> void:
	var w := VIRTUAL_SIZE.x
	var xs := [0.19, 0.44, 0.70]
	var flick := 0.10 + 0.04 * sin(t * 2.3)
	for i in xs.size():
		var rx := w * float(xs[i]) + w * 0.06
		var key := str(_top_building_keys[i]) if i < _top_building_keys.size() else ""
		var neon: Color = GameTheme.building_neon(key) if not key.is_empty() else NEON_SET[i % NEON_SET.size()]
		draw_line(Vector2(rx, ground_y), Vector2(rx, ground_y + VIRTUAL_SIZE.y * 0.06),
				Color(neon.r, neon.g, neon.b, flick), 3.0)


## Deco corner brackets — a thin double keyline at each frame corner.
func _draw_corner_brackets() -> void:
	var w := VIRTUAL_SIZE.x
	var h := VIRTUAL_SIZE.y
	var m := 6.0
	var bl := 26.0
	var g := INK_GOLD_BRIGHT
	for corner in [[m, m, 1.0, 1.0], [w - m, m, -1.0, 1.0],
			[m, h - m, 1.0, -1.0], [w - m, h - m, -1.0, -1.0]]:
		var cx: float = corner[0]
		var cy: float = corner[1]
		var sx: float = corner[2]
		var sy: float = corner[3]
		draw_line(Vector2(cx, cy), Vector2(cx + sx * bl, cy), Color(g, 0.6), 2.0)
		draw_line(Vector2(cx, cy), Vector2(cx, cy + sy * bl), Color(g, 0.6), 2.0)
		draw_line(Vector2(cx + sx * 5, cy + sy * 5),
				Vector2(cx + sx * (bl - 4), cy + sy * 5), Color(g, 0.3), 1.0)
