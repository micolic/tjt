@tool
class_name Unit
extends Area2D

signal quick_sell_pressed

const CELL_SIZE := Vector2(32, 32)

@export var stats: UnitStats : set = set_stats

@onready var skin: Sprite2D = $Visuals/Skin
@onready var health_bar: ProgressBar = $HealthBar
@onready var mana_bar: ProgressBar = $ManaBar
@onready var drag_and_drop: DragAndDrop = $DragAndDrop
@onready var velocity_based_rotation: VelocityBasedRotation = $VelocityBasedRotation
@onready var outline_highlighter: OutlineHighlighter = $OutlineHighlighter

var is_hovered := false

## Called when the node enters the scene tree. Connects drag signals if not in editor.
func _ready() -> void:
	if not Engine.is_editor_hint():
		drag_and_drop.drag_started.connect(_on_drag_started)
		drag_and_drop.drag_canceled.connect(_on_drag_canceled)
		
		# Connect stats signals
		if stats:
			_connect_stats_signals()


## Connects to unit stats signals.
func _connect_stats_signals() -> void:
	if not stats:
		return
	
	# Prevent duplicate connections
	if stats.health_reached_zero.is_connected(_on_health_reached_zero):
		return
	
	# Check if already connected to avoid duplicate connections
	if not stats.health_reached_zero.is_connected(_on_health_reached_zero):
		stats.health_reached_zero.connect(_on_health_reached_zero)
	
	# Connect health_changed signal (use lambda to ignore the health value argument)
	if not stats.health_changed.is_connected(func(_new_health): _update_health_bar()):
		stats.health_changed.connect(func(_new_health): _update_health_bar())
	
	# Add to team groups (only if not already in group)
	add_to_group("units")  # Add to global units group
	if stats.team == UnitStats.Team.PLAYER:
		if not is_in_group("player_units"):
			add_to_group("player_units")
	else:
		if not is_in_group("enemy_units"):
			add_to_group("enemy_units")
	
	# Initialize health and mana
	stats.reset_health()
	stats.reset_mana()
	_update_health_bar()
	_update_mana_bar()


## Updates health bar display.
func _update_health_bar() -> void:
	if not stats or not health_bar:
		return
	
	health_bar.max_value = stats.get_max_health()
	health_bar.value = stats.health
	
	# Update health bar color based on health percentage
	_update_health_bar_color()
	
	# Flash effect when taking damage
	_flash_health_bar()


## Update health bar color gradient based on health percentage.
func _update_health_bar_color() -> void:
	if not stats or not health_bar:
		return
	
	var health_percent: float = float(stats.health) / float(stats.get_max_health())
	var bar_color: Color
	
	# Color gradient with precise breakpoints:
	# 100% - Dark Green
	# 75% - Slightly lighter green
	# 50% - Light Green
	# 30% - Light Green -> Yellow -> Ochre transition
	# 20% - Ochre -> Orange transition
	# 15% - Orange
	# 10% - Orange -> Red transition
	# 0% - Red
	
	if health_percent >= 0.75:
		# Dark Green (100%) to slightly lighter green (75%)
		bar_color = Color(0.0, 0.4, 0.0).lerp(Color(0.0, 0.6, 0.0), (1.0 - health_percent) / 0.25)
	elif health_percent >= 0.50:
		# Slightly lighter green (75%) to Light Green (50%)
		bar_color = Color(0.0, 0.6, 0.0).lerp(Color(0.2, 0.9, 0.2), (0.75 - health_percent) / 0.25)
	elif health_percent >= 0.30:
		# Light Green (50%) to Yellow (30%)
		bar_color = Color(0.2, 0.9, 0.2).lerp(Color(1.0, 1.0, 0.0), (0.50 - health_percent) / 0.20)
	elif health_percent >= 0.20:
		# Yellow (30%) to Orange (20%)
		bar_color = Color(1.0, 1.0, 0.0).lerp(Color(1.0, 0.5, 0.0), (0.30 - health_percent) / 0.10)
	elif health_percent >= 0.10:
		# Orange (20%) to Orange/Red (10%)
		bar_color = Color(1.0, 0.5, 0.0).lerp(Color(1.0, 0.2, 0.0), (0.20 - health_percent) / 0.10)
	else:
		# Red (below 10%)
		bar_color = Color(1.0, 0.0, 0.0)
	
	# Create and set StyleBoxFlat directly
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = bar_color
	style_box.border_width_left = 1
	style_box.border_width_top = 1
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.13, 0.13, 0.13, 1)
	
	# Get or create theme
	var theme = health_bar.theme
	if not theme:
		theme = Theme.new()
		health_bar.theme = theme
	
	# Override the fill style
	theme.set_stylebox("fill", "ProgressBar", style_box)


## Flash health bar red when taking damage.
func _flash_health_bar() -> void:
	if not health_bar:
		return
	
	# Just a visual feedback - no actual effect needed
	pass


## Updates mana bar display.
func _update_mana_bar() -> void:
	if not stats or not mana_bar:
		return
	
	mana_bar.max_value = stats.max_mana
	mana_bar.value = stats.mana


## Called when unit's health reaches zero.
func _on_health_reached_zero() -> void:
	print("%s died!" % stats.name)
	
	# Notify battle manager
	var battle_manager := get_tree().get_first_node_in_group("battle_manager")
	if battle_manager:
		battle_manager.check_win_condition()
	
	# Play death animation/effect (TODO)
	
	# Remove from game
	queue_free()

## Handles input events to detect quick sell action when unit is hovered.
func _input(event: InputEvent) -> void:
	if not is_hovered:
		return

	if event.is_action_pressed("quick_sell"):
		quick_sell_pressed.emit()

## Sets the unit's stats and updates the skin position accordingly.
func set_stats(value: UnitStats) -> void:
	stats = value
	
	if value == null:
		return
	
	if not is_node_ready():
		await ready
	
	# Set the correct spritesheet based on team
	skin.texture = value.TEAM_SPRITESHEET[value.team]
	skin.region_rect.position = Vector2(stats.skin_coordinates) * CELL_SIZE
	
	# Connect stats signals if not in editor
	if not Engine.is_editor_hint():
		_connect_stats_signals()

## Resets the unit's position and disables rotation after dragging is canceled.
func reset_after_dragging(starting_position: Vector2) -> void:
	velocity_based_rotation.enabled = false
	global_position = starting_position

## Called when dragging starts; enables velocity-based rotation.
func _on_drag_started() -> void:
	velocity_based_rotation.enabled = true
	#outline_highlighter.clear_highlight()

## Called when dragging is canceled; resets the unit's state.
func _on_drag_canceled(starting_position: Vector2) -> void:
	reset_after_dragging(starting_position)

## Highlights the unit when the mouse enters, unless dragging.
func _on_mouse_entered() -> void:
	if drag_and_drop.dragging:
		return
	
	is_hovered = true
	outline_highlighter.highlight()
	z_index = 1

## Clears highlight when the mouse exits, unless dragging.
func _on_mouse_exited() -> void:
	if drag_and_drop.dragging:
		return
	
	is_hovered = false
	outline_highlighter.clear_highlight()
	z_index = 0
