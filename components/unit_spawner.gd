
# Spawns units into the first available play area (enemy or game area).
class_name UnitSpawner
extends Node


# Emitted when a unit is spawned and added to the scene.
# Use an untyped signal to avoid strict class conversion issues between Unit and EnemyUnit.
signal unit_spawned(unit)


# References to the enemy and game play areas where units can be spawned.
@export var enemy_area: PlayArea
@export var game_area: PlayArea


# Spawns units into the first available play area (enemy or game area).
# Emits the unit_spawned signal after adding the unit.
func spawn_unit(unit: UnitStats, tile: Vector2i = Vector2i(-1, -1)) -> Node:
	# Load unit scene dynamically based on team
	var unit_scene_path: String
	if unit.team == UnitStats.Team.PLAYER:
		unit_scene_path = "res://scenes/unit/unit.tscn"
	else:
		unit_scene_path = "res://scenes/unit/enemy_unit.tscn"
	
	var unit_scene = load(unit_scene_path)
	assert(unit_scene, "Could not load unit scene: " + unit_scene_path)
	
	# Determine which area to spawn in based on team
	var area: PlayArea
	if unit.team == UnitStats.Team.PLAYER:
		area = game_area
		assert(not game_area.unit_grid.is_grid_full(), "Game area is full!")
	else:
		area = enemy_area
		assert(not enemy_area.unit_grid.is_grid_full(), "Enemy area is full!")
	
	var new_unit: Node = unit_scene.instantiate()
	# Determine anchor to spawn at: use provided anchor if the footprint fits, otherwise first
	# available
	var footprint: Vector2i = unit.footprint if "footprint" in unit else UnitGrid.DEFAULT_FOOTPRINT
	var spawn_tile: Vector2i = tile
	if spawn_tile == Vector2i(-1, -1) or not area.unit_grid.is_area_free(spawn_tile, footprint):
		spawn_tile = area.unit_grid.get_first_available_tile(footprint)

	# Duplicate the UnitStats resource so each spawned unit has its own independent stats instance.
	# MUST happen BEFORE add_child() so _ready() sees the correct stats (not the .tscn default).
	if typeof(unit) == TYPE_OBJECT and unit is Resource:
		new_unit.stats = unit.duplicate(true)
	else:
		new_unit.stats = unit

	# Place unit in grid and scene
	area.unit_grid.add_unit(spawn_tile, new_unit)
	# Parent to the unit_grid so movement logic/reparenting stays consistent
	area.unit_grid.add_child(new_unit)
	new_unit.global_position = area.get_unit_position(spawn_tile, footprint)

	# Normalize transform to avoid skew/rotation inherited from templates or scripts
	new_unit.rotation = 0
	new_unit.scale = Vector2.ONE
	if new_unit.has_node("VelocityBasedRotation"):
		var v = new_unit.get_node("VelocityBasedRotation")
		if v and v.has_method("set_enabled"):
			v.set_enabled(false)
		elif v:
			v.enabled = false

	unit_spawned.emit(new_unit)
	return new_unit
