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

var _segments: Array = []
var _position: float = 0.0
var _sweeping: bool = false
var _wager_mode := false
var _revealing := false
var _reveal_t := 0.0
var _reveal_from := 0.0
var _reveal_travel := 0.0


func _ready() -> void:
	set_process(false)
	custom_minimum_size.y = maxf(custom_minimum_size.y, 84.0)


func set_segments(segs: Array) -> void:
	_segments = segs
	_wager_mode = false
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
