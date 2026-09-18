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
	if buildings.size() > 8:
		mult *= dock_income_mult(buildings[8].owned)
	if buildings.size() > 10:
		mult *= hq_income_mult(buildings[10].owned)
	return mult


## Compounding: each dock multiplies all passive income by 1.015.
static func dock_income_mult(docks: int) -> float:
	return pow(1.015, maxi(docks, 0))


## Compounding: each HQ multiplies all income by 1.06.
static func hq_income_mult(hqs: int) -> float:
	return pow(1.06, maxi(hqs, 0))


static func dealer_click_bonus(buildings: Array[Building]) -> float:
	if buildings.is_empty():
		return 0.0
	return float(buildings[0].owned) * GameConfig.CLICK_DEALER_BONUS


static func pawn_cost_reduction(buildings: Array[Building]) -> float:
	if buildings.size() <= 4:
		return 0.0
	return pawn_reduction_for(buildings[4].owned)


static func pawn_reduction_for(pawns: int) -> float:
	return clampf(0.02 * pawns, 0.0, 0.50)


static func casino_manager_bonus(buildings: Array[Building]) -> float:
	if buildings.size() <= 6:
		return 1.0
	return casino_bonus_for(buildings[6].owned)


static func casino_bonus_for(casinos: int) -> float:
	return 1.0 + 0.10 * maxi(casinos, 0)


const RACKET_STEP := 0.05
const RACKET_CAP := 2.0


## Additive, not compounding: 1 + 0.05 per racket, capped at ×2 (20 rackets).
static func racket_dealer_multiplier(rackets: int) -> float:
	if rackets <= 0:
		return 1.0
	return minf(RACKET_CAP, 1.0 + RACKET_STEP * rackets)


static func sync_racket_multiplier(buildings: Array[Building]) -> void:
	if buildings.size() < 2:
		return
	buildings[0].income_multiplier = racket_dealer_multiplier(buildings[1].owned)


# Income/$ rises about 20% per tier after Protection Racket. This keeps each new
# tier attractive without the old ~45% curve collapsing post-prestige cadence.
# Keep in sync with src/buildings.py _DEFS.
const _RAW: Array = [
	["Corner Dealer", 10.0, 0.0290, 1.15, "Moves product on the block", "dealer",
		"Click bonus: +$0.10 cash per dealer owned"],
	["Protection Racket", 150.0, 0.1090, 1.18, "Businesses pay for 'insurance'", "racket",
		"+0.05× Corner Dealer income per racket (cap ×2)"],
	["Chop Shop", 2000.0, 1.77, 1.18, "Cars in, parts out, no questions", "chop",
		"8% chance/sec: 2× income bonus payout"],
	["Sports Betting Ring", 20000.0, 21.9, 1.18, "The house always wins", "betting",
		"Jackpot every 60–150s: 30s income instantly"],
	["Pawn Shop", 150000.0, 185.0, 1.18, "No serial numbers, no problems", "pawn",
		"−2% all upgrade costs per pawn (cap −50%)"],
	["Loan Shark Office", 1200000.0, 1820.0, 1.20, "Generous terms. Very generous.", "loan",
		"+0.05% balance/min per office (max 2 offices)"],
	["Underground Casino", 10000000.0, 18670.0, 1.20, "High stakes, no tax man", "casino",
		"+10% manager income per casino (when hired)"],
	["Nightclub", 80000000.0, 184250.0, 1.20, "Laundromat with a dance floor", "club",
		"Launders heat: −0.5/sec per nightclub"],
	["Dock Smuggling Op", 600000000.0, 1698400.0, 1.20, "Containers of plausible deniability", "dock",
		"×1.015 all passive income per dock"],
	["Arms Broker", 5000000000.0, 17460300.0, 1.20, "Supply and demand, emphasis supply", "arms",
		"+0.1 Influence/hour per broker"],
	["Crime Syndicate HQ", 40000000000.0, 172470100.0, 1.20, "The whole city answers to you", "hq",
		"×1.06 all income per HQ owned"],
]
