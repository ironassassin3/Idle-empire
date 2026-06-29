class_name EconomyRules
extends RefCounted

static func level_from_xp(xp: int) -> int:
	var level := 1
	for i in range(1, SimConstants.LEVEL_THRESHOLDS.size()):
		if xp >= SimConstants.LEVEL_THRESHOLDS[i]:
			level = i + 1
	return mini(level, SimConstants.MAX_LEVEL)


static func xp_to_next_level(level: int, xp: int) -> int:
	if level >= SimConstants.MAX_LEVEL:
		return 0
	var next_threshold: int = SimConstants.LEVEL_THRESHOLDS[level]
	return maxi(0, next_threshold - xp)


static func round_gold_payout(gold: int, won_last: bool, win_streak: int, loss_streak: int = 0) -> int:
	var payout := SimConstants.BASE_GOLD_PER_ROUND
	# Streak gold: a hot OR cold streak both pay a bonus — reward committing to a
	# win streak, or stabilizing and spiking out of a loss streak (classic
	# autobattler econ). Loss streaks mirror the existing win-streak bonus.
	if won_last:
		payout += mini(win_streak, SimConstants.WIN_STREAK_CAP)
	else:
		payout += mini(loss_streak, SimConstants.WIN_STREAK_CAP)
	var interest := mini(gold / SimConstants.INTEREST_DIVISOR, SimConstants.MAX_INTEREST)
	return payout + interest


static func hp_loss_on_defeat(enemy_survivors: int, enemy_star_total: int) -> int:
	var base := 2
	return base + enemy_survivors * 2 + enemy_star_total


static func round_xp_gain(won: bool) -> int:
	return 2 if won else 1
