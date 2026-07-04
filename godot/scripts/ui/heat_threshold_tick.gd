class_name HeatThresholdTick
extends Control
## Raid-threshold marker drawn over the heat ProgressBar: red tick at 60%
## (GameConfig raid threshold). Anchor full-rect inside the bar; ignores mouse.

const THRESHOLD_PCT := 0.6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var x := size.x * THRESHOLD_PCT
	draw_line(Vector2(x, -1), Vector2(x, size.y + 1), Color(GameTheme.RED, 0.9), 1.5)
