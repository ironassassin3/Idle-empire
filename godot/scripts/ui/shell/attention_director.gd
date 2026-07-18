extends Node
## AttentionDirector — single source of truth for "what should the player look
## at" (UI_OVERHAUL_ARCHITECTURE.md §6.1). Publishes exactly ONE rail item at a
## time plus nav-dock badge counts. May never spawn a persistent widget.

const _OperationSystem = preload("res://scripts/systems/operation_system.gd")
const _GoalSystem = preload("res://scripts/systems/goal_system.gd")
const _ManagerSystem = preload("res://scripts/systems/manager_system.gd")

const TAKEOVER_DWELL := 4.0
const REFRESH_INTERVAL := 0.5
const LOG_MAX := 40

# Priority table (high → low). Takeovers queue by priority; ambient items fill
# the slot when no takeover is active.
const PRIO_RAID := 100
const PRIO_OP_COLLECT := 80
const PRIO_GOAL_DONE := 70
const PRIO_PRESTIGE_READY := 60
# One-shot onboarding beats (D5 compact-mode offer) rank above passive
# goal/afford hints — otherwise, since those hints are near-always present
# past prestige 1, the "offered once" promise could starve forever and never
# actually surface. Still below anything genuinely actionable right now.
const PRIO_OFFER := 45
const PRIO_AFFORD_HINT := 40
const PRIO_GOAL_HINT := 30

var _takeovers: Array = []            # [{prio, kind, text, value, target}]
var _takeover_left: float = 0.0
var _current: Dictionary = {}
var _refresh_left: float = 0.0
var _badges: Dictionary = {}
## Session log — the rail's archive; Empire Report renders it (§8 Stats).
var event_log: Array = []
## D5: the compact-ledger offer persists as an ambient item (not a 4s
## takeover, since 4s is too short to read+decide) but still must retire on
## its own — "offered once" means it shouldn't camp in the rail forever
## whenever the player happens to be idle.
const _COMPACT_OFFER_MAX_SHOWN := 8.0
var _compact_offer_live := false
var _compact_offer_shown_for := 0.0

@onready var _stage: Node = null  # set by shell for world-FX preference


func _ready() -> void:
	GameState.notification.connect(_on_notification)
	GameState.stats_changed.connect(func(): _refresh_left = 0.0)
	UiEvents.rail_action.connect(_on_rail_action)


func _on_rail_action(kind: String) -> void:
	if kind == "compact_offer":
		dismiss_compact_offer()


func _maybe_offer_compact() -> void:
	if _compact_offer_live or GameState.prestige_count < 1 or GameState.compact_offer_done \
			or GameState.ui_compact_rows:
		return
	_compact_offer_live = true
	_publish()


## Called by the rail when the compact offer is accepted OR the player moves
## on to something else — either way the one-shot is spent.
func dismiss_compact_offer() -> void:
	if not _compact_offer_live:
		return
	_compact_offer_live = false
	GameState.compact_offer_done = true
	_publish()


func set_stage(stage: Node) -> void:
	_stage = stage


func _process(delta: float) -> void:
	if _takeover_left > 0.0:
		_takeover_left -= delta
		if _takeover_left <= 0.0:
			_takeovers.pop_front()
			_publish()
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_INTERVAL
		_refresh_ambient()
	if _compact_offer_live and str(_current.get("kind", "")) == "compact_offer":
		_compact_offer_shown_for += delta
		if _compact_offer_shown_for >= _COMPACT_OFFER_MAX_SHOWN:
			dismiss_compact_offer()


# Wire flavor pools (§4.8 narrative density) — the archive reads like a noir
# city desk, not a debug log. Rotation keyed to log length, deterministic.
const _WIRE_RAID := [
	"The precinct came knocking — %s",
	"Sirens on the block. %s",
	"Badges kicked a door tonight: %s",
]
const _WIRE_GOAL := [
	"The ledger notes it: %s",
	"Word gets around — %s",
	"Another line inked: %s",
]
const _WIRE_RIVAL := [
	"The city exhales. %s",
	"One less crown in the gutter: %s",
	"The obituaries write themselves: %s",
]


func _on_notification(message: String, _color: Color) -> void:
	# Raid detection: rail takeover + world FX + archive (kills the alarm ticker).
	if message.begins_with("Police raid"):
		_log("raid", _WIRE_RAID[event_log.size() % 3] % message)
		if _stage != null and _stage.has_method("play_raid"):
			_stage.play_raid()
		_push_takeover(PRIO_RAID, "raid", message, "")
	elif message.contains("EARNED") or message.begins_with("Goal"):
		_log("goal", _WIRE_GOAL[event_log.size() % 3] % message.split("\n")[0])
	elif message.begins_with("ELIMINATED"):
		_log("rival", _WIRE_RIVAL[event_log.size() % 3] % message.split("\n")[0])


func _push_takeover(prio: int, kind: String, text: String, value: String) -> void:
	var item := {"prio": prio, "kind": kind, "text": text, "value": value, "target": ""}
	_takeovers.append(item)
	_takeovers.sort_custom(func(a, b): return int(a["prio"]) > int(b["prio"]))
	if _takeovers[0] == item:
		_takeover_left = TAKEOVER_DWELL
	_publish()


func announce_goal_complete(text: String) -> void:
	_push_takeover(PRIO_GOAL_DONE, "goal_done", text, "")


func _refresh_ambient() -> void:
	_refresh_badges()
	# Cheap, so it's fine to re-check every tick rather than one-shot from
	# _ready() — a one-shot deferred check raced GameState's own boot-time
	# reset in short-lived harness contexts (fine in real play, many frames
	# separate boot from shell entry there, but not worth two code paths).
	_maybe_offer_compact()
	if not _takeovers.is_empty():
		return
	_publish()


func _ambient_item() -> Dictionary:
	# Ops ready to collect?
	var ready_ops := 0
	for op in GameState.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.is_ready(GameState, op):
			ready_ops += 1
	if ready_ops > 0:
		return {
			"kind": "op_collect", "prio": PRIO_OP_COLLECT,
			"text": "▸ OPERATION COMPLETE — collect your take",
			"value": "×%d" % ready_ops, "target": "ops",
		}
	if GameState.can_prestige():
		var gain: int = Prestige.calc_influence_gain(GameState.lifetime_earnings)
		return {
			"kind": "prestige_ready", "prio": PRIO_PRESTIGE_READY,
			"text": "▸ EMPIRE READY TO ASCEND",
			"value": "+%d INF" % gain, "target": "prestige",
		}
	# NOTE: _ambient_item is a first-match cascade, not a sort by "prio" — the
	# prio fields below are cosmetic/telemetry only. Ordering here IS the
	# priority. The compact-mode offer sits here (above goal/afford hints) so
	# it can't be starved forever by the near-always-present passive hints.
	if _compact_offer_live:
		return {
			"kind": "compact_offer", "prio": PRIO_OFFER,
			"text": "▸ BOSS MODE — a compact ledger for a grown empire",
			"value": "ENABLE", "target": "compact",
		}
	var order := _ManagerSystem.pending_manager_order(GameState)
	if not order.is_empty():
		var val := "APPROVE" if bool(order.get("can_approve", false)) else ""
		return {
			"kind": "manager_order", "prio": PRIO_AFFORD_HINT + 5,
			"text": _ManagerSystem.pending_order_hint(GameState),
			"value": val, "target": "bldgs",
		}
	# Real Phase-55 goals beat soft coaching — the rail used to mislabel
	# next_focus_hint as "GOAL" while actual goals only lived in Stats.
	for raw in _GoalSystem.current_goals(GameState, 4):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var g: Dictionary = raw
		var prog: Dictionary = _GoalSystem.progress_for(GameState, g)
		var cur := float(prog.get("current", 0.0))
		var tgt := float(prog.get("target", 1.0))
		var frac := clampf(cur / tgt, 0.0, 1.0) if tgt > 0.0 else 0.0
		# Skip met-but-not-yet-acked goals (check_goals runs on the sim tick).
		if frac >= 1.0:
			continue
		return {
			"kind": "goal", "prio": PRIO_GOAL_HINT,
			"text": str(g.get("label", "Goal")),
			"value": _format_goal_progress(g, cur, tgt),
			"progress": frac,
			"target": "stats",
		}
	var hint := _GoalSystem.next_focus_hint(GameState)
	if not hint.is_empty():
		return {
			"kind": "hint", "prio": PRIO_GOAL_HINT,
			"text": hint, "value": "", "target": "",
		}
	hint = GameState.next_purchase_hint()
	if not hint.is_empty():
		return {
			"kind": "afford", "prio": PRIO_AFFORD_HINT,
			"text": hint, "value": "", "target": "bldgs",
		}
	return {}


func _format_goal_progress(g: Dictionary, cur: float, tgt: float) -> String:
	var kind := str(g.get("progress_kind", ""))
	if kind in ["balance", "route", "lifetime"]:
		return "%s/%s" % [FormatUtil.format_money(cur), FormatUtil.format_money(tgt)]
	if tgt >= 1.0:
		return "%d/%d" % [int(cur), int(tgt)]
	if tgt > 0.0:
		return "%.0f%%" % (clampf(cur / tgt, 0.0, 1.0) * 100.0)
	return ""


func _publish() -> void:
	var item: Dictionary
	if not _takeovers.is_empty():
		item = _takeovers[0]
		if _takeover_left <= 0.0:
			_takeover_left = TAKEOVER_DWELL
	else:
		item = _ambient_item()
	if item != _current:
		_current = item
		UiEvents.attention_changed.emit(item)


func _refresh_badges() -> void:
	var counts := {
		"bldgs": GameState.count_affordable_buildings(),
		"upgrs": GameState.count_affordable_upgrades(),
		"mgrs": GameState.count_hireable_managers(),
		"turf": 0,
	}
	var ready_ops := 0
	for op in GameState.operations:
		if typeof(op) == TYPE_DICTIONARY and _OperationSystem.is_ready(GameState, op):
			ready_ops += 1
	counts["turf"] = ready_ops
	if counts != _badges:
		_badges = counts
		UiEvents.badges_changed.emit(counts)


func _log(kind: String, text: String) -> void:
	event_log.append({
		"kind": kind,
		"text": text,
		"at": Time.get_time_string_from_system().substr(0, 5),
	})
	if event_log.size() > LOG_MAX:
		event_log.pop_front()
