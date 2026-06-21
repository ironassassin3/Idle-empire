class_name StatsDashboard
extends RefCounted
## Tiered stats tab — above-fold dashboard cards (Phase 126, Godot 1.0).

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _GoalSystem = preload("res://scripts/systems/goal_system.gd")
const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")
const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _AchievementSystem = preload("res://scripts/systems/achievement_system.gd")

static func rebuild(host: VBoxContainer, state) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()

	_add_card_grid(host, "SESSION", [
		{"label": "Balance", "value": FormatUtil.format_money(state.balance), "gold": true},
		{"label": "Income / sec", "value": FormatUtil.format_money(state.income_per_second()), "gold": false},
		{"label": "Click value", "value": FormatUtil.format_money(state.click_value()), "gold": false},
		{"label": "Prestige mult", "value": "%.2fx" % Prestige.income_mult(state.prestige_tokens), "gold": true},
	])

	var ach_mult: float = _AchievementSystem.income_mult(state.achievements)
	var respect_bonus: float = Prestige.respect_income_bonus(state.influence)
	_add_card_grid(host, "RESOURCES", [
		{"label": "Influence", "value": "%d" % state.prestige_tokens, "gold": true},
		{"label": "Respect", "value": "%d" % state.influence, "gold": true},
	])
	_add_muted_line(host, "Respect income bonus: +%.0f%% (caps +50%%)" % (respect_bonus * 100.0))
	_add_muted_line(host, "Achievement income bonus: +%.0f%%" % ((ach_mult - 1.0) * 100.0))

	_add_rank_section(host, state)
	_add_goals_section(host, state)

	var rob: Dictionary = _ManagerSystem.empire_efficiency_report(state)
	if not rob.is_empty():
		_add_rob_section(host, rob)

	_add_heat_section(host, state)
	_add_city_section(host, state)
	_add_lifetime_section(host, state)


static func _card_stylebox() -> StyleBox:
	return GameTheme.stat_card_style()


static func _section_header(parent: Control, title: String) -> void:
	var strip := PanelContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if GameTheme.is_rustic_active() or GameTheme.is_city_v2_active():
		strip.add_theme_stylebox_override("panel", GameTheme.list_section_header_style())
	var row := HBoxContainer.new()
	strip.add_child(row)
	var lbl := Label.new()
	lbl.text = title
	GameTheme.apply_list_section_title(lbl)
	row.add_child(lbl)
	parent.add_child(strip)


static func _add_muted_line(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if GameTheme.is_city_v2_active():
		lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	else:
		lbl.add_theme_color_override("font_color", GameTheme.GREEN)
	lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	parent.add_child(lbl)


static func _add_card_grid(parent: Control, section: String, cards: Array) -> void:
	_section_header(parent, section)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	for card in cards:
		grid.add_child(_make_stat_card(
			str(card.get("label", "")),
			str(card.get("value", "")),
			bool(card.get("gold", false)),
		))


static func _make_stat_card(label: String, value: String, gold: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _card_stylebox())
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	vbox.add_child(lbl)
	var val := Label.new()
	val.text = value
	val.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT if gold else GameTheme.TEXT)
	val.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	vbox.add_child(val)
	return panel


static func _add_rank_section(parent: Control, state) -> void:
	_section_header(parent, "RANK")
	var rank_lbl := Label.new()
	rank_lbl.text = state.rank_label()
	rank_lbl.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	rank_lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(16))
	parent.add_child(rank_lbl)

	var perks: Dictionary = Prestige.get_cumulative_rank_perks(state.prestige_tokens)
	var perk_parts: PackedStringArray = PackedStringArray()
	if perks.get("territory_success", 0.0) > 0.0:
		perk_parts.append("+%.0f%% turf" % (float(perks["territory_success"]) * 100.0))
	if perks.get("operation_reward", 0.0) > 0.0:
		perk_parts.append("+%.0f%% ops" % (float(perks["operation_reward"]) * 100.0))
	if perks.get("heat_decay", 0.0) > 0.0:
		perk_parts.append("+%.2f/s heat decay" % float(perks["heat_decay"]))
	if perks.get("income_bonus", 0.0) > 0.0:
		perk_parts.append("+%.0f%% income" % (float(perks["income_bonus"]) * 100.0))
	if not perk_parts.is_empty():
		_add_muted_line(parent, "  ·  ".join(perk_parts))

	var nri: Variant = Prestige.get_next_rank(state.prestige_tokens)
	if nri == null:
		return
	var nr_label: String = str(nri[0])
	var nr_thresh: int = int(nri[1])
	var cur_thresh: int = 0
	for entry in Prestige.HIERARCHY:
		if state.prestige_tokens >= int(entry[0]):
			cur_thresh = int(entry[0])
	var span: int = maxi(1, nr_thresh - cur_thresh)
	var pct: float = clampf(float(state.prestige_tokens - cur_thresh) / float(span), 0.0, 1.0)
	_add_muted_line(parent, "Next: %s  (%d / %d)" % [nr_label, state.prestige_tokens, nr_thresh])
	_add_bar(parent, pct, GameTheme.GOLD)


static func _add_goals_section(parent: Control, state) -> void:
	var goals: Array = _GoalSystem.current_goals(state, 3)
	if goals.is_empty():
		return
	_section_header(parent, "ACTIVE GOALS")
	for g in goals:
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var prog: Dictionary = _GoalSystem.progress_for(state, g)
		var target: float = maxf(1.0, float(prog.get("target", 1.0)))
		var cur: float = float(prog.get("current", 0.0))
		var pct: float = clampf(cur / target, 0.0, 1.0)
		var title: String = str(g.get("narrative", ""))
		if title.is_empty():
			title = str(g.get("label", "Goal"))
		_add_muted_line(parent, title)
		_add_bar(parent, pct, GameTheme.BLUE_BRIGHT)


static func _add_rob_section(parent: Control, rob: Dictionary) -> void:
	_section_header(parent, "ROB'S EMPIRE DASHBOARD")
	_add_muted_line(parent, "Where your money comes from")
	var shares: Dictionary = rob.get("shares", {})
	var strongest: Array = rob.get("strongest", [])
	var weakest: Array = rob.get("weakest", [])
	for key in ["buildings", "operations", "territory", "clicks"]:
		var lbl: String = str(rob.get("labels", {}).get(key, key.capitalize()))
		var pct: float = float(shares.get(key, 0.0))
		var col: Color = GameTheme.ACCENT
		if strongest.size() >= 2 and lbl == str(strongest[0]):
			col = GameTheme.GREEN
		elif weakest.size() >= 2 and lbl == str(weakest[0]):
			col = GameTheme.TEXT_MUTED
		_add_labeled_bar(parent, lbl, pct / 100.0, col, "%.0f%%" % pct)
	if strongest.size() >= 2 and weakest.size() >= 2:
		var sum := Label.new()
		sum.text = "Strongest: %s (%.0f%%)  ·  Weakest: %s (%.0f%%)" % [
			strongest[0], float(strongest[1]), weakest[0], float(weakest[1]),
		]
		sum.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sum.add_theme_color_override("font_color", GameTheme.GOLD)
		sum.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
		parent.add_child(sum)
	for rec in rob.get("recommendations", []):
		_add_muted_line(parent, "→ %s" % rec)


static func _add_heat_section(parent: Control, state) -> void:
	_section_header(parent, "HEAT")
	var heat: float = state.heat
	var heat_col: Color = GameTheme.GREEN
	if heat >= HeatSystem.RAID_THRESHOLD:
		heat_col = GameTheme.RED
	elif heat >= 45.0:
		heat_col = GameTheme.GOLD
	var big := Label.new()
	big.text = "%.0f%%" % heat
	big.add_theme_color_override("font_color", heat_col)
	big.add_theme_font_size_override("font_size", GameTheme.scaled_font(22))
	parent.add_child(big)
	_add_bar(parent, heat / 100.0, heat_col)
	if heat >= HeatSystem.RAID_THRESHOLD:
		var warn := Label.new()
		warn.text = "Raid risk — police can seize cash above %d%% heat" % int(HeatSystem.RAID_THRESHOLD)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_color_override("font_color", GameTheme.RED)
		warn.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
		parent.add_child(warn)
	else:
		_add_muted_line(parent, "Safe — raids begin at %d%%" % int(HeatSystem.RAID_THRESHOLD))
	var inc_bonus: float = HeatSystem.heat_income_mult(heat) - 1.0
	if inc_bonus > 0.001:
		_add_muted_line(parent, "High-heat income bonus: +%.0f%%" % (inc_bonus * 100.0))


static func _add_city_section(parent: Control, state) -> void:
	_section_header(parent, "CITY DOMINATION")
	var terr: int = _TerritorySystem.player_district_count(state.territories)
	var total_t: int = maxi(1, state.territories.size())
	var ctrl_pct: float = float(terr) / float(total_t)
	var ctrl_col: Color = GameTheme.GREEN if ctrl_pct >= 0.75 else (
		GameTheme.GOLD if ctrl_pct >= 0.5 else GameTheme.TEXT)
	var big := Label.new()
	big.text = "%d%%" % int(round(ctrl_pct * 100.0))
	big.add_theme_color_override("font_color", ctrl_col)
	big.add_theme_font_size_override("font_size", GameTheme.scaled_font(22))
	parent.add_child(big)
	_add_muted_line(parent, "%d / %d districts under your control" % [terr, total_t])
	_add_bar(parent, ctrl_pct, ctrl_col)
	var count_bonus: float = _TerritorySystem.territory_district_count_bonus(state.territories, state)
	var mile: float = _TerritorySystem.milestone_income_mult(state)
	var bonus_parts: PackedStringArray = PackedStringArray()
	if count_bonus > 0.0:
		bonus_parts.append("+%.0f%% district count" % (count_bonus * 100.0))
	if mile > 1.0:
		bonus_parts.append("+50%% city milestone")
	if not bonus_parts.is_empty():
		_add_muted_line(parent, "Territory income: " + ", ".join(bonus_parts))
	_add_muted_line(parent, "Peak control: %d%%  ·  Crew: %d / %d" % [
		int(round(state.highest_city_control * 100.0)),
		_CrewSystem.crew_total(state.crew),
		_CrewSystem.available(state),
	])


static func _add_lifetime_section(parent: Control, state) -> void:
	var play_secs: int = int(state.play_time)
	var ph: int = int(play_secs / 3600.0)
	var pm: int = int(play_secs % 3600 / 60.0)
	var time_str: String = "%dh %dm" % [ph, pm] if ph > 0 else "%dm" % pm
	var ach_earned: int = _AchievementSystem.earned_count(state.achievements)
	var ach_total: int = state.achievements.size()
	var terr: int = _TerritorySystem.player_district_count(state.territories)
	_add_card_grid(parent, "LIFETIME", [
		{"label": "Cash earned (run)", "value": FormatUtil.format_money(state.lifetime_earnings), "gold": true},
		{"label": "Peak income / sec", "value": FormatUtil.format_money(state.peak_income), "gold": false},
		{"label": "Highest cash held", "value": FormatUtil.format_money(state.highest_cash_held), "gold": true},
		{"label": "Play time", "value": time_str, "gold": false},
		{"label": "Buildings bought", "value": "%d" % state.total_buildings_purchased, "gold": false},
		{"label": "Districts captured", "value": "%d" % state.total_territories_captured, "gold": false},
		{"label": "Rivals defeated", "value": "%d" % state.total_rivals_defeated, "gold": false},
		{"label": "Ops completed", "value": "%d" % state.total_ops_completed, "gold": false},
		{"label": "Total clicks", "value": "%d" % state.click_count, "gold": false},
		{"label": "Prestiges (all time)", "value": "%d" % state.prestige_count, "gold": false},
		{"label": "Achievements", "value": "%d / %d" % [ach_earned, ach_total], "gold": true},
		{"label": "Heat generated", "value": "%.0f" % state.total_heat_generated, "gold": false},
	])


static func _add_bar(parent: Control, ratio: float, color: Color) -> void:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 100.0
	bar.value = ratio * 100.0
	bar.show_percentage = false
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := GameTheme.ink_progress_track_style() if GameTheme.is_city_v2_active() else StyleBoxFlat.new()
	if not GameTheme.is_city_v2_active():
		bg_style.bg_color = Color(0.1, 0.11, 0.18)
		bg_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg_style)
	parent.add_child(bar)


static func _add_labeled_bar(parent: Control, label: String, ratio: float, color: Color, right: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	row.add_child(lbl)
	var pct_lbl := Label.new()
	pct_lbl.text = right
	pct_lbl.add_theme_color_override("font_color", GameTheme.TEXT)
	pct_lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	row.add_child(pct_lbl)
	_add_bar(parent, ratio, color)
