extends SceneTree
## Layout invariants — the machine-checkable half of the device pass.
##
##   godot --path godot --resolution 320x240 --position 3000,3000 \
##       -s res://scripts/tools/layout_invariants.gd
##   (add `-- --verbose` to list every surface, not just the failures)
##
## Every layout bug the 2026-07-29/30 device pass turned up was a measurable
## fact rather than a matter of taste: a title wider than the screen, a gear
## chip pushed past the right edge, a sheet row sharing pixels with the nav
## dock. None of them were visible to ui_capture, because desktop renders at a
## 1.0 font scale and a 263dpi handset applies a 1.6 boost to the same layout.
## This walks the real shell at BOTH scales and asserts the rules, so the next
## one fails here instead of on a phone.
##
## Rules:
##   OVERFLOW  a live control (Button, or Label with text) that is not inside a
##             scroller, whose rect leaves the viewport — the menu title and the
##             vanished gear chip were both this
##   CHROME    a live control sharing pixels with the masthead or the nav dock —
##             the boss sheet buried its own Luck Wheel row under the dock, two
##             owners for one tap area
##   CLIP      a control whose text needs more width than the box it was given,
##             where it never opted into ellipsis or wrapping
##   HSCROLL   an overlay that only fits by scrolling sideways — Dragon Patron
##             pushed its third patron's Choose button off the right edge
##
## Needs a real (tiny, offscreen) window: layout does not settle under
## --headless, same caveat as deck_bounds_smoke.gd.

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")

const SIZE := Vector2i(720, 1604)
const BOOSTS: Array[float] = [1.0, 1.6]
const TOL := 0.5

## tab/subtab feed UiEvents exactly like ui_capture; overlay opens a modal on
## top. A "scene" entry checks some other screen instead of the shell — the
## chrome rule simply finds no masthead/dock there and stands down.
const SURFACES := [
	{"id": "main_menu", "scene": "res://scenes/main_menu.tscn",
		"tab": "", "sub": "", "overlay": ""},
	{"id": "bldgs", "tab": "bldgs", "sub": "", "overlay": ""},
	{"id": "upgrs", "tab": "upgrs", "sub": "", "overlay": ""},
	{"id": "turf", "tab": "turf", "sub": "turf", "overlay": ""},
	{"id": "rivals", "tab": "turf", "sub": "rivals", "overlay": ""},
	{"id": "crew", "tab": "turf", "sub": "crew", "overlay": ""},
	{"id": "ops", "tab": "turf", "sub": "ops", "overlay": ""},
	{"id": "stats", "tab": "stats", "sub": "", "overlay": ""},
	{"id": "mgrs", "tab": "mgrs", "sub": "", "overlay": ""},
	{"id": "config", "tab": "", "sub": "", "overlay": "config"},
	{"id": "boss_sheet", "tab": "bldgs", "sub": "", "overlay": "boss"},
	{"id": "prestige_tree", "tab": "bldgs", "sub": "", "overlay": "prestige"},
	{"id": "dragon_patron", "tab": "bldgs", "sub": "", "overlay": "dragon"},
	{"id": "luck_wheel", "tab": "bldgs", "sub": "", "overlay": "gambling"},
]

const SETTLE := 14      # shell _ready + the deferred font-boost pass
const OPEN_AT := 18
const CHECK_AT := 80

var _jobs: Array = []
var _job_index := -1
var _job: Dictionary = {}
var _shell: Node
var _sv: SubViewport
var _frames := 0
var _failures := 0
var _checked := 0
var _verbose := false
## Loaded at runtime, not preloaded: game_theme.gd refers to the GameState
## autoload, which does not exist yet while this script is being compiled.
var _theme: GDScript


func _initialize() -> void:
	SoakAutoloads.install(self)
	_theme = load("res://scripts/ui/game_theme.gd") as GDScript
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_verbose = OS.get_cmdline_user_args().has("--verbose")
	for boost in BOOSTS:
		for surface in SURFACES:
			var job: Dictionary = surface.duplicate()
			job["boost"] = boost
			_jobs.append(job)
	_next_job()


func _next_job() -> void:
	if _sv != null:
		_sv.queue_free()
		_sv = null
		_shell = null
	_job_index += 1
	if _job_index >= _jobs.size():
		_report()
		return
	_job = _jobs[_job_index]
	# device_font_boost() caches its answer in a static, so a single process can
	# only test one scale unless we reset it between jobs.
	_theme.set("_device_font_boost", float(_job["boost"]))
	_seed()
	_sv = SubViewport.new()
	_sv.size = SIZE
	_sv.disable_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.gui_embed_subwindows = true
	root.add_child(_sv)
	var scene_path := str(_job.get("scene", ""))
	if scene_path.is_empty():
		scene_path = "res://scenes/game_shell.tscn"
	_shell = (load(scene_path) as PackedScene).instantiate()
	_sv.add_child(_shell)
	_frames = 0


func _seed() -> void:
	# A fresh save hides most tabs behind rank gates and leaves rows empty, so
	# the wide-content cases (big balances, long district names) never appear.
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		return
	gs.reset_new_game()
	gs.balance = 1.2e21
	gs.prestige_tokens = 30
	gs.prestige_count = 3
	for b in gs.buildings:
		if b != null:
			b.owned = 250
	for i in gs.territories.size():
		var t = gs.territories[i]
		if typeof(t) == TYPE_DICTIONARY and i < 12:
			t["unlocked"] = true
			t["owner"] = "player"
	gs.stats_changed.emit()


## Seeded late-game state keeps firing rank-ups and achievements; left alone they
## park a modal over the surface under inspection.
func _suppress() -> void:
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		return
	gs.tutorial_step = 99
	gs.milestone_queue = []
	gs.milestone_timer = 0.0
	gs.pending_event = {}
	gs.show_offline_overlay = false
	gs.show_daily_overlay = false


func _process(_delta: float) -> bool:
	if _shell == null:
		return false
	_frames += 1
	if _frames >= SETTLE:
		_suppress()
	if _frames == SETTLE:
		var events: Node = root.get_node_or_null("UiEvents")
		if events != null:
			if not str(_job["tab"]).is_empty():
				events.emit_signal("tab_requested", str(_job["tab"]))
			if not str(_job["sub"]).is_empty():
				events.emit_signal("subtab_requested", str(_job["sub"]))
	if _frames == OPEN_AT and not str(_job["overlay"]).is_empty():
		var ev: Node = root.get_node_or_null("UiEvents")
		if ev != null:
			ev.emit_signal("overlay_requested", str(_job["overlay"]))
	if _frames >= CHECK_AT:
		_check()
		_next_job()
	return false


# ----------------------------------------------------------------- the rules

func _check() -> void:
	var vp := Rect2(Vector2.ZERO, Vector2(SIZE))
	var masthead: Control = _shell.find_child("Masthead", true, false) as Control
	var dock: Control = _shell.find_child("NavDock", true, false) as Control
	var chrome: Array[Rect2] = []
	for c in [masthead, dock]:
		if c != null and c.is_visible_in_tree():
			chrome.append(c.get_global_rect())
	var found: Array[String] = []
	_walk(_shell, func(c: Control) -> void:
		if not c.is_visible_in_tree():
			return
		var r := c.get_global_rect()
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			return
		var text := str(c.get("text")) if c.get("text") != null else ""
		var is_button := c is Button
		var live := is_button or (c is Label and not text.is_empty())
		if not live:
			return
		if _under_scroll(c):
			# Scroll descendants are meant to leave the viewport on the scrolling
			# axis; their width still has to fit, which CLIP covers.
			if _clipped(c, text):
				found.append("CLIP     %s  needs %.0fpx, given %.0f  \"%s\"" % [
					_path(c), c.get_combined_minimum_size().x, r.size.x, text.left(28)])
			return
		if not _contains(vp, r):
			found.append("OVERFLOW %s  rect %.0f,%.0f %.0fx%.0f leaves %dx%d  \"%s\"" % [
				_path(c), r.position.x, r.position.y, r.size.x, r.size.y,
				SIZE.x, SIZE.y, text.left(28)])
		if is_button and not _in_chrome(c, masthead, dock):
			for cr in chrome:
				if cr.intersects(r):
					found.append("CHROME   %s  overlaps chrome %.0f..%.0f  \"%s\"" % [
						_path(c), maxf(r.position.y, cr.position.y),
						minf(r.end.y, cr.end.y), text.left(28)])
					break
		if _clipped(c, text):
			found.append("CLIP     %s  needs %.0fpx, given %.0f  \"%s\"" % [
				_path(c), c.get_combined_minimum_size().x, r.size.x, text.left(28)])
	)
	if not str(_job["overlay"]).is_empty():
		found.append_array(_hscroll_findings())
	_checked += 1
	var label := "%s @ %.1fx" % [_job["id"], float(_job["boost"])]
	if found.is_empty():
		if _verbose:
			print("[layout] OK   %s" % label)
	else:
		_failures += found.size()
		printerr("[layout] FAIL %s" % label)
		for f in found:
			printerr("           %s" % f)


## A control that never asked for ellipsis or wrapping, squeezed under the width
## its own text needs. Controls that opted in are doing it deliberately.
func _clipped(c: Control, text: String) -> bool:
	if text.is_empty():
		return false
	var overrun = c.get("text_overrun_behavior")
	if overrun != null and int(overrun) != TextServer.OVERRUN_NO_TRIMMING:
		return false
	var wrap = c.get("autowrap_mode")
	if wrap != null and int(wrap) != TextServer.AUTOWRAP_OFF:
		return false
	if bool(c.get("clip_text")):
		return false
	return c.get_combined_minimum_size().x > c.get_global_rect().size.x + TOL


## An overlay that only fits by scrolling sideways is one the player has to
## discover a gesture to finish reading — treat it as a layout failure.
func _hscroll_findings() -> Array[String]:
	var out: Array[String] = []
	_walk(_shell, func(c: Control) -> void:
		if not (c is ScrollContainer) or not c.is_visible_in_tree():
			return
		var sc := c as ScrollContainer
		if sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
			return
		for child in sc.get_children():
			if child is Control:
				var need: float = (child as Control).get_combined_minimum_size().x
				if need > sc.get_global_rect().size.x + TOL:
					out.append("HSCROLL  %s  content %.0fpx in %.0fpx viewport" % [
						_path(sc), need, sc.get_global_rect().size.x])
	)
	return out


# --------------------------------------------------------------------- utils

func _walk(node: Node, fn: Callable) -> void:
	if node is Control:
		fn.call(node as Control)
	for child in node.get_children():
		_walk(child, fn)


func _contains(outer: Rect2, inner: Rect2) -> bool:
	return (inner.position.x >= outer.position.x - TOL
		and inner.position.y >= outer.position.y - TOL
		and inner.end.x <= outer.end.x + TOL
		and inner.end.y <= outer.end.y + TOL)


func _under_scroll(c: Control) -> bool:
	var n: Node = c.get_parent()
	while n != null and n != _shell:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false


func _in_chrome(c: Control, masthead: Control, dock: Control) -> bool:
	var n: Node = c
	while n != null and n != _shell:
		if n == masthead or n == dock:
			return true
		n = n.get_parent()
	return false


func _path(c: Control) -> String:
	var p := str(_shell.get_path_to(c))
	return p.right(52) if p.length() > 52 else p


func _report() -> void:
	if _failures > 0:
		printerr("[layout] FAIL — %d violation(s) across %d surfaces" % [_failures, _checked])
		quit(1)
	else:
		print("[layout] PASS — %d surfaces clean at %s" % [
			_checked, ", ".join(BOOSTS.map(func(b): return "%.1fx" % b))])
		quit(0)
