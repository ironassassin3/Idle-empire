extends ScreenBase
## Buildings tab — row list with data-driven disclosure horizon (§6.2):
## owned/affordable rows in full, next silhouettes as "???" teasers, the rest
## hidden behind a count footer. Buy qty comes from the sheet-header control.

const BUILDING_ROW := preload("res://scenes/building_row.tscn")
const _TutorialSystem = preload("res://scripts/systems/tutorial_system.gd")
const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")

var stage: Node = null   # set by the shell for feedback-in-world flashes

var _list: VBoxContainer
var _rows: Array[Control] = []
var _sils: Array[Control] = []
var _sil_names: Array[Label] = []
var _sil_costs: Array[Label] = []
var _footer: Label
var _header: HBoxContainer
var _approve: Button
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

	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 6)
	_approve = Button.new()
	_approve.visible = false
	_approve.custom_minimum_size = Vector2(108, 48)
	_approve.pressed.connect(_on_approve_order)
	_header.add_child(_approve)
	_seg = SegmentedControl.new()
	_header.add_child(_seg)

	GameState.stats_changed.connect(_refresh_header)
	refresh_slow()


func screen_title() -> String:
	return "FRONT BUSINESSES"


func header_control() -> Control:
	return _header


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
	_refresh_header()


func _refresh_header() -> void:
	var order := _ManagerSystem.pending_manager_order(GameState)
	if order.is_empty():
		_approve.visible = false
	else:
		_approve.visible = true
		var qty: int = maxi(1, int(order.get("qty", 1)))
		var qty_txt := "" if qty <= 1 else " ×%d" % qty
		var cost_str := FormatUtil.format_money(float(order.get("cost", 0.0)))
		_approve.text = "APPROVE\n%s%s · %s" % [order.get("building_name", ""), qty_txt, cost_str]
		_fit_approve_width()
		var can: bool = bool(order.get("can_approve", false))
		_approve.disabled = not can
		if GameConfig.UI_SHELL_V3:
			Affordance.apply_action_button(
				_approve, Affordance.READY if can else Affordance.APPROACHING)
	if _seg != null and is_instance_valid(_seg):
		_seg.visible = Disclosure.buy_mult_visible(GameState)


## A Button derives its minimum width from a single text run, so the second line of
## "APPROVE\n<building> · <cost>" isn't counted and the price clipped mid-number on
## device. Measure the widest line ourselves; the cost is the point of the chip.
func _fit_approve_width() -> void:
	var font := GameFonts.heading()
	var px := GameTheme.scaled_font(13)
	var widest := 0.0
	for line in _approve.text.split("\n"):
		widest = maxf(widest, font.get_string_size(
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x)
	_approve.custom_minimum_size.x = ceilf(widest) + 20.0


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


func _on_approve_order() -> void:
	var order := _ManagerSystem.pending_manager_order(GameState)
	if order.is_empty():
		return
	var idx: int = int(order.get("index", -1))
	var before: int = GameState.total_buildings_owned()
	if not GameState.approve_manager_order():
		if idx >= 0 and idx < GameState.buildings.size():
			var b = GameState.buildings[idx]
			var qty: int = maxi(1, int(order.get("qty", 1)))
			GameState.notification.emit(
				"Need %s for %s ×%d" % [
					FormatUtil.format_money(b.cost_for_n(qty)), b.display_name, qty,
				],
				GameTheme.TEXT_MUTED,
			)
		return
	_finish_building_buy(idx, before)


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
	_finish_building_buy(index, before)


func _finish_building_buy(index: int, before: int) -> void:
	var ms := GameState.record_first_building_buy_ms()
	if ms >= 0:
		Telemetry.log_event("ui_first_building_buy_ms", {"ms": ms})
	if GameState.tutorial_step == 1 and GameState.total_buildings_owned() > before:
		_TutorialSystem.advance_tutorial(GameState)
	UiEvents.building_purchased.emit(GameState.buildings[index].icon_key)
