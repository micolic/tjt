class_name PlayArea
extends TileMapLayer

## Logical placement grid cell size in pixels. The visual tilemap stays at 32 px,
## but placement snaps to a 4x finer 8 px grid so units can have different
## footprints (standard unit = 4x4 cells = 32 px; see UnitStats.footprint).
const GRID_CELL_PX := 8.0

@export var unit_grid: UnitGrid
@export var tile_highlighter: TileHighlighter

## Converts a global position to a logical (8 px) tile coordinate in this play area.
func get_tile_from_global(global: Vector2) -> Vector2i:
	var local := to_local(global)
	return Vector2i(floori(local.x / GRID_CELL_PX), floori(local.y / GRID_CELL_PX))

## Converts a logical tile coordinate to the global position of the cell's center.
func get_global_from_tile(tile: Vector2i) -> Vector2:
	return to_global(
		Vector2(tile) * GRID_CELL_PX + Vector2(GRID_CELL_PX, GRID_CELL_PX) * 0.5
	)

## Returns the logical tile currently hovered by the mouse in this play area.
func get_hovered_tile() -> Vector2i:
	var local := get_local_mouse_position()
	return Vector2i(floori(local.x / GRID_CELL_PX), floori(local.y / GRID_CELL_PX))

## Returns true if the given logical tile is within the play area bounds.
func is_tile_within_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < unit_grid.size.x and tile.y >= 0 and tile.y < unit_grid.size.y

## Returns true if a footprint anchored at `anchor` fits entirely within bounds.
func is_area_within_bounds(anchor: Vector2i, footprint: Vector2i) -> bool:
	return anchor.x >= 0 and anchor.y >= 0 \
		and anchor.x + footprint.x <= unit_grid.size.x \
		and anchor.y + footprint.y <= unit_grid.size.y

## Returns the footprint center (in global pixels) for the given anchor.
func get_footprint_center(anchor: Vector2i, footprint: Vector2i) -> Vector2:
	var local_center := Vector2(anchor) * GRID_CELL_PX + Vector2(footprint) * GRID_CELL_PX * 0.5
	return to_global(local_center)

## Returns the anchor (top-left cell) so that the footprint is centered on the
## cell under the cursor. This gives 8px (1-cell) snap resolution instead of
## footprint-size jumps, making drag feel smoother.
## Clamped so the whole footprint stays inside the grid.
func get_anchor_for_global(global: Vector2, footprint: Vector2i) -> Vector2i:
	var tile := get_tile_from_global(global)
	var anchor := Vector2i(
		tile.x - footprint.x / 2,
		tile.y - footprint.y / 2
	)
	anchor.x = clampi(anchor.x, 0, maxi(unit_grid.size.x - footprint.x, 0))
	anchor.y = clampi(anchor.y, 0, maxi(unit_grid.size.y - footprint.y, 0))
	return anchor

## Returns the global position for a unit node anchored at `anchor`.
## The unit's origin is the footprint center, and the sprite is centered on that
## point so the unit sits centered in its footprint.
func get_unit_position(anchor: Vector2i, footprint: Vector2i) -> Vector2:
	return get_footprint_center(anchor, footprint)
