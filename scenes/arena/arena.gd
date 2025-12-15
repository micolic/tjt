class_name Arena
extends Node2D

const CELL_SIZE := Vector2(32, 32)
const HALF_CELL_SIZE := Vector2(16, 16)
const QUARTER_CELL_SIZE := Vector2(8, 8)

@onready var unit_mover: UnitMover = $UnitMover
@onready var unit_spawner: UnitSpawner = $UnitSpawner
@onready var sell_portal: SellPortal = $SellPortal
@onready var battle_manager: BattleManager = $BattleManager
@onready var unit_stats_container: VBoxContainer = $UI/UnitStatsContainer
@onready var start_battle_button: Button = $UI/RightPanel/StartBattleButton
@onready var enemy_area: PlayArea = $EnemyArea

# LEGACY: Old enemy wave spawn system - kept for compatibility
# Now using WaveManager system instead
@export var enemy_wave := []
@export_range(1, 3) var enemy_spawn_batch_size: int = 1
@export var enemy_spawn_interval: float = 0.45

# Wave system
var wave_manager: Node

## Called when the node enters the scene tree. Connects unit spawner to unit mover.
func _ready() -> void:
	unit_spawner.unit_spawned.connect(unit_mover.setup_unit)
	unit_spawner.unit_spawned.connect(sell_portal.setup_unit)
	
	# Connect battle manager signals
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.preparation_started.connect(_on_preparation_started)
	battle_manager.state_changed.connect(_on_battle_state_changed)

	# Connect UI button
	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)
		# initial state based on current battle manager state
		_on_battle_state_changed(battle_manager.current_state)
	
	# Get or find wave manager
	wave_manager = get_node_or_null("WaveManager")
	if not wave_manager:
		wave_manager = get_tree().get_first_node_in_group("wave_manager")


## Called when battle starts - disable dragging.
func _on_battle_started() -> void:
	_set_drag_enabled(false)

	# Clear any pre-existing enemy units in the enemy area (safety)
	if enemy_area and enemy_area.unit_grid:
		for tile in enemy_area.unit_grid.units.keys():
			var u = enemy_area.unit_grid.units[tile]
			if u:
				enemy_area.unit_grid.remove_unit(tile)
				if is_instance_valid(u):
					u.queue_free()
	
	# If wave manager exists, it handles spawning
	# Otherwise fall back to legacy enemy_wave system
	if wave_manager:
		# Wave manager will start first wave automatically
		return
	
	# LEGACY: Spawn configured enemy wave via UnitSpawner at/around center in batches
	if enemy_wave and unit_spawner and enemy_area and enemy_area.unit_grid:
		var grid_size: Vector2i = enemy_area.unit_grid.size
		var center_tile: Vector2i = Vector2i(grid_size.x >> 1, grid_size.y >> 1)

		# Offsets to place multiple enemies around center (spiral-ish)
		var offsets: Array[Vector2i] = [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(1,1)]

		var total: int = int(enemy_wave.size())
		var batch: int = max(1, int(enemy_spawn_batch_size))
		var i: int = 0
		while i < total:
			# Spawn this batch
			var end_idx: int = min(i + batch, total)
			for j in range(i, end_idx):
				var enemy_stats: UnitStats = enemy_wave[j]
				if not enemy_stats:
					continue

				var placed: bool = false
				for off in offsets:
					var try_tile: Vector2i = Vector2i(center_tile.x + off.x, center_tile.y + off.y)
					if try_tile.x < 0 or try_tile.y < 0 or try_tile.x >= grid_size.x or try_tile.y >= grid_size.y:
						continue
					if not enemy_area.unit_grid.is_tile_occupied(try_tile):
						unit_spawner.spawn_unit(enemy_stats, try_tile)
						placed = true
						break
				if not placed:
					unit_spawner.spawn_unit(enemy_stats)

			i += batch
			# Wait between batches if more remain
			if i < total and enemy_spawn_interval > 0:
				await get_tree().create_timer(enemy_spawn_interval).timeout

			# After spawning all batches, enable AI for all units so newly spawned enemies become active
			if battle_manager and battle_manager.has_method("enable_ai_for_all"):
				battle_manager.enable_ai_for_all(true)


## Called when preparation starts - enable dragging.
func _on_preparation_started() -> void:
	_set_drag_enabled(true)
	# Ensure Start button enabled in preparation
	if start_battle_button:
		start_battle_button.disabled = false


func _on_start_battle_pressed() -> void:
	# Safety: only allow when in PREPARATION
	if battle_manager and battle_manager.current_state == BattleManager.State.PREPARATION:
		battle_manager.force_start_battle()


func _on_battle_state_changed(new_state: int) -> void:
	# Disable the start button during battle or after ended
	if not start_battle_button:
		return
	if new_state == BattleManager.State.PREPARATION:
		start_battle_button.disabled = false
	else:
		start_battle_button.disabled = true


## Updates the unit stats display.
func _process(_delta: float) -> void:
	update_stats_display()


## Updates the unit stats display with current ally units.
func update_stats_display() -> void:
	# Clear existing panels
	for child in unit_stats_container.get_children():
		child.queue_free()
	
	# Get ally units
	var ally_units = get_tree().get_nodes_in_group("player_units")
	
	# Create panels for each
	for unit in ally_units:
		var panel = preload("res://scenes/arena/unit_stats_panel.tscn").instantiate()
		unit_stats_container.add_child(panel)
		panel.set_unit(unit)


## Enables or disables dragging for all units.
func _set_drag_enabled(enabled: bool) -> void:
	var all_units := get_tree().get_nodes_in_group("units")
	for unit in all_units:
		if unit.has_node("DragAndDrop"):
			unit.get_node("DragAndDrop").enabled = enabled
