class_name RunState
extends RefCounted

var seed: int = 1
var round: int = 1
var phase: int = SimConstants.RunPhase.RUN_INIT
var player_hp: int = SimConstants.STARTING_HP
var gold: int = SimConstants.STARTING_GOLD
var level: int = 1
var xp: int = 0
var win_streak: int = 0
var loss_streak: int = 0
var shop: ShopState = ShopState.new()
var bench: BenchState = BenchState.new()
var board: BoardState = BoardState.new()
var shop_pool: ShopPool = ShopPool.create_default()
var rng: SeededRNG = SeededRNG.new()
var units: Dictionary = {}
var next_instance_id: int = 1
var traits_cache: Array = []
var last_combat: CombatState = null
var last_combat_won: bool = false
var run_won: bool = false
var run_events: EventLog = EventLog.new()


func duplicate_state() -> RunState:
	var copy := RunState.new()
	copy.seed = seed
	copy.round = round
	copy.phase = phase
	copy.player_hp = player_hp
	copy.gold = gold
	copy.level = level
	copy.xp = xp
	copy.win_streak = win_streak
	copy.loss_streak = loss_streak
	copy.shop = shop.duplicate_shop()
	copy.bench = bench.duplicate_bench()
	copy.board = board.duplicate_board()
	copy.shop_pool = ShopPool.create_default()
	copy.shop_pool.remaining = shop_pool.remaining.duplicate()
	copy.rng = rng.duplicate_rng()
	copy.next_instance_id = next_instance_id
	copy.traits_cache = traits_cache.duplicate(true)
	copy.last_combat_won = last_combat_won
	copy.run_won = run_won
	copy.run_events = run_events.duplicate_log()
	for key in units.keys():
		var unit: UnitInstance = units[key]
		copy.units[key] = unit.duplicate_unit()
	if last_combat != null:
		copy.last_combat = last_combat.duplicate_state()
	return copy


func get_board_units() -> Array[UnitInstance]:
	var result: Array[UnitInstance] = []
	for key in board.slots.keys():
		var instance_id: int = board.slots[key]
		if units.has(instance_id):
			result.append(units[instance_id])
	return result


func refresh_traits() -> void:
	traits_cache = TraitCalculator.active_traits_for_units(get_board_units())
