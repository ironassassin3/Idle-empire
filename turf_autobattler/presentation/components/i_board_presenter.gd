class_name IBoardPresenter
extends RefCounted

## Presentation contract for 2.5D board modes (handoff §14).


func grid_to_world(col: int, row: int) -> Vector2:
	return Vector2.ZERO


func depth_sort_key(col: int, row: int) -> float:
	return SimGrid.depth_sort_key(col, row, SimConstants.BOARD_WIDTH)


func tile_size() -> Vector2:
	return Vector2(64, 32)
