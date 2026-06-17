extends PanelContainer

signal action_pressed(index: int, action: String)

const _RivalSystem = preload("res://scripts/systems/rival_system.gd")

var rival_index: int = -1

@onready var _name: Label = $VBox/Top/NameLabel
@onready var _badge: Label = $VBox/Top/BadgeLabel
@onready var _leader: Label = $VBox/LeaderLabel
@onready var _trait: Label = $VBox/TraitLabel
@onready var _stats: Label = $VBox/StatsLabel
@onready var _flavor: Label = $VBox/FlavorLabel
@onready var _actions: HBoxContainer = $VBox/Actions
@onready var _attack: Button = $VBox/Actions/AttackBtn
@onready var _bribe: Button = $VBox/Actions/BribeBtn
@onready var _negotiate: Button = $VBox/Actions/NegotiateBtn
@onready var _sabotage: Button = $VBox/Actions/SabotageBtn


func setup(index: int) -> void:
	rival_index = index
	_refresh()


func _ready() -> void:
	_attack.pressed.connect(func(): action_pressed.emit(rival_index, "attack"))
	_bribe.pressed.connect(func(): action_pressed.emit(rival_index, "bribe"))
	_negotiate.pressed.connect(func(): action_pressed.emit(rival_index, "negotiate"))
	_sabotage.pressed.connect(func(): action_pressed.emit(rival_index, "sabotage"))
	GameState.stats_changed.connect(_refresh)


func _refresh() -> void:
	if rival_index < 0 or rival_index >= GameState.rivals.size():
		return
	var r: Dictionary = GameState.rivals[rival_index]
	var symbol: String = str(r.get("symbol", ""))
	var status: String = str(r.get("status", "Active"))
	var eliminated: bool = status == "Eliminated"
	var at_war: bool = bool(r.get("at_war", false))
	_name.text = "%s %s" % [symbol, r.get("name", "?")] if not symbol.is_empty() else str(r.get("name", "?"))
	if eliminated:
		_badge.text = "ELIMINATED"
		_badge.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	elif at_war:
		_badge.text = "WAR"
		_badge.add_theme_color_override("font_color", GameTheme.RED)
	else:
		_badge.text = status
		_badge.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	var leader: String = str(r.get("leader_name", ""))
	var title: String = str(r.get("leader_title", ""))
	if not leader.is_empty() and not eliminated:
		_leader.text = "%s  \"%s\"" % [leader, title]
		_leader.visible = true
	else:
		_leader.visible = false
	var trait_text: String = str(r.get("trait", ""))
	_trait.text = trait_text
	_trait.visible = not trait_text.is_empty() and not eliminated
	_stats.text = "Turf: %d  ·  Wealth: %s  ·  Power: %d" % [
		int(r.get("turf", 0)),
		FormatUtil.format_money(float(r.get("wealth", 0.0))),
		int(r.get("power", 0)),
	]
	var key: String = str(r.get("faction_key", ""))
	if eliminated:
		_flavor.text = "[%s] %s" % [status, r.get("last_action", "")]
	else:
		_flavor.text = _RivalSystem.CARD_FLAVOR.get(key, str(r.get("last_action", "")))
	_actions.visible = not eliminated
	if not eliminated:
		_set_action_labels()


func _set_action_labels() -> void:
	var r: Dictionary = GameState.rivals[rival_index]
	var attack_pct: int = int(round(_RivalSystem.preview_success_chance(r, "attack", GameState) * 100.0))
	var attack_min: float = _RivalSystem.action_cost(GameState, "attack")
	var can_attack := _RivalSystem.can_afford_action(GameState, "attack")
	if can_attack:
		_attack.text = "Attack\n~%d%% win" % attack_pct
	else:
		_attack.text = "Needs\n%s" % FormatUtil.format_money(attack_min)
	_attack.disabled = not can_attack
	var bribe_cost: float = _RivalSystem.action_cost(GameState, "bribe")
	var sabotage_cost: float = _RivalSystem.action_cost(GameState, "sabotage")
	_bribe.text = "Bribe\n%s" % FormatUtil.format_money(bribe_cost)
	_sabotage.text = "Sabotage\n%s" % FormatUtil.format_money(sabotage_cost)
	_bribe.disabled = not _RivalSystem.can_afford_action(GameState, "bribe")
	_sabotage.disabled = not _RivalSystem.can_afford_action(GameState, "sabotage")
	_negotiate.disabled = GameState.heat < _RivalSystem.NEGOTIATE_HEAT_MIN
	if _negotiate.disabled:
		_negotiate.text = "Needs\n5 heat"
	else:
		_negotiate.text = "Negotiate"
