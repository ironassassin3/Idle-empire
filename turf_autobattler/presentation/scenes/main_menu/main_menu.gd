extends Control

@onready var cred_label: Label = %CredLabel
@onready var stats_label: Label = %StatsLabel
@onready var upgrades_box: VBoxContainer = %UpgradesBox


func _ready() -> void:
	%VersionLabel.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.0.0")
	%StartButton.pressed.connect(_on_start_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh()


func _refresh() -> void:
	_update_metagame()
	_build_upgrades()


func _update_metagame() -> void:
	var mg := RunBridge.metagame
	cred_label.text = "Street Cred: %d" % mg.currency
	stats_label.text = "Runs: %d | Wins: %d | Best round: %d" % [
		int(mg.stats.get("runs", 0)),
		int(mg.stats.get("wins", 0)),
		int(mg.stats.get("best_round", 0)),
	]


func _build_upgrades() -> void:
	for child in upgrades_box.get_children():
		child.queue_free()
	var mg := RunBridge.metagame
	for unlock_id in MetagameRules.UNLOCKS.keys():
		var def: Dictionary = MetagameRules.UNLOCKS[unlock_id]
		var button := Button.new()
		button.tooltip_text = String(def.get("desc", ""))
		if mg.unlocks.has(unlock_id):
			button.text = "%s — owned" % def.get("name", unlock_id)
			button.disabled = true
		else:
			var cost := int(def.get("cost", 0))
			button.text = "%s — %d cred" % [def.get("name", unlock_id), cost]
			button.disabled = mg.currency < cost
			button.pressed.connect(_on_purchase.bind(String(unlock_id)))
		upgrades_box.add_child(button)


func _on_purchase(unlock_id: String) -> void:
	if MetagameRules.purchase(RunBridge.metagame, unlock_id):
		SaveStore.save_from(RunBridge)
		_refresh()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://presentation/scenes/run/run_shell.tscn")
