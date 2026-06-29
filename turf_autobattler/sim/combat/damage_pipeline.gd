class_name DamagePipeline
extends RefCounted

const HOME_ATTACK_BONUS_PCT := 10


static func apply(attacker: CombatUnit, target: CombatUnit, turf_type: int) -> Dictionary:
	var raw := attacker.attack
	if turf_type == SimConstants.TurfCellType.HOME and attacker.team_id == SimConstants.TeamId.PLAYER:
		raw = int(round(float(raw) * (1.0 + float(HOME_ATTACK_BONUS_PCT) / 100.0)))
	var reduced := maxi(1, raw - int(floor(float(target.armor) * 0.5)))
	target.current_hp -= reduced
	if target.current_hp <= 0:
		target.current_hp = 0
		target.alive = false
	return {
		"source_id": attacker.instance_id,
		"target_id": target.instance_id,
		"amount": reduced,
		"remaining_hp": target.current_hp,
	}
