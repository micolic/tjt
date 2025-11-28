class_name UnitMover
extends Node

@export var play_areas: Array[PlayArea]

## Called when the node enters the scene tree. Sets up all units in the scene.
func _ready() -> void:
	var units := get_tree().get_nodes_in_group("units")
	for unit: Unit in units:
		setup_unit(unit)


## Connects drag-and-drop signals for a given unit to the mover's handlers.
func setup_unit(unit: Unit) -> void:
	unit.drag_and_drop.drag_started.connect(_on_unit_drag_started.bind(unit))
	unit.drag_and_drop.drag_canceled.connect(_on_unit_drag_canceled.bind(unit))
	unit.drag_and_drop.dropped.connect(_on_unit_dropped.bind(unit))

## Enables or disables tile highlighters for all play areas.
func _set_highlighters(enabled: bool) -> void:
	# Only enable highlighter for GameArea (index 1), not EnemyArea (index 0)
	for i in play_areas.size():
		if i == 0:  # Skip EnemyArea
			continue
		play_areas[i].tile_highlighter.enabled = enabled

## Returns the index of the play area containing the given global position.
func _get_play_area_for_position(global: Vector2) -> int:
	var dropped_area_index := -1

	for i in play_areas.size():
		var tile := play_areas[i].get_tile_from_global(global)
		if play_areas[i].is_tile_within_bounds(tile):
			dropped_area_index = i
		
	return dropped_area_index


## Resets a unit to its starting position and updates the grid.
func _reset_unit_to_starting_position(starting_position: Vector2, unit: Unit) -> void:
	var i := _get_play_area_for_position(starting_position)
	if i == -1 or i >= play_areas.size():
		unit.reset_after_dragging(starting_position)
		return
	var tile := play_areas[i].get_tile_from_global(starting_position)

	unit.reset_after_dragging(starting_position)
	play_areas[i].unit_grid.add_unit(tile, unit)

## Moves a unit to a specific tile in a play area and updates its position.
func _move_unit(unit: Unit, play_area: PlayArea, tile: Vector2i) -> void:
	play_area.unit_grid.add_unit(tile, unit)
	unit.global_position = play_area.get_global_from_tile(tile) - Arena.HALF_CELL_SIZE
	unit.reparent(play_area.unit_grid)

## Handler for when a unit starts being dragged. Removes it from its old tile.
func _on_unit_drag_started(unit: Unit) -> void:
	_set_highlighters(true)

	var i := _get_play_area_for_position(unit.global_position)
	if i > -1:
		var tile := play_areas[i].get_tile_from_global(unit.global_position)
		play_areas[i].unit_grid.remove_unit(tile)

## Handler for when a unit drag is canceled. Resets the unit to its original position.
func _on_unit_drag_canceled(starting_position: Vector2, unit: Unit) -> void:
	_set_highlighters(false)
	_reset_unit_to_starting_position(starting_position, unit)

## Handler for when a unit is dropped. Moves the unit or swaps if occupied.
func _on_unit_dropped(starting_position: Vector2, unit: Unit) -> void:
	_set_highlighters(false)

	var old_area_index := _get_play_area_for_position(starting_position)
	var drop_area_index := _get_play_area_for_position(unit.get_global_mouse_position())

	# Prevent dropping on EnemyArea (index 0)
	if drop_area_index == -1 or drop_area_index == 0:
		_reset_unit_to_starting_position(starting_position, unit)
		return
	
	var new_area := play_areas[drop_area_index]
	var new_tile := new_area.get_hovered_tile()
	
	# If old_area_index is -1, unit was not in any play area (shouldn't happen, but safety check)
	if old_area_index == -1:
		# Only place if tile is not occupied
		if not new_area.unit_grid.is_tile_occupied(new_tile):
			_move_unit(unit, new_area, new_tile)
		else:
			unit.reset_after_dragging(starting_position)
		return

	var old_area := play_areas[old_area_index]
	var old_tile := old_area.get_tile_from_global(starting_position)

	# Check if the destination tile is occupied
	if new_area.unit_grid.is_tile_occupied(new_tile):
		var target_unit: Unit = new_area.unit_grid.units[new_tile]
		
		# Remove both units from their current positions
		new_area.unit_grid.remove_unit(new_tile)
		old_area.unit_grid.remove_unit(old_tile)
		
		# Swap: move dragged unit to destination, and target unit to origin
		_move_unit(unit, new_area, new_tile)
		_move_unit(target_unit, old_area, old_tile)
	else:
		# No swap needed, just move the unit
		_move_unit(unit, new_area, new_tile)
