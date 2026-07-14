extends Control
## ev1b — banner state sheet (DESIGN MOCK — godot/design only).
## Entry frames + severity tiers + the palette argument, side by side, so the
## band can be judged without waiting for a tween.

const Banner := preload("res://design/ev1b_heat_banner.gd")

const H := 62.0


func _ready() -> void:
	GameState.balance = 1_240_000.0

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = GameTheme.BG
	add_child(bg)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 0)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 20)
	add_child(pad)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pad.add_child(v)

	_caption(v, "ENTRY — 0.34s drop across the masthead (BACK / OUT), t = 0.05 / 0.15 / rest")
	_slot(v, 64.0, -46.0, 0.35)
	_slot(v, 64.0, -20.0, 0.8)
	_slot(v, 64.0, 0.0, 1.0)

	_caption(v, "SEVERITY — WARN 60-84% (outline glyph) · CRITICAL 85%+ (filled, faster pulse)")
	_slot(v, 61.0, 0.0, 1.0)
	_slot(v, 74.0, 0.0, 1.0)
	_slot(v, 91.0, 0.0, 1.0)

	_caption(v, "PALETTE — danger without the brand accent")
	v.add_child(_swatches())


func _caption(parent: Control, txt: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	parent.add_child(gap)
	var l := Label.new()
	l.add_theme_font_override("font", GameFonts.mono(false))
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	l.text = "// " + txt
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_child(l)
	parent.add_child(m)


## One 62px window with a static banner parked at a given slide offset/alpha.
func _slot(parent: Control, heat: float, y: float, alpha: float) -> void:
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(0, H)
	frame.clip_contents = true
	parent.add_child(frame)

	var b: Control = Banner.new()
	b.heat = heat
	b.animate = false
	b.rest_y = y
	b.modulate.a = alpha
	frame.add_child(b)


func _swatches() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_child(row)
	var entries := [
		["ALERT_EDGE\nc43e34", Banner.ALERT_EDGE],
		["ALERT_HOT\ne8623f", Banner.ALERT_HOT],
		["ALERT_INK\n1b0d10", Banner.ALERT_INK],
		["ALERT_TEXT\nf2ded7", Banner.ALERT_TEXT],
		["theme RED\n9a4a4a", GameTheme.RED],
		["theme GOLD\n(unused)", GameTheme.GOLD],
	]
	for e in entries:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 4)
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(0, 30)
		chip.color = e[1]
		cell.add_child(chip)
		var l := Label.new()
		l.add_theme_font_override("font", GameFonts.mono(false))
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		l.text = str(e[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		row.add_child(cell)
	return m
