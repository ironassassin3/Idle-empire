extends Control

const BUILDING_ROW := preload("res://scenes/building_row.tscn")

@onready var _balance: Label = $Root/Header/Balance
@onready var _ips: Label = $Root/Header/Income
@onready var _rank: Label = $Root/Header/Rank
@onready var _hustle: Button = $Root/Body/Left/HustleBtn
@onready var _click_info: Label = $Root/Body/Left/ClickInfo
@onready var _prestige_btn: Button = $Root/Body/Left/PrestigeBtn
@onready var _prestige_info: Label = $Root/Body/Left/PrestigeInfo
@onready var _list: VBoxContainer = $Root/Body/Right/Scroll/List
@onready var _notif: Label = $Root/Notif
@onready var _menu_btn: Button = $Root/Header/MenuBtn

var _notif_timer: float = 0.0


func _ready() -> void:
	_apply_theme()
	for i in GameState.buildings.size():
		var row: Control = BUILDING_ROW.instantiate()
		_list.add_child(row)
		row.setup(i)
		row.buy_pressed.connect(_on_buy)
	GameState.stats_changed.connect(_refresh_all)
	GameState.notification.connect(_on_notification)
	_hustle.pressed.connect(_on_hustle)
	_prestige_btn.pressed.connect(_on_prestige)
	_menu_btn.pressed.connect(_on_menu)
	_refresh_all()


func _process(delta: float) -> void:
	if _notif_timer > 0.0:
		_notif_timer -= delta
		if _notif_timer <= 0.0:
			_notif.text = ""


func _apply_theme() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = GameTheme.BG
	add_theme_stylebox_override("panel", panel)


func _refresh_all() -> void:
	_balance.text = FormatUtil.format_money(GameState.balance)
	_ips.text = "%s/s passive" % FormatUtil.format_money(GameState.income_per_second())
	_rank.text = "%s  ·  %d Influence" % [GameState.rank_label(), GameState.prestige_tokens]
	_click_info.text = "Click: %s  (+%s from dealers)" % [
		FormatUtil.format_money(GameState.click_value()),
		FormatUtil.format_money(BuildingDefs.dealer_click_bonus(GameState.buildings)),
	]
	var can := GameState.can_prestige()
	_prestige_btn.disabled = not can
	var req := Prestige.prestige_earnings_required(GameState.prestige_count, GameState.next_prestige_earnings)
	_prestige_info.text = "Prestige: %s / %s lifetime" % [
		FormatUtil.format_money(GameState.lifetime_earnings),
		FormatUtil.format_money(req),
	]


func _on_hustle() -> void:
	GameState.do_click()


func _on_buy(index: int, qty: int) -> void:
	GameState.buy_building(index, qty)


func _on_prestige() -> void:
	GameState.do_prestige()


func _on_menu() -> void:
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_notification(message: String, _color: Color) -> void:
	_notif.text = message
	_notif_timer = 2.5
