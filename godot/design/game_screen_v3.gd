extends Control
## /godot-design — SURFACE overhaul direction ("gilded ledger").
## v2 proved layout; v3 changes what 90% of pixels look like:
## lifted card fills, 2px frames, INVERTED gold CTAs (gold fill, dark text),
## gold-filled active tab, framed list zone. Static mock, fake data.

const INK := Color("0d0912")
const CARD := Color("221a2e")
const CARD_EDGE := Color("4a3c2a")
const GOLD_FILL := Color("c8a35a")
const GOLD_TEXT_DARK := Color("1a1208")

const ROWS := [
	["Corner Dealer", 12, "$4 / sec each", "$186", true, false],
	["Protection Racket", 6, "$28 / sec each", "$1.24K", true, false],
	["Chop Shop", 3, "$96 / sec each", "$8.9K", true, true],
	["Sports Betting Ring", 1, "$310 / sec each", "$46.5K", true, false],
	["Pawn Shop", 0, "No income yet", "$128K", false, false],
]

var _fmt: Node


func _ready() -> void:
	_fmt = get_node("/root/FormatUtil")
	var bg := ColorRect.new()
	bg.color = INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	col.add_child(_masthead())
	col.add_child(_goal_strip())
	col.add_child(_list_zone())
	col.add_child(_tab_bar())


func _masthead() -> Control:
	var head := Control.new()
	head.custom_minimum_size = Vector2(0, 210)
	var sky := SkyBand.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.add_child(sky)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 2)
	head.add_child(v)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_child(top)
	v.add_child(pad)

	top.add_child(_plate("STREET HUSTLER", "RANK I · 0 INF"))
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spring)
	top.add_child(_gold_chip("×1"))
	top.add_child(_gold_chip("⚙"))

	var mid := Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(mid)

	var bal := Label.new()
	bal.text = "$75.3K"
	bal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bal.add_theme_font_override("font", GameFonts.display())
	bal.add_theme_font_size_override("font_size", 56)
	bal.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	bal.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	bal.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(bal)
	var ips := Label.new()
	ips.text = "+ $1.24K / SEC"
	ips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ips.add_theme_font_override("font", GameFonts.mono(true))
	ips.add_theme_font_size_override("font_size", 15)
	ips.add_theme_color_override("font_color", GameTheme.GREEN)
	v.add_child(ips)
	var rule := Rule.new()
	rule.custom_minimum_size = Vector2(0, 14)
	v.add_child(rule)
	return head


func _plate(title: String, sub: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.9)
	sb.border_color = GOLD_FILL
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", GameFonts.heading())
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	v.add_child(t)
	var s := Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 10)
	s.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	v.add_child(s)
	return p


func _gold_chip(txt: String) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(46, 42)
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD_FILL
	sb.set_corner_radius_all(4)
	sb.border_color = GameTheme.GOLD_BRIGHT
	sb.set_border_width_all(1)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", GOLD_TEXT_DARK)
	b.add_theme_font_size_override("font_size", 15)
	return b


func _goal_strip() -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("171020")
	sb.border_color = GOLD_FILL
	sb.border_width_left = 4
	sb.content_margin_left = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.content_margin_right = 12
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	p.add_child(h)
	var l := Label.new()
	l.text = "▸ NEXT — Own 25 businesses to attract a Manager"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", GameTheme.TEXT)
	h.add_child(l)
	var r := Label.new()
	r.text = "22/25"
	r.add_theme_font_override("font", GameFonts.mono(true))
	r.add_theme_font_size_override("font_size", 14)
	r.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	h.add_child(r)
	return p


func _list_zone() -> Control:
	# The framed ledger: list sits inside a visible gold-edged panel.
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("140e1c")
	sb.border_color = Color(GOLD_FILL, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", sb)
	var outer := MarginContainer.new()
	for side in ["left", "right"]:
		outer.add_theme_constant_override("margin_" + side, 10)
	outer.add_theme_constant_override("margin_top", 8)
	outer.add_theme_constant_override("margin_bottom", 4)
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(frame)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	frame.add_child(v)
	v.add_child(_section_head("FRONT BUSINESSES", "5 OF 11"))
	for r in ROWS:
		v.add_child(_card(r[0], r[1], r[2], r[3], r[4], r[5]))
	return outer


func _section_head(title: String, meta: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1f1626")
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	p.add_child(h)
	var t := Label.new()
	t.text = title
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_theme_font_override("font", GameFonts.heading())
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", GameTheme.GOLD)
	h.add_child(t)
	var m := Label.new()
	m.text = meta
	m.add_theme_font_override("font", GameFonts.mono(false))
	m.add_theme_font_size_override("font_size", 11)
	m.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	h.add_child(m)
	return p


func _card(nm: String, owned: int, inc: String, cost: String, buyable: bool, pete: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 96)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD if buyable else Color("18121f")
	sb.border_color = GameTheme.GOLD_BRIGHT if pete else (CARD_EDGE if buyable else Color("2a2232"))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	card.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.add_child(h)
	card.add_child(pad)

	var medal := Medal.new()
	medal.count = owned
	medal.custom_minimum_size = Vector2(56, 56)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(medal)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 3)
	h.add_child(mid)
	var n := Label.new()
	n.text = nm
	n.add_theme_font_override("font", GameFonts.heading())
	n.add_theme_font_size_override("font_size", 18)
	n.add_theme_color_override("font_color", GameTheme.GOLD if buyable else GameTheme.TEXT_MUTED)
	mid.add_child(n)
	var i := Label.new()
	i.text = inc
	i.add_theme_font_override("font", GameFonts.mono(false))
	i.add_theme_font_size_override("font_size", 12)
	i.add_theme_color_override("font_color", GameTheme.GREEN if owned > 0 else GameTheme.TEXT_MUTED)
	mid.add_child(i)
	if pete:
		var pk := Label.new()
		pk.text = "★ PETE'S PICK"
		pk.add_theme_font_size_override("font_size", 11)
		pk.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
		mid.add_child(pk)

	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 5)
	h.add_child(right)
	var c := Label.new()
	c.text = cost
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_override("font", GameFonts.mono(true))
	c.add_theme_font_size_override("font_size", 15)
	c.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT if buyable else GameTheme.TEXT_MUTED)
	right.add_child(c)
	var b := Button.new()
	b.custom_minimum_size = Vector2(104, 46)
	b.text = "BUY" if buyable else "LOCKED"
	b.add_theme_font_override("font", GameFonts.heading())
	b.add_theme_font_size_override("font_size", 15)
	var bs := StyleBoxFlat.new()
	bs.set_corner_radius_all(4)
	if buyable:
		bs.bg_color = GOLD_FILL
		bs.border_color = GameTheme.GOLD_BRIGHT
		bs.set_border_width_all(1)
		b.add_theme_color_override("font_color", GOLD_TEXT_DARK)
	else:
		bs.bg_color = Color("18121f")
		bs.border_color = Color("2a2232")
		bs.set_border_width_all(1)
		b.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, bs)
	right.add_child(b)
	return card


func _tab_bar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 72)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a1322")
	sb.border_color = Color(GOLD_FILL, 0.5)
	sb.border_width_top = 1
	bar.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	pad.add_theme_constant_override("margin_top", 7)
	pad.add_theme_constant_override("margin_bottom", 7)
	pad.add_child(h)
	bar.add_child(pad)
	var tabs := [["buildings", "Empire", true], ["trend-up", "Upgrades", false],
		["users-three", "Managers", false], ["map-pin", "Turf", false], ["chart-bar", "Stats", false]]
	for t in tabs:
		h.add_child(_tab(t[0], t[1], t[2]))
	return bar


func _tab(icon: String, label: String, active: bool) -> Control:
	var slot := PanelContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	sb.bg_color = GOLD_FILL if active else Color(0, 0, 0, 0)
	slot.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	slot.add_child(v)
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
	return slot


class SkyBand extends Control:
	func _draw() -> void:
		var s := size
		var steps := 26
		for i in steps:
			var t := float(i) / steps
			var c := Color("2c1f3a").lerp(Color("0d0912"), t)
			draw_rect(Rect2(0, s.y * t, s.x, s.y / steps + 1.0), c)
		var seed_v := 11
		var x := -8.0
		while x < s.x:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			var bw := 30.0 + float(seed_v % 46)
			var bh := 34.0 + float((seed_v >> 7) % 96)
			draw_rect(Rect2(x, s.y - bh, bw, bh), Color("120c1a"))
			var wx := x + 5.0
			while wx < x + bw - 5.0:
				seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
				if seed_v % 4 == 0:
					draw_rect(Rect2(wx, s.y - bh + 6.0 + float(seed_v % int(maxf(bh - 16.0, 1.0))), 3, 4),
						Color(GameTheme.GOLD, 0.6))
				wx += 8.0
			x += bw + 5.0


class Rule extends Control:
	func _draw() -> void:
		var mid := size.y * 0.5
		var cx := size.x * 0.5
		draw_line(Vector2(24, mid), Vector2(cx - 14, mid), Color(GameTheme.GOLD, 0.6), 1.0)
		draw_line(Vector2(cx + 14, mid), Vector2(size.x - 24, mid), Color(GameTheme.GOLD, 0.6), 1.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, mid - 4), Vector2(cx + 5, mid), Vector2(cx, mid + 4), Vector2(cx - 5, mid)]),
			GameTheme.GOLD)


class Medal extends Control:
	var count := 0
	func _draw() -> void:
		var c := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		draw_circle(c, radius, Color("120c1a"))
		draw_arc(c, radius, 0, TAU, 48, Color(GameTheme.GOLD, 0.95), 2.0)
		draw_arc(c, radius - 4.0, 0, TAU, 48, Color(GameTheme.GOLD, 0.4), 1.0)
		var font := GameFonts.mono(true)
		var txt := str(count)
		var fs := 20 if txt.length() < 3 else 15
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, Vector2(c.x - ts.x * 0.5, c.y + ts.y * 0.30), txt,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs,
			GameTheme.GOLD_BRIGHT if count > 0 else GameTheme.TEXT_MUTED)
