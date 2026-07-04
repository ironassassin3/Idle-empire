extends ScreenBase
## Stats tab → "Empire Report" (§8, kills D9). Three player-facing sections:
## Tonight's numbers · The street · Career. The attention rail's archive
## (raid/goal/rival log) lives here.

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
const _RivalSystem = preload("res://scripts/systems/rival_system.gd")
const _AchievementSystem = preload("res://scripts/systems/achievement_system.gd")

var director: Node = null   # AttentionDirector, set by shell (log source)

var _box: VBoxContainer
var _ach_panel: VBoxContainer
var _ach_list: Label
var _ach_open := false
var _refresh_left := 0.0


func _ready() -> void:
	var parts := make_scroll_list()
	_box = parts[1]
	_box.add_theme_constant_override("separation", 10)


func screen_title() -> String:
	return "EMPIRE REPORT"


func on_show() -> void:
	_rebuild()


func refresh_slow() -> void:
	_refresh_left -= 0.1
	if _refresh_left <= 0.0:
		_refresh_left = 1.0
		_rebuild()


func _rebuild() -> void:
	var ach_was_open := _ach_open
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()

	# --- Tonight's numbers -------------------------------------------------
	_section("TONIGHT'S NUMBERS")
	var ach_mult: float = _AchievementSystem.income_mult(GameState.achievements)
	_tiles([
		["Prestige mult", "%.2f×" % Prestige.income_mult(GameState.prestige_tokens), true],
		["Click value", FormatUtil.format_money(GameState.click_value()), false],
		["Influence", str(GameState.prestige_tokens), true],
		["Respect", str(GameState.influence), false],
		["Achievement bonus", "+%.0f%%" % ((ach_mult - 1.0) * 100.0), false],
		["Districts", str(_TerritorySystem.player_district_count(GameState.territories)), false],
	])
	var adv: Dictionary = _ManagerSystem.prestige_advice(GameState)
	if not adv.is_empty():
		_muted("%s — %s" % [adv.get("source", "Advisor"), adv.get("recommend", "")])

	# --- The street ----------------------------------------------------------
	_section("THE STREET")
	var impact: Dictionary = _RivalSystem.get_empire_impact(GameState)
	_tiles([
		["Heat", "%.0f%%" % GameState.heat, GameState.heat >= 60.0],
		["Rival power", str(int(impact.get("total_power", 0))), false],
		["Rivals defeated", str(GameState.total_rivals_defeated), false],
		["Ops completed", str(GameState.total_ops_completed), false],
	])
	var log_lines: PackedStringArray = PackedStringArray()
	if director != null:
		var log: Array = director.event_log
		for i in range(log.size() - 1, maxi(-1, log.size() - 9), -1):
			var e: Dictionary = log[i]
			log_lines.append("%s  %s" % [e.get("at", ""), e.get("text", "")])
	if log_lines.is_empty():
		log_lines.append("Quiet night. The city sleeps; your ledger doesn't.")
	_muted("TONIGHT'S WIRE\n" + "\n".join(log_lines))

	# --- Career --------------------------------------------------------------
	_section("CAREER")
	_tiles([
		["Rank", GameState.rank_label(), true],
		["Lifetime earnings", FormatUtil.format_money(GameState.lifetime_earnings), true],
		["Prestiges", str(GameState.prestige_count), false],
		["Businesses", str(GameState.total_buildings_owned()), false],
	])
	_build_achievements(ach_was_open)


func _section(title: String) -> void:
	var strip := PanelContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", GameTheme.list_section_header_style())
	var lbl := Label.new()
	lbl.text = title
	GameTheme.apply_list_section_title(lbl)
	strip.add_child(lbl)
	_box.add_child(strip)


func _tiles(rows: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_box.add_child(grid)
	for r in rows:
		var tile := PanelContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel", GameTheme.ink_stat_card_style())
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		tile.add_child(v)
		var name_l := Label.new()
		name_l.text = str(r[0]).to_upper()
		name_l.add_theme_font_override("font", GameFonts.heading())
		name_l.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
		name_l.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		v.add_child(name_l)
		var val_l := Label.new()
		val_l.text = str(r[1])
		val_l.add_theme_font_override("font", GameFonts.mono(true))
		val_l.add_theme_font_size_override("font_size", GameTheme.scaled_font(15))
		val_l.add_theme_color_override(
			"font_color", GameTheme.GOLD_BRIGHT if bool(r[2]) else GameTheme.TEXT)
		v.add_child(val_l)
		grid.add_child(tile)


func _muted(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_box.add_child(lbl)


func _build_achievements(open: bool) -> void:
	var earned: int = _AchievementSystem.earned_count(GameState.achievements)
	var total: int = GameState.achievements.size()
	var mult: float = _AchievementSystem.income_mult(GameState.achievements)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	btn.text = "★ Achievements  %d / %d  ·  +%.0f%% income" % [
		earned, total, (mult - 1.0) * 100.0,
	]
	GameTheme.apply_ink_chip_button(btn, false, GameTheme.FONT_CHIP, GameTheme.GOLD_BRIGHT)
	btn.pressed.connect(_toggle_achievements)
	_box.add_child(btn)

	_ach_panel = VBoxContainer.new()
	_ach_panel.add_theme_constant_override("separation", 6)
	_ach_panel.visible = open
	_ach_open = open
	_box.add_child(_ach_panel)
	_ach_list = Label.new()
	_ach_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ach_list.add_theme_color_override("font_color", GameTheme.TEXT)
	_ach_list.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_ach_panel.add_child(_ach_list)
	if open:
		_fill_achievements()


func _toggle_achievements() -> void:
	_ach_open = not _ach_open
	_ach_panel.visible = _ach_open
	if _ach_open:
		_fill_achievements()


func _fill_achievements() -> void:
	var lines: PackedStringArray = PackedStringArray()
	var cat_order: PackedStringArray = PackedStringArray([
		"money", "clicks", "building", "prestige", "manager",
		"time", "territory", "rival", "operations", "secret",
	])
	var by_cat: Dictionary = {}
	for a in GameState.achievements:
		var cat: String = str(a.get("category", "other"))
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(a)
	for cat in cat_order:
		if not by_cat.has(cat):
			continue
		lines.append(cat.to_upper())
		for a in by_cat[cat]:
			var mark: String = "✓" if bool(a.get("earned", false)) else "○"
			lines.append("  %s  %s — %s" % [mark, a.get("name", ""), a.get("description", "")])
		lines.append("")
	_ach_list.text = "\n".join(lines)
