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


## Called when battle starts - disable dragging.
func _on_battle_started() -> void:
	_set_drag_enabled(false)


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
