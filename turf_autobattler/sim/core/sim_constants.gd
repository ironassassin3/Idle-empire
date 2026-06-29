class_name SimConstants
extends RefCounted

## Global sim constants — no Node dependencies.

const LOG_VERSION := 1
const TICKS_PER_SECOND := 10
const MAX_COMBAT_TICKS := 600

const BOARD_WIDTH := 4
const BOARD_HEIGHT := 4
const BENCH_SLOTS := 9
const SHOP_SLOTS := 5

const STARTING_HP := 100
const MAX_ROUNDS := 15
const STARTING_GOLD := 0
const BASE_GOLD_PER_ROUND := 5
const REROLL_COST := 2
const XP_BUY_COST := 4
const XP_BUY_AMOUNT := 4
const MAX_LEVEL := 8
const INTEREST_DIVISOR := 10
const MAX_INTEREST := 5
const WIN_STREAK_CAP := 3

const LEVEL_THRESHOLDS := [0, 2, 6, 10, 20, 36, 56, 80, 100]
const BOARD_CAP_BY_LEVEL := [0, 1, 2, 3, 4, 5, 6, 7, 8]

enum RunPhase {
	RUN_INIT,
	PLANNING,
	COMBAT_RESOLVE,
	COMBAT_PLAYBACK,
	ROUND_RESOLVE,
	RUN_END,
}

enum TurfCellType { HOME, CONTESTED, NEUTRAL }

enum CombatOutcome { PENDING, PLAYER, ENEMY, DRAW }

enum TeamId { PLAYER, ENEMY }

enum RejectReason {
	OK,
	WRONG_PHASE,
	NOT_ENOUGH_GOLD,
	BENCH_FULL,
	BOARD_FULL,
	INVALID_SLOT,
	UNKNOWN_INSTANCE,
	EMPTY_SHOP_SLOT,
	ALREADY_MAX_LEVEL,
	NOT_YOUR_BOARD,
}
