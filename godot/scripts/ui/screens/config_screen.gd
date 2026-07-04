extends ScreenBase
## Settings screen — opened from the masthead gear, rendered in the deck like
## any other screen. Port of the old config tab (audio / display / retention /
## store / data); monetization stays out of core-loop chrome (§2 rule).

var _body: VBoxContainer


func _ready() -> void:
	var parts := make_scroll_list()
	_body = parts[1]
	_body.add_theme_constant_override("separation", 8)


func screen_title() -> String:
	return "SETTINGS"


func on_show() -> void:
	rebuild()


func rebuild() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_header("AUDIO")
	_cycle_row("Master Volume", ["0%", "25%", "50%", "75%", "100%"],
		_vol_index(GameState.master_volume), func(i): _set_volume("master_volume", i))
	_cycle_row("SFX Volume", ["0%", "25%", "50%", "75%", "100%"],
		_vol_index(GameState.sfx_volume), func(i): _set_volume("sfx_volume", i))
	_cycle_row("Music Volume", ["0%", "25%", "50%", "75%", "100%"],
		_vol_index(GameState.music_volume), func(i): _set_volume("music_volume", i))
	_cycle_row("Mute All", ["OFF", "ON"], 1 if GameState.mute_all else 0, func(i):
		GameState.mute_all = i == 1
		AudioManager.apply_from_state(GameState)
	)
	_header("DISPLAY")
	_cycle_row("Text scale", ["100%", "125%", "150%"], GameState.ui_text_scale, func(i):
		GameState.ui_text_scale = i
		SaveManager.save_game()
		rebuild()
	)
	_cycle_row("FPS Cap", ["30", "60", "120"], [30, 60, 120].find(GameState.fps_cap), func(i):
		GameState.fps_cap = int([30, 60, 120][i])
		Engine.max_fps = GameState.fps_cap
	)
	_cycle_row("Show FPS", ["OFF", "ON"], 1 if GameState.show_debug_fps else 0, func(i):
		GameState.show_debug_fps = i == 1
		SaveManager.save_game()
	)
	_cycle_row("Particles / motion", ["ON", "OFF"], 0 if GameState.show_particles else 1, func(i):
		GameState.show_particles = i == 0
		SaveManager.save_game()
	)
	_cycle_row("Compact ledger", ["OFF", "ON"], 1 if GameState.ui_compact_rows else 0, func(i):
		GameState.ui_compact_rows = i == 1
		GameState.stats_changed.emit()
		SaveManager.save_game()
	)
	_header("RETENTION")
	_cycle_row("Notifications", ["OFF", "ON"], 1 if GameState.notifications_enabled else 0, func(i):
		var on: bool = i == 1
		GameState.notifications_enabled = on
		if on:
			Notifications.request_permission()
		SaveManager.save_game()
	)
	_cycle_row("Analytics", ["OFF", "ON"], 1 if GameState.telemetry_consent else 0, func(i):
		GameState.telemetry_consent = i == 1
		SaveManager.save_game()
	)
	if CloudSave.is_signed_in():
		var cloud_lbl := Label.new()
		cloud_lbl.text = "Cloud save: signed in"
		cloud_lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
		_body.add_child(cloud_lbl)
	else:
		_action_button("Sign in (cloud backup)", func(): CloudSave.sign_in())
	_header("STORE")
	_iap_row("Remove ads", Monetization.PRODUCT_REMOVE_ADS, "Hides ads permanently")
	_iap_row("Starter pack", Monetization.PRODUCT_STARTER, "Cash + Influence boost")
	_iap_row("2× income (permanent)", Monetization.PRODUCT_INCOME_X2, "Doubles passive income")
	_action_button("Restore purchases", func(): Monetization.restore())
	_header("DATA")
	_action_button("Save & Main Menu", func():
		SaveManager.save_game()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	_action_button("Reset Tutorial", func():
		GameState.reset_tutorial()
		rebuild()
	)
	_action_button("Delete Save", func():
		SaveManager.delete_save()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	var note := Label.new()
	note.text = "Auto-save every %ds" % int(GameConfig.AUTOSAVE_INTERVAL)
	note.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	_body.add_child(note)


func _header(text: String) -> void:
	var strip := PanelContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_stylebox_override("panel", GameTheme.config_section_header_style())
	var lbl := Label.new()
	lbl.text = text
	GameTheme.apply_list_section_title(lbl)
	strip.add_child(lbl)
	_body.add_child(strip)


func _cycle_row(label: String, options: Array, index: int, cb: Callable) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", GameTheme.config_row_style())
	var row := HBoxContainer.new()
	panel.add_child(row)
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
	lbl.add_theme_color_override("font_color", GameTheme.TEXT)
	row.add_child(lbl)
	var btn := Button.new()
	var holder: Dictionary = {"i": clampi(index, 0, options.size() - 1)}
	btn.text = str(options[holder.i])
	btn.custom_minimum_size = Vector2(88, 48)
	GameTheme.apply_ink_chip_button(btn, false)
	btn.pressed.connect(func():
		holder.i = (int(holder.i) + 1) % options.size()
		btn.text = str(options[holder.i])
		cb.call(holder.i)
	)
	row.add_child(btn)
	_body.add_child(panel)


func _action_button(label: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameTheme.apply_ink_chip_button(btn, false, 14, GameTheme.TEXT)
	btn.pressed.connect(cb)
	_body.add_child(btn)


func _iap_row(label: String, product_id: String, hint: String) -> void:
	if Monetization.product_owned(product_id):
		var owned := Label.new()
		owned.text = "%s — owned" % label
		owned.add_theme_color_override("font_color", GameTheme.GREEN)
		owned.add_theme_font_size_override("font_size", GameTheme.scaled_font(13))
		_body.add_child(owned)
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Affordance.row_style(Affordance.READY))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vbox)
	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(14))
	lbl.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	vbox.add_child(lbl)
	var hint_lbl := Label.new()
	hint_lbl.text = hint
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	hint_lbl.add_theme_font_size_override("font_size", GameTheme.scaled_font(12))
	vbox.add_child(hint_lbl)
	var btn := Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size = Vector2(96, 48)
	GameTheme.apply_overlay_cta(btn, true)
	btn.pressed.connect(func(): Monetization.purchase(product_id))
	row.add_child(btn)
	_body.add_child(panel)


func _vol_index(v: float) -> int:
	if v <= 0.01:
		return 0
	if v <= 0.26:
		return 1
	if v <= 0.51:
		return 2
	if v <= 0.76:
		return 3
	return 4


func _set_volume(field: String, i: int) -> void:
	GameState.set(field, [0.0, 0.25, 0.5, 0.75, 1.0][i])
	AudioManager.apply_from_state(GameState)
