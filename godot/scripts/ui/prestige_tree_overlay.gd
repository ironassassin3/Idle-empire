extends CanvasLayer
## Full-screen prestige tree — Godot-native overlay (mirrors PrestigeTreeState).

const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")
const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Panel
@onready var _influence: Label = $Panel/Margin/VBox/InfluenceLabel
@onready var _prompt: Label = $Panel/Margin/VBox/PromptLabel
@onready var _branch_row: HBoxContainer = $Panel/Margin/VBox/BranchRow
@onready var _blurb: Label = $Panel/Margin/VBox/BlurbLabel
@onready var _perk_scroll: ScrollContainer = $Panel/Margin/VBox/PerkScroll
@onready var _perk_grid: GridContainer = $Panel/Margin/VBox/PerkScroll/PerkGrid
@onready var _lock_label: Label = $Panel/Margin/VBox/LockLabel
@onready var _back_btn: Button = $Panel/Margin/VBox/BottomRow/BackBtn
@onready var _prestige_btn: Button = $Panel/Margin/VBox/BottomRow/PrestigeBtn
@onready var _dragon_patron_btn: Button = $Panel/Margin/VBox/BottomRow/DragonPatronBtn
@onready var _branch_dialog: PanelContainer = $BranchDialog
@onready var _branch_dialog_title: Label = $BranchDialog/Margin/VBox/Title
@onready var _branch_dialog_body: Label = $BranchDialog/Margin/VBox/Body
@onready var _branch_yes: Button = $BranchDialog/Margin/VBox/Row/YesBtn
@onready var _branch_no: Button = $BranchDialog/Margin/VBox/Row/NoBtn
@onready var _prestige_dialog: PanelContainer = $PrestigeDialog
@onready var _prestige_gain: Label = $PrestigeDialog/Margin/VBox/GainLabel
@onready var _prestige_rank: Label = $PrestigeDialog/Margin/VBox/RankLabel
@onready var _prestige_yes: Button = $PrestigeDialog/Margin/VBox/Row/YesBtn
@onready var _prestige_no: Button = $PrestigeDialog/Margin/VBox/Row/NoBtn

var _pending_branch: String = ""
var _branch_buttons: Dictionary = {}
var _ui_time: float = 0.0


func _process(delta: float) -> void:
	_ui_time += delta
	if _prestige_dialog.visible:
		var pulse: float = 0.85 + 0.15 * sin(_ui_time * 4.0)
		_prestige_dialog.modulate = Color(1.0, 0.92, 0.55, pulse)
	else:
		_prestige_dialog.modulate = Color.WHITE


func _ready() -> void:
	layer = 10
	visible = false
	_build_branch_buttons()
	_back_btn.pressed.connect(close)
	_prestige_btn.pressed.connect(_on_prestige_pressed)
	_dragon_patron_btn.pressed.connect(_on_dragon_patron_pressed)
	_branch_yes.pressed.connect(_confirm_branch)
	_branch_no.pressed.connect(_cancel_branch_dialog)
	_prestige_yes.pressed.connect(_confirm_prestige)
	_prestige_no.pressed.connect(_cancel_prestige_dialog)
	GameState.stats_changed.connect(_refresh)


func open() -> void:
	visible = true
	_branch_dialog.visible = false
	_prestige_dialog.visible = false
	_pending_branch = ""
	_refresh()


func close() -> void:
	visible = false
	_branch_dialog.visible = false
	_prestige_dialog.visible = false
	_pending_branch = ""


func _build_branch_buttons() -> void:
	for child in _branch_row.get_children():
		child.queue_free()
	_branch_buttons.clear()
	for br in PrestigeTree.BRANCH_ORDER:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 54)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_branch_pressed.bind(br))
		_branch_row.add_child(btn)
		_branch_buttons[br] = btn


func _refresh() -> void:
	_influence.text = "Influence: %d" % GameState.prestige_tokens
	var committed: String = GameState.prestige_branch
	if committed.is_empty():
		_prompt.text = "Choose your path — permanent until your next prestige"
		_blurb.visible = true
		var lines: PackedStringArray = PackedStringArray()
		for br in PrestigeTree.BRANCH_ORDER:
			var meta: Dictionary = PrestigeTree.BRANCH_META[br]
			lines.append("%s: %s" % [meta.get("name", br), meta.get("blurb", "")])
		_blurb.text = "\n".join(lines)
		_perk_scroll.visible = false
	else:
		var meta: Dictionary = PrestigeTree.BRANCH_META[committed]
		_prompt.text = "Path: %s — %s  (locked this cycle)" % [meta.get("name", ""), meta.get("tag", "")]
		_blurb.visible = false
		_perk_scroll.visible = true
		_refresh_perks(committed)
	_refresh_branch_buttons(committed)
	_refresh_lock_strip()
	_refresh_prestige_button()
	_refresh_dragon_patron_button()


func _refresh_dragon_patron_button() -> void:
	var unlocked: bool = _DragonSystem.dragon_unlocked(GameState)
	_dragon_patron_btn.disabled = not unlocked
	var patron: String = _DragonSystem.active_dragon(GameState)
	if not unlocked:
		_dragon_patron_btn.text = "DRAGON (locked)"
	elif patron.is_empty():
		_dragon_patron_btn.text = "DRAGON PATRON"
	else:
		var meta: Dictionary = _DragonSystem.DRAGON_META[patron]
		_dragon_patron_btn.text = meta.get("title", "DRAGON")
		_dragon_patron_btn.add_theme_color_override("font_color", meta.get("color", GameTheme.GOLD))


func _on_dragon_patron_pressed() -> void:
	var dragon := get_node_or_null("../DragonPatronOverlay")
	if dragon:
		dragon.open()


func _refresh_branch_buttons(committed: String) -> void:
	for br in PrestigeTree.BRANCH_ORDER:
		var btn: Button = _branch_buttons[br]
		var meta: Dictionary = PrestigeTree.BRANCH_META[br]
		var is_committed: bool = committed == br
		var is_locked: bool = not committed.is_empty() and not is_committed
		var owned: int = PrestigeTree.branch_perk_count(GameState, br)
		if is_committed:
			btn.text = "%s\n%d/4 perks\nACTIVE" % [meta.get("name", br), owned]
		elif is_locked:
			btn.text = "%s\nlocked" % meta.get("name", br)
		elif owned > 0:
			btn.text = "%s\n%d/4 perks" % [meta.get("name", br), owned]
		else:
			btn.text = "%s\n%s" % [meta.get("name", br), meta.get("short", "")]
		btn.disabled = not committed.is_empty()


func _refresh_perks(branch: String) -> void:
	for child in _perk_grid.get_children():
		child.queue_free()
	var perks: Array = PrestigeTree.BRANCH_PERKS.get(branch, [])
	var meta: Dictionary = PrestigeTree.BRANCH_META.get(branch, {})
	for entry in perks:
		var key: String = entry[0]
		var name: String = entry[1]
		var cost: int = int(entry[2])
		var effect: String = entry[3]
		var tier: int = int(entry[4])
		var card := _make_perk_card(key, name, cost, effect, tier, meta)
		_perk_grid.add_child(card)


func _make_perk_card(key: String, perk_name: String, cost: int, effect: String, tier: int, meta: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 128)
	panel.add_theme_stylebox_override("panel", GameTheme.make_row_card_flat(
		GameTheme.RowAffordance.OWNED if key in GameState.perks_purchased else GameTheme.RowAffordance.LOCKED
	))
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var tier_l := Label.new()
	tier_l.text = "TIER %d" % tier
	tier_l.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	tier_l.add_theme_font_size_override("font_size", GameTheme.scaled_font(11))
	vbox.add_child(tier_l)
	var name_l := Label.new()
	name_l.text = perk_name
	name_l.add_theme_font_size_override("font_size", GameTheme.scaled_font(15))
	name_l.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	vbox.add_child(name_l)
	var eff_l := Label.new()
	eff_l.text = effect
	eff_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff_l.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	eff_l.add_theme_color_override("font_color", GameTheme.GREEN if key in GameState.perks_purchased else GameTheme.TEXT)
	vbox.add_child(eff_l)
	var btn := Button.new()
	btn.custom_minimum_size.y = 48.0
	var owned: bool = key in GameState.perks_purchased
	var gate: Dictionary = PrestigeTree.can_buy_perk(GameState, key)
	if owned:
		btn.text = "Owned"
		btn.disabled = true
	elif gate.get("ok", false):
		btn.text = "Buy (%d inf)" % cost
		btn.pressed.connect(_on_buy_perk.bind(key))
		panel.add_theme_stylebox_override("panel", GameTheme.make_row_card_flat(GameTheme.RowAffordance.BUYABLE))
	else:
		btn.text = str(gate.get("reason", "Locked"))
		btn.disabled = true
	vbox.add_child(btn)
	var detail: String = PrestigeTree.perk_detail(key)
	if not detail.is_empty():
		var detail_l := Label.new()
		detail_l.text = detail
		detail_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_l.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		detail_l.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
		vbox.add_child(detail_l)
	return panel


func _refresh_lock_strip() -> void:
	if GameState.can_prestige():
		_lock_label.text = ""
		return
	var reqs: Dictionary = Prestige.check_requirements(GameState)
	var earn: Dictionary = reqs["earnings"]
	var gain: int = Prestige.calc_influence_gain(GameState.lifetime_earnings)
	var line := "PRESTIGE LOCKED — Empire %s / %s" % [
		FormatUtil.format_money(float(earn.get("current", 0.0))),
		FormatUtil.format_money(float(earn.get("required", 0.0))),
	]
	if gain > 0:
		line += "  (+ %d Influence at prestige)" % gain
	var parts: PackedStringArray = PackedStringArray()
	for key in ["dealers", "rackets", "chops"]:
		if reqs.has(key):
			var r: Dictionary = reqs[key]
			parts.append("%s %d/%d" % [key.capitalize(), int(r.get("current", 0)), int(r.get("required", 0))])
	if reqs.has("rank"):
		var r: Dictionary = reqs["rank"]
		parts.append("Rank: %s" % r.get("required", ""))
	if not parts.is_empty():
		line += "\n" + "  ·  ".join(parts)
	_lock_label.text = line


func _refresh_prestige_button() -> void:
	var can: bool = GameState.can_prestige()
	_prestige_btn.disabled = not can
	_prestige_btn.text = "PRESTIGE" if can else "PRESTIGE (locked)"


func _on_branch_pressed(branch: String) -> void:
	if not GameState.prestige_branch.is_empty():
		return
	_pending_branch = branch
	var meta: Dictionary = PrestigeTree.BRANCH_META[branch]
	_branch_dialog_title.text = "Commit: %s?" % meta.get("name", branch)
	_branch_dialog_body.text = (
		"%s\n%s\n\nThis path is LOCKED until your next prestige.\nOther branches' perks stay inactive this cycle."
		% [meta.get("tag", ""), meta.get("blurb", "")]
	)
	_branch_dialog.visible = true


func _confirm_branch() -> void:
	if _pending_branch.is_empty():
		_branch_dialog.visible = false
		return
	var outcome: String = GameState.select_prestige_branch(_pending_branch)
	GameState.notification.emit(outcome, GameTheme.GOLD)
	_pending_branch = ""
	_branch_dialog.visible = false
	_refresh()


func _cancel_branch_dialog() -> void:
	_pending_branch = ""
	_branch_dialog.visible = false


func _on_prestige_pressed() -> void:
	if not GameState.can_prestige():
		return
	var raw: float = float(Prestige.calc_influence_gain(GameState.lifetime_earnings))
	raw *= _ManagerSystem.influence_gain_mult(GameState)
	raw *= PrestigeTree.influence_gain_mult(GameState)
	var gain: int = maxi(1, int(round(raw)))
	var tokens_after: int = GameState.prestige_tokens + gain
	_prestige_gain.text = "Influence gain: +%d  ·  Income after: ×%.2f" % [
		gain, Prestige.income_mult(tokens_after),
	]
	_prestige_rank.text = "New rank: %s" % Prestige.get_rank(tokens_after)
	_prestige_dialog.visible = true


func _confirm_prestige() -> void:
	if GameState.do_prestige():
		close()
	_prestige_dialog.visible = false


func _cancel_prestige_dialog() -> void:
	_prestige_dialog.visible = false


func _on_buy_perk(key: String) -> void:
	var outcome: String = GameState.buy_prestige_perk(key)
	var color := GameTheme.GREEN if outcome.begins_with("Purchased") else GameTheme.GOLD
	GameState.notification.emit(outcome, color)
	_refresh()
