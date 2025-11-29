class_name PlayArea
extends TileMapLayer

@export var unit_grid: UnitGrid
@export var tile_highlighter: TileHighlighter

## Converts a global position to a tile coordinate in this play area.
func get_tile_from_global(global: Vector2) -> Vector2i:
	return local_to_map(to_local(global))

## Converts a tile coordinate to a global position in this play area.
func get_global_from_tile(tile: Vector2i) -> Vector2:
	return to_global(map_to_local(tile))

## Returns the tile currently hovered by the mouse in this play area.
func get_hovered_tile() -> Vector2i:
	return local_to_map(get_local_mouse_position())

## Returns true if the given tile is within the play area bounds.
func is_tile_within_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < unit_grid.size.x and tile.y >= 0 and tile.y < unit_grid.size.y
