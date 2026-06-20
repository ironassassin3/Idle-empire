extends CanvasLayer

@onready var _continue_btn: Button = $Margin/Center/LedgerPanel/VBox/ContinueBtn
@onready var _new_btn: Button = $Margin/Center/LedgerPanel/VBox/NewBtn
@onready var _import_btn: Button = $Margin/Center/LedgerPanel/VBox/ImportBtn
@onready var _preview_card: PanelContainer = $Margin/Center/LedgerPanel/VBox/PreviewCard
@onready var _prestige_lbl: Label = $Margin/Center/LedgerPanel/VBox/PreviewCard/PreviewVBox/PrestigeLabel
@onready var _influence_lbl: Label = $Margin/Center/LedgerPanel/VBox/PreviewCard/PreviewVBox/InfluenceLabel
@onready var _time_lbl: Label = $Margin/Center/LedgerPanel/VBox/PreviewCard/PreviewVBox/TimeLabel
@onready var _preview_head: Label = $Margin/Center/LedgerPanel/VBox/PreviewCard/PreviewVBox/PreviewHead
@onready var _import_note: Label = $Margin/Center/LedgerPanel/VBox/ImportNote
@onready var _title: Label = $Margin/Center/LedgerPanel/VBox/Title
@onready var _subtitle: Label = $Margin/Center/LedgerPanel/VBox/Subtitle
@onready var _version: Label = $Margin/Center/LedgerPanel/VBox/Version


func _ready() -> void:
	GameState.set_simulation_active(false)
	_version.text = GameConfig.VERSION
	_apply_menu_theme()
	_continue_btn.pressed.connect(_on_continue)
	_new_btn.pressed.connect(_on_new)
	_import_btn.pressed.connect(_on_import)
	# Dev-only: the importer reads a hardcoded desktop path (d:/2d_game/) and is
	# useless on a device. Show it only when running inside the editor so it never
	# ships in any exported build.
	_import_btn.visible = OS.has_feature("editor")
	_refresh_save_ui()


func _apply_menu_theme() -> void:
	$Background.color = GameTheme.BG
	_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_TITLE))
	_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_subtitle.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_SUBTITLE))
	_subtitle.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_preview_card.add_theme_stylebox_override("panel", GameTheme.menu_preview_style())
	_preview_head.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_PREVIEW_HEAD))
	_preview_head.add_theme_color_override("font_color", GameTheme.GOLD)
	_prestige_lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_PREVIEW_LEAD))
	_prestige_lbl.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_influence_lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_PREVIEW_BODY))
	_influence_lbl.add_theme_color_override("font_color", GameTheme.TEXT)
	_time_lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_PREVIEW_BODY))
	_time_lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_version.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_VERSION))
	_version.add_theme_color_override("font_color", Color(GameTheme.TEXT_MUTED, 0.7))
	GameTheme.apply_menu_button(_continue_btn, true)
	GameTheme.apply_menu_button(_new_btn, false)
	GameTheme.apply_menu_button(_import_btn, false)


func _refresh_save_ui() -> void:
	var has_save := SaveManager.has_save()
	_continue_btn.visible = has_save
	_preview_card.visible = has_save
	_import_note.visible = false
	if not has_save:
		return
	var p := SaveManager.preview()
	_prestige_lbl.text = "Prestige ×%d" % p.get("prestige_count", 0)
	_influence_lbl.text = "%d Influence" % p.get("prestige_tokens", 0)
	_time_lbl.text = "%.0f min played" % (float(p.get("play_time", 0.0)) / 60.0)


func _on_continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/game_screen.tscn")


func _on_new() -> void:
	if SaveManager.has_save():
		SaveManager.delete_save()
	GameState.reset_new_game()
	get_tree().change_scene_to_file("res://scenes/game_screen.tscn")


func _on_import() -> void:
	if SaveManager.try_import_python_save():
		get_tree().change_scene_to_file("res://scenes/game_screen.tscn")
	else:
		_import_note.visible = true
		_preview_card.visible = false
