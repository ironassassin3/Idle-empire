extends ColorRect
## P14.7 overlay dim — base scrim + code-drawn edge vignette.


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	var steps := 8
	var edge := minf(w, h) * 0.28
	var strip := edge / float(steps)
	for i in steps:
		var t := float(i) / float(steps)
		var a := 0.22 * (1.0 - t)
		var col := Color(0.0, 0.0, 0.0, a)
		var off := strip * float(i)
		draw_rect(Rect2(0.0, off, w, strip), col)
		draw_rect(Rect2(0.0, h - off - strip, w, strip), col)
		draw_rect(Rect2(off, 0.0, strip, h), col)
		draw_rect(Rect2(w - off - strip, 0.0, strip, h), col)
