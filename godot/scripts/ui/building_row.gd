extends PanelContainer

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")

signal buy_pressed(index: int, qty: int)

var building_index: int = -1
var _building: Building
var _affordance: int = GameTheme.RowAffordance.LOCKED

@onready var _medal: CountMedallion = $Margin/HBox/Medal
@onready var _name: Label = $Margin/HBox/Info/NameLabel
@onready var _desc: Label = $Margin/HBox/Info/DescLabel
@onready var _special: Label = $Margin/HBox/Info/SpecialLabel
@onready var _owned: Label = $Margin/HBox/Info/OwnedLabel
@onready var _income: Label = $Margin/HBox/Info/IncomeLabel
@onready var _buy1: Button = $Margin/HBox/Buy1
@onready var _buy10: Button = $Margin/HBox/Buy10
@onready var _buy_max: Button = $Margin/HBox/BuyMax


func setup(index: int) -> void:
	building_index = index
	_building = GameState.buildings[index]
	_desc.text = _building.description
	_medal.initial = _building.display_name.left(1)
	_medal.hue_index = index
	_medal.signature_key = _building.icon_key
	_apply_special_line()
	_refresh()


func _ready() -> void:
	set_process(false)  # armed only while a wipe runs
	for btn in [_buy1, _buy10, _buy_max]:
		GameTheme.apply_row_buy_button(btn)
	# Genre convention (AdCap): ONE fat buy button per row; quantity comes
	# from the global ×1/×10/Max chip in the masthead.
	_buy10.visible = false
	_buy_max.visible = false
	_buy1.custom_minimum_size = Vector2(118, 56)
	_buy1.add_theme_font_override("font", GameFonts.heading())
	_buy1.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	_apply_label_scale()
	_buy1.pressed.connect(_on_buy_primary)
	_buy10.pressed.connect(func(): buy_pressed.emit(building_index, 10))
	_buy_max.pressed.connect(_on_buy_max)
	GameState.stats_changed.connect(_refresh)
	var events: Node = get_node_or_null("/root/UiEvents")
	if events != null:
		events.building_purchased.connect(_on_any_purchase)
	if building_index >= 0:
		_refresh()


## Same beat as the city facade: this row's medallion acknowledges the purchase.
## NEW: the spend arcs as coins from the ledger down INTO this business —
## direction matters, a purchase is a spend (the masthead dips; ADR-001).
## The medallion flare below is the coins' landing beat.
func _on_any_purchase(key: String) -> void:
	if _building == null or str(_building.icon_key) != key:
		return
	# Arc only when this row is actually on screen: manager purchase orders
	# fire while the row may be scrolled away or on a hidden tab. State-only
	# under headless (probe-able); FxLayer gates reduced-motion itself.
	if is_visible_in_tree() and get_global_rect().intersects(get_viewport_rect()):
		var fx: Node = get_tree().get_first_node_in_group("fx_layer")
		if fx != null:
			var n: int = clampi(GameState.buy_mult_mode + 1, 1, 3)  # x1/x10/Max -> 1/2/3 coins
			fx.call("coin_arc", fx.call("ledger_point"),
					_medal.get_global_rect().get_center(), n)
	if DisplayServer.get_name() == "headless" or GameTheme.ui_reduced_motion():
		return
	var tw := create_tween()
	tw.tween_property(_medal, "modulate", GameTheme.GOLD_BRIGHT, 0.12)
	tw.tween_property(_medal, "modulate", Color.WHITE, 0.45).set_ease(Tween.EASE_OUT)


func _apply_label_scale() -> void:
	GameTheme.apply_row_title(_name, 16)
	_desc.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_special.add_theme_font_size_override("font_size", GameTheme.scaled_font(10))
	_owned.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_income.add_theme_font_override("font", GameFonts.mono(false))
	_income.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	_income.add_theme_color_override("font_color", GameTheme.GREEN)


func _apply_special_line() -> void:
	if _building == null or _building.special.is_empty():
		_special.visible = false
		_special.text = ""
		return
	_special.visible = true
	_special.text = "* %s" % _building.special


# Rule 10 (Stage & Ledger): progress-to-afford underbar while APPROACHING.
var _afford := 0.0

## Unlock ink-wipe: normalized progress, -1 = idle. Starts ONLY on a genuine
## false->true affordability transition during play — never on row
## instantiation (rows are rebuilt on every tab entry).
var _wipe := -1.0
var _prev_ready := false
var _ready_init := false
const _WIPE_TIME := 0.35


func _process(delta: float) -> void:
	if _wipe < 0.0:
		set_process(false)
		return
	_wipe = minf(_wipe + delta / _WIPE_TIME, 1.0)
	queue_redraw()
	if _wipe >= 1.0:
		_wipe = -1.0


func is_unlock_wiping() -> bool:
	return _wipe >= 0.0


## Study `_CardBg`: a code-drawn vertical-gradient body + left accent bar, giving
## the row depth a flat StyleBox can't. Drawn FIRST (behind wax seal / underbar /
## ink-wipe). Opaque — it overpaints the panel stylebox; corners read square,
## matching the mock. Accent = the business signature color (same as the medallion).
func _draw_card_gradient() -> void:
	var w := size.x
	var h := size.y
	var buyable := _affordance != GameTheme.RowAffordance.LOCKED
	var accent := GameTheme.building_neon(_building.icon_key) if _building != null else GameTheme.GOLD
	var top := GameTheme.BG_CARD.lerp(Color.WHITE, 0.05 if buyable else 0.02)
	var bot := GameTheme.BG_CARD.lerp(GameTheme.BG, 0.55)
	var steps := 14
	for i in steps:
		var t := float(i) / float(steps)
		draw_rect(Rect2(0, t * h, w, h / steps + 1.0), top.lerp(bot, t))
	draw_rect(Rect2(0, 0, 3.0, h), Color(accent, 0.9 if buyable else 0.3))
	if buyable:
		draw_rect(Rect2(0, 0, w, h), Color(accent.r, accent.g, accent.b, 0.03))
	draw_rect(Rect2(0, 0, w, h), Color(accent, 0.42 if buyable else 0.16), false, 1.0)
	draw_rect(Rect2(0, 0, w, 1.0), Color(accent, 0.20 if buyable else 0.07))


func _draw() -> void:
	if _building != null:
		_draw_card_gradient()
	GameTheme.draw_row_wax_seal(self, _affordance)
	if _afford > 0.0 and _afford < 1.0:
		draw_rect(Rect2(0, size.y - 3.0, size.x, 3.0), Color(GameTheme.GOLD, 0.14))
		draw_rect(Rect2(0, size.y - 3.0, size.x * _afford, 3.0), GameTheme.GOLD)
	if _wipe >= 0.0 and _wipe < 1.0:
		# Left -> right gold ink-wipe: faint fill behind a bright leading edge,
		# both fading as the wipe completes (same drawn-state idiom as the
		# afford underbar above).
		var lead_x := size.x * _wipe
		draw_rect(Rect2(0.0, 0.0, lead_x, size.y),
				Color(GameTheme.GOLD.r, GameTheme.GOLD.g, GameTheme.GOLD.b, 0.08 * (1.0 - _wipe)))
		draw_rect(Rect2(lead_x - 6.0, 0.0, 6.0, size.y),
				Color(GameTheme.GOLD_BRIGHT.r, GameTheme.GOLD_BRIGHT.g, GameTheme.GOLD_BRIGHT.b,
						0.35 * (1.0 - _wipe * 0.5)))


func _refresh() -> void:
	if building_index < 0 or building_index >= GameState.buildings.size():
		return
	_building = GameState.buildings[building_index]
	# Supremacy N8 veteran density: compact rows keep name + cost + underbar
	# only; touch targets stay at the 48px floor.
	if GameConfig.UI_SHELL_V3:
		var compact: bool = GameState.ui_compact_rows
		_desc.visible = not compact
		_special.visible = not compact and not _building.special.is_empty()
		_income.visible = not compact
		_owned.visible = not compact
		custom_minimum_size.y = 64.0 if compact else 0.0
		_buy1.custom_minimum_size = Vector2(118, 48 if compact else 56)
	var advisor_idx := _ManagerSystem.building_advisor_index(GameState)
	var is_advised := advisor_idx == building_index
	var prefix := _ManagerSystem.building_advisor_prefix(GameState, building_index)
	if is_advised and not prefix.is_empty():
		_name.text = "%s%s" % [prefix, _building.display_name]
	else:
		_name.text = _building.display_name
	_apply_special_line()
	var dim := _building.owned <= 0
	_special.add_theme_color_override(
		"font_color",
		GameTheme.BLUE_BRIGHT if not dim else GameTheme.TEXT_MUTED
	)
	_owned.text = "Owned: %d" % _building.owned
	_income.text = "%s/s" % FormatUtil.format_money(_building.income_per_second())
	var qty := GameState.effective_buy_qty(building_index)
	var cost_qty := _building.cost_for_n(qty)
	_buy1.text = "BUY %s\n%s" % [GameState.buy_mult_label(), FormatUtil.format_money(cost_qty)]
	_buy10.text = "×10\n%s" % FormatUtil.format_money(_building.cost_for_n(10))
	var max_n := GameState.max_affordable_building(building_index)
	_buy_max.text = "Max (%d)" % max_n if max_n > 0 else "Max"
	var can_primary := GameState.can_buy_building(building_index, qty)
	if not _ready_init:
		_ready_init = true
		_prev_ready = can_primary
	elif can_primary and not _prev_ready:
		_prev_ready = true
		if not GameTheme.ui_reduced_motion():
			_wipe = 0.0
			set_process(true)
	elif not can_primary:
		_prev_ready = false
	_buy1.disabled = not can_primary
	_buy10.disabled = not GameState.can_buy_building(building_index, 10)
	_buy_max.disabled = max_n <= 0
	var can_any := GameState.can_buy_building(building_index, 1)
	if is_advised and can_any:
		_affordance = GameTheme.RowAffordance.PETE
	elif can_any:
		_affordance = GameTheme.RowAffordance.BUYABLE
	else:
		_affordance = GameTheme.RowAffordance.LOCKED
	_medal.count = _building.owned
	_medal.locked = _affordance == GameTheme.RowAffordance.LOCKED and _building.owned <= 0
	GameTheme.apply_row_affordance(self, _affordance)
	if GameConfig.UI_SHELL_V3:
		Affordance.apply_action_button(
			_buy1, Affordance.READY if can_primary else Affordance.APPROACHING)
		_afford = 0.0 if can_primary else Affordance.progress(cost_qty, GameState.balance)
		queue_redraw()
	modulate = Color.WHITE


func _on_buy_primary() -> void:
	var fx: Node = get_tree().get_first_node_in_group("fx_layer")
	if fx != null:
		fx.call("ripple", _buy1.get_global_rect().get_center())
	var qty := GameState.effective_buy_qty(building_index)
	if qty > 0:
		buy_pressed.emit(building_index, qty)


func _on_buy_max() -> void:
	var n := GameState.max_affordable_building(building_index)
	if n > 0:
		buy_pressed.emit(building_index, n)
