class_name Manager
extends RefCounted

var display_name: String
var building_index: int
var flavor: String
var cost: float
var title: String
var bonus_desc: String
var specialty: String
var hired: bool = false


func _init(
	p_name: String,
	p_bld: int,
	p_flavor: String,
	p_cost: float,
	p_title: String,
	p_bonus: String,
	p_specialty: String
) -> void:
	display_name = p_name
	building_index = p_bld
	flavor = p_flavor
	cost = p_cost
	title = p_title
	bonus_desc = p_bonus
	specialty = p_specialty
