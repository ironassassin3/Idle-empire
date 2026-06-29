class_name ShopState
extends RefCounted

var offers: Array = []
var frozen: bool = false


func duplicate_shop() -> ShopState:
	var copy := ShopState.new()
	copy.offers = offers.duplicate()
	copy.frozen = frozen
	return copy
