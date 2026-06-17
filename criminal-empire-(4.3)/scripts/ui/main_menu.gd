extends Control

@onready var _title: Label = $VBox/Title
@onready var _subtitle: Label = $VBox/Subtitle
@onready var _continue_btn: Button = $VBox/ContinueBtn
@onready var _new_btn: Button = $VBox/NewBtn
@onready var _import_btn: Button = $VBox/ImportBtn
@onready var _preview: Label = $VBox/Preview
@onready var _version: Label = $VBox/Version


func _ready() -> void:
	_apply_theme()
	var has_save := SaveManager.has_save()
	_continue_btn.visible = has_save
	_preview.visible = has_save
	if has_save:
		var p := SaveManager.preview()
		_preview.text = "Prestige ×%d  ·  %d Influence  ·  %.0f min played" % [
			p.get("prestige_count", 0),
			p.get("prestige_tokens", 0),
			float(p.get("play_time", 0.0)) / 60.0,
		]
	_version.text = GameConfig.VERSION
	_continue_btn.pressed.connect(_on_continue)
	_new_btn.pressed.connect(_on_new)
	_import_btn.pressed.connect(_on_import)


func _apply_theme() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = GameTheme.BG
	add_theme_stylebox_override("panel", bg)


func _on_continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/game_screen.tscn")


func _on_new() -> void:
	if SaveManager.has_save():
		SaveManager.delete_save()
	else:
		GameState.reset_new_game()
	get_tree().change_scene_to_file("res://scenes/game_screen.tscn")


func _on_import() -> void:
	if SaveManager.try_import_python_save():
		_preview.text = "Imported pygame save.json → user://save.json"
		_continue_btn.visible = true
		get_tree().change_scene_to_file("res://scenes/game_screen.tscn")
	else:
		_preview.text = "No ../save.json found next to godot/ folder"
		_preview.visible = true
