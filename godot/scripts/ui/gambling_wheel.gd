extends Control
## Luck Wheel sweep bar — free-spin skill input + casino reveal display.
##
## Free-spin mode: a marker sweeps the segment bar; the player taps to stop it.
## The segment under the marker (normalised position 0..1) is exactly what
## GameState.resolve_gamble reads, so what you see is what you get.
## Wager (casino) mode: pure RNG — the outcome is already resolved before the
## needle moves; spin_to_band() plays a cosmetic auto-spin that settles on the
## drawn band and emits `landed`. No input, no payout logic in this view.

signal stopped(position: float)
signal landed

const _Gambling = preload("res://scripts/systems/gambling_system.gd")

const REVEAL_TIME := 1.6   # seconds for the cosmetic casino reveal
const REVEAL_LOOPS := 2.5  # extra full loops before settling

# Three-Card Monte reveal (cash-wager reskin). The outcome is already resolved;
# these two phases are pure presentation — a shuffle, then the dealer flips the
# centre card to the band's face. `landed` fires exactly as the wheel's does.
const MONTE_SHUFFLE_TIME := 0.9
const MONTE_FLIP_TIME := 0.55
const MONTE_PERMS: Array = [[0, 1, 2], [1, 0, 2], [1, 2, 0], [0, 1, 2]]
const MONTE_CENTER_SLOT := 1

var _segments: Array = []
var _position: float = 0.0
var _sweeping: bool = false
var _wager_mode := false
var _revealing := false
var _reveal_t := 0.0
var _reveal_from := 0.0
var _reveal_travel := 0.0

# Monte state. _monte_phase: 0 idle · 1 shuffle · 2 flip.
var _monte_mode := false
var _monte_card: Dictionary = {}
var _monte_phase := 0
var _monte_t := 0.0


func _ready() -> void:
	set_process(false)
	custom_minimum_size.y = maxf(custom_minimum_size.y, 84.0)


func set_segments(segs: Array) -> void:
	_segments = segs
	_wager_mode = false
	_monte_mode = false
	queue_redraw()


## Casino mode: show the cosmetic band ring the reveal needle settles on.
func set_wager_segments(segs: Array) -> void:
	_segments = segs
	_wager_mode = true
	queue_redraw()


func is_wager_mode() -> bool:
	return _wager_mode


func has_round() -> bool:
	return not _segments.is_empty()


func reset() -> void:
	_sweeping = false
	_revealing = false
	set_process(false)
	_position = 0.0
	queue_redraw()


func start_sweep() -> void:
	if not has_round() or _revealing:
		return
	_position = randf()
	_sweeping = true
	set_process(true)


## Cosmetic reveal: auto-spin the needle and settle it on a segment holding
## `band`. The outcome is already resolved — this animation only presents it.
func spin_to_band(band: float) -> void:
	if _segments.is_empty():
		return
	var candidates: Array = []
	for i in _segments.size():
		if is_equal_approx(float(_segments[i]), band):
			candidates.append(i)
	if candidates.is_empty():
		candidates.append(0)
	var idx: int = candidates[randi() % candidates.size()]
	var target := (float(idx) + randf_range(0.35, 0.65)) / float(_segments.size())
	_reveal_from = fposmod(_position, 1.0)
	_reveal_travel = REVEAL_LOOPS + fposmod(target - _reveal_from, 1.0)
	_reveal_t = 0.0
	_revealing = true
	_sweeping = false
	set_process(true)


## Casino mode, Monte skin: stage three face-down cards (no animation yet).
func set_monte_round() -> void:
	_monte_mode = true
	_wager_mode = false
	_monte_phase = 0
	_monte_t = 0.0
	_monte_card = {}
	queue_redraw()


## Cosmetic reveal for the Monte skin: shuffle, then flip the centre card to the
## card face mapped from `band`. Outcome is already resolved — this only presents
## it, and emits `landed` when the flip settles (same contract as spin_to_band).
func reveal_monte(band: float) -> void:
	_monte_card = _Gambling.monte_card_for_band(band)
	_monte_mode = true
	_wager_mode = false
	_revealing = false
	_sweeping = false
	_monte_phase = 1
	_monte_t = 0.0
	set_process(true)


func is_sweeping() -> bool:
	return _sweeping


func stop_sweep() -> float:
	if not _sweeping:
		return _position
	_sweeping = false
	set_process(false)
	queue_redraw()
	stopped.emit(_position)
	return _position


func _process(delta: float) -> void:
	if _monte_phase == 1:  # shuffle
		_monte_t += delta / MONTE_SHUFFLE_TIME
		if _monte_t >= 1.0:
			_monte_t = 0.0
			_monte_phase = 2  # → flip
		queue_redraw()
		return
	if _monte_phase == 2:  # flip
		_monte_t = minf(_monte_t + delta / MONTE_FLIP_TIME, 1.0)
		queue_redraw()
		if _monte_t >= 1.0:
			_monte_phase = 0
			set_process(false)
			landed.emit()
		return
	if _revealing:
		_reveal_t = minf(_reveal_t + delta / REVEAL_TIME, 1.0)
		var eased := 1.0 - pow(1.0 - _reveal_t, 3)
		_position = fposmod(_reveal_from + _reveal_travel * eased, 1.0)
		queue_redraw()
		if _reveal_t >= 1.0:
			_revealing = false
			set_process(false)
			landed.emit()
		return
	if not _sweeping:
		return
	_position = fposmod(_position + _Gambling.SWEEP_SPEED * delta, 1.0)
	queue_redraw()


func _seg_color(mult: float) -> Color:
	if mult >= _Gambling.JACKPOT_MULT:
		return GameTheme.GOLD_BRIGHT
	if mult <= 0.0:
		return Color(0.28, 0.12, 0.18)  # bust — cool crimson ink
	if mult >= 2.0:
		return GameTheme.GREEN
	if mult >= 1.0:
		return Color(0.22, 0.24, 0.36)  # ink plate
	return Color(0.16, 0.17, 0.26)  # < 1× consolation


func _seg_label(mult: float) -> String:
	if mult <= 0.0:
		return "—"
	if mult == floor(mult):
		return "%d×" % int(mult)
	return "%.1f×" % mult


func _draw() -> void:
	if _monte_mode:
		_draw_monte()
		return
	var segs: Array = _segments if not _segments.is_empty() else _Gambling.SEGMENT_MULTS
	var n: int = segs.size()
	if n == 0:
		return
	var w: float = size.x
	var h: float = size.y
	var font := get_theme_default_font()
	var fs := GameTheme.scaled_font(13)
	var seg_w := w / float(n)
	for i in n:
		var mult := float(segs[i])
		var x := float(i) * seg_w
		draw_rect(Rect2(x + 1.0, 0.0, seg_w - 2.0, h), _seg_color(mult))
		var label := _seg_label(mult)
		var col := GameTheme.GOLD_TEXT_DARK if mult >= 2.0 else GameTheme.TEXT
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(
			font, Vector2(x + (seg_w - ts.x) * 0.5, h * 0.5 + ts.y * 0.3),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col,
		)
	_draw_needle()


func _draw_needle() -> void:
	var nx: float = _position * size.x
	draw_rect(Rect2(nx - 2.0, -4.0, 4.0, size.y + 8.0), GameTheme.GOLD_BRIGHT)
	draw_colored_polygon(
		PackedVector2Array([Vector2(nx - 7.0, -4.0), Vector2(nx + 7.0, -4.0), Vector2(nx, 7.0)]),
		GameTheme.GOLD_BRIGHT,
	)


# ── Three-Card Monte reveal ─────────────────────────────────────────────────

## Normalised x-centre (0..1) of a card slot (0, 1, 2).
func _monte_slot_x(slot: int) -> float:
	return (float(slot) + 0.5) / 3.0


## Per-card x-centres for the current shuffle progress. Cards are evenly spaced
## when settled (phase != 1); during the shuffle they cross between the keyframe
## permutations in MONTE_PERMS. Purely cosmetic — the outcome is already drawn.
func _monte_positions() -> Array:
	if _monte_phase != 1:
		return [_monte_slot_x(0), _monte_slot_x(1), _monte_slot_x(2)]
	var segs: int = MONTE_PERMS.size() - 1
	var p := clampf(_monte_t, 0.0, 0.9999)
	var seg := int(p * float(segs))
	var local := p * float(segs) - float(seg)
	var eased := 0.5 - 0.5 * cos(local * PI)
	var a: Array = MONTE_PERMS[seg]
	var b: Array = MONTE_PERMS[seg + 1]
	var out: Array = []
	for i in 3:
		out.append(lerpf(_monte_slot_x(int(a[i])), _monte_slot_x(int(b[i])), eased))
	return out


func _draw_monte() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var xs := _monte_positions()
	var card_w := (w / 3.0) * 0.82
	var card_h := h * 0.92
	var top := (h - card_h) * 0.5
	for i in 3:
		var cx: float = float(xs[i]) * w
		var flipping := _monte_phase == 2 and i == MONTE_CENTER_SLOT
		if flipping:
			# scaleX 1→0→1 over the flip; back until halfway, face after.
			var sx: float = maxf(absf(cos(_monte_t * PI)), 0.04)
			var ww := card_w * sx
			var rect := Rect2(cx - ww * 0.5, top, ww, card_h)
			if _monte_t >= 0.5:
				_draw_card_face(rect, _monte_card)
			else:
				_draw_card_back(rect)
		else:
			_draw_card_back(Rect2(cx - card_w * 0.5, top, card_w, card_h))


func _draw_card_back(rect: Rect2) -> void:
	draw_rect(rect, Color(0.10, 0.08, 0.14))
	draw_rect(rect, GameTheme.GOLD_BRIGHT, false, 2.0)
	if rect.size.x < 8.0:
		return
	var inset := rect.grow(-rect.size.x * 0.16)
	draw_rect(inset, Color(0.20, 0.10, 0.24, 0.85))
	draw_circle(rect.get_center(), rect.size.x * 0.14, GameTheme.GOLD_BRIGHT)


func _draw_card_face(rect: Rect2, card: Dictionary) -> void:
	var tier := int(card.get("tier", 0))
	var accent := _monte_tier_color(tier)
	draw_rect(rect, Color(0.96, 0.94, 0.90))     # card stock
	draw_rect(rect, accent, false, 3.0)          # tier-coloured border
	if rect.size.x < 10.0:
		return
	var rank := str(card.get("rank", "?"))
	var suit := str(card.get("suit", ""))
	var red := suit == "H" or suit == "D"
	var ink := Color(0.72, 0.12, 0.14) if red else Color(0.10, 0.10, 0.12)
	var font := get_theme_default_font()
	var center := rect.get_center()
	if tier == 0:  # sucker card — a marked loser, crimson wash + big X
		draw_rect(rect.grow(-rect.size.x * 0.12), Color(0.72, 0.12, 0.14, 0.10))
		_draw_center_text(font, center, "X", GameTheme.scaled_font(34), Color(0.55, 0.10, 0.14))
		return
	# Rank pip top-left, big rank centre, suit below.
	_draw_center_text(font, rect.position + Vector2(rect.size.x * 0.22, rect.size.y * 0.20), rank, GameTheme.scaled_font(15), ink)
	_draw_center_text(font, center - Vector2(0.0, rect.size.y * 0.08), rank, GameTheme.scaled_font(32), ink)
	_draw_suit_pip(center + Vector2(0.0, rect.size.y * 0.24), rect.size.x * 0.16, suit, ink)


func _draw_center_text(font: Font, center: Vector2, text: String, fs: int, col: Color) -> void:
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2(center.x - ts.x * 0.5, center.y + ts.y * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Code-drawn suit pip (ART_POLICY: no asset files — vector shapes only).
func _draw_suit_pip(c: Vector2, r: float, suit: String, col: Color) -> void:
	match suit:
		"D":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.7, 0), c + Vector2(0, r), c + Vector2(-r * 0.7, 0)]), col)
		"H":
			draw_circle(c + Vector2(-r * 0.4, -r * 0.25), r * 0.5, col)
			draw_circle(c + Vector2(r * 0.4, -r * 0.25), r * 0.5, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.85, -r * 0.05), c + Vector2(r * 0.85, -r * 0.05), c + Vector2(0, r)]), col)
		"S":
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.85, r * 0.35), c + Vector2(-r * 0.85, r * 0.35)]), col)
			draw_circle(c + Vector2(-r * 0.4, r * 0.2), r * 0.45, col)
			draw_circle(c + Vector2(r * 0.4, r * 0.2), r * 0.45, col)
			draw_rect(Rect2(c.x - r * 0.12, c.y + r * 0.2, r * 0.24, r * 0.6), col)
		"C":
			draw_circle(c + Vector2(0, -r * 0.4), r * 0.42, col)
			draw_circle(c + Vector2(-r * 0.45, r * 0.2), r * 0.42, col)
			draw_circle(c + Vector2(r * 0.45, r * 0.2), r * 0.42, col)
			draw_rect(Rect2(c.x - r * 0.12, c.y, r * 0.24, r * 0.7), col)
		_:
			pass


func _monte_tier_color(tier: int) -> Color:
	match tier:
		0: return Color(0.55, 0.16, 0.20)
		1: return Color(0.35, 0.37, 0.45)
		2: return Color(0.30, 0.34, 0.52)
		3: return GameTheme.GREEN
		4: return GameTheme.GREEN
		5: return GameTheme.GOLD_BRIGHT
	return GameTheme.TEXT
