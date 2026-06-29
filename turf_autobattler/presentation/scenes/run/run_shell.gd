extends Control

@onready var board_view: Control = %TurfBoardView
@onready var shop_list: VBoxContainer = %ShopList
@onready var bench_list: HBoxContainer = %BenchList
@onready var hud_label: Label = %HudLabel
@onready var trait_label: Label = %TraitLabel
@onready var log_label: Label = %LogLabel
@onready var fight_button: Button = %FightButton
@onready var reroll_button: Button = %RerollButton
@onready var skip_button: Button = %SkipButton
@onready var sell_button: Button = %SellButton
@onready var xp_button: Button = %XpButton
@onready var run_end_panel: PanelContainer = %RunEndPanel
@onready var run_end_label: Label = %RunEndLabel
@onready var menu_button: Button = %MenuButton
@onready var again_button: Button = %AgainButton

var _selected_instance_id: int = -1
var _input_router


func _ready() -> void:
	var router_script: Script = preload("res://presentation/components/input_router.gd")
	_input_router = router_script.new()
	add_child(_input_router)
	_input_router.setup(board_view, bench_list)
	_input_router.placement_rejected.connect(_on_placement_rejected)
	RunBridge.state_changed.connect(_refresh)
	RunBridge.phase_changed.connect(_on_phase_changed)
	RunBridge.combat_event.connect(_on_combat_event)
	RunBridge.run_ended.connect(_on_run_ended)
	fight_button.pressed.connect(_on_fight_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	skip_button.pressed.connect(_on_skip_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	xp_button.pressed.connect(_on_xp_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	again_button.pressed.connect(_on_again_pressed)
	board_view.cell_clicked.connect(_on_board_clicked)
	run_end_panel.visible = false
	RunBridge.start_run(int(Time.get_unix_time_from_system()) % 100000)
	_refresh()


func _refresh() -> void:
	var run := RunBridge.get_run_dto()
	hud_label.text = "Round %d | HP %d | Gold %d | Lv %d" % [
		run["round"], run["player_hp"], run["gold"], run["level"],
	]
	var traits := RunBridge.get_trait_dto()
	var trait_names: PackedStringArray = []
	for t in traits:
		trait_names.append("%s(%d)" % [t.get("display_name", "?"), t.get("count", 0)])
	trait_label.text = "Traits: %s" % ", ".join(trait_names)
	var display := RunBridge.get_display_dto()
	board_view.set_board_dto(display, display.get("combat_mode", false))
	board_view.queue_redraw()
	_update_shop()
	_update_bench()
	var planning: bool = run["phase"] == SimConstants.RunPhase.PLANNING
	fight_button.disabled = not planning
	reroll_button.disabled = not planning
	skip_button.disabled = run["phase"] != SimConstants.RunPhase.COMBAT_PLAYBACK


func _update_shop() -> void:
	for child in shop_list.get_children():
		child.queue_free()
	var shop := RunBridge.get_shop_dto()
	for i in shop["offers"].size():
		var offer = shop["offers"][i]
		var btn := Button.new()
		if offer == null:
			btn.text = "[empty]"
			btn.disabled = true
		else:
			var def: Dictionary = UnitRegistry.get_def(String(offer))
			btn.text = "%s (%dg)" % [def.get("display_name", offer), def.get("cost", 0)]
			btn.pressed.connect(_on_buy_pressed.bind(i))
		shop_list.add_child(btn)


func _update_bench() -> void:
	for child in bench_list.get_children():
		child.queue_free()
	var bench := RunBridge.get_bench_dto()
	for unit in bench:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 48)
		if unit == null:
			btn.text = "-"
			btn.disabled = true
		else:
			btn.text = String(unit["display_name"]).substr(0, 8)
			var instance_id := int(unit["instance_id"])
			btn.pressed.connect(_on_bench_pressed.bind(instance_id))
			_input_router.register_bench_button(btn, instance_id)
		bench_list.add_child(btn)


func _on_buy_pressed(index: int) -> void:
	RunBridge.submit_intent(PlayerIntent.make("BUY_FROM_SHOP", {"index": index}))


func _on_bench_pressed(instance_id: int) -> void:
	_selected_instance_id = instance_id


func _on_board_clicked(pos: Vector2i) -> void:
	if _selected_instance_id < 0:
		return
	RunBridge.submit_intent(PlayerIntent.make("MOVE_TO_BOARD", {
		"instance_id": _selected_instance_id,
		"grid_pos": pos,
	}))
	_selected_instance_id = -1


func _on_placement_rejected(message: String) -> void:
	log_label.text = message


func _on_fight_pressed() -> void:
	log_label.text = "Combat resolving..."
	RunBridge.submit_intent(PlayerIntent.make("LOCK_BOARD"))


func _on_reroll_pressed() -> void:
	RunBridge.submit_intent(PlayerIntent.make("REROLL_SHOP"))


func _on_skip_pressed() -> void:
	RunBridge.skip_playback()


func _on_sell_pressed() -> void:
	if _selected_instance_id < 0:
		log_label.text = "Select a bench unit to sell."
		return
	RunBridge.submit_intent(PlayerIntent.make("SELL", {"instance_id": _selected_instance_id}))
	_selected_instance_id = -1


func _on_xp_pressed() -> void:
	RunBridge.submit_intent(PlayerIntent.make("BUY_XP"))


func _on_phase_changed(phase: int) -> void:
	if phase == SimConstants.RunPhase.PLANNING:
		log_label.text = "Planning — drag crew or tap bench then turf tile."


func _on_combat_event(event: Dictionary) -> void:
	match event.get("type", ""):
		"DAMAGE":
			log_label.text = "Hit for %s (hp %s)" % [event.get("amount", 0), event.get("remaining_hp", 0)]
			board_view.spawn_damage_text(int(event.get("target_id", -1)), int(event.get("amount", 0)))
			_flash_unit_cell(int(event.get("target_id", -1)))
		"UNIT_DIED":
			log_label.text = "Unit %s down." % event.get("instance_id", "?")
			board_view.mark_unit_dead(int(event.get("instance_id", -1)))
			board_view.queue_redraw()
		"COMBAT_END":
			var outcome := int(event.get("outcome", -1))
			var label := "Draw"
			if outcome == SimConstants.CombatOutcome.PLAYER:
				label = "Victory"
			elif outcome == SimConstants.CombatOutcome.ENEMY:
				label = "Defeat"
			log_label.text = "%s at tick %s" % [label, event.get("tick", 0)]


func _flash_unit_cell(instance_id: int) -> void:
	for cell in RunBridge.get_display_dto()["cells"]:
		var unit = cell.get("unit")
		if unit != null and int(unit["instance_id"]) == instance_id:
			board_view.flash_cell(cell["pos"])
			return


func _on_run_ended(result: Dictionary) -> void:
	var won: bool = result.get("won", false)
	run_end_label.text = "%s\nRound %d | +%d Street Cred" % [
		"Victory!" if won else "Eliminated",
		int(result.get("round_reached", 0)),
		int(result.get("reward", 0)),
	]
	run_end_panel.visible = true


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://presentation/scenes/main_menu/main_menu.tscn")


func _on_again_pressed() -> void:
	get_tree().change_scene_to_file("res://presentation/scenes/run/run_shell.tscn")
