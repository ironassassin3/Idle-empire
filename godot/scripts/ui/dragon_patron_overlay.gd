extends CanvasLayer
## Dragon Patron selection — port of DragonPatronState.

const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _stage: Label = $Panel/Margin/VBox/StageLabel
@onready var _prompt: Label = $Panel/Margin/VBox/PromptLabel
@onready var _cards: HBoxContainer = $Panel/Margin/VBox/CardRow
@onready var _locked: Label = $Panel/Margin/VBox/LockedLabel
@onready var _back: Button = $Panel/Margin/VBox/BackBtn
@onready var _confirm: PanelContainer = $ConfirmDialog
@onready var _confirm_title: Label = $ConfirmDialog/Margin/VBox/Title
@onready var _confirm_body: Label = $ConfirmDialog/Margin/VBox/Body
@onready var _confirm_yes: Button = $ConfirmDialog/Margin/VBox/Row/YesBtn
@onready var _confirm_no: Button = $ConfirmDialog/Margin/VBox/Row/NoBtn

var _pending_key: String = ""
var _card_buttons: Dictionary = {}


func _ready() -> void:
	layer = 11
	visible = false
	_build_cards()
	_back.pressed.connect(close)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_on_confirm_no)
	GameState.stats_changed.connect(_refresh)


func open() -> void:
	visible = true
	_pending_key = ""
	_confirm.visible = false
	_refresh()


func close() -> void:
	visible = false
	_pending_key = ""
	_confirm.visible = false


func _build_cards() -> void:
	for child in _cards.get_children():
		child.queue_free()
	_card_buttons.clear()
	for key in _DragonSystem.DRAGON_ORDER:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(200, 280)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)
		var title := Label.new()
		title.name = "Title"
		vbox.add_child(title)
		var tag := Label.new()
		tag.name = "Tag"
		tag.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		tag.add_theme_font_size_override("font_size", 11)
		vbox.add_child(tag)
		var body := Label.new()
		body.name = "Body"
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 11)
		body.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		vbox.add_child(body)
		var strengths := Label.new()
		strengths.name = "Strengths"
		strengths.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		strengths.add_theme_font_size_override("font_size", 10)
		strengths.add_theme_color_override("font_color", GameTheme.GREEN)
		vbox.add_child(strengths)
		var costs := Label.new()
		costs.name = "Costs"
		costs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		costs.add_theme_font_size_override("font_size", 10)
		costs.add_theme_color_override("font_color", GameTheme.RED)
		vbox.add_child(costs)
		var btn := Button.new()
		btn.name = "ChooseBtn"
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(_on_card_pressed.bind(key))
		vbox.add_child(btn)
		_cards.add_child(card)
		_card_buttons[key] = card


func _refresh() -> void:
	var unlocked: bool = _DragonSystem.dragon_unlocked(GameState)
	var current: String = _DragonSystem.active_dragon(GameState)
	_locked.visible = not unlocked
	_cards.visible = unlocked
	_card_row_interactive(unlocked)
	if current.is_empty():
		_stage.text = ""
		_prompt.text = "Choose your patron — grows with you across all runs"
	else:
		var meta: Dictionary = _DragonSystem.DRAGON_META[current]
		var prog: Dictionary = _DragonSystem.stage_xp_progress(GameState)
		var needed: int = int(prog.get("needed", 0))
		if needed > 0:
			_stage.text = "%s  ·  %d/%d XP → %s" % [
				_DragonSystem.STAGE_LABELS[_DragonSystem.get_stage(GameState)],
				int(prog.get("progress", 0)),
				needed,
				_DragonSystem.STAGE_LABELS.get(prog.get("next", ""), ""),
			]
		else:
			_stage.text = "%s  ·  ANCIENT (maxed)" % _DragonSystem.STAGE_LABELS[_DragonSystem.get_stage(GameState)]
		_stage.add_theme_color_override("font_color", meta.get("color", GameTheme.GOLD))
		_prompt.text = "Active patron: %s" % meta.get("title", current)
	if not unlocked:
		_locked.text = "Complete your first prestige to unlock Dragon Patrons.\n\nDragon Patrons grow with you across every run — a permanent companion."
		return
	for key in _DragonSystem.DRAGON_ORDER:
		var card: PanelContainer = _card_buttons[key]
		var meta: Dictionary = _DragonSystem.DRAGON_META[key]
		var vbox: VBoxContainer = card.get_child(0)
		var title: Label = vbox.get_node("Title")
		var tag: Label = vbox.get_node("Tag")
		var body: Label = vbox.get_node("Body")
		var strengths: Label = vbox.get_node("Strengths")
		var costs: Label = vbox.get_node("Costs")
		var btn: Button = vbox.get_node("ChooseBtn")
		title.text = str(meta.get("title", key))
		title.add_theme_color_override("font_color", meta.get("color", GameTheme.GOLD))
		tag.text = str(meta.get("tag", ""))
		var is_current: bool = current == key
		if is_current:
			body.text = _DragonSystem.STAGE_LABELS[_DragonSystem.get_stage(GameState)]
		else:
			body.text = str(meta.get("blurb", ""))
		var s_lines: PackedStringArray = PackedStringArray(["STRENGTHS"])
		for line in meta.get("strengths", []):
			s_lines.append("+ %s" % line)
		strengths.text = "\n".join(s_lines)
		var c_lines: PackedStringArray = PackedStringArray(["COSTS"])
		for line in meta.get("costs", []):
			c_lines.append("− %s" % line)
		costs.text = "\n".join(c_lines)
		if is_current:
			btn.text = "ACTIVE PATRON"
			btn.disabled = true
			card.modulate = Color(1.0, 1.0, 1.0, 1.0)
		elif current.is_empty():
			btn.text = "Choose"
			btn.disabled = false
		else:
			btn.text = "Switch (−%d Inf)" % _DragonSystem.DRAGON_CHANGE_COST
			btn.disabled = false


func _card_row_interactive(enabled: bool) -> void:
	for key in _card_buttons:
		var card: PanelContainer = _card_buttons[key]
		var vbox: VBoxContainer = card.get_child(0)
		var btn: Button = vbox.get_node("ChooseBtn")
		if not enabled:
			btn.disabled = true


func _on_card_pressed(key: String) -> void:
	if not _DragonSystem.dragon_unlocked(GameState):
		return
	var current: String = _DragonSystem.active_dragon(GameState)
	if current == key:
		return
	_pending_key = key
	var meta: Dictionary = _DragonSystem.DRAGON_META[key]
	if current.is_empty():
		_confirm_title.text = "Choose %s?" % meta.get("title", key)
		_confirm_body.text = "%s\n%s\n\nFree — you have no current patron.\nDragon XP persists forever." % [
			meta.get("tag", ""), meta.get("blurb", ""),
		]
	else:
		_confirm_title.text = "Switch to %s?" % meta.get("title", key)
		_confirm_body.text = "%s\n%s\n\nCosts %d Influence to switch.\nThis patron grows with you across all runs." % [
			meta.get("tag", ""), meta.get("blurb", ""), _DragonSystem.DRAGON_CHANGE_COST,
		]
	_confirm.visible = true


func _on_confirm_yes() -> void:
	if _pending_key.is_empty():
		_confirm.visible = false
		return
	var result: Dictionary = _DragonSystem.select_dragon(GameState, _pending_key)
	if bool(result.get("ok", false)):
		var meta: Dictionary = _DragonSystem.DRAGON_META[_pending_key]
		GameState.notification.emit("Dragon Patron: %s" % meta.get("title", _pending_key), meta.get("color", GameTheme.GOLD))
		GameState._mark_ips_dirty()
		GameState.stats_changed.emit()
	else:
		GameState.notification.emit(str(result.get("message", "Cannot select patron")), GameTheme.GOLD)
	_pending_key = ""
	_confirm.visible = false
	_refresh()


func _on_confirm_no() -> void:
	_pending_key = ""
	_confirm.visible = false
