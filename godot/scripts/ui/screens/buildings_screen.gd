extends ScreenBase
## Buildings tab — row list with data-driven disclosure horizon (§6.2):
## owned/affordable rows in full, next silhouettes as "???" teasers, the rest
## hidden behind a count footer. Buy qty comes from the sheet-header control.

const BUILDING_ROW := preload("res://scenes/building_row.tscn")
const _TutorialSystem = preload("res://scripts/systems/tutorial_system.gd")

var stage: Node = null   # set by the shell for feedback-in-world flashes

var _list: VBoxContainer
var _rows: Array[Control] = []
var _sils: Array[Control] = []
var _sil_names: Array[Label] = []
var _sil_costs: Array[Label] = []
var _footer: Label
var _seg: SegmentedControl


func _ready() -> void:
	var parts := make_scroll_list()
	_list = parts[1]
	for i in GameState.buildings.size():
		var row: Control = BUILDING_ROW.instantiate()
		_list.add_child(row)
		row.setup(i)
		row.buy_pressed.connect(_on_buy)
		_rows.append(row)
		var sil := _make_silhouette(i)
		_list.add_child(sil)
		_sils.append(sil)
	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_footer.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	_list.add_child(_footer)
	refresh_slow()


func screen_title() -> String:
	return "FRONT BUSINESSES"


func header_control() -> Control:
	if _seg == null or not is_instance_valid(_seg):
		_seg = SegmentedControl.new()
		_seg.visible = true
	return _seg


func refresh_slow() -> void:
	var hidden := 0
	for i in _rows.size():
		var mode := Disclosure.building_mode(GameState, i)
		_rows[i].visible = mode == "shown"
		_sils[i].visible = mode == "silhouette"
		if mode == "silhouette":
			_sil_costs[i].text = "unlocks at " + FormatUtil.format_money(
				GameState.buildings[i].current_cost())
		elif mode == "hidden":
			hidden += 1
	_footer.visible = hidden > 0
	if hidden > 0:
		_footer.text = "%d more discovered as you grow" % hidden
	# Buy multiplier control is itself disclosure-gated (§6.2).
	if _seg != null and is_instance_valid(_seg):
		_seg.visible = Disclosure.buy_mult_visible(GameState)


func _make_silhouette(index: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 64)
	card.add_theme_stylebox_override("panel", Affordance.row_style(Affordance.LOCKED))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var name_l := Label.new()
	name_l.text = "???"
	name_l.add_theme_font_override("font", GameFonts.heading())
	name_l.add_theme_font_size_override("font_size", GameTheme.scaled_font(16))
	name_l.add_theme_color_override("font_color", Color(GameTheme.TEXT_MUTED, 0.6))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_l)
	var cost_l := Label.new()
	cost_l.add_theme_font_override("font", GameFonts.mono(false))
	cost_l.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	cost_l.add_theme_color_override("font_color", Color(GameTheme.TEXT_MUTED, 0.55))
	h.add_child(cost_l)
	_sil_names.append(name_l)
	_sil_costs.append(cost_l)
	card.visible = false
	return card


func _on_buy(index: int, qty: int) -> void:
	var before: int = GameState.total_buildings_owned()
	if not GameState.buy_building(index, qty):
		if index >= 0 and index < GameState.buildings.size():
			var b = GameState.buildings[index]
			GameState.notification.emit(
				"Need %s for %s ×%d" % [
					FormatUtil.format_money(b.cost_for_n(qty)), b.display_name, qty,
				],
				GameTheme.TEXT_MUTED,
			)
		return
	var ms := GameState.record_first_building_buy_ms()
	if ms >= 0:
		Telemetry.log_event("ui_first_building_buy_ms", {"ms": ms})
	if GameState.tutorial_step == 1 and GameState.total_buildings_owned() > before:
		_TutorialSystem.advance_tutorial(GameState)
	# Feedback in the world (rule 8) — the stage is the progress bar.
	if stage != null and stage.has_method("flash_building"):
		stage.flash_building(GameState.buildings[index].icon_key)
