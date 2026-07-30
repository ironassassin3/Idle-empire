extends CanvasLayer
## Dragon Patron selection — port of DragonPatronState.

const _DragonSystem = preload("res://scripts/systems/dragon_system.gd")
const GameFonts = preload("res://scripts/ui/game_fonts.gd")

@onready var _dim: ColorRect = $Dim
@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _stage: Label = $Panel/Margin/VBox/StageLabel
@onready var _prompt: Label = $Panel/Margin/VBox/PromptLabel
@onready var _scroll: ScrollContainer = $Panel/Margin/VBox/CardScroll
## Plain BoxContainer, not HBox — Godot rejects set_vertical() on the H/V subclasses.
@onready var _cards: BoxContainer = $Panel/Margin/VBox/CardScroll/CardRow
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
	_apply_ink_theme()
	_build_cards()
	_back.pressed.connect(close)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_no.pressed.connect(_on_confirm_no)
	GameState.stats_changed.connect(_refresh)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


## Portrait phones can't fit three 200px cards side by side, so stack them and
## let the scroller handle the overflow; wide viewports keep the compare-at-a-
## glance row. Panel itself is clamped to the viewport (it was a fixed 840px).
func _apply_layout() -> void:
	GameTheme.fit_overlay_panel(_panel, Vector2(840, 620))
	GameTheme.fit_overlay_panel(_confirm, Vector2(460, 260))
	# Must read the same space fit_overlay_panel clamps in — Control.get_viewport_rect
	# is canvas units, Viewport.get_visible_rect is raw window pixels, and they
	# differ whenever a content scale is active.
	var vp: Vector2 = _panel.get_viewport_rect().size
	# Three columns need width in proportion to the text they carry. The 700px
	# threshold was authored at a 1.0 font scale, so a 720px handset stayed in
	# row mode while its 1.6 boost blew each card past 200px -- clipping the
	# third patron's title, body and Choose button off the right edge.
	var boost: float = GameTheme.device_font_boost()
	var stacked: bool = vp.x < 700.0 * boost
	_cards.vertical = stacked
	_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED if stacked else ScrollContainer.SCROLL_MODE_AUTO
	)
	_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO if stacked else ScrollContainer.SCROLL_MODE_DISABLED
	)
	for key in _card_buttons:
		var card: PanelContainer = _card_buttons[key]
		card.custom_minimum_size = (
			Vector2(0, 0) if stacked else Vector2(200.0 * boost, 280.0 * boost)
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if stacked else Control.SIZE_FILL


func _apply_ink_theme() -> void:
	if GameTheme.is_city_v2_active():
		_panel.add_theme_stylebox_override("panel", GameTheme.overlay_ledger_style())
		_confirm.add_theme_stylebox_override("panel", GameTheme.overlay_ledger_style())
	_title.add_theme_font_override("font", GameFonts.heading())
	_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(20))
	_stage.add_theme_font_override("font", GameFonts.mono(false))
	_stage.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	_prompt.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_prompt.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	_locked.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_locked.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	_confirm_title.add_theme_font_override("font", GameFonts.heading())
	_confirm_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_confirm_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(16))
	_confirm_body.add_theme_color_override("font_color", GameTheme.TEXT)
	_confirm_body.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	GameTheme.apply_overlay_cta(_confirm_yes, true)
	GameTheme.apply_overlay_cta(_confirm_no, false)
	GameTheme.apply_ink_chip_button(_back, false, 14, GameTheme.TEXT)


func open() -> void:
	visible = true
	_pending_key = ""
	_confirm.visible = false
	_apply_layout()
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
		# Cards have unequal body text; this pushes every CTA to the card bottom so
		# the row's buttons line up. Collapses to nothing when cards are stacked.
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(spacer)
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
			card.modulate = Color.WHITE
		elif current.is_empty():
			btn.text = "Choose"
			btn.disabled = false
		else:
			btn.text = "Switch (−%d Inf)" % _DragonSystem.DRAGON_CHANGE_COST
			btn.disabled = false
		var accent: Color = meta.get("color", GameTheme.GOLD)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(GameTheme.INK_FIELD, 0.92)
		sb.border_color = Color(accent, 0.85 if is_current else 0.45)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", sb)
		GameTheme.apply_overlay_cta(btn, not btn.disabled and current.is_empty())
		if btn.disabled:
			GameTheme.apply_ink_chip_button(btn, false, 12, GameTheme.TEXT_MUTED)
		elif not current.is_empty():
			GameTheme.apply_overlay_cta(btn, false)


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
