class_name UnitGrid
extends Node

## Footprint-aware unit grid. Cells are 8 px logical tiles (see PlayArea.GRID_CELL_PX);
## each unit occupies a rectangle of cells given by its stats.footprint (default 4x4).
## `units` maps EVERY occupied cell to the unit; `unit_anchors` maps a unit to its
## anchor (top-left) cell so multi-cell units can be moved/removed cleanly.

signal unit_grid_changed

const DEFAULT_FOOTPRINT := Vector2i(4, 4)

@export var size: Vector2i

var units: Dictionary
var unit_anchors: Dictionary

## Initializes the grid dictionary with empty slots for each tile.
func _ready() -> void:
	for i in range(size.x):
		for j in range(size.y):
			units[Vector2i(i, j)] = null

## Returns the footprint of a unit node (falls back to 4x4 for stat-less nodes).
static func footprint_of(unit: Node) -> Vector2i:
	if unit and "stats" in unit and unit.stats and "footprint" in unit.stats:
		return unit.stats.footprint
	return DEFAULT_FOOTPRINT

## Adds a unit anchored at `anchor`, occupying its whole footprint.
func add_unit(anchor: Vector2i, unit: Node) -> void:
	var footprint := footprint_of(unit)
	for x in range(anchor.x, anchor.x + footprint.x):
		for y in range(anchor.y, anchor.y + footprint.y):
			var cell := Vector2i(x, y)
			if units.has(cell):
				units[cell] = unit
	unit_anchors[unit] = anchor
	unit_grid_changed.emit()

## Removes the unit occupying `cell` (any cell of its footprint) from the grid.
func remove_unit(cell: Vector2i) -> void:
	if not units.has(cell):
		return
	var unit = units[cell]
	if unit == null:
		return
	# Guard against freed objects (double-kill on same frame)
	if not is_instance_valid(unit):
		_clear_cells_of(unit)
		unit_anchors.erase(unit)
		unit_grid_changed.emit()
		return
	remove_unit_node(unit)

## Removes a specific unit from the grid, clearing all its cells.
func remove_unit_node(unit: Node) -> void:
	if unit == null:
		return
	_clear_cells_of(unit)
	unit_anchors.erase(unit)
	unit_grid_changed.emit()

## Clears every cell currently pointing at `unit`.
func _clear_cells_of(unit: Node) -> void:
	for cell in units.keys():
		if units[cell] == unit:
			units[cell] = null

## Removes all units from the grid.
func clear() -> void:
	for cell in units.keys():
		units[cell] = null
	unit_anchors.clear()
	unit_grid_changed.emit()

## Returns true if the specified cell is occupied by a unit.
func is_tile_occupied(tile: Vector2i) -> bool:
	return units.get(tile) != null

## Returns the unit occupying `cell`, or null.
func get_unit_at(cell: Vector2i) -> Node:
	return units.get(cell)

## Returns the anchor (top-left cell) of a unit, or (-1, -1) if not in the grid.
func get_unit_anchor(unit: Node) -> Vector2i:
	return unit_anchors.get(unit, Vector2i(-1, -1))

## Returns true if every cell of a footprint anchored at `anchor` is free and in bounds.
## `ignore` (optional) treats cells occupied by that unit as free (for move/swap checks).
func is_area_free(anchor: Vector2i, footprint: Vector2i, ignore: Node = null) -> bool:
	if anchor.x < 0 or anchor.y < 0 \
			or anchor.x + footprint.x > size.x or anchor.y + footprint.y > size.y:
		return false
	for x in range(anchor.x, anchor.x + footprint.x):
		for y in range(anchor.y, anchor.y + footprint.y):
			var occupant = units.get(Vector2i(x, y))
			if occupant != null and occupant != ignore:
				return false
	return true

## Returns all distinct units overlapping a footprint anchored at `anchor`.
func get_units_in_area(anchor: Vector2i, footprint: Vector2i) -> Array:
	var found := []
	for x in range(anchor.x, anchor.x + footprint.x):
		for y in range(anchor.y, anchor.y + footprint.y):
			var occupant = units.get(Vector2i(x, y))
			if occupant != null and not found.has(occupant):
				found.append(occupant)
	return found

## Returns true if there is no room left for a standard (4x4) unit.
func is_grid_full() -> bool:
	return get_first_available_tile() == Vector2i(-1, -1)

## Returns the first anchor where `footprint` fits, or (-1, -1) if none.
func get_first_available_tile(footprint: Vector2i = DEFAULT_FOOTPRINT) -> Vector2i:
	for j in range(0, size.y - footprint.y + 1):
		for i in range(0, size.x - footprint.x + 1):
			var anchor := Vector2i(i, j)
			if is_area_free(anchor, footprint):
				return anchor
	return Vector2i(-1, -1)

## Returns an array of all distinct units currently in the grid.
func get_all_units() -> Array:
	var unit_list = []
	for unit in unit_anchors.keys():
		if unit != null and is_instance_valid(unit):
			unit_list.append(unit)
	return unit_list
