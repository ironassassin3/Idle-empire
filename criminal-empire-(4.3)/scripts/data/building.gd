class_name Building
extends RefCounted
## One criminal front business — mirrors src/buildings.py Building dataclass.

var display_name: String
var base_cost: float
var base_income: float
var cost_scale: float
var description: String
var icon_key: String
var special: String
var owned: int = 0
var income_multiplier: float = 1.0
var special_timer: float = 0.0


func _init(
	p_name: String,
	p_cost: float,
	p_income: float,
	p_scale: float,
	p_desc: String,
	p_icon: String,
	p_special: String
) -> void:
	display_name = p_name
	base_cost = p_cost
	base_income = p_income
	cost_scale = p_scale
	description = p_desc
	icon_key = p_icon
	special = p_special


func current_cost() -> float:
	return base_cost * pow(cost_scale, owned)


func income_per_second() -> float:
	return base_income * owned * income_multiplier


func cost_for_n(n: int) -> float:
	if n <= 0:
		return 0.0
	var s := cost_scale
	return base_cost * pow(s, owned) * (pow(s, n) - 1.0) / (s - 1.0)
