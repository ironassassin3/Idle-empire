class_name IsoBoardPresenter
extends IBoardPresenter

const TILE_W := 64.0
const TILE_H := 32.0


func grid_to_world(col: int, row: int) -> Vector2:
	return Vector2((col - row) * TILE_W * 0.5, (col + row) * TILE_H * 0.5)


func tile_size() -> Vector2:
	return Vector2(TILE_W, TILE_H)
