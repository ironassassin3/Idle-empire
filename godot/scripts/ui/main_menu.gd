extends CanvasLayer

@onready var _continue_btn: Button = $Margin/Center/VBox/ContinueBtn
@onready var _new_btn: Button = $Margin/Center/VBox/NewBtn
@onready var _import_btn: Button = $Margin/Center/VBox/ImportBtn
@onready var _preview: Label = $Margin/Center/VBox/Preview
@onready var _version: Label = $Margin/Center/VBox/Version


func _ready() -> void:
	GameState.set_simulation_active(false)
	_version.text = GameConfig.VERSION
	_continue_btn.pressed.connect(_on_continue)
	_new_btn.pressed.connect(_on_new)
	_import_btn.pressed.connect(_on_import)
	_refresh_save_ui()


func _refresh_save_ui() -> void:
	var has_save := SaveManager.has_save()
	_continue_btn.visible = has_save
	_preview.visible = has_save
	if not has_save:
		_preview.text = ""
		return
	var p := SaveManager.preview()
	_preview.text = "Prestige x%d  ·  %d Influence  ·  %.0f min played" % [
		p.get("prestige_count", 0),
		p.get("prestige_tokens", 0),
		float(p.get("play_time", 0.0)) / 60.0,
	]


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
		_preview.text = "No save.json found in parent folder (d:/2d_game/)"
		_preview.visible = true
