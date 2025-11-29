class_name UnitAI
extends Node

## Emitted when unit reaches target
signal movement_finished
## Emitted when unit attacks
signal attack_performed(target)

const CELL_SIZE := Vector2(32, 32)
const HALF_CELL_SIZE := Vector2(16, 16)

@export var enabled: bool = false
@export var update_interval: float = 0.5  ## How often AI updates (performance)

var unit
var current_target
var path: Array[Vector2i] = []
var current_path_index: int = 0
var movement_speed: float = 100.0  ## Pixels per second
var attack_timer: float = 0.0
var update_timer: float = 0.0

## Reference to play areas for pathfinding
var play_area: PlayArea
var enemy_area: PlayArea


## Called when the node enters the scene tree.
func _ready() -> void:
	unit = get_parent()
	assert(unit, "UnitAI must be a child of Unit!")
	
	# Find play areas from the scene
	_find_play_areas()
	
	# Initialize stats
	if unit.stats:
		# Combat movement speed - balanced for visible but quick movement
		movement_speed = 50.0  # pixels per second


## Process AI logic.
func _process(delta: float) -> void:
	if not enabled or not unit or not unit.stats:
		return
	
	update_timer -= delta
	if update_timer <= 0:
		update_timer = update_interval
		_update_ai()
	
	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
	
	# Separation logic - push units away from each other to prevent overlap
	_apply_separation(delta)
	
	# Attempt attack if in range and cooldown ready
	if current_target and is_instance_valid(current_target):
		var distance_to_target: float = unit.global_position.distance_to(current_target.global_position)
		var attack_range_pixels: float = unit.stats.attack_range * CELL_SIZE.x
		
		if distance_to_target <= attack_range_pixels and attack_timer <= 0:
			# In range and ready to attack
			_try_attack()
		elif distance_to_target > attack_range_pixels:
			# Out of range - move closer continuously each frame
			var direction: Vector2 = (current_target.global_position - unit.global_position).normalized()
			var distance_to_move: float = movement_speed * delta
			unit.global_position += direction * distance_to_move
			#print("  %s: moving towards %s (%.1f/%.1f px)" % [unit.stats.name, current_target.stats.name, distance_to_target, attack_range_pixels])


## Main AI update logic.
func _update_ai() -> void:
	# Find or update target
	if not current_target or not is_instance_valid(current_target):
		current_target = _find_nearest_enemy()


## Finds the nearest enemy unit.
func _find_nearest_enemy():
	if not unit.stats:
		return null
	
	var target_group: String = UnitStats.TARGET[unit.stats.team]
	var enemies := get_tree().get_nodes_in_group(target_group)
	
	if enemies.is_empty():
		return null
	
	var nearest = null
	var nearest_distance := INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# Skip self
		if enemy == unit:
			print("  - Skipping self: %s" % enemy.stats.name)
			continue
		
		var distance: float = unit.global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	
	return nearest


## Moves towards the current target.

## Performs an attack on the target.
func _move_along_path(delta: float) -> void:
	if path.is_empty() or current_path_index >= path.size():
		path.clear()
		movement_finished.emit()
		return
	
	var target_tile := path[current_path_index]
	var target_pos := play_area.get_global_from_tile(target_tile) - HALF_CELL_SIZE
	
	var direction: Vector2 = (target_pos - unit.global_position).normalized()
	var move_distance: float = movement_speed * delta
	
	if unit.global_position.distance_to(target_pos) <= move_distance:
		# Reached waypoint
		unit.global_position = target_pos
		current_path_index += 1
		
		if current_path_index >= path.size():
			path.clear()
			movement_finished.emit()
	else:
		# Move towards waypoint
		unit.global_position += direction * move_distance


## Attempts to attack the current target.
func _try_attack() -> void:
	if not current_target or not is_instance_valid(current_target):
		return
	
	if attack_timer > 0:
		return  # Still on cooldown
	
	# Perform attack
	_perform_attack(current_target)
	
	# Set cooldown
	if unit.stats:
		attack_timer = unit.stats.get_time_between_attacks()


## Performs an attack on the target.
func _perform_attack(target) -> void:
	if not target or not target.stats:
		return
	
	# Prevent unit from attacking itself
	if target == unit:
		return
	
	# Calculate damage
	var damage: int = unit.stats.get_attack_damage()
	
	# Apply damage
	target.stats.health -= damage
	
	attack_performed.emit(target)
	
	# Flash attacker
	_flash_unit(unit)
	# Flash target (will be red from health bar flash already)
	_flash_unit(target, Color.RED)


## Simple A* pathfinding (placeholder - will improve later).
func _find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	# For now, simple direct path (will implement proper A* later)
	var result: Array[Vector2i] = []
	
	if not play_area:
		return result
	
	print("  [_find_path] start=%s, goal=%s" % [start, goal])
	
	# Just move towards goal tile by tile
	var current := start
	var max_steps = 0
	while current != goal and max_steps < 200:
		max_steps += 1
		
		if current.x < goal.x:
			current.x += 1
		elif current.x > goal.x:
			current.x -= 1
		elif current.y < goal.y:
			current.y += 1
		elif current.y > goal.y:
			current.y -= 1
		
		# NOTE: We allow tiles outside bounds since targets can be in different areas
		# Only skip if tile is explicitly occupied
		if play_area.unit_grid.units.has(current) and play_area.unit_grid.is_tile_occupied(current):
			print("    - tile %s occupied" % current)
			continue
		
		print("    - adding tile %s" % current)
		result.append(current)
	
	print("  [_find_path] result: %d waypoints (stopped after %d steps)" % [result.size(), max_steps])
	return result


## Finds the play areas from the scene tree.
func _find_play_areas() -> void:
	# Get arena node
	var arena := get_tree().get_first_node_in_group("arena")
	if not arena:
		print("ERROR: Could not find Arena node in group 'arena'!")
		return
	
	# Find play areas based on unit's team
	if unit.stats:
		if unit.stats.team == UnitStats.Team.PLAYER:
			play_area = arena.get_node_or_null("GameArea")
			enemy_area = arena.get_node_or_null("EnemyArea")
		else:
			play_area = arena.get_node_or_null("EnemyArea")
			enemy_area = arena.get_node_or_null("GameArea")
		
		print("UnitAI for %s initialized - play_area: %s, enemy_area: %s" % [unit.stats.name, play_area != null, enemy_area != null])


## Flashes a unit sprite with a color for visual feedback.
func _flash_unit(target_unit, color: Color = Color.WHITE) -> void:
	if target_unit and target_unit.has_method("flash_skin"):
		target_unit.flash_skin(color)
	else:
		# Fallback for units without flash_skin method
		if not target_unit or not target_unit.has_node("Visuals/Skin"):
			return
		
		var skin = target_unit.get_node("Visuals/Skin")
		var original_color = skin.modulate
		skin.modulate = color
		
		# Reset color after short delay
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(skin):
			skin.modulate = original_color


## Apply separation force to avoid unit overlap.
func _apply_separation(delta: float) -> void:
	if not unit or not unit.stats:
		return
	
	var min_distance: float = 40.0  # Minimum distance between units (slightly more than 1 tile)
	var separation_force: float = 200.0  # Force to push apart
	
	var all_units = get_tree().get_nodes_in_group("units")
	var separation_vector: Vector2 = Vector2.ZERO
	var neighbor_count: int = 0
	
	for other_unit in all_units:
		if other_unit == unit or not is_instance_valid(other_unit) or not other_unit.stats:
			continue
		
		# Only separate from allies, not enemies
		if other_unit.stats.team != unit.stats.team:
			continue
		
		var distance: float = unit.global_position.distance_to(other_unit.global_position)
		if distance < min_distance and distance > 0.1:
			# Calculate separation direction (away from other unit)
			var direction: Vector2 = (unit.global_position - other_unit.global_position).normalized()
			var strength: float = 1.0 - (distance / min_distance)  # Stronger when closer
			separation_vector += direction * strength
			neighbor_count += 1
	
	# Apply separation if there are neighbors
	if neighbor_count > 0:
		separation_vector = separation_vector.normalized()
		var push_distance: float = separation_force * delta
		unit.global_position += separation_vector * push_distance
