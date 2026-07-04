extends SceneTree
## Design preview harness — render an arbitrary UI scene to PNG for the
## /godot-design loop (screenshot.gd's sibling: that one captures the shipped
## game screens, this one captures work-in-progress design scenes).
## Godot 4 cannot read back a viewport under --headless, so run WITHOUT it:
##   godot --path godot -s res://scripts/tools/design_preview.gd -- \
##       --scene res://design/offer_card.tscn --out D:/shots/offer.png
## Args (after the `--`):
##   --scene RES_PATH   Scene to render (required)
##   --out PATH         Output PNG — absolute, user:// or res:// (default user://design_shot.png)
##   --w / --h          Window size (default project 720x1280)
##   --frames N         Frames to settle before capture (default 30)
##   --cash N           Seed GameState.balance so affordance states populate

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")
const GameFonts = preload("res://scripts/ui/game_fonts.gd")

var _frame := 0
var _settle := 30
var _out := "user://design_shot.png"


func _initialize() -> void:
	var scene_path := _arg_after("--scene", "")
	if scene_path.is_empty():
		printerr("design_preview: --scene is required")
		quit(1)
		return
	_settle = int(_arg_after("--frames", "30"))
	_out = _arg_after("--out", "user://design_shot.png").replace("\\", "/")
	var w := int(_arg_after("--w", "720"))
	var h := int(_arg_after("--h", "1280"))

	SoakAutoloads.install(self)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	var gs: Node = root.get_node_or_null("GameState")
	if gs != null and gs.has_method("reset_new_game"):
		gs.reset_new_game()
		var cash := float(_arg_after("--cash", "0"))
		if cash > 0.0:
			gs.balance = cash

	# Same font stack the shipped screens use; design scenes inherit it from root.
	var theme: Theme = ThemeDB.get_project_theme()
	if theme == null:
		theme = Theme.new()
	GameFonts.apply_to_theme(theme)
	root.theme = theme

	root.set_content_scale_size(Vector2i(w, h))
	DisplayServer.window_set_size(Vector2i(w, h))

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		printerr("design_preview: failed to load %s" % scene_path)
		quit(1)
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < _settle:
		return false
	var img: Image = root.get_texture().get_image()
	var err := img.save_png(_out)
	if err != OK:
		printerr("design_preview: save_png failed (%d) for %s" % [err, _out])
		quit(1)
		return true
	print(JSON.stringify({"ok": true, "out": ProjectSettings.globalize_path(_out)}))
	quit(0)
	return true


func _arg_after(flag: String, fallback: String) -> String:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for i in pack.size():
			if pack[i] == flag and i + 1 < pack.size():
				return pack[i + 1]
	return fallback
