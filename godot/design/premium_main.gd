extends Control
## Premium main-screen direction study (DESIGN MOCK — godot/design only).
## Three code-drawn elevations of the masthead + city + rows, differing on the
## color/atmosphere axis so the owner can pick a direction from pixels. Strictly
## code-drawn per ART_POLICY: gradients + deco linework via _draw, StyleBoxFlat
## panels, real GameFonts. Non-kit palette values are EXPLORE proposals (marked
## per direction) — kit-amendment candidates, not shipped as-is.

@export var direction := "a"

# ── Direction palettes (EXPLORE — proposed GameTheme amendments) ──
# a: Gilded Deco   — warm near-black, gold focal + emerald/oxblood jewel structure
# b: Neon Noir     — cool near-black, gold demoted, electric teal + hot magenta
# c: Speakeasy Ink — sepia-black, brass/amber warmth, parchment text, oxblood
const PALETTES := {
	"a": {
		"name": "GILDED DECO",
		"bg": Color("0a0806"), "panel": Color("161009"), "card": Color("1e150b"),
		"sky_top": Color("241a10"), "sky_bot": Color("0a0806"),
		"glow": Color("c8863a"), "ink": Color("efe6d2"), "muted": Color("9a8a6a"),
		"gold": Color("c8a35a"), "gold_hi": Color("f0cf88"),
		"jewel_a": Color("3f8f77"), "jewel_b": Color("9a3b3b"),  # emerald / oxblood
		"win": Color("f0b860"),
	},
	"b": {
		"name": "NEON NOIR",
		"bg": Color("06070c"), "panel": Color("0c0f18"), "card": Color("11151f"),
		"sky_top": Color("0e1826"), "sky_bot": Color("06070c"),
		"glow": Color("1f5f7a"), "ink": Color("e6ecf2"), "muted": Color("7a869a"),
		"gold": Color("c9a45c"), "gold_hi": Color("ecca7d"),
		"jewel_a": Color("2fd6c6"), "jewel_b": Color("e5457e"),  # teal / rose-magenta
		"win": Color("4fe0d0"),
	},
	"c": {
		"name": "SPEAKEASY INK",
		"bg": Color("0f0b08"), "panel": Color("1b140d"), "card": Color("241a10"),
		"sky_top": Color("2e2012"), "sky_bot": Color("0f0b08"),
		"glow": Color("b87a34"), "ink": Color("ecdcc0"), "muted": Color("a4906c"),
		"gold": Color("ca9a5c"), "gold_hi": Color("e9c98a"),
		"jewel_a": Color("5c7a4a"), "jewel_b": Color("8a3a2a"),  # forest / rust
		"win": Color("e6b45c"),
	},
}

var _p: Dictionary


func _ready() -> void:
	_p = PALETTES.get(direction, PALETTES["a"])
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = _p["bg"]
	add_child(bg)

	# Code-drawn atmospheric backdrop (skyline + sky gradient + deco frame).
	var back := _Backdrop.new()
	back.p = _p
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_build_masthead()
	_build_sheet()
	_build_dock()


# ───────────────────────────────── masthead
func _build_masthead() -> void:
	var band := Control.new()
	band.anchor_right = 1.0
	band.offset_top = 0.0
	band.offset_bottom = 150.0
	add_child(band)

	var top := HBoxContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 12
	top.add_theme_constant_override("separation", 8)
	band.add_child(top)
	top.add_child(_chip("STREET KINGPIN", _p["gold"], true))
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spring)
	top.add_child(_heat_pill(72))
	top.add_child(_chip("⚙", _p["muted"], false))

	var hero := Label.new()
	hero.anchor_right = 1.0
	hero.offset_top = 52
	hero.add_theme_font_override("font", GameFonts.display())
	hero.add_theme_font_size_override("font_size", 58)
	hero.add_theme_color_override("font_color", _p["gold_hi"])
	hero.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hero.add_theme_constant_override("shadow_offset_y", 3)
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.text = "$4.82M"
	band.add_child(hero)

	var ips := Label.new()
	ips.anchor_right = 1.0
	ips.offset_top = 120
	ips.add_theme_font_override("font", GameFonts.mono(true))
	ips.add_theme_font_size_override("font_size", 15)
	ips.add_theme_color_override("font_color", _p["jewel_a"])
	ips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ips.text = "▲  + $128.4K / SEC"
	band.add_child(ips)


func _chip(txt: String, col: Color, boxed: bool) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(_p["panel"].r, _p["panel"].g, _p["panel"].b, 0.85)
	sb.border_color = Color(col, 0.55 if boxed else 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	pc.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.add_theme_font_override("font", GameFonts.heading())
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", col if boxed else _p["ink"])
	l.text = txt
	pc.add_child(l)
	return pc


func _heat_pill(pct: int) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(_p["panel"].r, _p["panel"].g, _p["panel"].b, 0.9)
	sb.border_color = Color(_p["jewel_b"], 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(7)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	pc.add_child(box)
	var l := Label.new()
	l.add_theme_font_override("font", GameFonts.mono(true))
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", _p["jewel_b"])
	l.text = "⚠ HEAT %d%%" % pct
	box.add_child(l)
	var bar := _Bar.new()
	bar.p = _p
	bar.frac = pct / 100.0
	bar.custom_minimum_size = Vector2(72, 4)
	box.add_child(bar)
	return pc


# ───────────────────────────────── content sheet
func _build_sheet() -> void:
	var sheet := PanelContainer.new()
	sheet.anchor_right = 1.0
	sheet.anchor_bottom = 1.0
	sheet.anchor_top = 0.44  # ratio, not a fixed 560px — composes at any height
	sheet.offset_top = 0
	sheet.offset_bottom = -88
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(_p["bg"].r, _p["bg"].g, _p["bg"].b, 0.97)
	sb.border_color = Color(_p["gold"], 0.5)
	sb.set_border_width(SIDE_TOP, 2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 14
	sb.content_margin_bottom = 10
	sheet.add_theme_stylebox_override("panel", sb)
	add_child(sheet)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	sheet.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var title := Label.new()
	title.add_theme_font_override("font", GameFonts.heading())
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", _p["gold"])
	title.text = "FRONT BUSINESSES"
	head.add_child(title)
	var hs := Control.new()
	hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hs)
	head.add_child(_qty_chip())

	var rows := [
		["C", "Casino Floor", "The house always wins", 34, "$412K/s", _p["jewel_a"], true, "$1.9M"],
		["S", "Smuggling Docks", "Nothing declared, everything moves", 21, "$284K/s", _p["jewel_b"], true, "$740K"],
		["N", "Neon District", "Every window pays rent", 12, "$96K/s", _p["gold"], true, "$210K"],
		["L", "Laundromat Chain", "Clean money, dirty floors", 5, "$31K/s", _p["jewel_a"], true, "$58K"],
		["V", "Vault Network", "Where the empire keeps its secrets", 0, "unlocks at $12M", _p["muted"], false, ""],
	]
	for r in rows:
		v.add_child(_row(r))

	# Absorb the slack and cap the list with a disclosure footer (the real
	# game's "N more as you grow" pattern), so the sheet never dead-ends.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0, 4)
	v.add_child(spacer)
	var foot := Label.new()
	foot.add_theme_font_override("font", GameFonts.body_italic())
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", _p["muted"])
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.text = "▾  7 more fronts open as the empire grows"
	v.add_child(foot)


func _qty_chip() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	for i in 3:
		var lbl: String = ["×1", "×10", "MAX"][i]
		var active := i == 0
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = _p["gold"] if active else _p["card"]
		sb.border_color = Color(_p["gold"], 0.4)
		sb.set_border_width_all(1)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		pc.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.add_theme_font_override("font", GameFonts.mono(true))
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", _p["bg"] if active else _p["muted"])
		l.text = lbl
		pc.add_child(l)
		hb.add_child(pc)
	return hb


func _row(data: Array) -> Control:
	var initial: String = data[0]
	var name_s: String = data[1]
	var desc_s: String = data[2]
	var owned: int = data[3]
	var meta_s: String = data[4]
	var accent: Color = data[5]
	var buyable: bool = data[6]
	var cost_s: String = data[7]

	# Row = code-drawn gradient card (depth) + margined content on top.
	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 88)
	var bgc := _CardBg.new()
	bgc.p = _p
	bgc.accent = accent
	bgc.buyable = buyable
	bgc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bgc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bgc)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", 9)
	mc.add_theme_constant_override("margin_bottom", 9)
	card.add_child(mc)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	mc.add_child(hb)

	var medal := _Medal.new()
	medal.p = _p
	medal.initial = initial
	medal.accent = accent
	medal.count = owned
	medal.locked = not buyable
	medal.custom_minimum_size = Vector2(58, 58)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(medal)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hb.add_child(info)
	var nm := Label.new()
	nm.add_theme_font_override("font", GameFonts.heading())
	nm.add_theme_font_size_override("font_size", 16)
	nm.add_theme_color_override("font_color", _p["gold_hi"] if buyable else _p["muted"])
	nm.text = name_s if buyable else "???"
	info.add_child(nm)
	var ds := Label.new()
	ds.add_theme_font_override("font", GameFonts.body_italic())
	ds.add_theme_font_size_override("font_size", 12)
	ds.add_theme_color_override("font_color", _p["muted"])
	ds.text = desc_s
	info.add_child(ds)
	if buyable:
		var ow := Label.new()
		ow.add_theme_font_override("font", GameFonts.mono(false))
		ow.add_theme_font_size_override("font_size", 11)
		ow.add_theme_color_override("font_color", accent)
		ow.text = "Owned %d   ·   %s" % [owned, meta_s]
		info.add_child(ow)

	if buyable:
		hb.add_child(_buy_btn(cost_s))
	else:
		var lock := Label.new()
		lock.add_theme_font_override("font", GameFonts.mono(false))
		lock.add_theme_font_size_override("font_size", 12)
		lock.add_theme_color_override("font_color", _p["muted"])
		lock.text = meta_s
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(lock)
	return card


func _buy_btn(cost_s: String) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(112, 54)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = _p["gold"]
	sb.set_border_width_all(1)
	sb.set_border_width(SIDE_BOTTOM, 3)
	sb.border_color = _p["gold_hi"]
	sb.set_corner_radius_all(7)
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	pc.add_child(v)
	var b := Label.new()
	b.add_theme_font_override("font", GameFonts.heading())
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", _p["bg"])
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.text = "BUY ×1"
	v.add_child(b)
	var c := Label.new()
	c.add_theme_font_override("font", GameFonts.mono(true))
	c.add_theme_font_size_override("font_size", 12)
	c.add_theme_color_override("font_color", Color(_p["bg"], 0.8))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.text = cost_s
	v.add_child(c)
	return pc


# ───────────────────────────────── nav dock
func _build_dock() -> void:
	var dock := PanelContainer.new()
	dock.anchor_top = 1.0
	dock.anchor_right = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_top = -84
	var sb := StyleBoxFlat.new()
	sb.bg_color = _p["panel"]
	sb.border_color = Color(_p["gold"], 0.4)
	sb.set_border_width(SIDE_TOP, 1)
	dock.add_theme_stylebox_override("panel", sb)
	add_child(dock)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 0)
	dock.add_child(hb)
	var tabs := ["BLDGS", "UPGRS", "MGRS", "TURF", "STATS"]
	for i in tabs.size():
		var active := i == 0
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(144, 76)
		if active:
			var asb := StyleBoxFlat.new()
			asb.bg_color = _p["gold"]
			asb.set_corner_radius_all(9)
			asb.content_margin_left = 8
			asb.content_margin_right = 8
			cell.add_theme_stylebox_override("panel", asb)
		hb.add_child(cell)
		var l := Label.new()
		l.add_theme_font_override("font", GameFonts.heading())
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", _p["bg"] if active else _p["muted"])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.text = tabs[i]
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cell.add_child(l)


# ═══════════════════════════════ code-drawn sub-canvases

class _Backdrop extends Control:
	var p: Dictionary

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var horizon := h * 0.44
		# Sky gradient (banded) with a glow bloom near the horizon.
		var steps := 40
		for i in steps:
			var t := float(i) / float(steps)
			var y := t * horizon
			var col: Color = p["sky_top"].lerp(p["sky_bot"], t)
			draw_rect(Rect2(0, y, w, horizon / steps + 1.0), col)
		# Horizon glow bloom (the neon/amber signature of each direction).
		var glow: Color = p["glow"]
		for i in 6:
			var t := float(i) / 6.0
			var r := w * (0.35 + t * 0.5)
			draw_circle(Vector2(w * 0.5, horizon), r, Color(glow.r, glow.g, glow.b, 0.05 * (1.0 - t)))
		# Skyline silhouettes with lit windows.
		var win: Color = p["win"]
		var xs := [0.04, 0.19, 0.30, 0.44, 0.58, 0.70, 0.83, 0.93]
		var hts := [0.30, 0.52, 0.40, 0.66, 0.34, 0.58, 0.44, 0.28]
		for i in xs.size():
			var bx := w * float(xs[i])
			var bw := w * 0.12
			var bh := horizon * float(hts[i])
			var by := horizon - bh
			draw_rect(Rect2(bx, by, bw, bh), Color(p["bg"].r, p["bg"].g, p["bg"].b, 0.92))
			draw_rect(Rect2(bx, by, bw, 2.0), Color(p["gold"], 0.25))
			# windows
			for wy in range(int(by) + 8, int(horizon) - 6, 12):
				for wx in range(int(bx) + 6, int(bx + bw) - 6, 11):
					if (wx * 7 + wy * 3) % 5 < 2:
						draw_rect(Rect2(wx, wy, 5.0, 6.0), Color(win, 0.85))
		# Neon rooftop signs — a few bright win-colored blooms for nightlife pop.
		for i in [1, 3, 5]:
			var sx := w * float(xs[i]) + w * 0.06
			var sy := horizon - horizon * float(hts[i]) - 4.0
			for k in 4:
				draw_circle(Vector2(sx, sy), 10.0 - k * 2.0, Color(win.r, win.g, win.b, 0.06))
			draw_circle(Vector2(sx, sy), 2.0, Color(win, 0.9))
		# Wet-street reflection band + vertical neon streaks (rain-slick asphalt).
		draw_rect(Rect2(0, horizon, w, h * 0.12), Color(glow.r, glow.g, glow.b, 0.08))
		for i in [1, 3, 5]:
			var rx := w * float(xs[i]) + w * 0.06
			draw_line(Vector2(rx, horizon), Vector2(rx, horizon + h * 0.09),
					Color(win.r, win.g, win.b, 0.14), 3.0)
		# Deco frame: thin double keyline + corner brackets.
		var m := 6.0
		var gold: Color = p["gold"]
		draw_rect(Rect2(m, m, w - 2 * m, h - 2 * m), Color(gold, 0.12), false, 1.0)
		var bl := 26.0
		for corner in [[m, m, 1.0, 1.0], [w - m, m, -1.0, 1.0], [m, h - m, 1.0, -1.0], [w - m, h - m, -1.0, -1.0]]:
			var cx: float = corner[0]
			var cy: float = corner[1]
			var sx: float = corner[2]
			var sy: float = corner[3]
			draw_line(Vector2(cx, cy), Vector2(cx + sx * bl, cy), Color(gold, 0.6), 2.0)
			draw_line(Vector2(cx, cy), Vector2(cx, cy + sy * bl), Color(gold, 0.6), 2.0)
			draw_line(Vector2(cx + sx * 5, cy + sy * 5), Vector2(cx + sx * (bl - 4), cy + sy * 5), Color(gold, 0.3), 1.0)


class _Bar extends Control:
	var p: Dictionary
	var frac := 0.5

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(p["muted"], 0.25))
		draw_rect(Rect2(0, 0, size.x * frac, size.y), p["jewel_b"])


class _CardBg extends Control:
	var p: Dictionary
	var accent := Color.WHITE
	var buyable := true

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Vertical gradient body — lit top edge into a darker base gives the row
		# depth a flat StyleBox can't. Buyable rows sit a shade warmer/brighter.
		var top: Color = p["card"].lerp(Color.WHITE, 0.05 if buyable else 0.02)
		var bot: Color = p["card"].lerp(p["bg"], 0.55)
		var steps := 14
		for i in steps:
			var t := float(i) / float(steps)
			draw_rect(Rect2(0, t * h, w, h / steps + 1.0), top.lerp(bot, t))
		# Left accent bar + faint accent wash for buyable rows.
		draw_rect(Rect2(0, 0, 3.0, h), Color(accent, 0.9 if buyable else 0.3))
		if buyable:
			draw_rect(Rect2(0, 0, w, h), Color(accent.r, accent.g, accent.b, 0.03))
		# Border + a brighter top highlight (the "lit" edge).
		draw_rect(Rect2(0, 0, w, h), Color(accent, 0.42 if buyable else 0.16), false, 1.0)
		draw_rect(Rect2(0, 0, w, 1.0), Color(accent, 0.20 if buyable else 0.07))


class _Medal extends Control:
	var p: Dictionary
	var initial := "C"
	var accent := Color.WHITE
	var count := 0
	var locked := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		var base: Color = p["muted"] if locked else accent
		# Filled disc: dark accent-tinted body, brighter toward center (fake glow),
		# so the emblem reads as a solid coin — not a thin wire ring.
		draw_circle(c, r, Color(p["bg"].r, p["bg"].g, p["bg"].b, 0.95))
		draw_circle(c, r - 1.0, Color(base.r, base.g, base.b, 0.16 if not locked else 0.06))
		draw_circle(c, r * 0.62, Color(base.r, base.g, base.b, 0.14 if not locked else 0.04))
		# Double deco ring.
		draw_arc(c, r, 0.0, TAU, 64, Color(base, 0.95 if not locked else 0.4), 2.5)
		draw_arc(c, r - 4.5, 0.0, TAU, 64, Color(base, 0.35 if not locked else 0.15), 1.0)
		# Initial — Cinzel, gold, centered.
		var f := GameFonts.heading()
		var fs := 26
		var tw := f.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, c - tw * 0.5 + Vector2(0, fs * 0.36), initial,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(p["gold_hi"] if not locked else p["muted"]))
		# Count badge — solid accent chip, dark number, clear of the ring.
		if not locked:
			var bc := c + Vector2(r * 0.72, r * 0.72)
			draw_circle(bc, 9.5, p["bg"])
			draw_circle(bc, 8.5, accent)
			var cf := GameFonts.mono(true)
			var cs := 11
			var cstr := str(count)
			var ctw := cf.get_string_size(cstr, HORIZONTAL_ALIGNMENT_LEFT, -1, cs)
			draw_string(cf, bc - ctw * 0.5 + Vector2(0, cs * 0.36), cstr,
					HORIZONTAL_ALIGNMENT_LEFT, -1, cs, p["bg"])
