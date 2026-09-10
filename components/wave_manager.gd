class_name WaveManager
extends Node

## Signals
signal wave_started(wave_number: int, wave_config: WaveConfig)
signal wave_completed(wave_number: int)
signal wave_rewards_earned(gold: int, xp: int)
signal all_waves_completed
signal wave_difficulty_changed(difficulty_multiplier: float)
signal preparation_phase_started(time_remaining: float)

@warning_ignore("unused_signal")
signal wave_timer_updated(time_remaining: float)

## Wave progression configuration
@export var waves: Array[WaveConfig] = []
@export var preparation_between_waves: float = 30.0  # Time between waves
@export var difficulty_scaling_per_wave: float = 0.05  # 5% harder each wave
@export var boss_wave_interval: int = 5  # Every 5th wave is a boss wave

## References
var battle_manager: Node
var unit_spawner: Node
var enemy_area: Node
var game_area: Node
var player_stats: Variant  # Can be Node or Resource

# Set via @onready after inheriting from Arena parent
@onready var _battle_manager: Node = get_tree().get_first_node_in_group("battle_manager")
@onready var _unit_spawner: Node = get_parent().get_node("UnitSpawner") if get_parent() else null
@onready var _enemy_area: Node = get_parent().get_node("EnemyArea") if get_parent() else null
@onready var _game_area: Node = get_parent().get_node("GameArea") if get_parent() else null
@onready var _player_stats: Variant = _get_player_stats_node()

## State
var current_wave_index: int = -1
var current_wave_number: int = 0
var is_wave_active: bool = false
var remaining_enemies: int = 0
var wave_timer: float = 0.0
var difficulty_multiplier: float = 1.0
var is_waiting_for_next_wave: bool = false
var prep_timer: float = 0.0

## Tracked enemies
var spawned_enemies: Array[Node] = []

## Saved ally unit positions (unit_node -> {tile, global_pos})
var saved_ally_positions: Dictionary = {}


func _ready() -> void:
	add_to_group("wave_manager")
	
	# Set references from @onready
	battle_manager = _battle_manager
	unit_spawner = _unit_spawner
	enemy_area = _enemy_area
	game_area = _game_area
	player_stats = _player_stats
	
	# Fallback - try to get from parent or scene
	if not battle_manager:
		battle_manager = get_parent().get_node_or_null("BattleManager")
	if not unit_spawner:
		unit_spawner = get_parent().get_node_or_null("UnitSpawner")
	if not enemy_area:
		enemy_area = get_parent().get_node_or_null("EnemyArea")
	if not game_area:
		game_area = get_parent().get_node_or_null("GameArea")
	if not player_stats:
		# Try to get from parent Arena's @export
		if "player_stats" in get_parent() and get_parent().player_stats:
			player_stats = get_parent().player_stats
	
	
	# Connect battle manager signals
	if battle_manager:
		battle_manager.battle_started.connect(_on_battle_started)
		battle_manager.battle_ended.connect(_on_battle_ended)
		if battle_manager.has_signal("state_changed"):
			battle_manager.state_changed.connect(_on_battle_state_changed)
	else:
		push_error("WaveManager: Could not find BattleManager!")
	
	if not unit_spawner:
		push_error("WaveManager: Could not find UnitSpawner!")
	if not enemy_area:
		push_error("WaveManager: Could not find EnemyArea!")


## Helper: Find PlayerStats node with multiple fallback strategies
func _get_player_stats_node() -> Variant:
	var parent = get_parent()
	if not parent:
		return null
	
	# Try parent's player_stats export first
	if "player_stats" in parent and parent.player_stats:
		return parent.player_stats
	
	# Try alternate path
	var alt_stats = parent.get_node_or_null("UI/PlayerStats")
	if alt_stats:
		return alt_stats
	
	# Try searching in tree
	var candidates = get_tree().get_nodes_in_group("player_stats")
	if candidates.size() > 0:
		return candidates[0]
	
	# Last resort: search Arena children
	if "player_stats" in parent:
		return parent.player_stats
	
	push_warning("[WAVE] Could not find PlayerStats node! Rewards will not be distributed.")
	return null


func _process(delta: float) -> void:
	# During prep phase between waves, count down timer
	if is_waiting_for_next_wave:
		if prep_timer > 0:
			prep_timer -= delta
			wave_timer_updated.emit(prep_timer)
			if prep_timer <= 0:
				_start_next_wave_battle()
		return
	
	if not is_wave_active or not battle_manager:
		return
	
	# During battle, check if all enemies are dead
	if battle_manager.current_state == BattleManager.State.BATTLE:
		if remaining_enemies <= 0:
			_complete_wave()


func _on_battle_started() -> void:
	# Only handle the very first battle start (wave_index == -1).
	# Subsequent waves are started via _start_next_wave_battle which calls
	# start_battle() again, but we don't want to reset state.
	if current_wave_index >= 0:
		return
	
	current_wave_index = -1
	current_wave_number = 0
	difficulty_multiplier = 1.0
	spawned_enemies.clear()
	is_waiting_for_next_wave = false
	
	# Save initial ally positions before first fight
	_save_ally_positions()
	
	# Start first wave
	await get_tree().process_frame
	start_next_wave()


func _on_battle_state_changed(_new_state: BattleManager.State) -> void:
	pass


func _on_battle_ended(winner: UnitStats.Team) -> void:
	if winner == UnitStats.Team.ENEMY:
		is_wave_active = false
		is_waiting_for_next_wave = false


## Starts the next wave
func start_next_wave() -> void:
	current_wave_index += 1
	current_wave_number = current_wave_index + 1
	
	# Check if we've completed all waves
	if current_wave_index >= waves.size():
		all_waves_completed.emit()
		return
	
	var wave_config: WaveConfig = waves[current_wave_index]
	
	# Apply scaling difficulty
	difficulty_multiplier = 1.0 + (difficulty_scaling_per_wave * current_wave_index)
	wave_difficulty_changed.emit(difficulty_multiplier)
	
	# Spawn the wave
	is_wave_active = true
	spawned_enemies.clear()
	wave_started.emit(current_wave_number, wave_config)
	
	await _spawn_wave(wave_config)


## Spawns enemy units one at a time, each immediately starts walking.
## Units spawn at random positions along the top of the enemy area.
func _spawn_wave(wave_config: WaveConfig) -> void:
	if not unit_spawner or not enemy_area:
		push_error("Wave Manager: Missing spawner or enemy area")
		return

	remaining_enemies = wave_config.get_total_enemies()

	# Enable AI for existing player units first
	if battle_manager:
		battle_manager.enable_ai_for_all(true)

	# Build a flat list of all enemies to spawn in order
	var spawn_queue: Array[UnitStats] = []
	for group in wave_config.enemy_groups:
		for i in range(group.count):
			if group.enemy_type:
				spawn_queue.append(group.enemy_type)

	# Compute spawn interval from wave config (use first group's interval as base)
	var spawn_interval: float = 0.5
	if not wave_config.enemy_groups.is_empty():
		spawn_interval = wave_config.enemy_groups[0].spawn_interval_within_group
		if spawn_interval <= 0:
			spawn_interval = 0.5

	# Spawn enemies one by one
	for idx in range(spawn_queue.size()):
		var base_stats: UnitStats = spawn_queue[idx]
		var scaled_stats = _create_scaled_stats(base_stats)

		var spawned_unit: Node = _spawn_enemy_at_top(scaled_stats)

		if spawned_unit:
			spawned_enemies.append(spawned_unit)
			# Connect death signal
			if "stats" in spawned_unit and spawned_unit.stats and spawned_unit.stats.has_signal("health_reached_zero"):
				spawned_unit.stats.health_reached_zero.connect(_on_enemy_died.bindv([spawned_unit]))
			# Enable AI immediately so unit starts walking
			var ai = spawned_unit.get_node_or_null("UnitAI")
			if ai:
				ai.enabled = true
		else:
			remaining_enemies = max(remaining_enemies - 1, 0)

		# Wait between spawns (skip delay on last unit)
		if idx < spawn_queue.size() - 1:
			await get_tree().create_timer(spawn_interval).timeout



## Spawns a single enemy at a random X along the top edge of the enemy area.
## Does NOT use the grid — the unit is free-moving from the start.
func _spawn_enemy_at_top(stats: UnitStats) -> Node:
	var unit_scene = load("res://scenes/unit/enemy_unit.tscn")
	if not unit_scene:
		push_error("Could not load enemy_unit.tscn")
		return null

	var new_unit: Node = unit_scene.instantiate()

	# Give independent stats copy (shallow-dup sprite_frames to avoid breaking AtlasTextures)
	if stats is Resource:
		var duped_stats = stats.duplicate(true)
		# sprite_frames should NOT be deep-duplicated — share the original reference
		if stats.sprite_frames:
			duped_stats.sprite_frames = stats.sprite_frames
		new_unit.stats = duped_stats
	else:
		new_unit.stats = stats

	# Determine spawn position: random X near center of the enemy area, at the top row (y=0)
	var footprint: Vector2i = UnitGrid.footprint_of(new_unit)
	var grid_size: Vector2i = enemy_area.unit_grid.size
	var center_x: int = (grid_size.x - footprint.x) >> 1
	var spread: int = 12  # ±12 logical cells (±3 old 32px tiles) from center
	var random_x: int = clampi(randi_range(center_x - spread, center_x + spread), 0, grid_size.x - footprint.x)
	var spawn_tile := Vector2i(random_x, 0)
	var spawn_pos: Vector2 = enemy_area.get_unit_position(spawn_tile, footprint)

	# Add to scene tree (parent to enemy area so it moves with the scene)
	enemy_area.add_child(new_unit)
	new_unit.global_position = spawn_pos

	# Reset transform
	new_unit.rotation = 0
	new_unit.scale = Vector2.ONE
	if new_unit.has_node("VelocityBasedRotation"):
		var v = new_unit.get_node("VelocityBasedRotation")
		if v and v.has_method("set_enabled"):
			v.set_enabled(false)
		elif v:
			v.enabled = false

	unit_spawner.unit_spawned.emit(new_unit)
	return new_unit



## Creates a copy of stats with difficulty scaling applied
func _create_scaled_stats(base_stats: UnitStats) -> UnitStats:
	# Create a modified resource with scaled stats
	var scaled = base_stats.duplicate()
	
	# Scale health and damage
	scaled.max_health = int(base_stats.max_health * difficulty_multiplier)
	scaled.attack_damage = int(base_stats.attack_damage * difficulty_multiplier)
	
	return scaled


func _on_enemy_died(unit: Node) -> void:
	if unit in spawned_enemies:
		spawned_enemies.erase(unit)
	else:
		# Already counted — avoid double-decrement
		return
	remaining_enemies = max(remaining_enemies - 1, 0)


## Returns the WaveConfig for the next upcoming wave, or null if none.
func get_next_wave_config() -> WaveConfig:
	var next_index := current_wave_index + 1
	if next_index < waves.size():
		return waves[next_index]
	return null


func _complete_wave() -> void:
	is_wave_active = false
	wave_completed.emit(current_wave_number)
	
	# Give rewards
	var wave_config: WaveConfig = waves[current_wave_index] if current_wave_index < waves.size() else null
	if wave_config and player_stats:
		var gold_reward = wave_config.gold_reward
		var xp_reward = wave_config.experience_reward
		
		player_stats.gold += gold_reward
		player_stats.xp += xp_reward
		
		wave_rewards_earned.emit(gold_reward, xp_reward)
	
	# Clean up any remaining dead/alive enemy units
	for u in spawned_enemies:
		if is_instance_valid(u):
			u.queue_free()
	spawned_enemies.clear()
	
	# Also clean up any enemy units still in the scene (e.g. parented to enemy_area)
	var remaining_enemy_nodes = get_tree().get_nodes_in_group("enemy_units")
	for u in remaining_enemy_nodes:
		if is_instance_valid(u):
			u.queue_free()
	
	# Check if all waves done
	if current_wave_index + 1 >= waves.size():
		all_waves_completed.emit()
		# End the battle as victory
		if battle_manager:
			battle_manager.end_battle(UnitStats.Team.PLAYER)
		return
	
	# End battle phase so AI stops
	if battle_manager:
		battle_manager.end_battle(UnitStats.Team.PLAYER)
	
	# Restore ally positions and reset their stats
	await get_tree().process_frame
	_restore_ally_positions()
	_reset_ally_stats()
	
	# Start preparation phase between waves
	is_waiting_for_next_wave = true
	prep_timer = preparation_between_waves
	preparation_phase_started.emit(prep_timer)
	
	# Enable dragging for unit repositioning
	if battle_manager:
		battle_manager.start_preparation()


## Get current wave info
func get_current_wave() -> WaveConfig:
	if current_wave_index >= 0 and current_wave_index < waves.size():
		return waves[current_wave_index]
	return null


func get_total_waves() -> int:
	return waves.size()


func get_progress() -> float:
	if waves.is_empty():
		return 0.0
	return float(current_wave_number) / float(waves.size())


func is_boss_wave() -> bool:
	return current_wave_number > 0 and current_wave_number % boss_wave_interval == 0


## Called when player presses Start Battle during between-wave preparation.
## Skips the remaining prep timer and immediately starts the next wave.
func skip_preparation() -> void:
	if not is_waiting_for_next_wave:
		return
	prep_timer = 0.0
	_start_next_wave_battle()


## Internal: starts the next wave's battle phase.
func _start_next_wave_battle() -> void:
	is_waiting_for_next_wave = false
	
	# Save ally positions before the fight
	_save_ally_positions()
	
	# Start battle phase
	if battle_manager:
		battle_manager.start_battle()
	
	start_next_wave()


## Saves the current position and tile of all ally units.
func _save_ally_positions() -> void:
	saved_ally_positions.clear()
	
	if not game_area or not game_area.unit_grid:
		return
	
	var ally_units = get_tree().get_nodes_in_group("player_units")
	for unit in ally_units:
		if not is_instance_valid(unit):
			continue
		if unit is Unit:
			unit.drag_and_drop.cancel()
		
		# Find this unit's anchor cell in the grid
		var tile: Vector2i = game_area.unit_grid.get_unit_anchor(unit)
		
		saved_ally_positions[unit] = {
			"tile": tile,
			"global_pos": unit.global_position
		}
	


## Restores all ally units to their saved positions.
func _restore_ally_positions() -> void:
	if saved_ally_positions.is_empty() or not game_area or not game_area.unit_grid:
		return
	
	# First clear the grid
	game_area.unit_grid.clear()
	
	var _restored_count: int = 0
	for unit in saved_ally_positions.keys():
		if not is_instance_valid(unit):
			continue
		
		var data: Dictionary = saved_ally_positions[unit]
		var tile: Vector2i = data["tile"]
		var saved_pos: Vector2 = data["global_pos"]
		
		# Re-register in grid at the saved anchor
		if tile != Vector2i(-1, -1):
			game_area.unit_grid.add_unit(tile, unit)
		
		# Restore position
		unit.global_position = saved_pos
		
		# Reset rotation/scale from battle movement
		unit.rotation = 0
		unit.scale = Vector2.ONE
		
		_restored_count += 1
	


## Resets HP, mana, and cooldowns for all surviving ally units.
func _reset_ally_stats() -> void:
	var ally_units = get_tree().get_nodes_in_group("player_units")
	var _reset_count: int = 0
	
	for unit in ally_units:
		if not is_instance_valid(unit):
			continue
		
		if not unit.stats:
			continue
		
		# King HP never resets — permanent damage from leaks
		if unit.stats.is_king:
			continue
		
		# Reset health to max
		if "current_health" in unit:
			unit.current_health = unit.stats.max_health
		elif unit.stats:
			unit.stats.reset_health()
		
		# Reset mana to starting_mana
		if "current_mana" in unit:
			unit.current_mana = unit.stats.starting_mana
		elif unit.stats:
			unit.stats.reset_mana()
		
		# Reset ability cooldown
		if "ability_on_cooldown" in unit:
			unit.ability_on_cooldown = false
		
		# Reset threat bookkeeping
		if "incoming_damage" in unit:
			unit.incoming_damage = 0.0
		if "incoming_healing" in unit:
			unit.incoming_healing = 0.0
		
		# Reset AI target
		if unit.has_node("UnitAI"):
			var ai = unit.get_node("UnitAI")
			if ai.current_target and ai.current_target.has_meta("is_dummy_target"):
				ai.current_target.queue_free()
			ai.current_target = null
			ai.path.clear()
			ai.attack_timer = 0.0
		
		# Reset animator to IDLE — prevents stuck WALK/ATTACK state during
		# preparation phase (AI is disabled and won't call play(IDLE) itself)
		if unit.has_node("UnitAnimator"):
			var animator = unit.get_node("UnitAnimator")
			if animator and animator.has_method("play"):
				animator.play(UnitAnimator.AnimState.IDLE)
		
		_reset_count += 1
	
