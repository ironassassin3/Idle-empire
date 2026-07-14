extends Control
## /godot-design — full main-screen redesign mock ("noir masthead" direction).
## Static visual mock: real tokens/fonts/icons, fake data. Not wired to game.

const ROW_DATA := [
	{"name": "Corner Dealer", "income": 4.2, "owned": 12, "cost": 186.0, "aff": GameTheme.RowAffordance.OWNED},
	{"name": "Protection Racket", "income": 28.0, "owned": 6, "cost": 1240.0, "aff": GameTheme.RowAffordance.BUYABLE},
	{"name": "Chop Shop", "income": 96.0, "owned": 3, "cost": 8900.0, "aff": GameTheme.RowAffordance.BUYABLE},
	{"name": "Sports Betting Ring", "income": 310.0, "owned": 1, "cost": 46500.0, "aff": GameTheme.RowAffordance.PETE},
	{"name": "Pawn Shop", "income": 0.0, "owned": 0, "cost": 128000.0, "aff": GameTheme.RowAffordance.BUYABLE},
	{"name": "Loan Shark", "income": 0.0, "owned": 0, "cost": 410000.0, "aff": GameTheme.RowAffordance.LOCKED},
	{"name": "Nightclub", "income": 0.0, "owned": 0, "cost": 1200000.0, "aff": GameTheme.RowAffordance.LOCKED},
	{"name": "Smuggling Ring", "income": 0.0, "owned": 0, "cost": 4800000.0, "aff": GameTheme.RowAffordance.LOCKED},
	{"name": "Underground Casino", "income": 0.0, "owned": 0, "cost": 22000000.0, "aff": GameTheme.RowAffordance.LOCKED},
	{"name": "Crypto Laundromat", "income": 0.0, "owned": 0, "cost": 95000000.0, "aff": GameTheme.RowAffordance.LOCKED},
]

const TABS := [
	["buildings", "Empire", true, 0],
	["trend-up", "Upgrades", false, 3],
	["users-three", "Managers", false, 0],
	["map-pin", "Turf", false, 1],
	["chart-bar", "Stats", false, 0],
]

var _fmt: Node


func _ready() -> void:
	_fmt = get_node("/root/FormatUtil")
	var bg := ColorRect.new()
	bg.color = GameTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	col.add_child(_masthead())
	col.add_child(_goal_strip())
	col.add_child(_section_header("FRONT BUSINESSES", "6 OF 11 UNLOCKED"))
	col.add_child(_rows_scroll())
	col.add_child(_tab_bar())


# ---------- masthead: skyline + rank + hero balance + heat ----------

func _masthead() -> Control:
	var head := PanelContainer.new()
	head.custom_minimum_size = Vector2(0, 236)
	var sky := SkylineBand.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	head.add_child(sky)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	head.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	margin.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	top.add_child(_rank_plate("CRIME LORD", "RANK VI"))
	var spring := Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spring)
	top.add_child(_heat_block(35.0))

	var midspring := Control.new()
	midspring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(midspring)

	var balance := Label.new()
	balance.text = _fmt.format_money(75320.0)
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance.add_theme_font_override("font", GameFonts.display())
	balance.add_theme_font_size_override("font_size", 54)
	balance.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	balance.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	balance.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(balance)

	var ips := Label.new()
	ips.text = "+ %s / SEC" % _fmt.format_money(1240.0)
	ips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ips.add_theme_font_override("font", GameFonts.mono(true))
	ips.add_theme_font_size_override("font_size", 15)
	ips.add_theme_color_override("font_color", GameTheme.GREEN)
	v.add_child(ips)

	var rule := GoldRule.new()
	rule.custom_minimum_size = Vector2(0, 14)
	v.add_child(rule)
	return head


func _rank_plate(rank: String, tier: String) -> Control:
	var plate := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.BG_PANEL, 0.82)
	sb.border_color = GameTheme.CHIP_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	plate.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	plate.add_child(v)
	var name_l := Label.new()
	name_l.text = rank
	name_l.add_theme_font_override("font", GameFonts.heading())
	name_l.add_theme_font_size_override("font_size", 15)
	name_l.add_theme_color_override("font_color", GameTheme.GOLD)
	v.add_child(name_l)
	var tier_l := Label.new()
	tier_l.text = tier + "  ·  DOWNTOWN"
	tier_l.add_theme_font_size_override("font_size", 10)
	tier_l.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	v.add_child(tier_l)
	return plate


func _heat_block(pct: float) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var lbl := Label.new()
	lbl.text = "HEAT %d%%" % int(pct)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_override("font", GameFonts.mono(true))
	lbl.add_theme_font_size_override("font_size", 12)
	var heat_col := GameTheme.TEXT_MUTED
	if pct >= 60.0:
		heat_col = GameTheme.RED
	elif pct >= 30.0:
		heat_col = GameTheme.GOLD
	lbl.add_theme_color_override("font_color", heat_col)
	v.add_child(lbl)
	var meter := HeatMeter.new()
	meter.pct = pct
	meter.custom_minimum_size = Vector2(132, 8)
	v.add_child(meter)
	return v


# ---------- goal strip ----------

func _goal_strip() -> Control:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", GameTheme.header_strip_style())
	var inset := MarginContainer.new()
	for side in ["left", "right"]:
		inset.add_theme_constant_override("margin_" + side, 14)
	strip.add_child(inset)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	inset.add_child(h)
	var kicker := Label.new()
	kicker.text = "NEXT"
	kicker.add_theme_font_override("font", GameFonts.heading())
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", GameTheme.GOLD)
	h.add_child(kicker)
	var goal := Label.new()
	goal.text = "Own 25 businesses to attract a Manager"
	goal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal.add_theme_font_size_override("font_size", 14)
	goal.add_theme_color_override("font_color", GameTheme.TEXT)
	goal.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(goal)
	var prog := Label.new()
	prog.text = "22/25"
	prog.add_theme_font_override("font", GameFonts.mono(true))
	prog.add_theme_font_size_override("font_size", 13)
	prog.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	h.add_child(prog)
	return strip


# ---------- section header ----------

func _section_header(title: String, meta: String) -> Control:
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", GameTheme.list_section_header_style())
	var inset := MarginContainer.new()
	for side in ["left", "right"]:
		inset.add_theme_constant_override("margin_" + side, 14)
	strip.add_child(inset)
	var h := HBoxContainer.new()
	inset.add_child(h)
	var t := Label.new()
	t.text = title
	GameTheme.apply_list_section_title(t)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var m := Label.new()
	m.text = meta
	m.add_theme_font_override("font", GameFonts.mono(false))
	m.add_theme_font_size_override("font_size", 11)
	m.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	h.add_child(m)
	return strip


# ---------- building rows ----------

func _rows_scroll() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_child(v)
	scroll.add_child(pad)
	for row in ROW_DATA:
		v.add_child(_building_card(row))
	return scroll


func _building_card(data: Dictionary) -> Control:
	var aff: int = data["aff"]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 92)
	card.add_theme_stylebox_override("panel", GameTheme.row_card_style(aff))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.add_child(h)
	card.add_child(pad)

	var locked := aff == GameTheme.RowAffordance.LOCKED
	var medal := Medallion.new()
	medal.count = data["owned"]
	medal.locked = locked
	medal.custom_minimum_size = Vector2(58, 58)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(medal)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_theme_constant_override("separation", 2)
	h.add_child(mid)
	var name_l := Label.new()
	name_l.text = data["name"] if not locked else "???"
	name_l.add_theme_font_override("font", GameFonts.heading())
	name_l.add_theme_font_size_override("font_size", 17)
	name_l.add_theme_color_override("font_color", GameTheme.TEXT_MUTED if locked else GameTheme.GOLD)
	mid.add_child(name_l)
	var income := Label.new()
	if locked:
		income.text = "Reach Enforcer rank to unlock"
		income.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		income.add_theme_font_size_override("font_size", 12)
	else:
		income.text = "%s / sec each" % _fmt.format_money(data["income"]) if data["income"] > 0.0 else "No income yet — buy the first"
		income.add_theme_font_override("font", GameFonts.mono(false))
		income.add_theme_font_size_override("font_size", 12)
		income.add_theme_color_override("font_color", GameTheme.GREEN if data["income"] > 0.0 else GameTheme.TEXT_MUTED)
	mid.add_child(income)
	if aff == GameTheme.RowAffordance.PETE:
		var pete := Label.new()
		pete.text = "★ PETE'S PICK — best value right now"
		pete.add_theme_font_size_override("font_size", 11)
		pete.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
		mid.add_child(pete)

	var right := VBoxContainer.new()
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 4)
	h.add_child(right)
	var cost := Label.new()
	cost.text = _fmt.format_money(data["cost"])
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.add_theme_font_override("font", GameFonts.mono(true))
	cost.add_theme_font_size_override("font_size", 15)
	cost.add_theme_color_override("font_color", GameTheme.TEXT_MUTED if locked else GameTheme.GOLD_BRIGHT)
	right.add_child(cost)
	var buy := Button.new()
	buy.text = "LOCKED" if locked else "BUY"
	buy.custom_minimum_size = Vector2(96, 44)
	buy.disabled = locked
	buy.add_theme_font_override("font", GameFonts.heading())
	buy.add_theme_font_size_override("font_size", 14)
	var plaque := StyleBoxFlat.new()
	plaque.set_corner_radius_all(3)
	if locked:
		plaque.bg_color = GameTheme.ROW_BG_LOCKED
		plaque.border_color = Color(GameTheme.CHIP_BORDER, 0.5)
		buy.add_theme_color_override("font_disabled_color", GameTheme.TEXT_MUTED)
	else:
		plaque.bg_color = GameTheme.ROW_BG_BUYABLE.lightened(0.04)
		plaque.border_color = GameTheme.GOLD
		buy.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	plaque.set_border_width_all(1)
	for state in ["normal", "hover", "pressed", "disabled"]:
		buy.add_theme_stylebox_override(state, plaque)
	right.add_child(buy)
	return card


# ---------- bottom tab bar ----------

func _tab_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", GameTheme.tab_bar_bg_style())
	bar.custom_minimum_size = Vector2(0, 70)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	bar.add_child(h)
	for tab in TABS:
		h.add_child(_tab_item(tab[0], tab[1], tab[2], tab[3]))
	return bar


func _tab_item(icon: String, label: String, active: bool, badge: int) -> Control:
	var slot := PanelContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_stylebox_override("panel", GameTheme.tab_strip_style(active))
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
	tex.modulate = GameTheme.GOLD_BRIGHT if active else GameTheme.TEXT_MUTED
	v.add_child(tex)
	var l := Label.new()
	l.text = GameTheme.tab_label_with_badge(label, badge)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", GameFonts.heading())
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", GameTheme.GOLD if active else GameTheme.TEXT_MUTED)
	v.add_child(l)
	return slot


# ---------- custom-drawn bits (code-built per ART_POLICY) ----------

class SkylineBand extends Control:
	func _draw() -> void:
		var s := size
		# Dusk gradient sky.
		var steps := 24
		for i in steps:
			var t := float(i) / steps
			var c := Color("241a2e").lerp(GameTheme.BG, t)
			draw_rect(Rect2(0, s.y * t, s.x, s.y / steps + 1.0), c)
		# Far skyline silhouettes.
		var seed_v := 7
		var x := -10.0
		while x < s.x:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			var bw := 34.0 + float(seed_v % 40)
			var bh := 40.0 + float((seed_v >> 8) % 90)
			draw_rect(Rect2(x, s.y - bh, bw, bh), Color("0d0a12"))
			# Lit windows — sparse gold specks.
			var wx := x + 6.0
			while wx < x + bw - 6.0:
				seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
				if seed_v % 5 == 0:
					var wy := s.y - bh + 8.0 + float(seed_v % int(maxf(bh - 20.0, 1.0)))
					draw_rect(Rect2(wx, wy, 3, 4), Color(GameTheme.GOLD, 0.55))
				wx += 9.0
			x += bw + 6.0
		# Bottom fade into panel bg.
		for i in 12:
			var t2 := float(i) / 12.0
			draw_rect(Rect2(0, s.y - 24 + t2 * 24.0, s.x, 3.0), Color(GameTheme.BG, t2 * 0.9))


class GoldRule extends Control:
	func _draw() -> void:
		var mid := size.y * 0.5
		var cx := size.x * 0.5
		draw_line(Vector2(24, mid), Vector2(cx - 14, mid), Color(GameTheme.GOLD, 0.5), 1.0)
		draw_line(Vector2(cx + 14, mid), Vector2(size.x - 24, mid), Color(GameTheme.GOLD, 0.5), 1.0)
		# Center diamond.
		var pts := PackedVector2Array([
			Vector2(cx, mid - 4), Vector2(cx + 5, mid), Vector2(cx, mid + 4), Vector2(cx - 5, mid),
		])
		draw_colored_polygon(pts, GameTheme.GOLD)


class HeatMeter extends Control:
	var pct := 0.0
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("241a20"))
		draw_rect(r, Color(GameTheme.CHIP_BORDER, 0.7), false, 1.0)
		var fill_w := size.x * clampf(pct / 100.0, 0.0, 1.0)
		if fill_w > 1.0:
			var hot := Color("6a3a2a").lerp(GameTheme.RED, pct / 100.0)
			draw_rect(Rect2(1, 1, fill_w - 2, size.y - 2), hot)
		# Raid threshold tick at 60%.
		var tick_x := size.x * 0.6
		draw_line(Vector2(tick_x, -2), Vector2(tick_x, size.y + 2), Color(GameTheme.RED, 0.9), 1.0)


class Medallion extends Control:
	var count := 0
	var locked := false
	func _draw() -> void:
		var c := size * 0.5
		var radius := minf(size.x, size.y) * 0.5 - 2.0
		var ring := GameTheme.CHIP_BORDER if locked else GameTheme.GOLD
		draw_circle(c, radius, Color("100c16"))
		draw_arc(c, radius, 0, TAU, 48, Color(ring, 0.9), 1.5)
		draw_arc(c, radius - 3.5, 0, TAU, 48, Color(ring, 0.35), 1.0)
		var font := GameFonts.mono(true)
		var txt := "—" if locked else str(count)
		var fs := 20 if len(txt) < 3 else 15
		var tsize := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var col := GameTheme.TEXT_MUTED if locked or count == 0 else GameTheme.GOLD_BRIGHT
		draw_string(font, Vector2(c.x - tsize.x * 0.5, c.y + tsize.y * 0.30), txt,
			HORIZONTAL_ALIGNMENT_CENTER, -1, fs, col)
