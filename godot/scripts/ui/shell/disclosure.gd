class_name Disclosure
extends RefCounted
## Declarative progressive-disclosure matrix (UI_OVERHAUL_ARCHITECTURE.md §6.2).
## Every chrome element / list horizon gets its predicate here — screens never
## hand-roll "should I show this" logic. Predicates always OR with ownership so
## returning players never lose something they already have.

const BUILDING_HORIZON := 2  # owned + next N lockable silhouettes
const UPGRADE_HORIZON := 2   # affordable-horizon + next N per group
const AD_OBJECT_SESSION_SECS := 300.0

static var session_started_msec: int = 0


static func heat_pill_visible(state) -> bool:
	# Heat matters once any heat has ever accrued or a racket exists.
	if state.heat > 0.5:
		return true
	for b in state.buildings:
		if b.icon_key == "racket" and b.owned > 0:
			return true
	return false


static func prestige_filament_visible(state) -> bool:
	# Phase 17 precedent: introduce prestige at 25% of the gate.
	if state.prestige_count > 0 or state.prestige_tokens > 0:
		return true
	var summary: Dictionary = Prestige.gate_progress_summary(state)
	return int(summary.get("pct", 0)) >= 25


static func buy_mult_visible(state) -> bool:
	return state.total_buildings_owned() >= 10


static func dragon_chip_visible(state) -> bool:
	var DragonSystem = load("res://scripts/systems/dragon_system.gd")
	return not DragonSystem.active_dragon(state).is_empty()


## Buildings list horizon. Returns per-index: "shown" (full row),
## "silhouette" ("???" teaser), or "hidden".
static func building_mode(state, index: int) -> String:
	var b = state.buildings[index]
	if b.owned > 0 or state.balance >= b.current_cost():
		return "shown"
	# Count locked (unowned, unaffordable) buildings cheaper than this one.
	var locked_before := 0
	for i in index:
		var other = state.buildings[i]
		if other.owned == 0 and state.balance < other.current_cost():
			locked_before += 1
	if locked_before == 0:
		return "shown"  # first frontier item stays fully readable
	if locked_before <= BUILDING_HORIZON:
		return "silhouette"
	return "hidden"


## Upgrades: show unpurchased upgrades whose cost is within horizon of balance
## trajectory; everything beyond the first N unaffordable stays hidden.
static func upgrade_mode(state, index: int) -> String:
	var u = state.upgrades[index]
	if u.purchased:
		return "hidden"
	if state.can_buy_upgrade(index):
		return "shown"
	var unaffordable_before := 0
	for i in state.upgrades.size():
		if i == index:
			break
		var other = state.upgrades[i]
		if not other.purchased and not state.can_buy_upgrade(i):
			unaffordable_before += 1
	return "shown" if unaffordable_before < UPGRADE_HORIZON else "hidden"


static func ad_coin_visible(state) -> bool:
	if not Monetization.ads_available():
		return false
	if session_started_msec <= 0:
		return false
	var elapsed := float(Time.get_ticks_msec() - session_started_msec) / 1000.0
	return elapsed >= AD_OBJECT_SESSION_SECS or state.prestige_count > 0
