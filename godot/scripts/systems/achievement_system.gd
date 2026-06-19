class_name AchievementSystem
extends RefCounted
## Achievement defs + checks — mirrors src/achievements.py (index-ordered for save compat).

const _TerritorySystem = preload("res://scripts/systems/territory_system.gd")

# [name, description, category, check_id]
const DEFS: Array = [
	["First Dollar", "Earn your first dollar", "money", "le_1"],
	["Pocket Change", "Reach $1,000 balance", "money", "bal_1k"],
	["Street Money", "Earn $10,000 lifetime", "money", "le_10k"],
	["Small Timer", "Earn $100,000 lifetime", "money", "le_100k"],
	["Millionaire", "Earn $1M lifetime", "money", "le_1m"],
	["Ten-Million Club", "Earn $10M lifetime", "money", "le_10m"],
	["Hundred-Mil Boss", "Earn $100M lifetime", "money", "le_100m"],
	["Billionaire", "Earn $1B lifetime", "money", "le_1b"],
	["Oligarch", "Earn $10B lifetime", "money", "le_10b"],
	["Trillionaire", "Earn $1T lifetime", "money", "le_1t"],
	["Quadrillionaire", "Earn $1Q lifetime", "money", "le_1q"],
	["High Roller", "Have $1M in the bank at once", "money", "bal_1m"],
	["Vault", "Have $1B in the bank at once", "money", "bal_1b"],
	["First Click", "Click once", "clicks", "clk_1"],
	["Two-Finger Typist", "Click 50 times", "clicks", "clk_50"],
	["Clicker", "Click 100 times", "clicks", "clk_100"],
	["Click Addict", "Click 500 times", "clicks", "clk_500"],
	["Click Machine", "Click 1,000 times", "clicks", "clk_1k"],
	["Click Enthusiast", "Click 5,000 times", "clicks", "clk_5k"],
	["Click God", "Click 10,000 times", "clicks", "clk_10k"],
	["Carpal Tunnel", "Click 50,000 times", "clicks", "clk_50k"],
	["One Hundred K", "Click 100,000 times", "clicks", "clk_100k"],
	["First Hire", "Own your first building", "building", "bld_1"],
	["Small Crew", "Own 10 buildings total", "building", "bld_10"],
	["Expanding Fast", "Own 25 buildings total", "building", "bld_25"],
	["Industrial Scale", "Own 50 buildings total", "building", "bld_50"],
	["Empire Builder", "Own 100 buildings total", "building", "bld_100"],
	["Big Spender", "Own 200 buildings total", "building", "bld_200"],
	["Megacorp", "Own 500 buildings total", "building", "bld_500"],
	["Corner King", "Own 25 Corner Dealers", "building", "bld_i0_25"],
	["Protection Mogul", "Own 25 Protection Rackets", "building", "bld_i1_25"],
	["Chop King", "Own 25 Chop Shops", "building", "bld_i2_25"],
	["High Stakes", "Own 10 Betting Rings", "building", "bld_i3_10"],
	["Pawnbroker", "Own 10 Pawn Shops", "building", "bld_i4_10"],
	["Loan Baron", "Own 5 Loan Shark Offices", "building", "bld_i5_5"],
	["House Always Wins", "Own a Casino", "building", "bld_i6_1"],
	["Made Man", "Own a Crime Syndicate HQ", "building", "bld_i10_1"],
	["Diversified", "Own at least 1 of every building", "building", "bld_all"],
	["Prestige!", "Complete your first prestige", "prestige", "prest_1"],
	["Second Wind", "Prestige twice", "prestige", "prest_2"],
	["Prestiged Pro", "Prestige 5 times", "prestige", "prest_5"],
	["Prestige Legend", "Prestige 10 times", "prestige", "prest_10"],
	["Infinite Loop", "Prestige 25 times", "prestige", "prest_25"],
	["Perk Collector", "Buy 3 prestige perks", "prestige", "perk_3"],
	["Full Perk Tree", "Buy 10 prestige perks", "prestige", "perk_10"],
	["Influential", "Earn 20 influence", "prestige", "inf_20"],
	["First Manager", "Hire your first manager", "manager", "mgr_1"],
	["Full Staff", "Hire 5 managers", "manager", "mgr_5"],
	["Fully Automated", "Hire all 13 managers", "manager", "mgr_13"],
	["Upgrade Rookie", "Purchase 3 upgrades", "building", "upg_3"],
	["Upgrade Hoarder", "Purchase 10 upgrades", "building", "upg_10"],
	["Max Research", "Purchase 20 upgrades", "building", "upg_20"],
	["Just Starting", "Play for 5 minutes", "time", "time_300"],
	["Committed", "Play for 30 minutes", "time", "time_1800"],
	["Veteran Boss", "Play for 2 hours", "time", "time_7200"],
	["Golden Coin Finder", "Catch a golden coin", "time", "coin_1"],
	["Coin Collector", "Catch 10 golden coins", "time", "coin_10"],
	["Whale", "Have $1T in the bank at once", "secret", "bal_1t"],
	["Speed Runner", "Prestige within 10 minutes", "secret", "speed_prest"],
	["No Manager Run", "Reach $1B with no managers hired", "secret", "nomgr_1b"],
	["The Phantom", "Earn $1M while offline", "secret", "offline_1m"],
	["Night Owl", "Buy the Off the Books (Kingpin) prestige perk", "secret", "perk_offline"],
	["First District", "Capture your first district", "territory", "terr_1"],
	["Expanding Turf", "Capture 5 territories", "territory", "terr_5"],
	["City Spreader", "Control half the city", "territory", "terr_half"],
	["City Dominator", "Control the entire city", "territory", "terr_full"],
	["First Blood", "Defeat your first rival syndicate", "rival", "riv_1"],
	["Rival Slayer", "Defeat 3 rival syndicates", "rival", "riv_3"],
	["Apex Predator", "Defeat 10 rival syndicates", "rival", "riv_10"],
	["Untouchable Boss", "Defeat all active rivals in one run", "rival", "riv_all"],
	["First Op", "Complete your first operation", "operations", "ops_1"],
	["Street Operative", "Complete 10 operations", "operations", "ops_10"],
	["Ghost Operative", "Complete 25 operations", "operations", "ops_25"],
	["Veteran Operative", "Complete 100 operations", "operations", "ops_100"],
]


static func make_achievements() -> Array:
	var out: Array = []
	for entry in DEFS:
		out.append({
			"name": entry[0],
			"description": entry[1],
			"category": entry[2],
			"check_id": entry[3],
			"earned": false,
		})
	return out


static func earned_count(achievements: Array) -> int:
	var n := 0
	for a in achievements:
		if typeof(a) == TYPE_DICTIONARY and bool(a.get("earned", false)):
			n += 1
	return n


static func income_mult(achievements: Array) -> float:
	return 1.0 + float(earned_count(achievements)) * 0.01


static func merge_save(achievements: Array, earned_list: Array) -> void:
	for i in mini(earned_list.size(), achievements.size()):
		if bool(earned_list[i]):
			achievements[i]["earned"] = true


static func to_save(achievements: Array) -> Array:
	var out: Array = []
	for a in achievements:
		out.append(bool(a.get("earned", false)))
	return out


static func check_and_earn(state) -> Array[String]:
	var newly: Array[String] = []
	for a in state.achievements:
		if bool(a.get("earned", false)):
			continue
		if _meets(state, str(a.get("check_id", ""))):
			a["earned"] = true
			newly.append(str(a.get("name", "")))
	return newly


static func _total_owned(state) -> int:
	var n := 0
	for b in state.buildings:
		n += b.owned
	return n


static func _bld(state, idx: int) -> int:
	if idx < 0 or idx >= state.buildings.size():
		return 0
	return state.buildings[idx].owned


static func _mgr_count(state) -> int:
	var n := 0
	for m in state.managers:
		if m.hired:
			n += 1
	return n


static func _upg_count(state) -> int:
	var n := 0
	for u in state.upgrades:
		if u.purchased:
			n += 1
	return n


static func _player_control_pct(state) -> float:
	var territories: Array = state.territories
	var total := territories.size()
	if total == 0:
		return 0.0
	return float(_TerritorySystem.player_district_count(territories)) / float(total)


static func _all_rivals_eliminated(state) -> bool:
	if state.rivals.is_empty():
		return false
	for r in state.rivals:
		if typeof(r) != TYPE_DICTIONARY:
			return false
		if str(r.get("status", "")) != "Eliminated":
			return false
	return true


static func _meets(state, check_id: String) -> bool:
	match check_id:
		"le_1": return state.lifetime_earnings >= 1.0
		"bal_1k": return state.balance >= 1_000.0
		"le_10k": return state.lifetime_earnings >= 10_000.0
		"le_100k": return state.lifetime_earnings >= 100_000.0
		"le_1m": return state.lifetime_earnings >= 1_000_000.0
		"le_10m": return state.lifetime_earnings >= 10_000_000.0
		"le_100m": return state.lifetime_earnings >= 100_000_000.0
		"le_1b": return state.lifetime_earnings >= 1_000_000_000.0
		"le_10b": return state.lifetime_earnings >= 10_000_000_000.0
		"le_1t": return state.lifetime_earnings >= 1_000_000_000_000.0
		"le_1q": return state.lifetime_earnings >= 1_000_000_000_000_000.0
		"bal_1m": return state.balance >= 1_000_000.0
		"bal_1b": return state.balance >= 1_000_000_000.0
		"clk_1": return state.click_count >= 1
		"clk_50": return state.click_count >= 50
		"clk_100": return state.click_count >= 100
		"clk_500": return state.click_count >= 500
		"clk_1k": return state.click_count >= 1_000
		"clk_5k": return state.click_count >= 5_000
		"clk_10k": return state.click_count >= 10_000
		"clk_50k": return state.click_count >= 50_000
		"clk_100k": return state.click_count >= 100_000
		"bld_1": return _total_owned(state) >= 1
		"bld_10": return _total_owned(state) >= 10
		"bld_25": return _total_owned(state) >= 25
		"bld_50": return _total_owned(state) >= 50
		"bld_100": return _total_owned(state) >= 100
		"bld_200": return _total_owned(state) >= 200
		"bld_500": return _total_owned(state) >= 500
		"bld_i0_25": return _bld(state, 0) >= 25
		"bld_i1_25": return _bld(state, 1) >= 25
		"bld_i2_25": return _bld(state, 2) >= 25
		"bld_i3_10": return _bld(state, 3) >= 10
		"bld_i4_10": return _bld(state, 4) >= 10
		"bld_i5_5": return _bld(state, 5) >= 5
		"bld_i6_1": return _bld(state, 6) >= 1
		"bld_i10_1": return _bld(state, 10) >= 1
		"bld_all":
			if state.buildings.size() < 11:
				return false
			for i in 11:
				if _bld(state, i) < 1:
					return false
			return true
		"prest_1": return state.prestige_count >= 1
		"prest_2": return state.prestige_count >= 2
		"prest_5": return state.prestige_count >= 5
		"prest_10": return state.prestige_count >= 10
		"prest_25": return state.prestige_count >= 25
		"perk_3": return state.perks_purchased.size() >= 3
		"perk_10": return state.perks_purchased.size() >= 10
		"inf_20": return state.prestige_tokens >= 20
		"mgr_1": return _mgr_count(state) >= 1
		"mgr_5": return _mgr_count(state) >= 5
		"mgr_13": return _mgr_count(state) >= 13
		"upg_3": return _upg_count(state) >= 3
		"upg_10": return _upg_count(state) >= 10
		"upg_20": return _upg_count(state) >= 20
		"time_300": return state.play_time >= 300.0
		"time_1800": return state.play_time >= 1800.0
		"time_7200": return state.play_time >= 7200.0
		"coin_1": return state.coins_caught >= 1
		"coin_10": return state.coins_caught >= 10
		"bal_1t": return state.balance >= 1_000_000_000_000.0
		"speed_prest": return state.prestige_count >= 1 and state.play_time < 600.0
		"nomgr_1b": return state.lifetime_earnings >= 1_000_000_000.0 and _mgr_count(state) == 0
		"offline_1m": return state.offline_gain >= 1_000_000.0
		"perk_offline": return "kp_ledger" in state.perks_purchased
		"terr_1": return state.total_territories_captured >= 1
		"terr_5": return state.total_territories_captured >= 5
		"terr_half": return _player_control_pct(state) >= 0.5
		"terr_full": return _player_control_pct(state) >= 1.0
		"riv_1": return state.total_rivals_defeated >= 1
		"riv_3": return state.total_rivals_defeated >= 3
		"riv_10": return state.total_rivals_defeated >= 10
		"riv_all": return _all_rivals_eliminated(state)
		"ops_1": return state.total_ops_completed >= 1
		"ops_10": return state.total_ops_completed >= 10
		"ops_25": return state.total_ops_completed >= 25
		"ops_100": return state.total_ops_completed >= 100
		_: return false
