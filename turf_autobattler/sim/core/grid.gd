class_name SimGrid
extends RefCounted

## Grid origin is bottom-left: (0,0) is front-left for the player board.


static func is_in_bounds(pos: Vector2i, width: int, height: int) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height


static func pos_key(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]


static func pos_from_key(key: String) -> Vector2i:
	var parts := key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


static func depth_sort_key(col: int, row: int, width: int) -> float:
	return float(row * width + col)


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
