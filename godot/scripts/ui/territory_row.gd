extends PanelContainer

signal action_pressed(index: int, action: String)

const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")

var territory_index: int = -1

@onready var _name: Label = $VBox/Top/NameLabel
@onready var _owner: Label = $VBox/Top/OwnerLabel
@onready var _desc: Label = $VBox/DescLabel
@onready var _perk: Label = $VBox/PerkLabel
@onready var _status: Label = $VBox/StatusLabel
@onready var _actions: HBoxContainer = $VBox/Actions
@onready var _attack: Button = $VBox/Actions/AttackBtn
@onready var _bribe: Button = $VBox/Actions/BribeBtn
@onready var _negotiate: Button = $VBox/Actions/NegotiateBtn
@onready var _sabotage: Button = $VBox/Actions/SabotageBtn


func setup(index: int) -> void:
	territory_index = index
	_refresh()


func _ready() -> void:
	_attack.pressed.connect(func(): action_pressed.emit(territory_index, "attack"))
	_bribe.pressed.connect(func(): action_pressed.emit(territory_index, "bribe"))
	_negotiate.pressed.connect(func(): action_pressed.emit(territory_index, "negotiate"))
	_sabotage.pressed.connect(func(): action_pressed.emit(territory_index, "sabotage"))
	GameState.stats_changed.connect(_refresh)


func _refresh() -> void:
	if territory_index < 0 or territory_index >= GameState.territories.size():
		return
	var t: Dictionary = GameState.territories[territory_index]
	_name.text = str(t.get("name", "?"))
	_desc.text = str(t.get("description", ""))
	var perk := str(t.get("perk", ""))
	_perk.text = perk
	_perk.visible = not perk.is_empty()
	var owner := str(t.get("owner", "unclaimed"))
	if owner == "player":
		_owner.text = "YOU"
		_owner.add_theme_color_override("font_color", GameTheme.GREEN)
	elif owner == "unclaimed":
		_owner.text = "UNCLAIMED"
		_owner.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	else:
		_owner.text = owner.substr(0, 14)
		_owner.add_theme_color_override("font_color", Color(0.86, 0.39, 0.31))
	var unlocked: bool = bool(t.get("unlocked", false))
	var can_act := _TerritorySystem.can_act_on(GameState, territory_index)
	if unlocked:
		var bonuses: PackedStringArray = []
		if float(t.get("income_bonus", 0.0)) > 0.0:
			bonuses.append("+%d%% income" % int(float(t["income_bonus"]) * 100.0))
		if float(t.get("click_bonus", 0.0)) > 0.0:
			bonuses.append("+%d%% clicks" % int(float(t["click_bonus"]) * 100.0))
		if float(t.get("heat_resistance", 0.0)) > 0.0:
			bonuses.append("-%d%% heat rise" % int(float(t["heat_resistance"]) * 100.0))
		_status.text = "  |  ".join(bonuses) if not bonuses.is_empty() else "Home turf"
		_status.add_theme_color_override("font_color", GameTheme.GREEN)
		_actions.visible = false
	elif owner != "player" and owner != "unclaimed":
		_status.text = "Held by %s — weaken them in Rivals first." % owner
		_status.add_theme_color_override("font_color", Color(0.86, 0.39, 0.31))
		_actions.visible = false
	else:
		var unlock_cost := int(t.get("unlock_cost", 0))
		if unlock_cost > 0:
			var cur := GameState.prestige_tokens
			var pct := int(minf(100.0, float(cur) / float(unlock_cost) * 100.0)) if unlock_cost > 0 else 100
			_status.text = "Requires %d Influence  (You: %d, %d%%)" % [unlock_cost, cur, pct]
		else:
			_status.text = "Accessible — use Attack, Bribe, Negotiate, or Sabotage"
		_status.add_theme_color_override(
			"font_color",
			GameTheme.GOLD if can_act else GameTheme.TEXT_MUTED
		)
		_actions.visible = can_act
	_set_action_labels(can_act and not unlocked)


func _set_action_labels(can_act: bool) -> void:
	if not can_act:
		return
	var ips: float = GameState.income_per_second()
	var bribe_cost: float = maxf(500.0, ips * 90.0)
	var sabotage_cost: float = maxf(200.0, ips * 30.0)
	var attack_lbl := "Attack"
	var negotiate_lbl := "Negotiate"
	var bribe_lbl := "Bribe\n%s" % FormatUtil.format_money(bribe_cost)
	var sabotage_lbl := "Sabotage\n%s" % FormatUtil.format_money(sabotage_cost)
	var can_bribe := GameState.balance >= bribe_cost
	var can_sabotage := GameState.balance >= sabotage_cost
	_bribe.disabled = not can_bribe
	_sabotage.disabled = not can_sabotage
	var best := _TerritorySystem.broker_best_action(GameState, territory_index)
	_style_broker_btn(_attack, "attack", best, attack_lbl)
	_style_broker_btn(_negotiate, "negotiate", best, negotiate_lbl)
	_style_broker_btn(_bribe, "bribe", best, bribe_lbl)
	_style_broker_btn(_sabotage, "sabotage", best, sabotage_lbl)


func _style_broker_btn(btn: Button, key: String, best: String, base_text: String) -> void:
	if key == best and not best.is_empty():
		btn.text = base_text + "\nBROKER"
		btn.add_theme_color_override("font_color", GameTheme.GREEN)
	else:
		btn.text = base_text
		btn.remove_theme_color_override("font_color")
