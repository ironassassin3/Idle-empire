class_name Upgrade
extends RefCounted

var display_name: String
var description: String
var cost: float
var effect_key: String
var purchased: bool = false


func _init(p_name: String, p_desc: String, p_cost: float, p_key: String) -> void:
	display_name = p_name
	description = p_desc
	cost = p_cost
	effect_key = p_key
