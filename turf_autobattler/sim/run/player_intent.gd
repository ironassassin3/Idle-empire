class_name PlayerIntent
extends RefCounted

var type: String = ""
var params: Dictionary = {}


static func make(intent_type: String, intent_params: Dictionary = {}) -> PlayerIntent:
	var intent := PlayerIntent.new()
	intent.type = intent_type
	intent.params = intent_params.duplicate()
	return intent
