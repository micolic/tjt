class_name UnitVisuals
extends RefCounted

## Shared visual helpers for Unit and EnemyUnit.
## All methods are static so both unit types can call them without inheritance.

const DamageNumberScene = preload("res://scenes/damage_number/damage_number.tscn")

const HEALTH_FLASH_DURATION: float = 0.05
const SKIN_FLASH_DURATION: float = 0.1


## Returns the health bar color for a given health percentage (0.0–1.0).
static func get_health_bar_color(health_percent: float) -> Color:
	if health_percent >= 0.75:
		return Color(0.0, 0.4, 0.0).lerp(Color(0.0, 0.6, 0.0), (1.0 - health_percent) / 0.25)
	elif health_percent >= 0.50:
		return Color(0.0, 0.6, 0.0).lerp(Color(0.2, 0.9, 0.2), (0.75 - health_percent) / 0.25)
	elif health_percent >= 0.30:
		return Color(0.2, 0.9, 0.2).lerp(Color(1.0, 1.0, 0.0), (0.50 - health_percent) / 0.20)
	elif health_percent >= 0.20:
		return Color(1.0, 1.0, 0.0).lerp(Color(1.0, 0.5, 0.0), (0.30 - health_percent) / 0.10)
	elif health_percent >= 0.10:
		return Color(1.0, 0.5, 0.0).lerp(Color(1.0, 0.2, 0.0), (0.20 - health_percent) / 0.10)
	else:
		return Color(1.0, 0.0, 0.0)


## Creates a StyleBoxFlat with the given color and standard border.
static func create_bar_stylebox(color: Color) -> StyleBoxFlat:
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = color
	style_box.border_width_left = 1
	style_box.border_width_top = 1
	style_box.border_width_right = 1
	style_box.border_width_bottom = 1
	style_box.border_color = Color(0.13, 0.13, 0.13, 1)
	return style_box


## Applies the health-based color gradient to a ProgressBar.
static func apply_health_bar_color(health_bar: ProgressBar, health_percent: float) -> void:
	if not health_bar:
		return

	var bar_color := get_health_bar_color(health_percent)
	var style_box := create_bar_stylebox(bar_color)

	var theme := health_bar.theme
	if not theme:
		theme = Theme.new()
		health_bar.theme = theme

	theme.set_stylebox("fill", "ProgressBar", style_box)


## Flashes a ProgressBar white briefly. Returns the flash id used.
static func flash_health_bar(health_bar: ProgressBar, tree: SceneTree, flash_id: int) -> int:
	if not health_bar or not is_instance_valid(health_bar):
		return flash_id

	flash_id += 1
	var current_id := flash_id

	var white_style := create_bar_stylebox(Color.WHITE)
	health_bar.add_theme_stylebox_override("fill", white_style)

	# Use WeakRef to avoid 'Lambda capture was freed' errors when
	# the unit dies before the flash timer fires.
	var bar_weak: WeakRef = weakref(health_bar)
	var eid := current_id
	var cid := flash_id
	tree.create_timer(HEALTH_FLASH_DURATION).timeout.connect(
		func() -> void:
			var bar = bar_weak.get_ref()
			if eid == cid and bar:
				bar.remove_theme_stylebox_override("fill")
	)

	return flash_id


## Flashes a Sprite2D with a color briefly. Returns the flash id used.
static func flash_skin(skin: Node2D, tree: SceneTree, flash_id: int, flash_color: Color = Color.RED) -> int:
	if not skin or not is_instance_valid(skin):
		return flash_id

	flash_id += 1
	var current_id := flash_id

	skin.modulate = flash_color

	var skin_weak: WeakRef = weakref(skin)
	var eid := current_id
	var cid := flash_id
	tree.create_timer(SKIN_FLASH_DURATION).timeout.connect(
		func() -> void:
			var s = skin_weak.get_ref()
			if eid == cid and s:
				s.modulate = Color(1, 1, 1, 1)
	)

	return flash_id


## Spawns a floating damage number at the given position.
static func spawn_damage_number(tree: SceneTree, position: Vector2, damage: float, color: Color = Color.WHITE) -> void:
	if not DamageNumberScene:
		return

	var damage_number = DamageNumberScene.instantiate()

	var current_scene = tree.current_scene
	if current_scene:
		current_scene.add_child(damage_number)
	else:
		tree.root.add_child(damage_number)

	damage_number.position = position + Vector2(0, -20)
	damage_number.setup(damage, color)


## Removes a unit from its parent grid and notifies the battle manager.
static func handle_unit_death(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	# Walk up parents to find the PlayArea (unit might be child of UnitGrid)
	var node = unit.get_parent()
	while node and not (node is PlayArea):
		node = node.get_parent()
	if node and node is PlayArea:
		var play_area: PlayArea = node as PlayArea
		# Remove the unit from all cells of its footprint (it may have moved during battle)
		var grid = play_area.unit_grid
		if grid and grid.has_method("remove_unit_node"):
			grid.remove_unit_node(unit)

	# If this is a player unit (not King), notify unit selection panel to decrement count
	if unit.is_in_group("player_units") and unit.stats and not unit.stats.is_king:
		var unit_selection_panel = unit.get_tree().get_first_node_in_group("unit_selection_panel")
		if unit_selection_panel and unit_selection_panel.has_method("on_unit_removed"):
			unit_selection_panel.on_unit_removed()

	var battle_manager := unit.get_tree().get_first_node_in_group("battle_manager")
	if battle_manager:
		battle_manager.check_win_condition()

	unit.queue_free()


## Sets up team groups for a unit node based on its stats.
static func setup_team_groups(unit: Node, stats: UnitStats) -> void:
	unit.add_to_group("units")
	if stats.team == UnitStats.Team.PLAYER:
		if not unit.is_in_group("player_units"):
			unit.add_to_group("player_units")
	else:
		if not unit.is_in_group("enemy_units"):
			unit.add_to_group("enemy_units")
