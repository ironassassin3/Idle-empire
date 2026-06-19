class_name TutorialSystem
extends RefCounted
## Tutorial steps + milestone queue — port of src/tutorial.py + states milestone hooks.

const _CrewSystem = preload("res://scripts/systems/crew_system.gd")
const _OperationSystem = preload("res://scripts/systems/operation_system.gd")

const MILESTONE_AUTO_DISMISS := 6.0

const STEPS: Array = [
	"Click HUSTLE to earn money",
	"Buy buildings to earn passively",
	"Open Upgrades — multiply your earnings",
	"Hire managers to automate income",
	"Prestige multiplies everything — open when ready",
]

const TAB_TUTORIALS := {
	"crew": "CREW UNLOCKED\nAssign crew to boost income, heat control, and turf success.",
	"ops": "OPERATIONS UNLOCKED\nTimed heists pay big — start one when crew and turf are ready.",
	"turf": "TURF WARFARE\nCapture districts for income, click, and heat bonuses.\nControl more of the city to reach milestone rewards.",
	"rivals": "RIVAL SYNDICATES\nFive factions threaten your empire.\nAttack, bribe, negotiate, or sabotage to weaken them.",
}


static func advance_tutorial(state) -> void:
	if state.tutorial_step < STEPS.size():
		state.tutorial_step += 1
		state.tutorial_advanced.emit(state.tutorial_step)


static func skip_tutorial(state) -> void:
	state.tutorial_step = STEPS.size()


static func is_complete(state) -> bool:
	return state.tutorial_step >= STEPS.size()


static func current_text(state) -> String:
	if is_complete(state):
		return ""
	return str(STEPS[state.tutorial_step])


static func push_milestone(state, text: String, duration: float = MILESTONE_AUTO_DISMISS) -> void:
	state.milestone_queue.append(text)
	if state.milestone_timer <= 0.0:
		state.milestone_timer = duration


static func dismiss_milestone(state) -> void:
	if state.milestone_queue.is_empty():
		state.milestone_timer = 0.0
		return
	state.milestone_queue.pop_front()
	state.milestone_timer = MILESTONE_AUTO_DISMISS if not state.milestone_queue.is_empty() else 0.0


static func tick_milestones(state, dt: float) -> void:
	if state.milestone_timer > 0.0:
		state.milestone_timer -= dt
		if state.milestone_timer <= 0.0 and not state.milestone_queue.is_empty():
			state.milestone_queue.pop_front()
			if not state.milestone_queue.is_empty():
				state.milestone_timer = MILESTONE_AUTO_DISMISS


static func on_tab_opened(state, tab_key: String) -> void:
	match tab_key:
		"crew":
			if not state.shown_crew_tutorial and _CrewSystem.is_unlocked(state):
				state.shown_crew_tutorial = true
				push_milestone(state, TAB_TUTORIALS["crew"], 7.0)
		"ops":
			if not state.shown_ops_tutorial and _OperationSystem.is_unlocked(state):
				state.shown_ops_tutorial = true
				push_milestone(state, TAB_TUTORIALS["ops"], 7.0)
		"turf":
			if not state.shown_territory_tutorial:
				state.shown_territory_tutorial = true
				push_milestone(state, TAB_TUTORIALS["turf"], 7.0)
		"rivals":
			if not state.shown_rivals_tutorial:
				state.shown_rivals_tutorial = true
				push_milestone(state, TAB_TUTORIALS["rivals"], 7.0)


static func tick_contextual(state) -> void:
	if state.influence > 0 and not state.shown_influence_tutorial:
		state.shown_influence_tutorial = true
		push_milestone(state, "RESPECT EARNED\nRespect unlocks turf actions and rival leverage.\nCheck Stats for your rank progress.", 7.0)
	if state.heat >= 45.0 and not state.shown_heat_warning:
		state.shown_heat_warning = true
		push_milestone(
			state,
			"HEAT RISING\nYour Heat is climbing. At 60% the police start RAIDING and seizing cash.\n"
			+ "Lower it: hire Clean Carl, buy Nightclubs, assign Crew to Heat Reduction,\n"
			+ "or run Political Bribery operations.",
			7.0,
		)


static func on_police_raid(state) -> void:
	if state.shown_raid_tutorial:
		return
	state.shown_raid_tutorial = true
	state.milestone_queue.insert(
		0,
		"POLICE RAID!\nHeat above 60 triggers raids that seize your cash.\n"
		+ "Lower Heat: hire Clean Carl, assign Crew to Heat Reduction,\n"
		+ "or run Political Bribery operations.",
	)
	if state.milestone_timer <= 0.0:
		state.milestone_timer = 8.0
