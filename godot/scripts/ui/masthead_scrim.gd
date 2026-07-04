class_name MastheadScrim
extends Control
## Legibility scrim over the city view: dark gradient at top (rank/heat row)
## and bottom (hero balance + rule) so masthead text reads over any skyline.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size
	var steps := 14
	var band := s.y * 0.34 / steps
	for i in steps:
		var t := 1.0 - float(i) / steps
		draw_rect(Rect2(0, i * band, s.x, band + 1.0), Color(GameTheme.BG, 0.72 * t))
	var bottom_h := s.y * 0.42
	for i in steps:
		var t2 := float(i) / steps
		var y := s.y - bottom_h + t2 * bottom_h
		draw_rect(Rect2(0, y, s.x, bottom_h / steps + 1.0), Color(GameTheme.BG, 0.8 * t2))
