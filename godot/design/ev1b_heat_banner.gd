extends Control
## ev1b — compact RAID WARNING banner (DESIGN MOCK — godot/design only).
##
## Fires when heat crosses the 60% raid threshold (HeatSystem.RAID_THRESHOLD)
## and slides down over the masthead. Reads as danger with ZERO gold: the five
## values below are the alert ramp this design proposes promoting into
## GameTheme at port time (DESIGN_KIT rule 2 — marked non-kit values that argue
## for a kit amendment). Everything else is drawn from GameTheme / GameFonts.
##
## Why not GameTheme.RED (#9a4a4a)? It is a *ledger* red — the colour of a
## negative number, tuned to sit quietly next to gold. Laid over a near-black
## masthead it has ~2.4:1 contrast and reads as "sad", not "sirens". ALERT_EDGE
## keeps RED's hue family but pushes chroma/luma into siren territory so the
## band owns the eye without borrowing the brand accent.

# ── proposed GameTheme tokens (design-only) ─────────────────────────────────
const ALERT_INK := Color("1b0d10")    # band fill — oxblood ink, near-black
const ALERT_PLATE := Color("2c1418")  # CTA plate (lifted fill)
const ALERT_EDGE := Color("c43e34")   # siren red — RED's hue, hot chroma
const ALERT_HOT := Color("e8623f")    # critical tier (>= 85% heat)
const ALERT_TEXT := Color("f2ded7")   # warm-white message ink

const BANNER_H := 62.0
const BAR_H := 4.0
const STRIPE_W := 4.0
const RAID_THRESHOLD := 60.0          # HeatSystem.RAID_THRESHOLD
const CRITICAL := 85.0
const SEIZE_PCT := 8                  # HeatSystem.RAID_BALANCE_PENALTY

# Set these BEFORE add_child().
var heat := 64.0
var rest_y := 124.0
var animate := true

var slide_y := -BANNER_H:
	set(v):
		slide_y = v
		offset_top = v
		offset_bottom = v + BANNER_H

var _stripe: ColorRect
var _bleed: Bleed
var _glyph: Hazard
var _title: Label
var _value: Label
var _sub: Label
var _cta: Button
var _bar: HeatBar


## Triangle-bang. Shape channel first (N6): danger is never colour-only.
class Hazard extends Control:
	var col := Color.RED
	var ink := Color.BLACK
	var filled := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(22, 22)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([
			Vector2(w * 0.5, 1.5), Vector2(w - 1.5, h - 2.5), Vector2(1.5, h - 2.5),
		])
		if filled:
			draw_colored_polygon(pts, col)
		var outline := PackedVector2Array(pts)
		outline.append(pts[0])
		draw_polyline(outline, col, 2.0, true)
		var mark := ink if filled else col
		draw_line(Vector2(w * 0.5, h * 0.40), Vector2(w * 0.5, h * 0.68), mark, 2.0)
		draw_circle(Vector2(w * 0.5, h * 0.83), 1.5, mark)


## Red bleed under the top keyline — the light the siren throws. Gives the band
## danger *mass* without lifting the fill (text stays on near-black).
class Bleed extends Control:
	var col := Color.RED

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		# Exact, non-overlapping bands: an overlapping step (UiPrims.Scrim's +1px
		# trick) double-blends at every seam and stripes a translucent ramp.
		var steps := 22
		for i in steps:
			var y0 := size.y * float(i) / float(steps)
			var y1 := size.y * float(i + 1) / float(steps)
			var t := float(i) / float(steps - 1)
			draw_rect(Rect2(0, y0, size.x, y1 - y0), Color(col, lerpf(0.28, 0.0, t * t)))


## Heat track + 60% raid notch — HeatThresholdTick's pattern, recoloured so the
## notch survives on top of the fill (RED-on-RED is invisible here).
class HeatBar extends Control:
	const NOTCH_AT := 0.6  # HeatSystem.RAID_THRESHOLD / 100

	var progress := 0.0
	var fill := Color.RED
	var notch := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(fill, 0.16))
		draw_rect(Rect2(0, 0, size.x * progress, size.y), fill)
		var x := size.x * NOTCH_AT
		draw_line(Vector2(x, -1.0), Vector2(x, size.y + 1.0), Color(notch, 0.9), 1.5)


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_right = 0.0
	custom_minimum_size = Vector2(0, BANNER_H)

	# Band fill lives in its own Panel: a PanelContainer would stretch every
	# absolutely-placed child (stripe / bar) to the full rect.
	var band := Panel.new()
	band.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_theme_stylebox_override("panel", _band_style())
	add_child(band)

	_bleed = Bleed.new()
	_bleed.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bleed.offset_bottom = 22.0
	add_child(_bleed)

	# Siren stripe — the only moving part; a slow breath, not a strobe.
	_stripe = ColorRect.new()
	_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stripe.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_stripe.offset_right = STRIPE_W
	add_child(_stripe)

	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", int(STRIPE_W) + 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 7)
	pad.add_theme_constant_override("margin_bottom", 9)
	add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(row)

	_glyph = Hazard.new()
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_glyph)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 7)
	col.add_child(head)
	_title = _mono(13, ALERT_TEXT, true)
	head.add_child(_title)
	head.add_child(_mono(13, Color(ALERT_TEXT, 0.35), false, "·"))
	_value = _mono(13, ALERT_EDGE, true)
	head.add_child(_value)

	_sub = _mono(10, Color(ALERT_TEXT, 0.62), false)
	col.add_child(_sub)

	_cta = _alert_button("COOL OFF")
	_cta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_cta)

	# Live heat track doubles as the band's bottom edge.
	_bar = HeatBar.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -BAR_H
	add_child(_bar)

	refresh()
	if animate:
		play_in()
	else:
		slide_y = rest_y


func refresh() -> void:
	var critical := heat >= CRITICAL
	var edge: Color = ALERT_HOT if critical else ALERT_EDGE

	_stripe.color = edge
	_bleed.col = edge
	_bleed.queue_redraw()
	_glyph.col = edge
	_glyph.ink = ALERT_INK
	_glyph.filled = critical
	_glyph.queue_redraw()

	_title.text = "RAID IMMINENT" if critical else "RAID RISK"
	_value.text = "HEAT %d%%" % int(round(heat))
	_value.add_theme_color_override("font_color", edge)
	_sub.text = (
		"Seizures escalate every second. Cool down NOW."
		if critical
		else "Police raids seize %d%% of your cash above %d%%." % [SEIZE_PCT, int(RAID_THRESHOLD)]
	)
	_cta.text = "COOL OFF"
	_style_button(_cta, edge)

	_bar.progress = clampf(heat / 100.0, 0.0, 1.0)
	_bar.fill = edge
	_bar.notch = ALERT_TEXT
	_bar.queue_redraw()

	if animate and not GameTheme.ui_reduced_motion():
		_pulse(edge, 0.7 if critical else 1.3)
	else:
		_stripe.modulate.a = 1.0


## Drops from behind the masthead's top edge and settles on its bottom rule.
## 0.34s, BACK/OUT — the overshoot is the "slam" that earns the glance.
func play_in() -> void:
	if GameTheme.ui_reduced_motion():
		slide_y = rest_y
		return
	slide_y = -BANNER_H - 8.0
	var tw := create_tween()
	tw.tween_property(self, "slide_y", rest_y, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func play_out() -> void:
	var tw := create_tween()
	tw.tween_property(self, "slide_y", -BANNER_H - 8.0, 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _pulse(edge: Color, period: float) -> void:
	_stripe.color = edge
	_stripe.modulate.a = 1.0
	var tw := create_tween().set_loops()
	tw.tween_property(_stripe, "modulate:a", 0.45, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_stripe, "modulate:a", 1.0, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _band_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ALERT_INK, 0.97)
	sb.border_color = Color(ALERT_EDGE, 0.85)
	sb.set_border_width_all(0)
	sb.set_border_width(Side.SIDE_TOP, 2)
	sb.set_corner_radius_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


func _mono(px: int, col: Color, bold: bool, txt: String = "") -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", GameFonts.mono(bold))
	l.add_theme_font_size_override("font_size", GameTheme.scaled_font(px))
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.text = txt
	return l


func _alert_button(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(104, 44)  # ADR-002 touch floor
	b.add_theme_font_override("font", GameFonts.mono(true))
	b.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	return b


## CTA speaks the ship button language (chunky fill + darker bottom bevel,
## GameTheme.make_game_button_flat) — but in alert red, never gold.
func _style_button(b: Button, edge: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ALERT_PLATE.lightened(0.04) if state == "hover" else ALERT_PLATE
		sb.border_color = edge
		sb.set_border_width_all(1)
		sb.set_border_width(Side.SIDE_BOTTOM, 1 if state == "pressed" else 4)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 8.0 if state == "pressed" else 6.0
		sb.content_margin_bottom = 6.0 if state == "pressed" else 4.0
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", ALERT_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ALERT_TEXT)
