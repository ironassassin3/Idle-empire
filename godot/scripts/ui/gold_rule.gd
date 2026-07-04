class_name GoldRule
extends Control
## Deco divider — twin gold hairlines meeting a center diamond
## (ported from /godot-design game_screen_v2 masthead).


func _draw() -> void:
	var mid := size.y * 0.5
	var cx := size.x * 0.5
	draw_line(Vector2(24, mid), Vector2(cx - 14, mid), Color(GameTheme.GOLD, 0.5), 1.0)
	draw_line(Vector2(cx + 14, mid), Vector2(size.x - 24, mid), Color(GameTheme.GOLD, 0.5), 1.0)
	var pts := PackedVector2Array([
		Vector2(cx, mid - 4), Vector2(cx + 5, mid), Vector2(cx, mid + 4), Vector2(cx - 5, mid),
	])
	draw_colored_polygon(pts, GameTheme.GOLD)
