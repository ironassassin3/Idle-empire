extends SceneTree
## Bake P15 ink UI PNGs into assets/ui/textures/ (policy-safe procedural).
## Usage: godot --path godot --headless -s res://scripts/tools/bake_ink_ui_textures.gd

const InkTextureBaker = preload("res://scripts/ui/ink_texture_baker.gd")

const OUT_DIR := "res://assets/ui/textures"


func _initialize() -> void:
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var jobs: Array = [
		["panel_9slice.png", InkTextureBaker.bake_panel_image],
		["card_frame.png", InkTextureBaker.bake_card_image],
		["modal_frame.png", InkTextureBaker.bake_modal_image],
		["tab_bar.png", InkTextureBaker.bake_tab_bar_image],
		["wax_seal.png", InkTextureBaker.bake_wax_seal_image],
		["film_grain.png", InkTextureBaker.bake_film_grain_image],
	]
	var ok := 0
	for job in jobs:
		var file_name: String = job[0]
		var img: Image = job[1].call()
		var path := "%s/%s" % [OUT_DIR, file_name]
		var err := img.save_png(ProjectSettings.globalize_path(path))
		if err != OK:
			push_error("Save failed %s err=%s" % [path, err])
			continue
		ok += 1
		print("Wrote %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	print("INK_UI_BAKE done: %d/%d" % [ok, jobs.size()])
	quit(0 if ok == jobs.size() else 1)
