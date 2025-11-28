class_name Arena
extends Node2D

const CELL_SIZE := Vector2(32, 32)
const HALF_CELL_SIZE := Vector2(16, 16)
const QUARTER_CELL_SIZE := Vector2(8, 8)

@onready var unit_mover: UnitMover = $UnitMover
@onready var unit_spawner: UnitSpawner = $UnitSpawner
@onready var sell_portal: SellPortal = $SellPortal
@onready var battle_manager: BattleManager = $BattleManager

## Called when the node enters the scene tree. Connects unit spawner to unit mover.
func _ready() -> void:
	unit_spawner.unit_spawned.connect(unit_mover.setup_unit)
	unit_spawner.unit_spawned.connect(sell_portal.setup_unit)
	
	# Connect battle manager signals
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.preparation_started.connect(_on_preparation_started)


## Called when battle starts - disable dragging.
func _on_battle_started() -> void:
	_set_drag_enabled(false)


## Called when preparation starts - enable dragging.
func _on_preparation_started() -> void:
	_set_drag_enabled(true)


## Enables or disables dragging for all units.
func _set_drag_enabled(enabled: bool) -> void:
	var all_units := get_tree().get_nodes_in_group("units")
	for unit in all_units:
		if unit.has_node("DragAndDrop"):
			unit.get_node("DragAndDrop").enabled = enabled
