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
# Wager (casino) mode: render a timing skill-meter with a sweet-spot target band
# instead of the payout ring. -1 = free-spin ring mode.
var _sweet_spot: float = -1.0


func _ready() -> void:
	set_process(false)
	custom_minimum_size.y = maxf(custom_minimum_size.y, 84.0)


func set_segments(segs: Array) -> void:
	_segments = segs
	_sweet_spot = -1.0
	queue_redraw()


## Switch to casino skill-meter mode with a sweet-spot target at [0,1).
func set_sweet_spot(spot: float) -> void:
	_sweet_spot = spot
	_segments = []
	queue_redraw()


func is_wager_mode() -> bool:
	return _sweet_spot >= 0.0


func has_round() -> bool:
	return not _segments.is_empty() or _sweet_spot >= 0.0


func reset() -> void:
	_sweeping = false
	set_process(false)
	_position = 0.0
	queue_redraw()


func start_sweep() -> void:
	if not has_round():
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
	if _sweet_spot >= 0.0:
		_draw_wager_meter()
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


## Casino skill-meter: a dim track with a graded sweet-spot zone. Stopping the
## needle near the centre earns full timing skill (→ higher RTP). The RNG payout
## is revealed separately by the overlay, so this bar never implies an outcome.
func _draw_wager_meter() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, h), Color(0.10, 0.11, 0.18))
	var tol: float = _Gambling.WAGER_SKILL_TOL
	# Graded band: green core (full skill) fading to amber at the tolerance edge.
	var steps := 24
	for i in steps:
		var frac := float(i) / float(steps - 1)  # 0 centre → 1 edge
		var off := (frac - 0.0) * tol
		var core := GameTheme.GREEN.lerp(GameTheme.GOLD, frac)
		core.a = 0.85 - 0.5 * frac
		for sgn in [-1.0, 1.0]:
			var cx: float = fposmod(_sweet_spot + sgn * off, 1.0) * w
			draw_rect(Rect2(cx - 3.0, 0.0, 6.0, h), core)
	# Sweet-spot centre line + "AIM" cap.
	var sx: float = _sweet_spot * w
	draw_rect(Rect2(sx - 1.5, 0.0, 3.0, h), GameTheme.GREEN)
	var font := get_theme_default_font()
	var fs := GameTheme.scaled_font(11)
	var lbl := "AIM"
	var ts := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2(clampf(sx - ts.x * 0.5, 0.0, w - ts.x), ts.y + 2.0),
		lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GameTheme.GREEN)
	_draw_needle()


func _draw_needle() -> void:
	var nx: float = _position * size.x
	draw_rect(Rect2(nx - 2.0, -4.0, 4.0, size.y + 8.0), GameTheme.GOLD_BRIGHT)
	draw_colored_polygon(
		PackedVector2Array([Vector2(nx - 7.0, -4.0), Vector2(nx + 7.0, -4.0), Vector2(nx, 7.0)]),
		GameTheme.GOLD_BRIGHT,
	)
