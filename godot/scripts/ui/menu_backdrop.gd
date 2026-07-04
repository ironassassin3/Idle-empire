class_name MenuBackdrop
extends Control
## Full-bleed menu scene: dusk gradient sky + code-drawn skyline with lit
## windows. Kills the black-void menu; ART_POLICY code-built.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size
	var steps := 30
	for i in steps:
		var t := float(i) / steps
		var c := Color("2c1f3a").lerp(Color("0d0912"), t)
		draw_rect(Rect2(0, s.y * t, s.x, s.y / steps + 1.0), c)
	# Far skyline: bottom third.
	var seed_v := 23
	var x := -10.0
	while x < s.x:
		seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
		var bw := 34.0 + float(seed_v % 52)
		var bh := s.y * 0.10 + float((seed_v >> 7) % int(s.y * 0.22))
		draw_rect(Rect2(x, s.y - bh, bw, bh), Color("120c1a"))
		var wx := x + 6.0
		while wx < x + bw - 6.0:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			if seed_v % 4 == 0:
				var wy := s.y - bh + 10.0 + float(seed_v % int(maxf(bh - 24.0, 1.0)))
				draw_rect(Rect2(wx, wy, 3, 4), Color(GameTheme.GOLD, 0.5))
			wx += 9.0
		x += bw + 6.0
	# Grounding fade at the very bottom.
	for i in 10:
		var t2 := float(i) / 10.0
		draw_rect(Rect2(0, s.y - 40 + t2 * 40.0, s.x, 5.0), Color("0d0912", t2 * 0.9))
