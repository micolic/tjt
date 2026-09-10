class_name Arena
extends Node2D

const VICTORY_SCENE := "res://scenes/menu/victory_screen.tscn"
const GAME_OVER_SCENE := "res://scenes/menu/game_over_screen.tscn"
const END_SCREEN_DELAY := 1.5  ## Seconds before transitioning to end screen

@export var player_stats: PlayerStats

@onready var unit_mover: UnitMover = $UnitMover
@onready var unit_spawner: UnitSpawner = $UnitSpawner
@onready var battle_manager: BattleManager = $BattleManager
@onready var right_sidebar: RightSidebar = $UI/RightSidebar
@onready var time_panel: TimePanel = $UI/TimePanel
@onready var hud_bar: Control = $UI/HudBar
var start_battle_button: Button
var toggle_units_button: Button
var quit_game_button: Button
@onready var enemy_area: PlayArea = $EnemyArea
@onready var game_area: PlayArea = $GameArea
@onready var unit_selection_panel: UnitSelectionPanel = $UI/UnitSelectionPanel
@onready var selected_unit_panel: SelectedUnitPanel = $UI/SelectedUnitPanel
@onready var toast_manager: ToastManager = $UI/ToastManager

# Wave system
var wave_manager: Node

# Placement mode state
var _placement_stats: UnitStats = null  ## The unit type being placed (null = not placement mode)
var _placement_ghost: Sprite2D = null  ## Ghost sprite following the cursor
var _drag_placing: bool = false  ## True when placing via card drag (release to place)
var _selected_unit: Unit = null
var _is_match_over: bool = false
var _last_ghost_anchor: Vector2i = Vector2i(-1, -1)

## Live battle-time occupancy: 32px tile -> Array of unit nodes on that tile.
## The placement unit_grid goes stale once units move in combat; UnitAI keeps
## this updated from real positions so movement can check passability.
var battle_occupancy: Dictionary = {}

# Camera zoom
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1
@onready var camera: Camera2D = $Camera2D
@onready var synergy_manager: SynergyManager = $SynergyManager

# Camera pan (middle mouse)
var _camera_panning := false
var _camera_pan_start := Vector2.ZERO

## Called when the node enters the scene tree. Connects unit spawner to unit mover.
func _ready() -> void:
	get_viewport().physics_object_picking_sort = true
	get_viewport().physics_object_picking_first_only = true
	# Add ProjectilePool if one doesn't already exist
	if not get_tree().get_first_node_in_group("projectile_pool"):
		var pool = Node.new()
		pool.name = "ProjectilePool"
		pool.set_script(load("res://components/projectile_pool.gd"))
		add_child(pool)

	unit_spawner.unit_spawned.connect(unit_mover.setup_unit)
	unit_spawner.unit_spawned.connect(_on_unit_spawned_for_synergy)
	unit_spawner.unit_spawned.connect(_setup_unit_selection)
	for unit: Node in get_tree().get_nodes_in_group("player_units"):
		_setup_unit_selection(unit)
	selected_unit_panel.upgrade_requested.connect(_on_upgrade_requested)
	selected_unit_panel.removal_requested.connect(_on_unit_removal_requested)
	selected_unit_panel.deselection_requested.connect(_clear_unit_selection)
	selected_unit_panel.set_player_stats(player_stats)
	selected_unit_panel.set_unit(null)
	
	# Connect battle manager signals
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.preparation_started.connect(_on_preparation_started)
	battle_manager.state_changed.connect(_on_battle_state_changed)

	# ── Right Sidebar ──
	if right_sidebar:
		start_battle_button = right_sidebar.start_battle_button
		toggle_units_button = right_sidebar.toggle_units_button
		quit_game_button = right_sidebar.quit_game_button

	# Connect UI button
	if start_battle_button:
		start_battle_button.pressed.connect(_on_start_battle_pressed)
		# initial state based on current battle manager state
		_on_battle_state_changed(battle_manager.current_state)
	
	# Get or find wave manager
	wave_manager = get_node_or_null("WaveManager")
	if not wave_manager:
		wave_manager = get_tree().get_first_node_in_group("wave_manager")

	# Connect wave manager signals for end-game transitions
	if wave_manager:
		wave_manager.all_waves_completed.connect(_on_all_waves_completed)

	# ── Unit Selection Panel ──
	if unit_selection_panel:
		unit_selection_panel.unit_selected.connect(_on_panel_unit_selected)
		unit_selection_panel.unit_drag_started.connect(_on_panel_unit_drag_started)
		unit_selection_panel.placement_cancelled.connect(_on_placement_cancelled)
		# Load deck from DeckManager (saved/default — always available)
		if not DeckManager.selected_deck.is_empty():
			unit_selection_panel.set_available_units(DeckManager.selected_deck.duplicate())
		else:
			push_warning("[Arena] Deck is empty! Using default available_units from scene.")
		# Count pre-placed player units
		var preplaced := get_tree().get_nodes_in_group("player_units")
		unit_selection_panel.deployed_count = preplaced.size()
		# Start with panel hidden
		unit_selection_panel.visible = false
		# Wire player stats for gold tracking
		if player_stats:
			unit_selection_panel.set_player_stats(player_stats)

	# ── Top HUD ──
	if hud_bar:
		hud_bar.player_stats = player_stats
		hud_bar.unit_selection_panel_path = NodePath("../UnitSelectionPanel")

	# Toggle button for unit panel
	if toggle_units_button:
		toggle_units_button.pressed.connect(_on_toggle_units_pressed)
	if quit_game_button:
		quit_game_button.pressed.connect(_on_quit_game_pressed)

	# ── Synergy ──
	if right_sidebar and synergy_manager:
		right_sidebar.setup_synergy(synergy_manager)

	# ── Spawn King ──
	_spawn_king()


## Spawns the King unit at the bottom-center of the GameArea.
func _spawn_king() -> void:
	var king_stats: UnitStats = load("res://data/units/king_ally.tres")
	if not king_stats:
		push_warning("[Arena] Could not load king_ally.tres!")
		return
	# Place at bottom-center of the game area (anchor of the King's footprint)
	var grid_size: Vector2i = game_area.unit_grid.size
	var king_footprint: Vector2i = king_stats.footprint
	var king_tile := Vector2i((grid_size.x - king_footprint.x) >> 1, grid_size.y - king_footprint.y)
	# Find a free spot near bottom-center
	if not game_area.unit_grid.is_area_free(king_tile, king_footprint):
		king_tile = game_area.unit_grid.get_first_available_tile(king_footprint)
	var king_node := unit_spawner.spawn_unit(king_stats, king_tile)
	if king_node:

		# Add to king group for easy lookup
		king_node.add_to_group("king")


## Registers newly spawned player units with SynergyManager.
func _on_unit_spawned_for_synergy(unit: Node) -> void:
	if synergy_manager and unit and "stats" in unit and unit.stats:
		if unit.stats.get("team") == UnitStats.Team.PLAYER:
			synergy_manager.register_unit(unit)


func _setup_unit_selection(unit: Node) -> void:
	if unit is Unit and not unit.selection_requested.is_connected(_on_unit_selection_requested):
		unit.selection_requested.connect(_on_unit_selection_requested)


func _on_unit_selection_requested(unit: Unit) -> void:
	if not is_instance_valid(unit) or not unit.stats:
		return
	if _placement_stats:
		unit.drag_and_drop.cancel()
		return
	if unit.stats.team != UnitStats.Team.PLAYER or unit.current_health <= 0.0 \
			or unit.is_queued_for_deletion():
		return
	_set_selected_unit(unit)


func _set_selected_unit(unit: Unit) -> void:
	if _selected_unit == unit:
		return
	if is_instance_valid(_selected_unit):
		_selected_unit.health_reached_zero.disconnect(_clear_unit_selection)
		_selected_unit.tree_exiting.disconnect(_on_selected_unit_tree_exiting)
		_selected_unit.set_selected(false)
	_selected_unit = unit
	if is_instance_valid(_selected_unit):
		_selected_unit.set_selected(true)
		_selected_unit.health_reached_zero.connect(_clear_unit_selection)
		_selected_unit.tree_exiting.connect(_on_selected_unit_tree_exiting)
	selected_unit_panel.set_unit(_selected_unit)
	_refresh_selected_unit_panel()


func _clear_unit_selection() -> void:
	_set_selected_unit(null)


func _on_selected_unit_tree_exiting() -> void:
	_refresh_selected_unit_panel.call_deferred()


func _refresh_selected_unit_panel() -> void:
	if _selected_unit != null:
		var invalid: bool = not is_instance_valid(_selected_unit)
		invalid = invalid or not _selected_unit.is_inside_tree()
		invalid = invalid or _selected_unit.current_health <= 0.0
		if invalid:
			_clear_unit_selection()
	selected_unit_panel.set_upgrades_enabled(_can_modify_units() and _placement_stats == null)
	selected_unit_panel.refresh()


func _can_modify_units() -> bool:
	return not _is_match_over and battle_manager != null \
			and battle_manager.current_state == BattleManager.State.PREPARATION


func _set_deck_panel_visible(show_panel: bool) -> void:
	unit_selection_panel.visible = show_panel and _can_modify_units()
	_update_toggle_button_text()


func _cancel_unit_drags() -> void:
	for unit: Node in get_tree().get_nodes_in_group("player_units"):
		if unit is Unit:
			unit.drag_and_drop.cancel()


# ── Upgrade and removal choices come from the selected unit panel ──
func _on_upgrade_requested(unit: Unit, target: UnitStats) -> void:
	if not is_instance_valid(unit) or unit != _selected_unit \
			or not _can_modify_units() or _placement_stats != null:
		return
	var anchor: Vector2i = game_area.unit_grid.get_unit_anchor(unit)
	if anchor != Vector2i(-1, -1):
		_upgrade_placed_unit(anchor, target)


func _on_unit_removal_requested(unit: Unit) -> void:
	if not is_instance_valid(unit) or unit != _selected_unit \
			or not _can_modify_units() or _placement_stats != null:
		return
	var anchor: Vector2i = game_area.unit_grid.get_unit_anchor(unit)
	if anchor != Vector2i(-1, -1):
		_remove_placed_unit(anchor)


## Called when battle starts - disable dragging.
func _on_battle_started() -> void:
	_set_drag_enabled(false)

	# Reset per-unit damage counters at the start of each battle
	for u in get_tree().get_nodes_in_group("units"):
		if is_instance_valid(u) and u.has_method("reset_damage_dealt"):
			u.reset_damage_dealt()

	# Only clear enemy area on first battle start, not between waves
	# (wave manager handles its own cleanup between waves)
	if wave_manager and wave_manager.current_wave_index >= 0:
		# This is a subsequent wave start, wave manager handles spawning
		return

	# Clear any pre-existing enemy units in the enemy area (safety)
	if enemy_area and enemy_area.unit_grid:
		for u in enemy_area.unit_grid.get_all_units():
			enemy_area.unit_grid.remove_unit_node(u)
			if is_instance_valid(u):
				u.queue_free()
	
	# Wave manager handles spawning
	if wave_manager:
		# Wave manager will start first wave automatically
		return


## Called when preparation starts - enable dragging.
func _on_preparation_started() -> void:
	_set_drag_enabled(true)
	# Ensure Start button enabled in preparation
	if start_battle_button:
		start_battle_button.disabled = false


## Called when battle ends with a winner.
func _on_battle_ended(winner: UnitStats.Team) -> void:
	if winner == UnitStats.Team.ENEMY:
		# King HP = 0 is the only defeat condition
		_transition_to_game_over()
		return

	# Re-enable dragging for surviving player units once preparation begins
	_set_drag_enabled(_can_modify_units())


## Called when wave_manager reports all waves cleared.
func _on_all_waves_completed() -> void:
	_transition_to_victory()


## Transitions to the Victory screen after a short delay.
func _transition_to_victory() -> void:
	_is_match_over = true
	_set_deck_panel_visible(false)
	_refresh_selected_unit_panel()
	if time_panel:
		time_panel.stop()
	await get_tree().create_timer(END_SCREEN_DELAY).timeout
	var victory_scene: PackedScene = load(VICTORY_SCENE)
	var screen: Control = victory_scene.instantiate()
	var total_waves: int = wave_manager.current_wave_number if wave_manager else 0
	# Gather gold/xp from player stats if available
	var gold := 0
	var xp := 0
	if wave_manager and wave_manager.player_stats:
		gold = wave_manager.player_stats.gold
		xp = wave_manager.player_stats.xp
	get_tree().root.add_child(screen)
	get_tree().current_scene = screen
	# Call setup() after adding to tree so _ready() has run and labels exist
	if screen.has_method("setup"):
		screen.setup(total_waves, gold, xp)
	queue_free()


## Transitions to the Game Over screen after a short delay.
func _transition_to_game_over() -> void:
	_is_match_over = true
	_set_deck_panel_visible(false)
	_refresh_selected_unit_panel()
	if time_panel:
		time_panel.stop()
	await get_tree().create_timer(END_SCREEN_DELAY).timeout
	var go_scene: PackedScene = load(GAME_OVER_SCENE)
	var screen: Control = go_scene.instantiate()
	get_tree().root.add_child(screen)
	get_tree().current_scene = screen
	# Call setup() after adding to tree so _ready() has run and labels exist
	if screen.has_method("setup"):
		screen.setup(wave_manager.current_wave_number if wave_manager else 0, _was_king_defeat())
	queue_free()


## Returns true if the defeat was caused by the King falling (HP reached 0).
## Since King HP = 0 is the only defeat condition, this checks whether the
## King is dead: either not present among player units, or present but at 0 HP.
func _was_king_defeat() -> bool:
	for u in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(u):
			continue
		if u is Unit and u.stats and u.stats.is_king:
			# King still in the scene — check if actually dead
			return u.current_health <= 0.0
	# King not found among player units — has been removed (died and freed)
	return true


func _on_start_battle_pressed() -> void:
	if not _can_modify_units():
		return
	_cancel_unit_drags()
	# If wave manager is waiting between waves, skip prep timer
	if wave_manager and wave_manager.is_waiting_for_next_wave:
		wave_manager.skip_preparation()
		return
	
	# Otherwise, normal start battle during initial preparation
	if battle_manager and battle_manager.current_state == BattleManager.State.PREPARATION:
		battle_manager.force_start_battle()


func _on_battle_state_changed(new_state: int) -> void:
	var can_interact: bool = _can_modify_units() and _placement_stats == null
	_set_drag_enabled(can_interact)
	# Disable the start button outside preparation or during placement
	if start_battle_button:
		start_battle_button.disabled = not can_interact
		if new_state == BattleManager.State.PREPARATION:
			var waiting: bool = wave_manager and wave_manager.is_waiting_for_next_wave
			start_battle_button.text = "Next Wave" if waiting else "Start Battle"
		elif new_state == BattleManager.State.ENDED:
			# After wave ends, button will be re-enabled by wave manager prep phase
			start_battle_button.text = "Start Battle"
		else:
			start_battle_button.text = "Battle..."

	# Toggle unit selection panel interactability
	if unit_selection_panel:
		unit_selection_panel.set_interactable(can_interact)
		if not can_interact:
			_set_deck_panel_visible(false)
	if toggle_units_button:
		toggle_units_button.visible = can_interact
		_update_toggle_button_text()
	_refresh_selected_unit_panel()


# ── Placement Mode ──

## Toggles the unit selection panel visibility.
func _on_toggle_units_pressed() -> void:
	if not _can_modify_units():
		return
	var show_deck: bool = not unit_selection_panel.visible
	_cancel_unit_drags()
	_set_deck_panel_visible(show_deck)


func _on_quit_game_pressed() -> void:
	get_tree().quit()


func _update_toggle_button_text() -> void:
	if toggle_units_button and unit_selection_panel:
		toggle_units_button.text = "Units ▲" if unit_selection_panel.visible else "Units ▼"


## Called when a card is clicked in the panel.
func _on_panel_unit_selected(unit_stats: UnitStats) -> void:
	if not _can_modify_units() or _placement_stats != null:
		return
	_placement_stats = unit_stats
	_drag_placing = false
	# Hide panel while placing
	if unit_selection_panel:
		unit_selection_panel.visible = false
		_update_toggle_button_text()
	_set_drag_enabled(false)
	if start_battle_button:
		start_battle_button.disabled = true
	_refresh_selected_unit_panel()
	# Match highlighter to the selected unit's footprint
	if game_area and game_area.tile_highlighter:
		game_area.tile_highlighter.footprint = unit_stats.footprint
		game_area.tile_highlighter.tracking_target = null
		game_area.tile_highlighter.reset_tracking()
		game_area.tile_highlighter.enabled = true
	# Create ghost sprite that follows the cursor
	_create_placement_ghost(unit_stats)


## Called when a card is dragged in the panel — enters drag-placement mode.
func _on_panel_unit_drag_started(unit_stats: UnitStats) -> void:
	if not _can_modify_units() or _placement_stats != null:
		return
	_placement_stats = unit_stats
	_drag_placing = true
	# Hide panel while dragging
	if unit_selection_panel:
		unit_selection_panel.visible = false
		_update_toggle_button_text()
	_set_drag_enabled(false)
	if start_battle_button:
		start_battle_button.disabled = true
	_refresh_selected_unit_panel()
	# Match highlighter to the selected unit's footprint
	if game_area and game_area.tile_highlighter:
		game_area.tile_highlighter.footprint = unit_stats.footprint
		game_area.tile_highlighter.tracking_target = null
		game_area.tile_highlighter.reset_tracking()
		game_area.tile_highlighter.enabled = true
	_create_placement_ghost(unit_stats)


## Called when placement is cancelled from the panel (clicking same card again).
func _on_placement_cancelled() -> void:
	_exit_placement_mode()


func _input(event: InputEvent) -> void:
	# ── Space toggles unit selection panel ──
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		if _can_modify_units():
			_on_toggle_units_pressed()
			get_viewport().set_input_as_handled()
			return
	# Right-click or ESC → cancel placement
	if not event.is_action_pressed("cancel_drag"):
		return
	var was_active: bool = is_instance_valid(_selected_unit) or _placement_stats != null
	_cancel_unit_drags()
	if _placement_stats:
		unit_selection_panel.cancel_selection()
	# ── Right-click deselects instead of selling a placed unit ──
	_clear_unit_selection()
	if was_active:
		get_viewport().set_input_as_handled()


## Handles unhandled input for placement clicks, deck visibility, and quick selling.
func _unhandled_input(event: InputEvent) -> void:
	# ── Mouse scroll zoom ──
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var new_zoom := minf(camera.zoom.x + ZOOM_STEP, ZOOM_MAX)
			camera.zoom = Vector2(new_zoom, new_zoom)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var new_zoom := maxf(camera.zoom.x - ZOOM_STEP, ZOOM_MIN)
			camera.zoom = Vector2(new_zoom, new_zoom)
			get_viewport().set_input_as_handled()
			return

	# ── Middle-click camera pan ──
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			_camera_panning = true
			_camera_pan_start = event.global_position
		else:
			_camera_panning = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _camera_panning:
		camera.position -= (event.relative / camera.zoom)
		get_viewport().set_input_as_handled()
		return

	# ── Quick sell: E key to delete hovered unit (during prep phase) ──
	if not _placement_stats and event.is_action_pressed("quick_sell"):
		if _can_modify_units() and game_area:
			var tile := game_area.get_hovered_tile()
			if game_area.is_tile_within_bounds(tile) and game_area.unit_grid.is_tile_occupied(tile):
				var hovered_unit: Node = game_area.unit_grid.get_unit_at(tile)
				_remove_placed_unit(game_area.unit_grid.get_unit_anchor(hovered_unit))
				get_viewport().set_input_as_handled()
				return

	if not _placement_stats:
		return
	if not _can_modify_units():
		unit_selection_panel.cancel_selection()
		return

	# Left-click → place on hovered tile (click mode: press, drag mode: release)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var want_place := false
		if _drag_placing and not event.pressed:
			want_place = true  # Drag mode: place on release
		elif not _drag_placing and event.pressed:
			want_place = true  # Click mode: place on press
		if not want_place:
			return
		if not game_area:
			if _drag_placing:
				_exit_placement_mode()
				if unit_selection_panel:
					unit_selection_panel.cancel_selection()
			return
		var footprint: Vector2i = _placement_stats.footprint
		var hovered := game_area.get_hovered_tile()
		if not game_area.is_tile_within_bounds(hovered):
			if _drag_placing:
				_exit_placement_mode()
				if unit_selection_panel:
					unit_selection_panel.cancel_selection()
			return
		var mouse_pos := game_area.get_global_mouse_position()
		var tile := game_area.get_anchor_for_global(mouse_pos, footprint)
		if not game_area.unit_grid.is_area_free(tile, footprint):
			if _drag_placing:
				_exit_placement_mode()
				if unit_selection_panel:
					unit_selection_panel.cancel_selection()
			return

		# Spawn the unit at the chosen anchor
		var spawned := unit_spawner.spawn_unit(_placement_stats, tile)
		if not spawned:
			return
		if unit_selection_panel:
			unit_selection_panel.on_unit_placed(_placement_stats)
		# Shift held → stay in placement mode for multi-place
		if Input.is_key_pressed(KEY_SHIFT) and _placement_stats:
			# Check if we can still afford
			if player_stats and _placement_stats and player_stats.gold < _placement_stats.gold_cost:
				_exit_placement_mode()
				if unit_selection_panel:
					unit_selection_panel.cancel_selection()
			# else: keep ghost active, stay in placement mode
		else:
			_exit_placement_mode()
			if unit_selection_panel:
				unit_selection_panel.cancel_selection()

		get_viewport().set_input_as_handled()


func _exit_placement_mode() -> void:
	_placement_stats = null
	_drag_placing = false
	_last_ghost_anchor = Vector2i(-1, -1)
	# Remove ghost sprite
	if _placement_ghost and is_instance_valid(_placement_ghost):
		_placement_ghost.queue_free()
		_placement_ghost = null
	# Reset highlighter footprint to the default 4x4 tile
	if game_area and game_area.tile_highlighter:
		game_area.tile_highlighter.footprint = Vector2i(4, 4)
		game_area.tile_highlighter.tracking_target = null
		game_area.tile_highlighter.reset_tracking()
		game_area.tile_highlighter.enabled = false
	# Show panel again
	_set_deck_panel_visible(true)
	var can_interact: bool = _can_modify_units()
	_set_drag_enabled(can_interact)
	if start_battle_button:
		start_battle_button.disabled = not can_interact
	_refresh_selected_unit_panel()


## Removes a placed ally unit from the grid, refunds gold, and frees the node.
func _remove_placed_unit(tile: Vector2i) -> void:
	if not _can_modify_units() or _placement_stats != null:
		return
	var unit: Unit = game_area.unit_grid.units.get(tile) as Unit
	if not is_instance_valid(unit) or not unit.stats or unit.current_health <= 0.0 \
			or unit.is_queued_for_deletion():
		return
	# King cannot be removed
	if unit.stats.is_king:
		return
	if unit == _selected_unit:
		_clear_unit_selection()

	# Refund gold
	var refund: int = unit.stats.gold_cost
	if player_stats:
		player_stats.gold += refund


	# Remove from grid
	game_area.unit_grid.remove_unit(tile)

	# Update panel deployed count
	if unit_selection_panel:
		unit_selection_panel.on_unit_removed()

	# Free the unit
	unit.queue_free()


## Upgrades the selected ally on `tile` into the option chosen in its info panel.
## The replacement keeps its position and the player pays the difference in gold.
## Only an upgrade belonging to the current unit is accepted during preparation.
## The original unit is kept alive until the replacement is successfully spawned.
func _upgrade_placed_unit(tile: Vector2i, target: UnitStats) -> void:
	if not _can_modify_units() or _placement_stats or not player_stats:
		return
	var unit: Unit = game_area.unit_grid.units.get(tile) as Unit
	if not is_instance_valid(unit) or not unit.stats or unit != _selected_unit:
		return
	if unit.current_health <= 0.0 or unit.is_queued_for_deletion() or unit.drag_and_drop.dragging:
		return
	var current: UnitStats = unit.stats
	if current.is_king or current.team != UnitStats.Team.PLAYER:
		return
	if not current.has_upgrades():
		return

	if not target or not current.upgrades.has(target) or target.team != UnitStats.Team.PLAYER:
		push_warning("[Upgrade] Invalid upgrade choice for %s" % current.name)
		return
	var cost: int = current.get_upgrade_cost(target)
	if player_stats.gold < cost:
		_show_toast("Not enough gold: %s needs %d" % [target.name, cost], Color(1.0, 0.6, 0.3))
		return

	# Pay, then swap the unit. The spawner duplicates stats and re-registers the new unit with
	# UnitMover + SynergyManager via unit_spawned, while selection transfers to the new node.
	player_stats.gold -= cost
	game_area.unit_grid.remove_unit(tile)
	var upgraded: Unit = unit_spawner.spawn_unit(target, tile) as Unit
	if not upgraded:
		push_warning("[Upgrade] Failed to spawn %s — refunding %d gold" % [target.name, cost])
		game_area.unit_grid.add_unit(tile, unit)
		player_stats.gold += cost
		return

	upgraded.global_position = unit.global_position
	_set_selected_unit(upgraded)
	unit.queue_free()
	_show_toast("%s upgraded to %s" % [current.name, target.name], Color(0.5, 0.9, 1.0))
	var vfx_spawner = get_tree().get_first_node_in_group("vfx_spawner")
	if vfx_spawner and vfx_spawner.has_method("spawn_vfx_on_unit"):
		vfx_spawner.spawn_vfx_on_unit("explosion_heal", upgraded)
	# Deployed count is unchanged (one unit out, one in) — only refresh gold/affordability
	if unit_selection_panel and player_stats:
		unit_selection_panel.set_player_stats(player_stats)


func _show_toast(message: String, color: Color) -> void:
	if toast_manager:
		toast_manager.show_toast(message, 2.5, color)


## Creates a semi-transparent ghost sprite that follows the cursor for placement preview.
func _create_placement_ghost(unit_stats: UnitStats) -> void:
	# Remove old ghost if any
	if _placement_ghost and is_instance_valid(_placement_ghost):
		_placement_ghost.queue_free()

	_placement_ghost = Sprite2D.new()
	_placement_ghost.texture = UnitStats.TEAM_SPRITESHEET.get(unit_stats.team)
	if not _placement_ghost.texture:
		push_warning("[Arena] No spritesheet found for team %d — ghost invisible"
				% unit_stats.team)
		_placement_ghost.queue_free()
		_placement_ghost = null
		return
	_placement_ghost.region_enabled = true
	_placement_ghost.region_rect = Rect2(
		Vector2(unit_stats.skin_coordinates) * Vector2(unit_stats.tile_size),
		Vector2(unit_stats.tile_size)
	)
	# Match the in-game sprite: raise by half the tile height so the unit's base
	# sits near the tile center instead of being centered in the highlight box.
	_placement_ghost.offset = Vector2(0, -float(unit_stats.tile_size.y) / 2.0)
	_placement_ghost.modulate = Color(1, 1, 1, 0.6)
	_placement_ghost.z_index = 100
	add_child(_placement_ghost)


var _stats_update_timer: float = 0.0
const STATS_UPDATE_INTERVAL: float = 0.25  ## Update stats 4x per second instead of every frame

## Updates the unit stats display on a throttled timer.
func _process(delta: float) -> void:
	_stats_update_timer -= delta
	if _stats_update_timer <= 0:
		_stats_update_timer = STATS_UPDATE_INTERVAL
		_refresh_selected_unit_panel()

	# Move placement ghost to snap to the hovered footprint anchor
	if _placement_ghost and is_instance_valid(_placement_ghost) and game_area and _placement_stats:
		var tile := game_area.get_hovered_tile()
		if game_area.is_tile_within_bounds(tile):
			var footprint: Vector2i = _placement_stats.footprint
			var mouse_pos := game_area.get_global_mouse_position()
			var anchor := game_area.get_anchor_for_global(mouse_pos, footprint)
			if anchor != _last_ghost_anchor:
				_last_ghost_anchor = anchor
			_placement_ghost.visible = true
			_placement_ghost.global_position = game_area.get_unit_position(anchor, footprint)
			# Tint green if free, red if occupied
			if not game_area.unit_grid.is_area_free(anchor, footprint):
				_placement_ghost.modulate = Color(1.0, 0.3, 0.3, 0.5)
			else:
				_placement_ghost.modulate = Color(0.3, 1.0, 0.5, 0.6)
		else:
			_placement_ghost.visible = false


## Enables or disables dragging for all units.
func _set_drag_enabled(enabled: bool) -> void:
	var all_units := get_tree().get_nodes_in_group("units")
	for unit in all_units:
		if unit is Unit:
			var can_drag: bool = enabled and unit.current_health > 0.0 and not unit.is_dead()
			unit.drag_and_drop.enabled = can_drag
