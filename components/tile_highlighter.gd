class_name TileHighlighter
extends Node

@export var enabled: bool = true : set = _set_enabled
@export var play_area: PlayArea
## Legacy TileMapLayer highlight. Cleared on ready but no longer used for
## highlighting — a Polygon2D + Line2D pair gives 8px-precise positioning.
@export var highlight_layer: TileMapLayer
@export var tile: Vector2i  ## Legacy; kept for scene compatibility
## Placement footprint in logical grid cells. Controls the size of the highlighted area.
@export var footprint: Vector2i = Vector2i(4, 4)
## Optional node to track instead of the mouse. Used during drag-and-drop so the
## highlight shows the tile the dragged unit will actually land on.
@export var tracking_target: Node2D = null

const HIGHLIGHT_FILL := Color(1.0, 0.85, 0.0, 0.0)
const HIGHLIGHT_BORDER := Color(1.0, 0.85, 0.0, 0.9)
const HIGHLIGHT_Z_INDEX := 1

var _fill: Polygon2D
var _border: Line2D
var _last_anchor: Vector2i = Vector2i(-1, -1)
var _last_footprint: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	_fill = Polygon2D.new()
	_fill.color = HIGHLIGHT_FILL
	_fill.z_index = HIGHLIGHT_Z_INDEX
	play_area.add_child.call_deferred(_fill)

	_border = Line2D.new()
	_border.width = 2.0
	_border.default_color = HIGHLIGHT_BORDER
	_border.z_index = HIGHLIGHT_Z_INDEX
	_border.closed = true
	play_area.add_child.call_deferred(_border)

	if highlight_layer:
		highlight_layer.clear()
	_set_visible(false)


## Updates the highlight each frame if enabled and within bounds.
func _process(_delta: float) -> void:
	if not enabled:
		return

	var target_pos := _get_target_position()
	var target_tile := play_area.get_tile_from_global(target_pos)
	if not play_area.is_tile_within_bounds(target_tile):
		_clear()
		return

	var anchor := play_area.get_anchor_for_global(target_pos, footprint)
	if not play_area.is_area_within_bounds(anchor, footprint):
		_clear()
		return

	_update_highlight(anchor)


## Returns the global position to highlight: the tracking target when dragging,
## otherwise the mouse cursor.
func _get_target_position() -> Vector2:
	if is_instance_valid(tracking_target):
		return tracking_target.global_position
	return play_area.get_global_mouse_position()


## Enables or disables the tile highlighter, clearing highlight if disabled.
func _set_enabled(new_value: bool) -> void:
	enabled = new_value
	if not enabled:
		if highlight_layer:
			highlight_layer.clear()
		_clear()


func _set_visible(vis: bool) -> void:
	if _fill:
		_fill.visible = vis
	if _border:
		_border.visible = vis


func _clear() -> void:
	_set_visible(false)
	_last_anchor = Vector2i(-1, -1)


## Clears the highlight and resets the change tracker so the next tile is logged.
func reset_tracking() -> void:
	_last_anchor = Vector2i(-1, -1)
	_last_footprint = Vector2i(-1, -1)
	_clear()


## Draws the highlight as a filled rectangle with a border at 8px precision.
## The Polygon2D and Line2D are children of the play area, so their points are
## in the play area's local coordinate space (8px per logical cell).
func _update_highlight(anchor: Vector2i) -> void:
	if anchor == _last_anchor and footprint == _last_footprint:
		return
	_last_anchor = anchor
	_last_footprint = footprint

	var px := PlayArea.GRID_CELL_PX
	var x: float = anchor.x * px
	var y: float = anchor.y * px
	var w: float = footprint.x * px
	var h: float = footprint.y * px

	var points := PackedVector2Array([
		Vector2(x, y),
		Vector2(x + w, y),
		Vector2(x + w, y + h),
		Vector2(x, y + h)
	])

	_fill.polygon = points
	_border.points = points
	_set_visible(true)

	print("[TileHighlighter] anchor: %s footprint: %s -> px (%.0f, %.0f, %.0f, %.0f)" % [
		anchor, footprint, x, y, w, h
	])
