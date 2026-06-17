class_name BuildingDefs
extends RefCounted

## Static building table — keep in sync with src/buildings.py _DEFS.


static func make_buildings() -> Array[Building]:
	var out: Array[Building] = []
	for row in _RAW:
		out.append(Building.new(row[0], row[1], row[2], row[3], row[4], row[5], row[6]))
	return out


static func global_special_mult(buildings: Array[Building]) -> float:
	var mult := 1.0
	if buildings.size() > 8 and buildings[8].owned > 0:
		mult *= pow(1.02, buildings[8].owned)
	if buildings.size() > 10 and buildings[10].owned > 0:
		mult *= pow(1.1, buildings[10].owned)
	return mult


static func dealer_click_bonus(buildings: Array[Building]) -> float:
	if buildings.is_empty():
		return 0.0
	return float(buildings[0].owned) * GameConfig.CLICK_DEALER_BONUS


static func pawn_cost_reduction(buildings: Array[Building]) -> float:
	if buildings.size() <= 4:
		return 0.0
	var pawn := buildings[4]
	if pawn.owned <= 0:
		return 0.0
	return minf(0.50, 0.02 * pawn.owned)


static func casino_manager_bonus(buildings: Array[Building]) -> float:
	if buildings.size() <= 6:
		return 1.0
	var casino := buildings[6]
	if casino.owned <= 0:
		return 1.0
	return 1.0 + 0.10 * casino.owned


static func sync_racket_multiplier(buildings: Array[Building]) -> void:
	if buildings.size() < 2:
		return
	var dealer := buildings[0]
	var racket := buildings[1]
	if racket.owned > 0:
		dealer.income_multiplier = minf(2.0, 1.0 + 0.05 * racket.owned)
	else:
		dealer.income_multiplier = 1.0


const _RAW: Array = [
	["Corner Dealer", 10.0, 0.11, 1.15, "Moves product on the block", "dealer",
		"Click bonus: +0.10 cash per dealer owned"],
	["Protection Racket", 150.0, 0.48, 1.18, "Businesses pay for 'insurance'", "racket",
		"Multiplies Corner Dealer income ×1.05 per racket"],
	["Chop Shop", 2000.0, 9.24, 1.18, "Cars in, parts out, no questions", "chop",
		"10% chance each sec for a bonus payout (3× income)"],
	["Sports Betting Ring", 20000.0, 134.2, 1.18, "The house always wins", "betting",
		"Random jackpot every 30–90s: 60s of income instantly"],
	["Pawn Shop", 150000.0, 1330.0, 1.18, "No serial numbers, no problems", "pawn",
		"Reduces all upgrade costs by 2% per pawn shop"],
	["Loan Shark Office", 1200000.0, 15400.0, 1.20, "Generous terms. Very generous.", "loan",
		"Passive interest: +0.5% of balance per minute"],
	["Underground Casino", 10000000.0, 186000.0, 1.20, "High stakes, no tax man", "casino",
		"Boosts manager effectiveness by +10% per casino"],
	["Nightclub", 80000000.0, 2160000.0, 1.20, "Laundromat with a dance floor", "club",
		"Launders heat: -0.5 heat per second per nightclub"],
	["Dock Smuggling Op", 600000000.0, 23400000.0, 1.20, "Containers of plausible deniability", "dock",
		"Multiplies all passive income by ×1.02 per dock"],
	["Arms Broker", 5000000000.0, 283000000.0, 1.20, "Supply and demand, emphasis supply", "arms",
		"Generates 0.1 Influence fragments per hour per broker"],
	["Crime Syndicate HQ", 40000000000.0, 3290000000.0, 1.20, "The whole city answers to you", "hq",
		"Global multiplier: ×1.1 all income per HQ owned"],
]
