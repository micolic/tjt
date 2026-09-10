class_name UnitMover
extends Node

@export var play_areas: Array[PlayArea]

var _dragging_area: PlayArea = null
var _last_snap_anchor: Vector2i = Vector2i(-1, -1)


## Called when the node enters the scene tree. Sets up all units in the scene.
func _ready() -> void:
	var units := get_tree().get_nodes_in_group("units")
	for unit in units:
		setup_unit(unit)


## Connects drag-and-drop signals for a given unit to the mover's handlers.
func setup_unit(unit) -> void:
	# Only setup drag-and-drop for units that have it (player units)
	if unit.has_node("DragAndDrop"):
		unit.drag_and_drop.drag_started.connect(_on_unit_drag_started.bind(unit))
		unit.drag_and_drop.drag_canceled.connect(_on_unit_drag_canceled.bind(unit))
		unit.drag_and_drop.dropped.connect(_on_unit_dropped.bind(unit))

const DEFAULT_FOOTPRINT := Vector2i(4, 4)


## Enables or disables tile highlighters for all play areas.
## The footprint is synced so the highlighted area matches the dragged/placed unit.
func _set_highlighters(enabled: bool, footprint: Vector2i = DEFAULT_FOOTPRINT) -> void:
	# Only enable highlighter for GameArea (index 1), not EnemyArea (index 0)
	for i in play_areas.size():
		if i == 0:  # Skip EnemyArea
			continue
		play_areas[i].tile_highlighter.footprint = footprint
		play_areas[i].tile_highlighter.reset_tracking()
		play_areas[i].tile_highlighter.enabled = enabled


## Stops highlighters from tracking the dragged unit.
func _clear_highlighter_tracking() -> void:
	for i in play_areas.size():
		if i == 0:  # Skip EnemyArea
			continue
		play_areas[i].tile_highlighter.tracking_target = null

## Returns the index of the play area containing the given global position.
func _get_play_area_for_position(global: Vector2) -> int:
	var dropped_area_index := -1

	for i in play_areas.size():
		var tile := play_areas[i].get_tile_from_global(global)
		if play_areas[i].is_tile_within_bounds(tile):
			dropped_area_index = i
		
	return dropped_area_index


## Resets a unit to its starting position and updates the grid.
func _reset_unit_to_starting_position(starting_position: Vector2, unit) -> void:
	var i := _get_play_area_for_position(starting_position)
	if i == -1 or i >= play_areas.size():
		unit.reset_after_dragging(starting_position)
		return
	var footprint := UnitGrid.footprint_of(unit)
	# starting_position is the unit origin (footprint center) — recover the anchor
	var anchor := play_areas[i].get_anchor_for_global(starting_position, footprint)

	unit.reset_after_dragging(starting_position)
	play_areas[i].unit_grid.add_unit(anchor, unit)

## Moves a unit to a specific anchor in a play area and updates its position.
func _move_unit(unit, play_area: PlayArea, anchor: Vector2i) -> void:
	var footprint := UnitGrid.footprint_of(unit)
	play_area.unit_grid.add_unit(anchor, unit)
	unit.global_position = play_area.get_unit_position(anchor, footprint)
	unit.reparent(play_area.unit_grid)

## Returns the snapped global position for a dragged unit based on the mouse tile.
## The bound unit argument is passed last by GDScript's Callable.bind.
func _snap_position_for(mouse_global: Vector2, unit) -> Vector2:
	if not _dragging_area:
		return unit.global_position
	var footprint := UnitGrid.footprint_of(unit)
	var area_index := _get_play_area_for_position(mouse_global)
	if area_index > 0:
		_dragging_area = play_areas[area_index]
	var anchor := _dragging_area.get_anchor_for_global(mouse_global, footprint)
	if anchor != _last_snap_anchor:
		_last_snap_anchor = anchor
	return _dragging_area.get_unit_position(anchor, footprint)


## Handler for when a unit starts being dragged. Removes it from its old cells.
func _on_unit_drag_started(unit) -> void:
	var footprint := UnitGrid.footprint_of(unit)
	_set_highlighters(true, footprint)
	_last_snap_anchor = Vector2i(-1, -1)

	var start_area_index := _get_play_area_for_position(unit.global_position)
	if start_area_index > 0:
		_dragging_area = play_areas[start_area_index]
	unit.drag_and_drop.snap_position = _snap_position_for.bind(unit)

	if start_area_index > -1:
		play_areas[start_area_index].unit_grid.remove_unit_node(unit)

## Handler for when a unit drag is canceled. Resets the unit to its original position.
func _on_unit_drag_canceled(starting_position: Vector2, unit) -> void:
	unit.drag_and_drop.snap_position = Callable()
	_dragging_area = null
	_set_highlighters(false)
	_clear_highlighter_tracking()
	_reset_unit_to_starting_position(starting_position, unit)

## Handler for when a unit is dropped. Moves the unit or swaps if occupied.
func _on_unit_dropped(starting_position: Vector2, unit) -> void:
	unit.drag_and_drop.snap_position = Callable()
	_dragging_area = null
	_set_highlighters(false)
	_clear_highlighter_tracking()

	var old_area_index := _get_play_area_for_position(starting_position)
	var drop_area_index := _get_play_area_for_position(unit.get_global_mouse_position())

	# Prevent dropping on EnemyArea (index 0)
	if drop_area_index == -1 or drop_area_index == 0:
		_reset_unit_to_starting_position(starting_position, unit)
		return

	var new_area := play_areas[drop_area_index]
	var footprint := UnitGrid.footprint_of(unit)
	# Anchor from the unit's dragged position (its footprint center), not the raw
	# mouse — the unit lands exactly where the player sees it, regardless of grab offset.
	var new_anchor := new_area.get_anchor_for_global(unit.global_position, footprint)

	# If old_area_index is -1, unit was not in any play area (shouldn't happen, but safety check)
	if old_area_index == -1:
		if new_area.unit_grid.is_area_free(new_anchor, footprint):
			_move_unit(unit, new_area, new_anchor)
		else:
			unit.reset_after_dragging(starting_position)
		return

	var old_area := play_areas[old_area_index]
	var old_anchor := old_area.get_anchor_for_global(starting_position, footprint)

	var occupants: Array = new_area.unit_grid.get_units_in_area(new_anchor, footprint)
	if occupants.is_empty():
		# Destination free — just move the unit
		_move_unit(unit, new_area, new_anchor)
	elif occupants.size() == 1:
		# Exactly one unit in the way — try to swap it back to the dragged unit's old spot
		var target_unit = occupants[0]
		var target_footprint := UnitGrid.footprint_of(target_unit)
		new_area.unit_grid.remove_unit_node(target_unit)
		if new_area.unit_grid.is_area_free(new_anchor, footprint) \
				and old_area.unit_grid.is_area_free(old_anchor, target_footprint):
			_move_unit(unit, new_area, new_anchor)
			_move_unit(target_unit, old_area, old_anchor)
		else:
			# Swap impossible (footprints don't fit) — restore both
			_restore_occupant(target_unit, new_area)
			_reset_unit_to_starting_position(starting_position, unit)
	else:
		# Multiple units in the way — no swap possible
		_reset_unit_to_starting_position(starting_position, unit)

## Re-registers an occupant at its current visual position after a failed swap.
func _restore_occupant(occupant, area: PlayArea) -> void:
	var footprint := UnitGrid.footprint_of(occupant)
	var anchor := area.get_anchor_for_global(occupant.global_position, footprint)
	area.unit_grid.add_unit(anchor, occupant)
