class_name ManagerDefs
extends RefCounted

const EARLY_TIER_MAX := 5

const LATE_RANK_GATES: Dictionary = {
	6: "Capo",
	7: "Underboss",
	8: "Underboss",
	9: "Boss",
	10: "Crime Lord",
	11: "Kingpin",
	12: "Kingpin",
}

const _RAW: Array = [
	["Sticky Pete", 0, "Runs the corner crew hands-off.", 3_000.0, "Street Boss", "1.5x Dealer income", "Street Boss"],
	["The Collector", 1, "Nobody skips a payment.", 10_000.0, "Enforcer", "1.5x Racket + raid shield", "Protection"],
	["The Mechanic", 2, "Chop shop runs itself.", 8_000.0, "Night Shift", "1.5x Chop Shop + auto-buy after 1st prestige", "Night Shift"],
	["Lucky Sal", 3, "He's never lost a bet.", 4_000.0, "Bookmaker", "1.5x Betting", "Bookmaker"],
	["Clean Carl", 4, "Everything's legitimate.", 50_000.0, "Front Man", "Heat forecast + rescue", "The Lawyer"],
	["The Accountant", 5, "Makes debts disappear.", 65_000.0, "Fixer", "1.5x Loan Shark + auto-buy after 1st prestige", "Automation"],
	["Maxine the Dealer", 6, "House always wins.", 500_000_000.0, "Pit Boss", "Boosts manager behaviors", "Pit Boss"],
	["The Promoter", 7, "VIP list only.", 4_000_000_000.0, "Club King", "Heat autopilot", "Club King"],
	["The Smuggler", 8, "Containers arrive.", 30_000_000_000.0, "Dock Master", "Ops alerts", "Dock Master"],
	["The Broker", 9, "Supply chain optimization.", 250_000_000_000.0, "Arms Dealer", "Turf intel", "Arms Dealer"],
	["The Consigliere", 10, "Sees everything.", 2_000_000_000_000.0, "Underboss", "Prestige advisory", "Underboss"],
	["Rudy Riches", 10, "Knows when to cash out.", 8_000_000_000_000.0, "Money Guy", "Prestige strategist", "Money Guy"],
	["Rob Revenue", 10, "Reads every dollar.", 12_000_000_000_000.0, "Numbers Guy", "Empire dashboard", "Numbers Guy"],
]


static func make_managers() -> Array[Manager]:
	var out: Array[Manager] = []
	for row in _RAW:
		out.append(Manager.new(row[0], row[1], row[2], row[3], row[4], row[5], row[6]))
	return out


static func is_unlocked(state, idx: int) -> bool:
	if idx < 0 or idx >= state.managers.size():
		return false
	if state.managers[idx].hired:
		return true
	if idx <= EARLY_TIER_MAX:
		var le: float = state.lifetime_earnings
		var heat: float = state.heat
		var heat_total: float = state.total_heat_generated
		match idx:
			0:
				return le >= 25_000.0
			1:
				return _owned(state, 1) >= 3
			2:
				return _owned(state, 2) >= 2
			3:
				return _owned(state, 3) >= 1 or le >= 25_000.0
			4:
				return heat >= 40.0 or heat_total >= 80.0
			5:
				return _building_types(state) >= 4 or le >= 200_000.0
	else:
		var gate: String = LATE_RANK_GATES.get(idx, "")
		if gate.is_empty():
			return false
		return _rank_meets(state, gate)
	return false


static func unlock_text(idx: int) -> String:
	match idx:
		0:
			return "Reach $25K lifetime earnings"
		1:
			return "Own 3 Protection Rackets"
		2:
			return "Own 2 Chop Shops"
		3:
			return "$25K lifetime OR 1 Betting Ring"
		4:
			return "Heat reaches 40%"
		5:
			return "$200K lifetime OR 4 building types"
		_:
			var gate: String = LATE_RANK_GATES.get(idx, "")
			if gate.is_empty():
				return "Unknown requirement"
			return "Reach rank %s" % gate


static func can_hire(state, idx: int) -> bool:
	if idx < 0 or idx >= state.managers.size():
		return false
	if state.managers[idx].hired:
		return false
	if not is_unlocked(state, idx):
		return false
	return state.balance >= state.managers[idx].cost


static func _owned(state, idx: int) -> int:
	if idx < state.buildings.size():
		return state.buildings[idx].owned
	return 0


static func _building_types(state) -> int:
	var n := 0
	for b in state.buildings:
		if b.owned > 0:
			n += 1
	return n


static func _rank_meets(state, required: String) -> bool:
	return Prestige.rank_index(Prestige.get_rank(state.lifetime_tokens)) >= Prestige.rank_index(required)
