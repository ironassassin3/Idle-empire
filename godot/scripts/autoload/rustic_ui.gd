extends Node
## Startup hook — bake/load rustic textures once, apply theme when ready.
## P15.4: city v2 ink theme takes precedence; rustic only when UI_RUSTIC_THEME && !city v2.


func _ready() -> void:
	if GameConfig.UI_CITY_V2 and GameConfig.UI_CITY_VIEW:
		GameTheme.apply_city_v2_theme(get_tree())
		return
	GameTheme.init_rustic()
	if GameTheme.is_rustic_active():
		GameTheme.apply_rustic_theme(get_tree())
