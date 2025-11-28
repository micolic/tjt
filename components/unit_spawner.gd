
# Spawns units into the first available play area (enemy or game area).
class_name UnitSpawner
extends Node


# Emitted when a unit is spawned and added to the scene.
signal unit_spawned(unit: Unit)


# References to the enemy and game play areas where units can be spawned.
@export var enemy_area: PlayArea
@export var game_area: PlayArea


# Spawns a new unit with the given stats in the appropriate play area based on team.
# Emits the unit_spawned signal after adding the unit.
func spawn_unit(unit: UnitStats) -> void:
	# Load unit scene dynamically
	var unit_scene = load("res://scenes/unit/unit.tscn")
	assert(unit_scene, "Could not load unit scene!")
	
	# Determine which area to spawn in based on team
	var area: PlayArea
	if unit.team == UnitStats.Team.PLAYER:
		area = game_area
		assert(not game_area.unit_grid.is_grid_full(), "Game area is full!")
	else:
		area = enemy_area
		assert(not enemy_area.unit_grid.is_grid_full(), "Enemy area is full!")
	
	var new_unit: Node = unit_scene.instantiate()
	var tile := area.unit_grid.get_first_available_tile()
	area.unit_grid.add_child(new_unit)
	area.unit_grid.add_unit(tile, new_unit)
	new_unit.global_position = area.get_global_from_tile(tile) - Arena.HALF_CELL_SIZE
	new_unit.stats = unit
	unit_spawned.emit(new_unit)
