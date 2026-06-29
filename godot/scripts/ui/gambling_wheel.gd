extends Control
## Luck Wheel sweep bar — the skill/timing input for GamblingSystem.
##
## A marker sweeps the segment bar; the player taps to stop it. The segment under
## the marker (normalised position 0..1) is exactly what GameState.resolve_gamble
## reads, so what you see is what you get. Pure view: holds no payout logic, only
## the segment layout handed to it by the overlay.

signal stopped(position: float)

const _Gambling = preload("res://scripts/systems/gambling_system.gd")

var _segments: Array = []
var _position: float = 0.0
var _sweeping: bool = false


func _ready() -> void:
	set_process(false)
	custom_minimum_size.y = maxf(custom_minimum_size.y, 84.0)


func set_segments(segs: Array) -> void:
	_segments = segs
	queue_redraw()


func has_round() -> bool:
	return not _segments.is_empty()


func reset() -> void:
	_sweeping = false
	set_process(false)
	_position = 0.0
	queue_redraw()


func start_sweep() -> void:
	if _segments.is_empty():
		return
	_position = randf()
	_sweeping = true
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
	if not _sweeping:
		return
	_position = fposmod(_position + _Gambling.SWEEP_SPEED * delta, 1.0)
	queue_redraw()


func _seg_color(mult: float) -> Color:
	if mult >= _Gambling.JACKPOT_MULT:
		return GameTheme.GOLD_BRIGHT
	if mult <= 0.0:
		return Color(0.32, 0.16, 0.16)  # bust
	if mult >= 2.0:
		return GameTheme.GREEN
	if mult >= 1.0:
		return Color(0.42, 0.46, 0.36)
	return Color(0.30, 0.30, 0.26)  # < 1× consolation


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
		var col := Color(0.08, 0.07, 0.05) if mult >= 2.0 else GameTheme.TEXT
		var ts := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(
			font, Vector2(x + (seg_w - ts.x) * 0.5, h * 0.5 + ts.y * 0.3),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col,
		)
	# Needle + triangle cap.
	var nx: float = _position * w
	draw_rect(Rect2(nx - 2.0, -4.0, 4.0, h + 8.0), GameTheme.GOLD_BRIGHT)
	draw_colored_polygon(
		PackedVector2Array([Vector2(nx - 7.0, -4.0), Vector2(nx + 7.0, -4.0), Vector2(nx, 7.0)]),
		GameTheme.GOLD_BRIGHT,
	)
