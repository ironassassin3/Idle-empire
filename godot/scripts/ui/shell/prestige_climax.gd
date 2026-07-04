extends CanvasLayer
## PrestigeClimax — the run-ending ceremony (Supremacy §4.7): the ascension
## reads as visible fiction, not a loading hiccup. Skyline dims to silhouette
## → gold "EMPIRE ASCENDED +X INFLUENCE" → the (already-reset) skyline lifts
## back into view as tier 0. ~3s, skippable, reduced-motion = instant flash.
## Own CanvasLayer above every other overlay (dragon/gambling top out at 11)
## so the ceremony always wins regardless of what else was open.

enum Phase { OFF, DIM, HOLD, LIFT }

const _DIM_TIME := 0.6
const _HOLD_TIME := 1.6
const _LIFT_TIME := 0.8

var phase: int = Phase.OFF
var _t := 0.0
var _root: Control
var _scrim: ColorRect
var _title: Label
var _subtitle: Label
var _rank: Label


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_tap)
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	_scrim = ColorRect.new()
	_scrim.color = Color(0, 0, 0, 0.0)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_title = Label.new()
	_title.text = "EMPIRE ASCENDED"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", GameFonts.display())
	_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(38))
	_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.modulate.a = 0.0
	v.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_override("font", GameFonts.mono(true))
	_subtitle.add_theme_font_size_override("font_size", GameTheme.scaled_font(18))
	_subtitle.add_theme_color_override("font_color", GameTheme.TEXT)
	_subtitle.modulate.a = 0.0
	v.add_child(_subtitle)

	_rank = Label.new()
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank.add_theme_font_override("font", GameFonts.heading())
	_rank.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	_rank.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_rank.modulate.a = 0.0
	v.add_child(_rank)


func is_active() -> bool:
	return phase != Phase.OFF


func start(gain: int, rank: String) -> void:
	_subtitle.text = "+%d INFLUENCE" % gain
	_rank.text = rank.to_upper()
	visible = true
	_t = 0.0
	Telemetry.log_event("ui_prestige_climax_start", {"gain": gain})
	if GameTheme.ui_reduced_motion():
		# Single instant flash frame, no theater — a beat, not a wait.
		phase = Phase.HOLD
		_scrim.color.a = 0.85
		_title.modulate.a = 1.0
		_subtitle.modulate.a = 1.0
		_rank.modulate.a = 1.0
		_t = _HOLD_TIME - 0.4
		return
	phase = Phase.DIM
	_scrim.color.a = 0.0
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_rank.modulate.a = 0.0


func _process(delta: float) -> void:
	if phase == Phase.OFF:
		return
	_t += delta
	match phase:
		Phase.DIM:
			var k := clampf(_t / _DIM_TIME, 0.0, 1.0)
			_scrim.color.a = k * 0.85
			if k >= 1.0:
				phase = Phase.HOLD
				_t = 0.0
			return
		Phase.HOLD:
			var k2 := clampf(_t / 0.35, 0.0, 1.0)
			_title.modulate.a = k2
			_subtitle.modulate.a = clampf((_t - 0.15) / 0.35, 0.0, 1.0)
			_rank.modulate.a = clampf((_t - 0.30) / 0.35, 0.0, 1.0)
			if _t >= _HOLD_TIME:
				phase = Phase.LIFT
				_t = 0.0
			return
		Phase.LIFT:
			var k3 := clampf(_t / _LIFT_TIME, 0.0, 1.0)
			var fade := 1.0 - k3
			_scrim.color.a = 0.85 * fade
			_title.modulate.a = fade
			_subtitle.modulate.a = fade
			_rank.modulate.a = fade
			if k3 >= 1.0:
				_stop()


func _on_tap(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and phase != Phase.OFF:
		Telemetry.log_event("ui_prestige_climax_skip", {"at": phase})
		_stop()


func _stop() -> void:
	phase = Phase.OFF
	visible = false
