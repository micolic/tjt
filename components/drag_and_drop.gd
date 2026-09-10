class_name DragAndDrop
extends Node

signal drag_canceled(starting_position: Vector2)
signal drag_started
signal dropped(starting_position: Vector2)

@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled and is_node_ready():
			cancel()
@export var target: Area2D

const DRAG_THRESHOLD: float = 8.0

var starting_position: Vector2
var offset: Vector2 = Vector2.ZERO
var dragging: bool = false
## Optional callback that maps a global mouse position to the target's snapped
## global position. When set, _process uses it instead of raw mouse + offset.
var snap_position: Callable = Callable()
var _press_position: Vector2 = Vector2.ZERO
var _pending_drag: bool = false


## Called when the node enters the scene tree. Asserts and connects input event.
func _ready() -> void:
	assert(target, "No target set for DragAndDrop Component!")
	target.input_event.connect(_on_target_input_event.unbind(1))


## Updates the target's position to follow the mouse while dragging.
## If a snap_position callback is set, the target is snapped to the grid tile
## under the cursor instead of using the raw grab offset.
func _process(_delta: float) -> void:
	if dragging and is_instance_valid(target):
		var mouse_pos: Vector2 = target.get_global_mouse_position()
		if not snap_position.is_null():
			var snap_pos: Vector2 = snap_position.call(mouse_pos)
			target.global_position = snap_pos
			offset = snap_pos - mouse_pos
		else:
			target.global_position = mouse_pos + offset


## Handles input for canceling or dropping the drag operation.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_drag"):
		cancel()
	elif event.is_action_released("select"):
		_pending_drag = false
		if dragging:
			_drop()
	elif event is InputEventMouseMotion and _pending_drag and enabled:
		if _press_position.distance_to(event.position) >= DRAG_THRESHOLD:
			_pending_drag = false
			_start_dragging()


func cancel() -> void:
	_pending_drag = false
	if dragging:
		_cancel_dragging()


## Ends the dragging state and resets the target's group and z-index.
func _end_dragging() -> void:
	dragging = false
	target.remove_from_group("dragging")
	target.z_index = int(target.global_position.y)


## Cancels dragging and emits the drag_canceled signal.
func _cancel_dragging() -> void:
	_end_dragging()
	drag_canceled.emit(starting_position)


## Starts dragging, records the starting position, and emits drag_started.
func _start_dragging() -> void:
	if not enabled or not is_instance_valid(target):
		return
	if get_tree().get_first_node_in_group("dragging"):
		return
	dragging = true
	starting_position = target.global_position
	target.add_to_group("dragging")
	target.z_index = 4096
	drag_started.emit()


## Ends dragging and emits the dropped signal.
func _drop() -> void:
	_end_dragging()
	dropped.emit(starting_position)
	

## Handles input events on the target to start dragging if appropriate.
func _on_target_input_event(_viewport: Node, event: InputEvent) -> void:
	if not enabled:
		return

	var dragging_object: Node = get_tree().get_first_node_in_group("dragging")
	
	if not dragging and dragging_object:
		return
	
	if not dragging and event.is_action_pressed("select") and event is InputEventMouseButton:
		_press_position = event.position
		offset = target.global_position - target.get_global_mouse_position()
		_pending_drag = true
