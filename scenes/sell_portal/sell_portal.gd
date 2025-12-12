class_name SellPortal
extends Area2D

@export var player_stats: PlayerStats

@onready var outline_highlighter: OutlineHighlighter = $OutlineHighlighter
@onready var gold: HBoxContainer = %Gold
@onready var gold_label: Label = %GoldLabel

var current_unit

## Called when the node enters the scene tree. Sets up all units in the scene.
func _ready() -> void:
	var units := get_tree().get_nodes_in_group("units")
	for unit in units:
		setup_unit(unit)

## Connects drag and quick sell signals for a given unit to the sell portal handlers.
func setup_unit(unit) -> void:
	if unit.has_node("DragAndDrop"):
		unit.drag_and_drop.dropped.connect(_on_unit_dropped.bind(unit))
	if unit.has_signal("quick_sell_pressed"):
		unit.quick_sell_pressed.connect(_sell_unit.bind(unit))

## Handler for when a unit is dropped on the sell portal area.
func _on_unit_dropped(_starting_position: Vector2, unit) -> void:
	if unit and unit == current_unit:
		_sell_unit(unit)

## Sells a unit and awards gold to the player.
func _sell_unit(unit) -> void:
	if not unit or not unit.stats:
		return
	
	player_stats.gold += unit.stats.get_gold_value()
	# TODO give items back to item pool
	# TODO put units back to the pool
	unit.queue_free()

## Handler for when an area enters the sell portal.
func _on_area_entered(unit) -> void:
	current_unit = unit
	outline_highlighter.highlight()
	gold_label.text = str(unit.stats.get_gold_value())
	gold.show()

## Handler for when an area exits the sell portal.
func _on_area_exited(unit) -> void:
	if unit and unit == current_unit:
		current_unit = null
	
	outline_highlighter.clear_highlight()
	gold.hide()
