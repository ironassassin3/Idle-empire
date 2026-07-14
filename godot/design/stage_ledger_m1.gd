extends Control
## /godot-design — M1 "Stage & Ledger" shell mock (UI_OVERHAUL_ARCHITECTURE.md §4).
## Full-bleed city stage · masthead w/ prestige filament · single attention rail ·
## translucent content sheet (REST) w/ segmented buy control + 3-state rows ·
## 5-tab nav dock. Static mock, fake data.

const INK := Color("08070a")
const INK_FIELD := Color("0c0c14")
const SHEET_GLASS := Color(0.047, 0.047, 0.078, 0.9)
const GOLD_TEXT_DARK := Color("1a1208")

# name, owned, income line, cost, state (0 READY / 1 APPROACHING / 2 LOCKED), afford 0..1
const ROWS := [
	["Corner Dealer", 24, "$4 / sec each", "$212", 0, 1.0],
	["Protection Racket", 8, "$28 / sec each", "$1.36K", 0, 1.0],
	["Chop Shop", 3, "$96 / sec each", "$8.9K", 1, 0.62],
	["Sports Betting Ring", 0, "The house always wins", "$46.5K", 1, 0.12],
	["???", 0, "Keep growing to discover", "$150K", 2, 0.0],
]


func _ready() -> void:
	var stage := CityStage.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	col.add_child(_masthead())
	col.add_child(_attention_rail())
	col.add_child(_stage_gap())
	col.add_child(_content_sheet())
	col.add_child(_nav_dock())


# ---------------------------------------------------------------- masthead

func _masthead() -> Control:
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 128)
	var scrim := Scrim.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.add_child(scrim)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 0)
	head.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_child(top)
	v.add_child(pad)

	top.add_child(_rank_chip("STREET HUSTLER"))
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spring)
	top.add_child(_heat_pill(0.23))
	top.add_child(_gear_chip())

	var bal := Label.new()
	bal.text = "$75.3K"
	bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bal.add_theme_font_override("font", GameFonts.display())
	bal.add_theme_font_size_override("font_size", 44)
	bal.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	bal.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	bal.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(bal)

	var ips := Label.new()
	ips.text = "+ $1.24K / SEC"
	ips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ips.add_theme_font_override("font", GameFonts.mono(true))
	ips.add_theme_font_size_override("font_size", 14)
	ips.add_theme_color_override("font_color", GameTheme.GREEN)
	v.add_child(ips)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)

	var filament := Filament.new()
	filament.progress = 0.34
	filament.custom_minimum_size = Vector2(0, 3)
	v.add_child(filament)
	return head


func _rank_chip(title: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.82)
	sb.border_color = Color(GameTheme.GOLD, 0.75)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", GameFonts.heading())
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	p.add_child(t)
	return p


func _heat_pill(heat: float) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.82)
	sb.border_color = Color(GameTheme.RED, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var t := Label.new()
	t.text = "HEAT %d%%" % int(heat * 100.0)
	t.add_theme_font_override("font", GameFonts.mono(true))
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", GameTheme.TEXT)
	v.add_child(t)
	var bar := MiniBar.new()
	bar.progress = heat
	bar.fill = GameTheme.RED
	bar.custom_minimum_size = Vector2(56, 3)
	v.add_child(bar)
	return p


func _gear_chip() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(44, 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.82)
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


# ------------------------------------------------------------ attention rail

func _attention_rail() -> Control:
	var outer := MarginContainer.new()
	for side in ["left", "right"]:
		outer.add_theme_constant_override("margin_" + side, 10)
	outer.add_theme_constant_override("margin_top", 8)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK_FIELD, 0.88)
	sb.border_color = GameTheme.GOLD
	sb.border_width_left = 3
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	p.add_theme_stylebox_override("panel", sb)
	outer.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var l := Label.new()
	l.text = "▸ GOAL — Own 25 businesses to attract a Manager"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", GameTheme.TEXT)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	var r := Label.new()
	r.text = "22/25"
	r.add_theme_font_override("font", GameFonts.mono(true))
	r.add_theme_font_size_override("font_size", 13)
	r.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	h.add_child(r)
	return outer


# ---------------------------------------------------------------- stage gap

func _stage_gap() -> Control:
	# Transparent spacer — the city stage shows through. Carries the tap
	# feedback ghosts + the $/tap chip so the mock reads "tap the city".
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var floats := TapGhosts.new()
	floats.set_anchors_preset(Control.PRESET_FULL_RECT)
	gap.add_child(floats)

	var chip := PanelContainer.new()
	chip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chip.offset_bottom = -10.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.6)
	sb.border_color = Color(GameTheme.GOLD, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", sb)
	var t := Label.new()
	t.text = "+$62 / TAP"
	t.add_theme_font_override("font", GameFonts.mono(false))
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	chip.add_child(t)
	gap.add_child(chip)
	return gap


# ------------------------------------------------------------- content sheet

func _content_sheet() -> Control:
	var sheet := PanelContainer.new()
	# REST snap state ≈ half the canvas; the real shell tweens between
	# PEEK / REST / FULL (UI_OVERHAUL_ARCHITECTURE.md §4 Z4).
	sheet.custom_minimum_size = Vector2(0, maxf(620.0, get_viewport_rect().size.y * 0.5))
	var sb := StyleBoxFlat.new()
	sb.bg_color = SHEET_GLASS
	sb.border_color = Color(GameTheme.GOLD, 0.35)
	sb.border_width_top = 1
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 4
	sheet.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sheet.add_child(v)

	var handle := Handle.new()
	handle.custom_minimum_size = Vector2(0, 10)
	v.add_child(handle)
	v.add_child(_sheet_header())
	for r in ROWS:
		v.add_child(_row_card(r[0], r[1], r[2], r[3], r[4], r[5]))
	return sheet


func _sheet_header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 4)
	pad.add_child(h)

	var t := Label.new()
	t.text = "FRONT BUSINESSES"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.add_theme_font_override("font", GameFonts.heading())
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", GameTheme.GOLD)
	h.add_child(t)

	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 0)
	h.add_child(seg)
	seg.add_child(_seg_btn("×1", true, true, false))
	seg.add_child(_seg_btn("×10", false, false, false))
	seg.add_child(_seg_btn("MAX", false, false, true))
	return pad


func _seg_btn(txt: String, active: bool, first: bool, last: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(56, 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GameTheme.GOLD if active else Color(GameTheme.CHIP_BG, 0.9)
	sb.border_color = Color(GameTheme.GOLD, 0.6)
	sb.set_border_width_all(1)
	if first:
		sb.corner_radius_top_left = 5
		sb.corner_radius_bottom_left = 5
	if last:
		sb.corner_radius_top_right = 5
		sb.corner_radius_bottom_right = 5
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", GameFonts.mono(true))
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", GOLD_TEXT_DARK if active else GameTheme.TEXT_MUTED)
	return b


func _row_card(nm: String, owned: int, inc: String, cost: String, state: int, afford: float) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 92)
	var sb := StyleBoxFlat.new()
	match state:
		0:  # READY
			sb.bg_color = Color("1a1520")
			sb.border_color = Color(GameTheme.GOLD, 0.65)
		1:  # APPROACHING
			sb.bg_color = Color("14101c")
			sb.border_color = Color("2e2638")
		_:  # LOCKED silhouette
			sb.bg_color = Color("100c16")
			sb.border_color = Color("221c2c")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", sb)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	card.add_child(stack)

	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 12)
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.add_child(h)
	stack.add_child(pad)

	var medal := Medal.new()
	medal.count = owned
	medal.locked = state == 2
	medal.custom_minimum_size = Vector2(50, 50)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(medal)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 2)
	h.add_child(mid)
	var n := Label.new()
	n.text = nm
	n.add_theme_font_override("font", GameFonts.heading())
	n.add_theme_font_size_override("font_size", 17)
	n.add_theme_color_override("font_color",
		GameTheme.GOLD if state == 0 else (GameTheme.TEXT if state == 1 else GameTheme.TEXT_MUTED))
	mid.add_child(n)
	var i := Label.new()
	i.text = inc
	i.add_theme_font_override("font", GameFonts.mono(false))
	i.add_theme_font_size_override("font_size", 12)
	i.add_theme_color_override("font_color", GameTheme.GREEN if owned > 0 else GameTheme.TEXT_MUTED)
	mid.add_child(i)

	h.add_child(_action_button(cost, state))

	var underbar := MiniBar.new()
	underbar.progress = afford if state == 1 else 0.0
	underbar.fill = GameTheme.GOLD
	underbar.track_alpha = 0.0
	underbar.custom_minimum_size = Vector2(0, 3)
	stack.add_child(underbar)
	return card


func _action_button(cost: String, state: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(116, 56)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	match state:
		0:
			b.text = "BUY  ·  " + cost
			sb.bg_color = GameTheme.GOLD
			sb.border_color = GameTheme.GOLD_BRIGHT
			sb.set_border_width_all(1)
			sb.border_width_bottom = 3
			sb.border_color = Color("8a6f3c")
			b.add_theme_color_override("font_color", GOLD_TEXT_DARK)
		1:
			b.text = cost
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(GameTheme.GOLD, 0.45)
			sb.set_border_width_all(1)
			b.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		_:
			b.text = cost
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color("221c2c")
			sb.set_border_width_all(1)
			b.add_theme_color_override("font_color", Color(GameTheme.TEXT_MUTED, 0.55))
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", GameFonts.heading())
	b.add_theme_font_size_override("font_size", 14)
	return b


# ------------------------------------------------------------------ nav dock

func _nav_dock() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 68)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK_FIELD, 0.97)
	sb.border_color = Color(GameTheme.GOLD, 0.4)
	sb.border_width_top = 1
	bar.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 6)
	pad.add_child(h)
	bar.add_child(pad)
	var tabs := [["buildings", "Buildings", true, false], ["trend-up", "Upgrades", false, true],
		["users-three", "Managers", false, false], ["map-pin", "Turf", false, false],
		["chart-bar", "Stats", false, false]]
	for t in tabs:
		h.add_child(_tab(t[0], t[1], t[2], t[3]))
	return bar


func _tab(icon: String, label: String, active: bool, badge: bool) -> Control:
	var slot := PanelContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	sb.bg_color = GameTheme.GOLD if active else Color(0, 0, 0, 0)
	slot.add_theme_stylebox_override("panel", sb)

	var wrap := Control.new()
	slot.add_child(wrap)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	wrap.add_child(v)
	var tex := TextureRect.new()
	tex.texture = GameIcons.texture(icon)
	tex.custom_minimum_size = Vector2(22, 22)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex.modulate = GOLD_TEXT_DARK if active else GameTheme.TEXT_MUTED
	v.add_child(tex)
	var l := Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameFonts.heading())
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", GOLD_TEXT_DARK if active else GameTheme.TEXT_MUTED)
	v.add_child(l)
	if badge:
		var dot := BadgeDot.new()
		dot.set_anchors_preset(Control.PRESET_CENTER_TOP)
		dot.offset_left = 12.0
		dot.offset_top = 3.0
		dot.offset_right = 22.0
		dot.offset_bottom = 13.0
		wrap.add_child(dot)
	return slot


# ------------------------------------------------------------ drawn helpers

class CityStage extends Control:
	## Full-bleed procedural city: sky gradient, moon, two skyline layers.
	func _draw() -> void:
		var s := size
		var steps := 32
		for i in steps:
			var t := float(i) / steps
			var c := Color("1c1632").lerp(Color("08070a"), pow(t, 0.8))
			draw_rect(Rect2(0, s.y * t, s.x, s.y / steps + 1.0), c)
		# moon disc — art-deco pale gold, in the visible stage gap
		var moon := Vector2(s.x * 0.76, s.y * 0.24)
		draw_circle(moon, 30.0, Color("c8a35a", 0.10))
		draw_arc(moon, 30.0, 0, TAU, 48, Color("c8a35a", 0.5), 1.5)
		# far skyline (rooftops ~26% height)
		_skyline(7, s.y * 0.26, s.y, Color("0e0a16"), 0.25, 44.0)
		# near skyline (rooftops ~33%)
		_skyline(23, s.y * 0.33, s.y, Color("120c1a"), 0.6, 60.0)

	func _skyline(seed_v: int, roof_min: float, ground: float, fill: Color,
			win_alpha: float, max_w: float) -> void:
		var s := size
		var x := -10.0
		while x < s.x:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			var bw := 26.0 + float(seed_v % int(max_w))
			var top := roof_min + float((seed_v >> 8) % 190)
			draw_rect(Rect2(x, top, bw, ground - top), fill)
			# lit windows — gold pinpricks
			var wy := top + 8.0
			while wy < ground - 10.0:
				var wx := x + 5.0
				while wx < x + bw - 5.0:
					seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
					if seed_v % 5 == 0:
						draw_rect(Rect2(wx, wy, 3, 4), Color(GameTheme.GOLD, win_alpha))
					wx += 9.0
				wy += 14.0
			x += bw + 4.0


class Scrim extends Control:
	## Masthead legibility gradient — opaque top fading toward the stage.
	func _draw() -> void:
		var s := size
		var steps := 18
		for i in steps:
			var t := float(i) / steps
			draw_rect(Rect2(0, s.y * t, s.x, s.y / steps + 1.0),
				Color(0.031, 0.027, 0.039, lerpf(0.95, 0.35, t)))


class Filament extends Control:
	## Prestige progress — a 3px gold thread along the masthead's bottom rule.
	var progress := 0.0
	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color("c8a35a", 0.16))
		draw_rect(Rect2(0, 0, size.x * progress, size.y), Color("ecca7d", 0.95))


class MiniBar extends Control:
	var progress := 0.0
	var fill := Color("c8a35a")
	var track_alpha := 0.25
	func _draw() -> void:
		if track_alpha > 0.0:
			draw_rect(Rect2(0, 0, size.x, size.y), Color(fill, track_alpha))
		if progress > 0.0:
			draw_rect(Rect2(0, 0, size.x * progress, size.y), fill)


class Handle extends Control:
	## Sheet drag notch.
	func _draw() -> void:
		var w := 40.0
		var r := Rect2((size.x - w) * 0.5, (size.y - 4.0) * 0.5, w, 4.0)
		draw_rect(r, Color("8a8070", 0.55))


class TapGhosts extends Control:
	## Static hint of tap feedback floating over the stage.
	func _draw() -> void:
		var font := GameFonts.mono(true)
		var spots := [
			[Vector2(0.30, 0.42), "+$62", 14, Color("e8e0d4", 0.7)],
			[Vector2(0.52, 0.22), "+$62", 12, Color("e8e0d4", 0.4)],
			[Vector2(0.64, 0.55), "CRIT +$496", 16, Color("ecca7d", 0.9)],
		]
		for sp in spots:
			var pos: Vector2 = Vector2(size.x * sp[0].x, size.y * sp[0].y)
			draw_string(font, pos, sp[1], HORIZONTAL_ALIGNMENT_LEFT, -1, sp[2], sp[3])


class BadgeDot extends Control:
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 5.0, Color("ecca7d"))
		draw_arc(c, 5.0, 0, TAU, 24, Color("1a1208", 0.9), 1.0)


class Medal extends Control:
	var count := 0
	var locked := false
	func _draw() -> void:
		var c := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, radius, Color("120c1a"))
		var ring := Color(GameTheme.GOLD, 0.3 if locked else 0.95)
		draw_arc(c, radius, 0, TAU, 48, ring, 2.0)
		draw_arc(c, radius - 4.0, 0, TAU, 48, Color(GameTheme.GOLD, 0.12 if locked else 0.4), 1.0)
		var font := GameFonts.mono(true)
		var txt := "?" if locked else str(count)
		var fs := 18 if txt.length() < 3 else 14
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, Vector2(c.x - ts.x * 0.5, c.y + ts.y * 0.30), txt,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs,
			Color(GameTheme.TEXT_MUTED, 0.6) if locked
			else (GameTheme.GOLD_BRIGHT if count > 0 else GameTheme.TEXT_MUTED))
