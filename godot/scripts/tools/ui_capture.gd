extends SceneTree
## ui_capture — next-gen capture harness for the design loop.
## Renders scenes into an offscreen SubViewport at EXACT pixel size (no OS
## window clamping — fixes the dead-strip artifact of window-resize capture).
## Needs a real (tiny) window for GPU readback: do NOT pass --headless.
##
##   godot --path godot --resolution 320x240 -s res://scripts/tools/ui_capture.gd -- \
##       --shell --tab 0 --w 1080 --h 1920 --cash 500 --out D:/shots/x.png
##
## Args (after `--`):
##   --shell            Capture game_shell.tscn (Stage & Ledger)
##   --scene RES_PATH   Capture an arbitrary scene (design mocks, legacy screens)
##   --tab N            Tab index (shell: 0 bldgs 1 upgrs 2 turf 3 rivals 4 crew
##                      5 ops 6 stats 7 mgrs 8 config)
##   --w / --h          Capture size in px (default 720x1280)
##   --out PATH         Output PNG (absolute, user:// or res://)
##   --frames N         Settle frames before capture (default 60)
##   --cash / --city-tier / --heat / --districts / --prestige-tokens   GameState seeds
##   --no-overlays      Dismiss tutorial/milestone/offline overlays before capture
##   --debug-rects      Outline every visible Control in the capture (cyan;
##                      magenta = zero-area, i.e. collapsed layout) and write
##                      <out>.rects.json with name/class/rect/min_size per node
##   --spec PATH        Batch mode: JSON array of job objects (same keys as the
##                      CLI flags, snake_case: shell, scene, tab, w, h, out,
##                      frames, cash, city_tier, heat, districts,
##                      prestige_tokens, no_overlays, debug_rects, inputs).
##                      One engine launch renders the whole capture matrix.
##
## Input playback (spec only): per-job "inputs" array drives synthetic touches
## before capture, so gestures (sheet drag, stage taps) can be exercised:
##   {"at": 30, "type": "tap",  "x": 360, "y": 585}
##   {"at": 40, "type": "drag", "x": 360, "y": 585, "to_x": 360, "to_y": 200, "frames": 12}

const SoakAutoloads = preload("res://scripts/tools/soak_autoloads.gd")
const GAME_SHELL := "res://scenes/game_shell.tscn"

const _TIER_BUILDINGS := [0, 5, 15, 35, 80]
const _SHELL_TABS := ["bldgs", "upgrs", "turf", "turf", "turf", "turf", "stats", "mgrs", "config"]
const _SHELL_SUBTABS := {2: "turf", 3: "rivals", 4: "crew", 5: "ops"}

var _jobs: Array = []
var _job_index := -1
var _job: Dictionary = {}
var _sv: SubViewport
var _scene: Node
var _frame := 0
var _failures := 0
var _drags: Array = []      # [{end_frame, from, to, start_frame}]
var _pending_ups: Array = []  # [{frame, pos}]


func _initialize() -> void:
	SoakAutoloads.install(self)
	# Capture runs are silent — seeded balance jumps would otherwise fire
	# rollover/purchase cues out loud on the dev machine.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_jobs = _collect_jobs()
	if _jobs.is_empty():
		printerr("ui_capture: nothing to do (need --shell or --scene)")
		quit(1)
		return
	_next_job()


const _JOB_DEFAULTS := {
	"shell": false, "scene": "", "tab": 0, "w": 720, "h": 1280,
	"out": "user://ui_capture.png", "frames": 60, "cash": 0.0,
	"city_tier": "", "heat": "", "districts": "", "prestige_tokens": "",
	"no_overlays": false, "debug_rects": false, "inputs": [],
	"reduced_motion": false, "text_scale": -1, "late_cash": 0.0,
	"offline_hours": 0.0, "compact_rows": false, "trigger_prestige_at": -1,
	"prestige_count": 0, "all_buildings_owned": 0,
}


func _collect_jobs() -> Array:
	var spec_path := _arg_after("--spec", "")
	if not spec_path.is_empty():
		return _load_spec(spec_path)
	var job := {
		"shell": _has_flag("--shell"),
		"scene": _arg_after("--scene", ""),
		"tab": int(_arg_after("--tab", "0")),
		"w": int(_arg_after("--w", "720")),
		"h": int(_arg_after("--h", "1280")),
		"out": _arg_after("--out", "user://ui_capture.png"),
		"frames": int(_arg_after("--frames", "60")),
		"cash": float(_arg_after("--cash", "0")),
		"city_tier": _arg_after("--city-tier", ""),
		"heat": _arg_after("--heat", ""),
		"districts": _arg_after("--districts", ""),
		"prestige_tokens": _arg_after("--prestige-tokens", ""),
		"no_overlays": _has_flag("--no-overlays"),
		"debug_rects": _has_flag("--debug-rects"),
	}
	if job["shell"] or not str(job["scene"]).is_empty():
		return [job]
	return []


func _load_spec(path: String) -> Array:
	var f := FileAccess.open(path.replace("\\", "/"), FileAccess.READ)
	if f == null:
		printerr("ui_capture: cannot open spec %s" % path)
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		printerr("ui_capture: spec must be a JSON array of job objects")
		return []
	var jobs: Array = []
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var job := _JOB_DEFAULTS.duplicate()
		for k in entry:
			job[k] = entry[k]
		# JSON numbers arrive as floats; normalize the int-typed fields.
		for k in ["tab", "w", "h", "frames"]:
			job[k] = int(job[k])
		if bool(job["shell"]) or not str(job["scene"]).is_empty():
			jobs.append(job)
	return jobs


# ------------------------------------------------------------------ job loop

func _next_job() -> void:
	_job_index += 1
	if _job_index >= _jobs.size():
		print(JSON.stringify({"ok": _failures == 0, "jobs": _jobs.size(), "failures": _failures}))
		quit(1 if _failures > 0 else 0)
		return
	_job = _jobs[_job_index]
	print("[ui_capture] job %d/%d -> %s" % [_job_index + 1, _jobs.size(), _job["out"]])
	_frame = 0
	_drags = []
	_pending_ups = []
	_seed_state()

	_sv = SubViewport.new()
	_sv.size = Vector2i(int(_job["w"]), int(_job["h"]))
	_sv.disable_3d = true
	_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sv.gui_embed_subwindows = true
	root.add_child(_sv)

	var path: String = GAME_SHELL if bool(_job["shell"]) else str(_job["scene"])
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		printerr("ui_capture: failed to load %s" % path)
		_failures += 1
		_finish_job()
		return
	_scene = packed.instantiate()
	_sv.add_child(_scene)


func _finish_job() -> void:
	if _scene != null:
		_scene.queue_free()
		_scene = null
	if _sv != null:
		_sv.queue_free()
		_sv = null
	# Give freed nodes a frame to leave the tree before the next job seeds state.
	await process_frame
	await process_frame
	_next_job()


func _process(_delta: float) -> bool:
	if _sv == null:
		return false
	_frame += 1
	# Session start (shell _ready) can reset seeded state — re-apply live.
	if _frame == 3:
		_seed_state()
	if _frame == 5:
		_select_tab()
		if bool(_job.get("no_overlays", false)):
			_dismiss_overlays()
	_play_inputs()
	# late_cash: inject a windfall shortly before capture so the balance
	# ticker (Supremacy §4.1) is caught mid-count in the shot.
	var late := float(_job.get("late_cash", 0.0))
	if late > 0.0 and _frame == int(_job.get("frames", 60)) - 8:
		var gs: Node = root.get_node_or_null("GameState")
		if gs != null:
			gs.balance += late
			gs.emit_signal("stats_changed")
	# trigger_prestige_at: fire the prestiged signal directly (bypassing the
	# tree overlay/economy gates) so the climax ceremony can be captured in
	# isolation with a fixed, reproducible gain.
	var trigger_at := int(_job.get("trigger_prestige_at", -1))
	if trigger_at >= 0 and _frame == trigger_at:
		var gs2: Node = root.get_node_or_null("GameState")
		if gs2 != null:
			gs2.emit_signal("prestiged", {"gain": 42, "rank": "Crime Lord"})
	if _frame < int(_job.get("frames", 60)):
		return false
	if _frame == int(_job.get("frames", 60)) and bool(_job.get("debug_rects", false)):
		_attach_rect_overlay()
		return false  # give the overlay one frame to draw before readback
	_capture()
	_finish_job()
	return false


func _capture() -> void:
	var img: Image = _sv.get_texture().get_image()
	var out := _resolve_out(str(_job["out"]))
	var err := img.save_png(out)
	if err != OK:
		printerr("ui_capture: save_png failed (%d) for %s" % [err, out])
		_failures += 1
	else:
		print(JSON.stringify({
			"shot": ProjectSettings.globalize_path(out),
			"size": "%dx%d" % [img.get_width(), img.get_height()],
		}))


# ---------------------------------------------------------- input playback

func _play_inputs() -> void:
	for entry in _job.get("inputs", []):
		if typeof(entry) != TYPE_DICTIONARY or int(entry.get("at", -1)) != _frame:
			continue
		var from := Vector2(float(entry.get("x", 0)), float(entry.get("y", 0)))
		match str(entry.get("type", "tap")):
			"tap":
				_push_button(from, true)
				_pending_ups.append({"frame": _frame + 1, "pos": from})
			"hold":
				# Press now, release after N frames — long-press affordances.
				_push_button(from, true)
				_pending_ups.append({
					"frame": _frame + maxi(2, int(entry.get("frames", 40))), "pos": from,
				})
			"drag":
				var to := Vector2(
					float(entry.get("to_x", from.x)), float(entry.get("to_y", from.y)))
				var dur := maxi(2, int(entry.get("frames", 10)))
				_push_button(from, true)
				_drags.append({
					"start_frame": _frame, "end_frame": _frame + dur,
					"from": from, "to": to,
				})
	for up in _pending_ups.duplicate():
		if int(up["frame"]) == _frame:
			_push_button(up["pos"], false)
			_pending_ups.erase(up)
	for drag in _drags.duplicate():
		var t := float(_frame - int(drag["start_frame"])) \
			/ float(int(drag["end_frame"]) - int(drag["start_frame"]))
		if t <= 0.0:
			continue
		var pos: Vector2 = (drag["from"] as Vector2).lerp(drag["to"] as Vector2, minf(t, 1.0))
		if t >= 1.0:
			_push_button(pos, false)
			_drags.erase(drag)
		else:
			var mm := InputEventMouseMotion.new()
			mm.position = pos
			mm.global_position = pos
			mm.button_mask = MOUSE_BUTTON_MASK_LEFT
			_sv.push_input(mm)


func _push_button(pos: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = pos
	mb.global_position = pos
	_sv.push_input(mb)


# ------------------------------------------------------------- debug rects

## The poor man's element inspector: outlines every visible Control and dumps
## the rect tree so layout bugs (min-size collapse, off-screen nodes, zero-area
## controls) are visible in one glance instead of three render cycles.
class RectOverlay extends Control:
	var target: Node

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		if target != null:
			_outline(target)

	func _outline(node: Node) -> void:
		if node is Control and node != self:
			var c := node as Control
			if c.visible and c.is_visible_in_tree():
				var r := c.get_global_rect()
				var collapsed := r.size.x < 1.0 or r.size.y < 1.0
				var col := Color(1, 0, 1, 0.9) if collapsed else Color(0, 0.9, 1, 0.35)
				if collapsed:
					draw_circle(r.position, 4.0, col)
				else:
					draw_rect(r, col, false, 1.0)
		for child in node.get_children():
			_outline(child)


func _attach_rect_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var overlay := RectOverlay.new()
	overlay.target = _scene
	layer.add_child(overlay)
	_sv.add_child(layer)
	_dump_rects()


func _dump_rects() -> void:
	var rows: Array = []
	_collect_rects(_scene, rows)
	var out := _resolve_out(str(_job["out"])) + ".rects.json"
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(rows, "\t"))
		print(JSON.stringify({"rects": ProjectSettings.globalize_path(out), "controls": rows.size()}))


func _collect_rects(node: Node, rows: Array) -> void:
	if node is Control:
		var c := node as Control
		var r := c.get_global_rect()
		rows.append({
			"path": str(_scene.get_path_to(c)) if node != _scene else ".",
			"class": c.get_class(),
			"rect": [r.position.x, r.position.y, r.size.x, r.size.y],
			"min": [c.get_combined_minimum_size().x, c.get_combined_minimum_size().y],
			"visible": c.is_visible_in_tree(),
		})
	for child in node.get_children():
		_collect_rects(child, rows)


# ----------------------------------------------------------------- seeding

func _seed_state() -> void:
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		return
	if _frame == 0:
		gs.reset_new_game()
	var cash := float(_job.get("cash", 0.0))
	if cash > 0.0:
		gs.balance = cash
	var tier_arg := str(_job.get("city_tier", ""))
	if not tier_arg.is_empty():
		var tier := clampi(int(tier_arg), 0, _TIER_BUILDINGS.size() - 1)
		_seed_buildings(gs, _TIER_BUILDINGS[tier])
	var heat_arg := str(_job.get("heat", ""))
	if not heat_arg.is_empty():
		gs.heat = clampf(float(heat_arg), 0.0, 100.0)
	var districts_arg := str(_job.get("districts", ""))
	if not districts_arg.is_empty() and gs.get("territories") != null:
		var districts: Array = gs.territories
		var unlock_count := clampi(int(districts_arg), 0, districts.size())
		for i in districts.size():
			var t = districts[i]
			if typeof(t) == TYPE_DICTIONARY:
				t["unlocked"] = i < unlock_count
				if i < unlock_count:
					t["owner"] = "player"
	var prestige_arg := str(_job.get("prestige_tokens", ""))
	if not prestige_arg.is_empty():
		gs.prestige_tokens = maxi(0, int(prestige_arg))
	# Batch jobs share one GameState across the whole spec run — every seed
	# flag with a meaningful "off" state must be set unconditionally each job,
	# or it silently inherits the previous job's value (bit us for compact_rows
	# and reduced_motion below).
	gs.show_particles = not bool(_job.get("reduced_motion", false))
	gs.ui_compact_rows = bool(_job.get("compact_rows", false))
	gs.prestige_count = int(_job.get("prestige_count", 0))
	var all_owned := int(_job.get("all_buildings_owned", 0))
	if all_owned > 0 and gs.get("buildings") != null:
		for b in gs.buildings:
			if b != null:
				b.owned = all_owned
	# owned_list: per-building owned counts by index — for testing the city
	# skyline / rows with a realistic mixed distribution (flagship + tail).
	var owned_list = _job.get("owned_list", [])
	if owned_list is Array and not owned_list.is_empty() and gs.get("buildings") != null:
		for i in gs.buildings.size():
			if gs.buildings[i] != null:
				gs.buildings[i].owned = int(owned_list[i]) if i < owned_list.size() else 0
	var off_hours := float(_job.get("offline_hours", 0.0))
	if off_hours > 0.0:
		gs.show_offline_overlay = true
		gs.show_daily_overlay = false
		gs.offline_gain = 12500.0
		gs.offline_secs_away = off_hours * 3600.0
		gs.offline_capped = off_hours >= GameConfig.OFFLINE_CAP_HOURS
		gs.return_ops_ready = 2
		gs.return_territory_player = 3
		gs.return_territory_total = 20
		gs.return_rival_active = 4
		gs.return_rival_at_war = 1
		var rival_lines: Array[String] = [
			"The Crimson Kings expanded into Downtown",
			"Blackwater Mob took a hit from the docks union",
		]
		gs.offline_rival_events = rival_lines
	# -1 sentinel means "unspecified" -> default 100%; always set (see the
	# unconditional-seed note above — text_scale leaks across batch jobs too).
	var tscale := int(_job.get("text_scale", -1))
	gs.ui_text_scale = clampi(tscale, 0, 2) if tscale >= 0 else 0
	if gs.has_signal("stats_changed"):
		gs.stats_changed.emit()


func _seed_buildings(gs: Node, count: int) -> void:
	if gs.get("buildings") == null or gs.buildings.is_empty():
		return
	for b in gs.buildings:
		if b != null:
			b.owned = 0
	gs.buildings[0].owned = count


func _select_tab() -> void:
	var tab := int(_job.get("tab", 0))
	if bool(_job["shell"]):
		var events: Node = root.get_node_or_null("UiEvents")
		if events != null and tab >= 0 and tab < _SHELL_TABS.size():
			if _SHELL_TABS[tab] == "config":
				events.emit_signal("overlay_requested", "config")
			else:
				events.emit_signal("tab_requested", _SHELL_TABS[tab])
			if _SHELL_SUBTABS.has(tab):
				events.emit_signal("subtab_requested", _SHELL_SUBTABS[tab])
	elif _scene != null and _scene.has_method("_set_tab"):
		_scene.call("_set_tab", tab)


func _dismiss_overlays() -> void:
	var gs: Node = root.get_node_or_null("GameState")
	if gs == null:
		return
	gs.tutorial_step = 99
	gs.milestone_queue = []
	gs.milestone_timer = 0.0
	gs.pending_event = {}
	gs.show_offline_overlay = false
	gs.show_daily_overlay = false


# ------------------------------------------------------------------- utils

func _resolve_out(path: String) -> String:
	var p := path.replace("\\", "/")
	if p.begins_with("docs/"):
		return "../" + p
	return p


func _has_flag(flag: String) -> bool:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		if pack.has(flag):
			return true
	return false


func _arg_after(flag: String, fallback: String) -> String:
	for pack in [OS.get_cmdline_user_args(), OS.get_cmdline_args()]:
		for i in pack.size():
			if pack[i] == flag and i + 1 < pack.size():
				return pack[i + 1]
	return fallback
