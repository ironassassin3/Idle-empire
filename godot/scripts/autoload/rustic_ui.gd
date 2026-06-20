extends Node
## Startup hook — bake/load rustic textures once, apply theme when ready.


func _ready() -> void:
	GameTheme.init_rustic()
	if GameTheme.is_rustic_active():
		GameTheme.apply_rustic_theme(get_tree())
