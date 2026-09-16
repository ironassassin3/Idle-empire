extends CanvasLayer

const MusicDefs = preload("res://scripts/audio/music_defs.gd")
const GameFonts = preload("res://scripts/ui/game_fonts.gd")

const _BASE_MARGIN := 20
const _INK_BG := Color("0c0c14")

@onready var _margin: MarginContainer = $Margin
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
	if AudioManager.is_enabled():
		AudioManager.set_music_mode(MusicDefs.MusicMode.MENU)
	_version.text = GameConfig.VERSION
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	get_viewport().size_changed.connect(_fit_title)
	_apply_menu_theme()
	_continue_btn.pressed.connect(_on_continue)
	_new_btn.pressed.connect(_on_new)
	_import_btn.pressed.connect(_on_import)
	# Dev-only: the importer reads a hardcoded desktop path (d:/2d_game/) and is
	# useless on a device. Show it only when running inside the editor so it never
	# ships in any exported build.
	_import_btn.visible = OS.has_feature("editor")
	_refresh_save_ui()
	_build_recovery_ui()
	GameTheme.apply_device_font_boost.call_deferred(self)
	# Runs after the boost pass above (both deferred, FIFO) so it measures the
	# size the title actually ends up at.
	_fit_title.call_deferred()


## Everything a player gets when the game has been failing to launch: what
## happened, a way to put the save aside, and a report they can paste into a
## message. This is the only screen a broken build is guaranteed to reach, so the
## recovery controls live here rather than behind the Config tab.
func _build_recovery_ui() -> void:
	var vbox: VBoxContainer = $Margin/Center/LedgerPanel/VBox
	# Rebuildable: a failed Continue re-runs this, and duplicated buttons would
	# push the real ones off a phone screen.
	for name in ["RecoveryNote", "RepairBtn", "DiagnosticsBtn"]:
		var existing := vbox.get_node_or_null(NodePath(name))
		if existing != null:
			vbox.remove_child(existing)
			existing.queue_free()
	var insert_at := _continue_btn.get_index()
	var note := ""
	if CrashReporter.safe_mode:
		note = "Recovery mode — the game closed %d times before it finished loading. \
Sound and ads are off for this launch." % CrashReporter.boot_failures
	if not CrashReporter.recovery_note.is_empty():
		note = (note + "\n" + CrashReporter.recovery_note).strip_edges()
	if not note.is_empty():
		var label := Label.new()
		label.name = "RecoveryNote"
		label.text = note
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", GameTheme.SIREN_RED)
		vbox.add_child(label)
		vbox.move_child(label, insert_at)
		insert_at += 1
	if CrashReporter.safe_mode and SaveManager.has_save():
		var repair := Button.new()
		repair.name = "RepairBtn"
		repair.text = "Repair save"
		GameTheme.apply_menu_button(repair, false)
		repair.pressed.connect(_on_repair)
		vbox.add_child(repair)
		vbox.move_child(repair, insert_at)
	var diagnostics := Button.new()
	diagnostics.name = "DiagnosticsBtn"
	diagnostics.text = "Crash diagnostics"
	GameTheme.apply_menu_button(diagnostics, false)
	diagnostics.pressed.connect(CrashReporter.show_report)
	vbox.add_child(diagnostics)
	vbox.move_child(diagnostics, _version.get_index())


## Sets the current save aside and falls back to the backup. The file is kept as
## save.json.broken so nothing the player earned is destroyed by pressing this.
func _on_repair() -> void:
	var recovered := SaveManager.repair_save()
	CrashReporter.set_recovery_note(
		"Save repaired from backup." if recovered else "No readable save remained after repair.")
	_refresh_save_ui()
	_build_recovery_ui()
	var note: Label = $Margin/Center/LedgerPanel/VBox.get_node_or_null("RecoveryNote")
	if note != null and recovered:
		note.add_theme_color_override("font_color", GameTheme.GREEN)


## The title screen is the root of the stack, so Back leaves the app from here.
## The engine no longer does this for us (quit_on_go_back=false, set so the game
## screen can unwind its overlays instead of dying on the first Back press).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Recorded because on a gesture-navigation phone this looks exactly like
		# "the game closed by itself": the log has to be able to tell a Back
		# gesture apart from a crash.
		CrashReporter.note("quit: back gesture at title screen")
		get_tree().quit()


## The display title at a phone's 1.6 font boost can be wider
## than a 720px screen. The title sits in a CenterContainer, so it stretched the
## panel past the viewport and clipped at BOTH edges — the first thing a player
## ever sees. Fit it to the width the panel is actually allowed.
func _fit_title() -> void:
	var panel := $Margin/Center/LedgerPanel as PanelContainer
	var pad := 0.0
	var sb: StyleBox = panel.get_theme_stylebox("panel") if panel != null else null
	if sb != null:
		pad = sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	var avail := get_viewport().get_visible_rect().size.x - pad - float(
		_margin.get_theme_constant("margin_left")
		+ _margin.get_theme_constant("margin_right"))
	var start := int(round(
		float(GameTheme.scaled_font(GameTheme.FONT_MENU_TITLE)) * GameTheme.device_font_boost()))
	GameTheme.fit_label_to_width(_title, avail, start)


func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return
	var vp := get_viewport().get_visible_rect().size
	var sx := vp.x / float(screen.x)
	var sy := vp.y / float(screen.y)
	var left := _BASE_MARGIN + int(maxf(0.0, float(safe.position.x)) * sx)
	var top := _BASE_MARGIN + int(maxf(0.0, float(safe.position.y)) * sy)
	var right := _BASE_MARGIN + int(maxf(0.0, float(screen.x - (safe.position.x + safe.size.x))) * sx)
	var bottom := _BASE_MARGIN + int(maxf(0.0, float(screen.y - (safe.position.y + safe.size.y))) * sy)
	_margin.add_theme_constant_override("margin_left", left)
	_margin.add_theme_constant_override("margin_top", top)
	_margin.add_theme_constant_override("margin_right", right)
	_margin.add_theme_constant_override("margin_bottom", bottom)


func _apply_menu_theme() -> void:
	if GameTheme.is_city_v2_active():
		$Background.color = _INK_BG
	else:
		$Background.color = GameTheme.BG
	_title.add_theme_font_override("font", GameFonts.display())
	_title.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_TITLE))
	_title.add_theme_color_override("font_color", GameTheme.GOLD_BRIGHT)
	_subtitle.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_SUBTITLE))
	_subtitle.add_theme_color_override("font_color", GameTheme.TEXT_MUTED)
	GameTheme.apply_flavor_label(_subtitle)
	_preview_card.add_theme_stylebox_override("panel", GameTheme.menu_preview_style())
	_preview_head.add_theme_font_override("font", GameFonts.heading())
	_preview_head.add_theme_font_size_override("font_size", GameTheme.scaled_font(GameTheme.FONT_MENU_PREVIEW_HEAD))
	_preview_head.add_theme_color_override("font_color", GameTheme.GOLD)
	_prestige_lbl.add_theme_font_override("font", GameFonts.mono(true))
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


## Stage & Ledger shell (UI_SHELL_V3) vs legacy strip shell — rollback flag.
func _game_scene() -> String:
	if GameConfig.UI_SHELL_V3:
		return "res://scenes/game_shell.tscn"
	return "res://scenes/game_screen.tscn"


func _on_continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file(_game_scene())
		return
	# Never a dead button: if the save cannot be applied, say so and offer the
	# only thing left instead of leaving the player tapping.
	CrashReporter.set_recovery_note("That save could not be opened. Start a new game to continue.")
	_refresh_save_ui()
	_build_recovery_ui()


func _on_new() -> void:
	# Unconditional: an unreadable file still has to go, and has_save() now only
	# reports saves that can actually be loaded.
	SaveManager.delete_save()
	GameState.reset_new_game()
	get_tree().change_scene_to_file(_game_scene())


func _on_import() -> void:
	if SaveManager.try_import_python_save():
		get_tree().change_scene_to_file(_game_scene())
	else:
		_import_note.visible = true
		_preview_card.visible = false
