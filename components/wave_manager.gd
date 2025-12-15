class_name WaveManager
extends Node

## Signals
signal wave_started(wave_number: int, wave_config: WaveConfig)
signal wave_completed(wave_number: int)
signal all_waves_completed
signal wave_difficulty_changed(difficulty_multiplier: float)

#@warning_ignore("unused_signal")
signal wave_timer_updated(time_remaining: float)

## Wave progression configuration
@export var waves: Array[WaveConfig] = []
@export var preparation_between_waves: float = 15.0  # Time between waves
@export var difficulty_scaling_per_wave: float = 0.05  # 5% harder each wave
@export var boss_wave_interval: int = 5  # Every 5th wave is a boss wave

## References
var battle_manager: Node
var unit_spawner: Node
var enemy_area: Node

# Set via @onready after inheriting from Arena parent
@onready var _battle_manager: Node = get_tree().get_first_node_in_group("battle_manager")
@onready var _unit_spawner: Node = get_parent().get_node("UnitSpawner") if get_parent() else null
@onready var _enemy_area: Node = get_parent().get_node("EnemyArea") if get_parent() else null

## State
var current_wave_index: int = -1
var current_wave_number: int = 0
var is_wave_active: bool = false
var remaining_enemies: int = 0
var wave_timer: float = 0.0
var difficulty_multiplier: float = 1.0

## Tracked enemies
var spawned_enemies: Array[Node] = []


func _ready() -> void:
	add_to_group("wave_manager")
	print("[WAVE] WaveManager._ready() starting...")
	
	# Set references from @onready
	battle_manager = _battle_manager
	unit_spawner = _unit_spawner
	enemy_area = _enemy_area
	
	# Fallback - try to get from parent or scene
	if not battle_manager:
		battle_manager = get_parent().get_node_or_null("BattleManager")
	if not unit_spawner:
		unit_spawner = get_parent().get_node_or_null("UnitSpawner")
	if not enemy_area:
		enemy_area = get_parent().get_node_or_null("EnemyArea")
	
	print("[WAVE] References - BattleManager: %s, UnitSpawner: %s, EnemyArea: %s" % [battle_manager != null, unit_spawner != null, enemy_area != null])
	print("[WAVE] Loaded %d waves" % waves.size())
	
	# Connect battle manager signals
	if battle_manager:
		battle_manager.battle_started.connect(_on_battle_started)
		if battle_manager.has_signal("state_changed"):
			battle_manager.state_changed.connect(_on_battle_state_changed)
		print("[WAVE] Connected to BattleManager signals")
	else:
		push_error("WaveManager: Could not find BattleManager!")
	
	if not unit_spawner:
		push_error("WaveManager: Could not find UnitSpawner!")
	if not enemy_area:
		push_error("WaveManager: Could not find EnemyArea!")
	print("[WAVE] WaveManager._ready() complete!\n")


func _process(_delta: float) -> void:
	if not is_wave_active or not battle_manager:
		return
	
	# During battle, units fight. Between waves, show prep timer.
	if battle_manager.current_state == BattleManager.State.BATTLE:
		# Check if all enemies are dead
		if remaining_enemies <= 0:
			_complete_wave()


func _on_battle_started() -> void:
	print("\n[WAVE] >>> BATTLE STARTED <<<")
	current_wave_index = -1
	current_wave_number = 0
	difficulty_multiplier = 1.0
	spawned_enemies.clear()
	
	# Start first wave
	await get_tree().process_frame
	print("[WAVE] Starting first wave...")
	start_next_wave()


func _on_battle_state_changed(_new_state: BattleManager.State) -> void:
	pass


## Starts the next wave
func start_next_wave() -> void:
	current_wave_index += 1
	current_wave_number = current_wave_index + 1
	print("[WAVE] Starting WAVE %d (index %d)" % [current_wave_number, current_wave_index])
	
	# Check if we've completed all waves
	if current_wave_index >= waves.size():
		print("[WAVE] !!! ALL WAVES COMPLETED !!!")
		all_waves_completed.emit()
		return
	
	var wave_config: WaveConfig = waves[current_wave_index]
	print("[WAVE] Wave name: %s" % wave_config.wave_name)
	print("[WAVE] Total enemies in wave: %d" % wave_config.get_total_enemies())
	
	# Apply scaling difficulty
	difficulty_multiplier = 1.0 + (difficulty_scaling_per_wave * current_wave_index)
	wave_difficulty_changed.emit(difficulty_multiplier)
	print("[WAVE] Difficulty multiplier: %.2fx" % difficulty_multiplier)
	
	# Spawn the wave
	is_wave_active = true
	spawned_enemies.clear()
	wave_started.emit(current_wave_number, wave_config)
	print("[WAVE] Wave started signal emitted")
	
	await _spawn_wave(wave_config)


## Spawns enemy units from wave config
func _spawn_wave(wave_config: WaveConfig) -> void:
	if not unit_spawner or not enemy_area or not enemy_area.unit_grid:
		push_error("Wave Manager: Missing spawner or enemy area")
		return
	
	var grid_size: Vector2i = enemy_area.unit_grid.size
	var center_tile: Vector2i = Vector2i(grid_size.x >> 1, grid_size.y >> 1)
	
	# Offsets for spreading enemies around center
	var offsets: Array[Vector2i] = [
		Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), 
		Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,-1), 
		Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1),
		Vector2i(-2,0), Vector2i(2,0), Vector2i(0,-2), Vector2i(0,2)
	]
	
	remaining_enemies = 0
	var offset_idx: int = 0
	print("[WAVE] Spawning %d enemy groups" % wave_config.enemy_groups.size())
	
	# Spawn groups with delay between them
	for group_idx in range(wave_config.enemy_groups.size()):
		var group: WaveEnemyGroup = wave_config.enemy_groups[group_idx]
		print("[WAVE]   Group %d: %d x %s" % [group_idx + 1, group.count, group.enemy_type.name if group.enemy_type else "NONE"])
		
		# Spawn group with delay
		if group_idx > 0 and wave_config.spawn_interval_between_groups > 0:
			await get_tree().create_timer(wave_config.spawn_interval_between_groups).timeout
		
		# Spawn enemies in this group
		for i in range(group.count):
			var enemy_stats: UnitStats = group.enemy_type
			if not enemy_stats:
				print("[WAVE]     WARNING: Enemy type is null!")
				continue
			
			# Apply difficulty scaling to stats
			var scaled_stats = _create_scaled_stats(enemy_stats)
			print("[WAVE]     Spawning enemy %d: %s (HP: %d, DMG: %d)" % [i + 1, scaled_stats.name, int(scaled_stats.max_health), int(scaled_stats.attack_damage)])
			
			# Find valid placement tile
			var placed: bool = false
			for attempt in range(offsets.size()):
				var try_tile: Vector2i = center_tile + offsets[offset_idx % offsets.size()]
				offset_idx += 1
				
				if _is_valid_tile(try_tile, grid_size) and not enemy_area.unit_grid.is_tile_occupied(try_tile):
					var spawned_unit = unit_spawner.spawn_unit(scaled_stats, try_tile)
					if spawned_unit:
						spawned_enemies.append(spawned_unit)
					# Connect to stats signal, not unit signal
					if spawned_unit.has_meta("stats") or spawned_unit.has_node_and_resource("stats"):
						if "stats" in spawned_unit and spawned_unit.stats and spawned_unit.stats.has_signal("health_reached_zero"):
							spawned_unit.stats.health_reached_zero.connect(_on_enemy_died.bindv([spawned_unit]))
			
			if not placed:
				# Spawn without specific tile
				var spawned_unit = unit_spawner.spawn_unit(scaled_stats)
				if spawned_unit:
					spawned_enemies.append(spawned_unit)
					# Connect to stats signal, not unit signal
					if "stats" in spawned_unit and spawned_unit.stats and spawned_unit.stats.has_signal("health_reached_zero"):
						spawned_unit.stats.health_reached_zero.connect(_on_enemy_died.bindv([spawned_unit]))
					remaining_enemies += 1
					print("[WAVE]       Spawned without specific tile")
	
	# Enable AI for all spawned units
	print("[WAVE] Total enemies spawned: %d" % remaining_enemies)
	if battle_manager:
		battle_manager.enable_ai_for_all(true)
		print("[WAVE] AI enabled for all units\n")


func _is_valid_tile(tile: Vector2i, grid_size: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < grid_size.x and tile.y < grid_size.y


## Creates a copy of stats with difficulty scaling applied
func _create_scaled_stats(base_stats: UnitStats) -> UnitStats:
	# Create a modified resource with scaled stats
	var scaled = base_stats.duplicate()
	
	# Scale health and damage
	scaled.max_health = int(base_stats.max_health * difficulty_multiplier)
	scaled.attack_damage = int(base_stats.attack_damage * difficulty_multiplier)
	
	return scaled


func _on_enemy_died(unit: Node) -> void:
	remaining_enemies -= 1
	if unit in spawned_enemies:
		spawned_enemies.erase(unit)
	print("[WAVE] Enemy died! Remaining: %d" % remaining_enemies)


func _complete_wave() -> void:
	print("[WAVE] <<< WAVE %d COMPLETE >>>" % current_wave_number)
	is_wave_active = false
	wave_completed.emit(current_wave_number)
	
	# Clean up any dead units
	for unit in spawned_enemies:
		if is_instance_valid(unit):
			unit.queue_free()
	spawned_enemies.clear()
	
	# Wait before starting next wave
	if preparation_between_waves > 0:
		print("[WAVE] Waiting %.1f seconds before next wave..." % preparation_between_waves)
		await get_tree().create_timer(preparation_between_waves).timeout
	
	print("[WAVE] Starting next wave...\n")
	start_next_wave()


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
