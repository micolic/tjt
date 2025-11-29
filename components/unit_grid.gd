class_name UnitGrid
extends Node

signal unit_grid_changed

@export var size: Vector2i

var units: Dictionary

## Initializes the grid dictionary with empty slots for each tile.
func _ready() -> void:
	for i in range(size.x):
		for j in range(size.y):
			units[Vector2i(i, j)] = null

## Adds a unit to the specified tile and emits a change signal.
func add_unit(tile: Vector2i, unit: Node) -> void:
	units[tile] = unit
	unit_grid_changed.emit()

## Removes a unit from the specified tile and emits a change signal.
func remove_unit(tile: Vector2i) -> void:
	if not units.has(tile):
		return
	
	var unit := units[tile] as Node

	if not unit:
		return
	
	units[tile] = null
	unit_grid_changed.emit()

## Returns true if the specified tile is occupied by a unit.
func is_tile_occupied(tile: Vector2i) -> bool:
	return units[tile] != null

## Returns true if all tiles in the grid are occupied.
func is_grid_full() -> bool:
	return units.keys().all(is_tile_occupied)

## Returns the first available (empty) tile in the grid, or (-1, -1) if full.
func get_first_available_tile() -> Vector2i:
	for tile in units.keys():
		if not is_tile_occupied(tile):
			return tile
	return Vector2i(-1, -1)

## Returns an array of all units currently in the grid.
func get_all_units() -> Array:
	var unit_list = []

	for unit in units.values():
		if unit:
			unit_list.append(unit)
	return unit_list
