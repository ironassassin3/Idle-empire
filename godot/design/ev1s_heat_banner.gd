extends Control
## /godot-design — ev1s: compact HEAT WARNING banner (heat >= 60%, raid threshold).
## Design scene only. Nothing here is wired into the game; port notes in REPORT.md.
##
## Reads as danger with ZERO gold: the band is built from GameTheme.RED and one
## derived ember tint (proposed token RED_ALARM, see _ALARM below). The gold
## masthead sits underneath it so the render shows the contrast.

# ── Proposed kit amendment (port would add to GameTheme) ──────────────────────
# RED_ALARM = RED.lerp(#ff5933, 0.55)  ->  ~#d2523d
# Why: GameTheme.RED (#9a4a4a) is the *loss* token — desaturated, it reads as a
# red number in a ledger, not as a siren. The banner needs one hot tint that is
# unmistakably not gold (hue 14 deg vs gold 40 deg) for the seizure figure,
# stripes and the alarm rule. Everything else in the band is RED / BG derived.
static func _alarm() -> Color:
	return GameTheme.RED.lerp(Color(1.0, 0.35, 0.2), 0.55)

static func _band_fill() -> Color:
	return GameTheme.BG.lerp(GameTheme.RED, 0.22)

const BANNER_H := 72.0
const MASTHEAD_H := 128.0

# Mock state (the harness resets a new game; the banner is a pure-layout mock).
const MOCK_BALANCE := 154_200.0
const MOCK_HEAT := 68.0
const RAID_PENALTY := 0.08  # HeatSystem.RAID_BALANCE_PENALTY

var _banner: Control
var _mast_body: VBoxContainer


# ─────────────────────────────────────────────────────────────── drawn pieces

## Diagonal hazard stripes — the danger anchor on the leading edge of the band.
## Slow scroll (motion says "live threat", not decoration).
class HazardCap extends Control:
	var t := 0.0
	var alarm := Color(0.82, 0.32, 0.24)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if GameTheme.ui_reduced_motion():
			return
		t = fposmod(t + delta * 9.0, 18.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.02, 0.03, 1.0))
		var step := 18.0
		var x := -size.y - step + t
		while x < size.x + size.y:
			var pts := PackedVector2Array([
				Vector2(x, size.y), Vector2(x + step * 0.5, size.y),
				Vector2(x + step * 0.5 + size.y, 0.0), Vector2(x + size.y, 0.0),
			])
			draw_colored_polygon(pts, alarm)
			x += step


## Siren wash — a soft red light sweeping across the band. One orchestrated
## motion beat; it is what makes a static strip feel like an alarm.
class SirenWash extends Control:
	var t := 0.0
	var alarm := Color(0.82, 0.32, 0.24)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if GameTheme.ui_reduced_motion():
			return
		t += delta * 0.55
		queue_redraw()

	func _draw() -> void:
		var head := fposmod(t, 1.0) * (size.x + 300.0) - 150.0
		var w := 3.0                       # fine slices — coarse ones band visibly
		var cols := int(ceil(size.x / w))
		for i in cols:
			var cx := (i + 0.5) * w
			var d: float = absf(cx - head) / 170.0
			if d >= 1.0:
				continue
			var a: float = (1.0 - d) * (1.0 - d) * 0.20
			# No slice overlap: overlapping alpha double-blends into visible seams.
			draw_rect(Rect2(i * w, 0.0, w, size.y), Color(alarm, a))


## Pulsing siren lamp — small, hot, next to the headline.
class SirenLamp extends Control:
	var t := 0.0
	var alarm := Color(0.82, 0.32, 0.24)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(18, 18)

	func _process(delta: float) -> void:
		if GameTheme.ui_reduced_motion():
			return
		t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var p: float = 0.5 + 0.5 * sin(t * 4.2)
		draw_circle(c, 8.0, Color(alarm, 0.10 + 0.16 * p))
		draw_circle(c, 5.0, Color(alarm, 0.30 + 0.30 * p))
		draw_circle(c, 2.6, Color(alarm, 0.85 + 0.15 * p))


## The band presses onto the masthead: a short shade falls from its bottom edge.
class UnderShade extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var steps := 12
		for i in steps:
			var f := float(i) / steps
			draw_rect(Rect2(0.0, size.y * f, size.x, size.y / steps + 1.0),
				Color(0.0, 0.0, 0.0, lerpf(0.55, 0.0, f)))


# ──────────────────────────────────────────────────────────────────── build

func _ready() -> void:
	_build_masthead_mock()
	_build_sheet_mock()
	_banner = _build_banner()
	add_child(_banner)
	_play_entrance()


func _build_masthead_mock() -> void:
	var mast := Control.new()
	mast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	mast.offset_bottom = MASTHEAD_H + BANNER_H
	mast.clip_contents = true
	add_child(mast)

	if ResourceLoader.exists("res://scenes/ui/city_view.tscn"):
		var city: Control = load("res://scenes/ui/city_view.tscn").instantiate()
		city.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mast.add_child(city)
	var scrim := MastheadScrim.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mast.add_child(scrim)

	# Masthead content, pushed down by the band (nothing is ever hidden behind it).
	_mast_body = VBoxContainer.new()
	_mast_body.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_mast_body.add_theme_constant_override("separation", 0)
	_mast_body.position.y = BANNER_H
	mast.add_child(_mast_body)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 8)
	_mast_body.add_child(pad)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	pad.add_child(top)
	top.add_child(_chip("STREET BOSS", GameTheme.GOLD_BRIGHT))
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spring)
	top.add_child(_gear_chip())

	var bal := Label.new()
	bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bal.add_theme_font_override("font", GameFonts.display())
	bal.add_theme_font_size_override("font_size", GameTheme.scaled_font(44))
	bal.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	bal.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	bal.add_theme_constant_override("shadow_offset_y", 3)
	bal.text = _money(MOCK_BALANCE)
	_mast_body.add_child(bal)

	var ips := Label.new()
	ips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ips.add_theme_font_override("font", GameFonts.mono(true))
	ips.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	ips.add_theme_color_override("font_color", GameTheme.GREEN)
	ips.text = "+ %s / SEC" % _money(1840.0)
	_mast_body.add_child(ips)


func _chip(txt: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.BG, 0.82)
	sb.border_color = Color(GameTheme.GOLD, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.add_theme_font_override("font", GameFonts.heading())
	l.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	l.add_theme_color_override("font_color", col)
	l.text = txt
	p.add_child(l)
	return p


func _gear_chip() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.BG, 0.82)
	sb.border_color = Color(GameTheme.GOLD, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.icon = GameIcons.texture("gear")
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 20)
	b.add_theme_color_override("icon_normal_color", GameTheme.GOLD)
	return b


func _build_banner() -> Control:
	var alarm := _alarm()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	root.offset_bottom = BANNER_H

	# Shade first (below the band, on the masthead) — the band presses down.
	var shade := UnderShade.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = BANNER_H
	shade.offset_bottom = BANNER_H + 16.0
	root.add_child(shade)

	var band := PanelContainer.new()
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	band.offset_bottom = BANNER_H
	var sb := StyleBoxFlat.new()
	sb.bg_color = _band_fill()
	# No bottom border: the heat rule IS the band's baseline, so the band's own
	# edge lights up as heat climbs and stays dark past the fill. The meter and
	# the frame are the same object.
	sb.border_width_top = 1
	sb.border_color = Color(alarm, 0.9)
	sb.shadow_color = Color(alarm, 0.18)
	sb.shadow_size = 6
	band.add_theme_stylebox_override("panel", sb)
	root.add_child(band)

	var stack := Control.new()   # band content + wash overlay
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	band.add_child(stack)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	stack.add_child(row)

	var cap := HazardCap.new()
	cap.alarm = alarm
	cap.clip_contents = true          # stripes stay inside the 14px leading edge
	cap.custom_minimum_size = Vector2(14, 0)
	row.add_child(cap)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 12)
	row.add_child(pad)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.alignment = BoxContainer.ALIGNMENT_BEGIN
	pad.add_child(inner)

	var lamp_box := CenterContainer.new()
	var lamp := SirenLamp.new()
	lamp.alarm = alarm
	lamp_box.add_child(lamp)
	inner.add_child(lamp_box)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 1)
	inner.add_child(text_col)

	# Kicker: what happened + the meter, in the chrome voice (Cinzel, bone).
	# The colorblind shape channel (▲) rides here, never color alone.
	var kicker := Label.new()
	kicker.add_theme_font_override("font", GameFonts.heading())
	kicker.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	kicker.add_theme_color_override("font_color", Color(GameTheme.TEXT, 0.88))
	kicker.text = "▲  POLICE ATTENTION  ·  HEAT %d%%" % int(MOCK_HEAT)
	text_col.add_child(kicker)

	# HERO: what the raid takes, in money. The one thing a player would repeat.
	# Number carries the weight; the verb is a caption beside it, not equal to it.
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 7)
	hero_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	text_col.add_child(hero_row)

	var hero := Label.new()
	hero.add_theme_font_override("font", GameFonts.mono(true))
	hero.add_theme_font_size_override("font_size", GameTheme.scaled_font(23))
	hero.add_theme_color_override("font_color", alarm)
	hero.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hero.add_theme_constant_override("shadow_offset_y", 2)
	hero.text = _money(MOCK_BALANCE * RAID_PENALTY)
	hero_row.add_child(hero)

	var caption := Label.new()
	caption.add_theme_font_override("font", GameFonts.mono(false))
	caption.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	caption.add_theme_color_override("font_color", Color(alarm, 0.72))
	caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	caption.text = "CAN BE SEIZED"
	hero_row.add_child(caption)

	# CTA: dark oxblood bevel — pressable, but it must never out-shout the number.
	var act := Button.new()
	act.text = "LAY LOW"
	act.custom_minimum_size = Vector2(104, 46)   # touch floor
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act.add_theme_stylebox_override("normal", _cta_style(alarm, false))
	act.add_theme_stylebox_override("hover", _cta_style(alarm, false))
	act.add_theme_stylebox_override("pressed", _cta_style(alarm, true))
	act.add_theme_font_override("font", GameFonts.heading())
	act.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	act.add_theme_color_override("font_color", GameTheme.TEXT)
	act.add_theme_color_override("font_hover_color", Color.WHITE)
	inner.add_child(act)

	var wash := SirenWash.new()
	wash.alarm = alarm
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(wash)

	# Heat rule hugging the band's bottom edge: the meter, as the band's own
	# baseline. The 60% raid tick is the shipped HeatThresholdTick component.
	var rule := UiPrims.mini_bar(alarm, 5.0)
	rule.track_alpha = 0.18
	rule.progress = MOCK_HEAT / 100.0
	rule.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	rule.offset_top = -5.0
	stack.add_child(rule)
	var tick := HeatThresholdTick.new()
	tick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rule.add_child(tick)

	return root


## Chunky-bevel button language (darker bottom edge), oxblood instead of gold.
func _cta_style(alarm: Color, pressed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameTheme.RED.darkened(0.45 if not pressed else 0.55)
	sb.border_color = Color(alarm, 0.75)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 1 if pressed else 4
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb


## Screen context so the band is judged in situ, not as a floating strip.
func _build_sheet_mock() -> void:
	var sheet := PanelContainer.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.offset_top = MASTHEAD_H + BANNER_H + 16.0
	sheet.offset_left = 10.0
	sheet.offset_right = -10.0
	sheet.offset_bottom = -10.0
	sheet.add_theme_stylebox_override("panel", GameTheme.panel_style())
	add_child(sheet)

	var pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 12)
	sheet.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pad.add_child(v)

	var title := Label.new()
	GameTheme.apply_list_section_title(title)
	title.text = "OPERATIONS"
	v.add_child(title)
	for r in [["Street Dealers", "24 owned"], ["Numbers Racket", "11 owned"],
			["Chop Shop", "6 owned"]]:
		v.add_child(_stub_row(str(r[0]), str(r[1])))


func _stub_row(name_txt: String, meta_txt: String) -> PanelContainer:
	var row := PanelContainer.new()
	GameTheme.apply_row_affordance(row, GameTheme.RowAffordance.OWNED)
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	row.add_child(m)
	var h := HBoxContainer.new()
	m.add_child(h)
	var n := Label.new()
	GameTheme.apply_row_title(n, 14)
	n.text = name_txt
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var meta := Label.new()
	meta.add_theme_font_override("font", GameFonts.mono(false))
	meta.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	meta.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	meta.text = meta_txt
	h.add_child(meta)
	return row


# ───────────────────────────────────────────────────────────────── entrance

## One beat: the band drops from behind the status bar, the masthead yields
## under it. 0.34s, overshoot on the band only.
func _play_entrance() -> void:
	if GameTheme.ui_reduced_motion():
		return
	_banner.position.y = -BANNER_H - 18.0
	_mast_body.position.y = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_banner, "position:y", 0.0, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mast_body, "position:y", BANNER_H, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _money(v: float) -> String:
	var fmt: Node = get_node_or_null("/root/FormatUtil")
	if fmt != null:
		return str(fmt.format_money(v))
	return "$%d" % int(v)
