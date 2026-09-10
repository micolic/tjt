@tool
class_name Unit
extends Area2D

signal quick_sell_pressed
signal health_reached_zero
signal health_changed(new_health: int)
signal mana_bar_filled
signal mana_changed(new_mana: int)  # Receives int for UI display
signal damage_dealt_changed(new_damage: float)
signal selection_requested(unit: Unit)

## Verbose ability logging (mirrors UnitAI.DEBUG_AI_VERBOSE)
const DEBUG_AI_VERBOSE: bool = false

@export var stats: UnitStats : set = set_stats

@onready var skin: Node2D = $Visuals/Skin
@onready var health_bar: ProgressBar = $HealthBar
@onready var mana_bar: ProgressBar = $ManaBar
@onready var drag_and_drop: DragAndDrop = $DragAndDrop
@onready var velocity_based_rotation: VelocityBasedRotation = $VelocityBasedRotation
@onready var outline_highlighter: OutlineHighlighter = $OutlineHighlighter
@onready var animator: UnitAnimator = $UnitAnimator

var is_hovered: bool = false
var is_selected: bool = false
var _health_flash_id: int = 0
var _skin_flash_id: int = 0
var _is_dead: bool = false  ## Guard: prevents multiple death signal emissions

## Returns true if the unit has died and is queued for deletion.
func is_dead() -> bool:
	return _is_dead

var current_health: float : set = _set_current_health
var current_mana: float : set = _set_current_mana
var ability_on_cooldown: bool = false
var _mana_retry_task_running: bool = false
var _passive_applied: bool = false  ## Prevents passive from stacking on re-init

## Threat bookkeeping — lets AI avoid overkill / overheal
var incoming_damage: float = 0.0   ## Total damage already "promised" by attackers this tick
var incoming_healing: float = 0.0  ## Total healing already "promised" by healers this tick
## Total damage this unit has dealt during the current battle
var damage_dealt: float = 0.0

## Effective HP that AI should use for target selection.
## Returns current_health minus damage already in-flight, clamped to 0.
func get_effective_health() -> float:
	return maxf(current_health - incoming_damage, 0.0)

## Effective missing HP that healers should use.
func get_effective_missing_health() -> float:
	var effective_hp: float = minf(current_health + incoming_healing, stats.max_health)
	return maxf(stats.max_health - effective_hp, 0.0)

## Called when the node enters the scene tree. Connects drag signals if not in editor.
func _ready() -> void:
	if not Engine.is_editor_hint():
		drag_and_drop.drag_started.connect(_on_drag_started)
		drag_and_drop.drag_canceled.connect(_on_drag_canceled)
		drag_and_drop.dropped.connect(_on_drag_dropped)
		input_event.connect(_on_selection_input_event)
		
		# Connect mana bar filled for ability casting
		mana_bar_filled.connect(_on_mana_bar_filled)
		
		# Connect stats signals
		if stats:
			_connect_stats_signals()
		
		# Setup animator
		if animator:
			animator.setup(skin, $Visuals)
			animator.play(UnitAnimator.AnimState.IDLE)
		
		# Add to unit grid (only for pre-placed scene units, NOT spawner-created ones)
		# Spawner already handles grid placement before _ready fires.
		var parent_node = get_parent()
		if parent_node and parent_node is PlayArea and parent_node.unit_grid:
			var play_area: PlayArea = parent_node as PlayArea
			var fp := UnitGrid.footprint_of(self)
			var anchor = play_area.get_anchor_for_global(global_position, fp)
			if play_area.unit_grid.is_area_free(anchor, fp):
				play_area.unit_grid.add_unit(anchor, self)


var _battle_manager_cache: Node = null  ## Cached BattleManager reference

## Processes health and mana regeneration.
func _process(delta: float) -> void:
	# Regeneration - only during BATTLE
	if not stats:
		return
	
	# Cached BattleManager lookup
	if not is_instance_valid(_battle_manager_cache):
		_battle_manager_cache = get_tree().get_first_node_in_group("battle_manager")
	if not _battle_manager_cache:
		return
	
	# Only regenerate during battle
	if _battle_manager_cache.current_state != BattleManager.State.BATTLE:
		return
	
	# Health regeneration
	if current_health < stats.max_health and stats.health_regen > 0:
		var health_regen_amount = stats.health_regen * delta
		current_health = min(current_health + health_regen_amount, stats.max_health)
		_update_health_bar()
	
	# Mana regeneration
	if current_mana < stats.max_mana:
		var mana_regen_amount = stats.mana_regen * delta
		if mana_regen_amount > 0:
			current_mana = min(current_mana + mana_regen_amount, stats.max_mana)
			_update_mana_bar()



## Connects to unit stats signals.
func _connect_stats_signals() -> void:
	if not stats:
		return
	
	# Prevent duplicate connections
	if health_reached_zero.is_connected(_on_health_reached_zero):
		return
	
	health_reached_zero.connect(_on_health_reached_zero)
	
	# Connect health_changed signal
	health_changed.connect(func(_new_health): _update_health_bar())
	# Health-reactive passives (e.g. Berserk) re-evaluate on every HP change, incl. wave reset
	health_changed.connect(func(_new_health):
		if stats and stats.passive_ability:
			stats.passive_ability.on_health_changed(self)
	)
	
	# Add to team groups via shared helper
	UnitVisuals.setup_team_groups(self, stats)
	
	# Apply passive ability if present (only once per unit instance)
	if stats.passive_ability and not _passive_applied:
		stats.passive_ability.apply(self)
		_passive_applied = true
	
	# Initialize health and mana
	current_health = stats.max_health
	current_mana = stats.starting_mana
	_update_health_bar()
	_update_mana_bar()


## Updates health bar display.
func _update_health_bar() -> void:
	if not stats or not health_bar:
		return
	
	health_bar.max_value = stats.get_max_health()
	health_bar.value = current_health
	
	# Update health bar color based on health percentage
	_update_health_bar_color()


## Update health bar color gradient based on health percentage.
func _update_health_bar_color() -> void:
	if not stats or not health_bar:
		return
	var health_percent: float = float(current_health) / float(stats.get_max_health())
	UnitVisuals.apply_health_bar_color(health_bar, health_percent)


## Flash health bar white when taking damage.
func _flash_health_bar() -> void:
	_health_flash_id = UnitVisuals.flash_health_bar(health_bar, get_tree(), _health_flash_id)


## Flash the unit's skin for visual feedback.
func flash_skin(flash_color: Color = Color.RED) -> void:
	_skin_flash_id = UnitVisuals.flash_skin(skin, get_tree(), _skin_flash_id, flash_color)


## Updates mana bar display.
func _update_mana_bar() -> void:
	if not stats or not mana_bar:
		return
	
	mana_bar.max_value = stats.max_mana
	mana_bar.value = current_mana

## Sets current health and emits signals.
func _set_current_health(value: float) -> void:
	var damage_taken = current_health - value
	current_health = value
	
	# Spawn damage number if we took damage
	if damage_taken > 0:
		_spawn_damage_number(damage_taken)
	
	health_changed.emit(int(current_health))
	if current_health <= 0 and not _is_dead:
		_is_dead = true
		health_reached_zero.emit()


## Sets current mana and emits signal if full.
func _set_current_mana(value: float) -> void:
	current_mana = value
	mana_changed.emit(int(current_mana))
	if current_mana >= stats.max_mana:
		mana_bar_filled.emit()


## Called when unit's health reaches zero.
func _on_health_reached_zero() -> void:
	input_pickable = false
	drag_and_drop.enabled = false
	is_hovered = false
	set_selected(false)
	# _is_dead guard in _set_current_health prevents duplicate calls
	# Permadeath toast — only for player units (not King, not enemies)
	if stats.team == UnitStats.Team.PLAYER and not stats.is_king:
		var toast_mgr := get_tree().get_first_node_in_group("toast_manager")
		if toast_mgr and toast_mgr.has_method("show_toast"):
			toast_mgr.show_toast("%s has fallen permanently" % stats.name, 2.5, Color(1.0, 0.35, 0.35))
	# Disable AI so dead units stop attacking
	var ai = get_node_or_null("UnitAI")
	if ai:
		ai.enabled = false
	# Spawn death VFX
	var vfx_spawner = get_tree().get_first_node_in_group("vfx_spawner")
	if vfx_spawner and vfx_spawner.has_method("spawn_vfx_on_unit"):
		vfx_spawner.spawn_vfx_on_unit("death_effect", self)
	if animator and not animator.is_dead():
		animator.play(UnitAnimator.AnimState.DEATH)
		animator.death_animation_finished.connect(func(): UnitVisuals.handle_unit_death(self), CONNECT_ONE_SHOT)
	else:
		UnitVisuals.handle_unit_death(self)


## Spawns a floating damage number above the unit.
func _spawn_damage_number(damage: float) -> void:
	UnitVisuals.spawn_damage_number(get_tree(), global_position, damage)


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
	
	# If sprite_frames are provided, swap Sprite2D for AnimatedSprite2D
	if value.sprite_frames:
		_swap_to_animated_sprite(value)
	else:
		# Set the correct spritesheet based on team
		skin.texture = value.TEAM_SPRITESHEET[value.team]
		skin.region_rect = Rect2(
			Vector2(stats.skin_coordinates) * Vector2(value.tile_size),
			Vector2(value.tile_size)
		)
		# The unit's origin is the footprint center. Raise the sprite by half the
		# tile height so the unit's base sits near the tile center and it does not
		# look like it is lying on the bottom edge of the highlighted tile.
		if skin is Sprite2D:
			var y_off: float = -float(value.tile_size.y) / 2.0
			skin.offset = Vector2(0, y_off)
			# Animator captures _base_offset in _ready before set_stats runs, then
			# overrides skin.offset.y every frame. Sync it so the offset persists.
			if animator:
				animator.set_base_offset(skin.offset)

	# Apply visual scale (e.g. King is larger)
	if value.visual_scale != 1.0:
		$Visuals.scale = Vector2(value.visual_scale, value.visual_scale)
		# Re-capture base scale so animator restores the correct size after attacks
		if animator:
			animator.set_base_scale($Visuals.scale)

	# Position HP/Mana bars above the (visually scaled) sprite, centered on the unit.
	_update_bar_positions()
	_update_collision_shape()

	# Connect stats signals if not in editor
	if not Engine.is_editor_hint():
		_connect_stats_signals()



## Repositions HP and Mana bars so they sit just above the sprite.
## The sprite is raised by skin.offset.y (in Visuals-local space); since Visuals
## is scaled by visual_scale, the raise in the unit's local space is
## skin.offset.y * visual_scale. The bars follow the raised sprite.
func _update_bar_positions() -> void:
	if not stats or not health_bar or not mana_bar:
		return
	var scaled_size: Vector2 = Vector2(stats.tile_size) * stats.visual_scale
	var half_size: Vector2 = scaled_size * 0.5
	# Match the sprite raise so bars sit above the raised sprite, not the tile.
	var skin_raise: float = (skin.offset.y if skin is Sprite2D else 0.0) * stats.visual_scale
	var top: float = -half_size.y + skin_raise
	var h_bar: ProgressBar = health_bar
	var m_bar: ProgressBar = mana_bar
	h_bar.offset_left = -half_size.x + 1.0
	h_bar.offset_right = half_size.x - 1.0
	h_bar.offset_top = top - 12.0
	h_bar.offset_bottom = top - 6.0
	m_bar.offset_left = -half_size.x + 1.0
	m_bar.offset_right = half_size.x - 1.0
	m_bar.offset_top = top - 5.0
	m_bar.offset_bottom = top - 1.0


## Resizes the clickable shape to cover the raised sprite AND the footprint tile.
## Without this only the tile under the unit's feet is clickable; the sprite body
## drawn above the origin would miss clicks. Shape is per-instance (sizes vary).
func _update_collision_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not stats or shape_node == null:
		return
	var skin_offset: Vector2 = skin.offset if skin is Sprite2D else Vector2.ZERO
	var sprite_center: Vector2 = skin_offset * stats.visual_scale
	var sprite_half: Vector2 = Vector2(stats.tile_size) * stats.visual_scale * 0.5
	var fp_half: Vector2 = Vector2(UnitGrid.footprint_of(self)) * PlayArea.GRID_CELL_PX * 0.5
	var top: float = minf(sprite_center.y - sprite_half.y, -fp_half.y)
	var bottom: float = maxf(sprite_center.y + sprite_half.y, fp_half.y)
	var left: float = minf(sprite_center.x - sprite_half.x, -fp_half.x)
	var right: float = maxf(sprite_center.x + sprite_half.x, fp_half.x)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(right - left, bottom - top) + Vector2(4.0, 4.0)
	shape_node.shape = rect
	shape_node.position = Vector2(left + right, top + bottom) * 0.5


## Swaps the static Sprite2D skin for an AnimatedSprite2D using the stats' sprite_frames.
func _swap_to_animated_sprite(value: UnitStats) -> void:
	var old_skin := skin
	var parent := old_skin.get_parent()
	var anim_sprite := AnimatedSprite2D.new()
	anim_sprite.name = "Skin"
	anim_sprite.sprite_frames = value.sprite_frames
	anim_sprite.offset = old_skin.offset
	parent.remove_child(old_skin)
	parent.add_child(anim_sprite)
	parent.move_child(anim_sprite, 0)
	old_skin.queue_free()
	skin = anim_sprite
	# Update velocity_based_rotation target
	if velocity_based_rotation:
		velocity_based_rotation.target = skin
	# Re-setup animator with new skin
	if animator:
		animator.setup(skin, $Visuals)

## Resets the unit's position and disables rotation after dragging is canceled.
func reset_after_dragging(starting_position: Vector2) -> void:
	velocity_based_rotation.enabled = false
	global_position = starting_position
	refresh_highlight()

## Called when dragging starts; enables velocity-based rotation.
func _on_drag_started() -> void:
	velocity_based_rotation.enabled = true
	#outline_highlighter.clear_highlight()
	refresh_highlight()

## Called when dragging is canceled; resets the unit's state.
func _on_drag_canceled(starting_position: Vector2) -> void:
	reset_after_dragging(starting_position)


func _on_drag_dropped(_starting_position: Vector2) -> void:
	velocity_based_rotation.enabled = false
	refresh_highlight.call_deferred()


func _on_selection_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if not _is_dead and event.is_action_pressed("select"):
		selection_requested.emit(self)


func set_selected(selected: bool) -> void:
	is_selected = selected and not _is_dead
	refresh_highlight()


func refresh_highlight() -> void:
	if not is_node_ready():
		return
	if not _is_dead and (is_selected or is_hovered or drag_and_drop.dragging):
		outline_highlighter.highlight()
		z_index = 4096  # Above any Y-sort value
	else:
		outline_highlighter.clear_highlight()
		z_index = int(global_position.y)  # Restore Y-sort value


## Highlights living units on hover in both preparation and battle.
func _on_mouse_entered() -> void:
	if _is_dead:  # Dead units cannot be inspected
		return
	is_hovered = true
	refresh_highlight()

## Clears the hover state without removing a selected unit's highlight.
func _on_mouse_exited() -> void:
	is_hovered = false
	refresh_highlight()


## Called when mana bar is filled - cast ability if available
func _on_mana_bar_filled() -> void:
	if not stats or not stats.ability_resource:
		return
	
	if ability_on_cooldown:
		return
	
	# Cast the ability
	var cast_ok := cast_ability()
	# If no valid targets, retry every second while mana stays full
	if not cast_ok and not ability_on_cooldown and current_mana >= stats.max_mana and not _mana_retry_task_running:
		_mana_retry_task_running = true
		# start async retry loop
		while current_mana >= stats.max_mana and not ability_on_cooldown:
			await get_tree().create_timer(1.0).timeout
			if cast_ability():
				break
			# loop continues until cast succeeds or mana changes/cooldown starts
		_mana_retry_task_running = false


## Casts the unit's ability
func cast_ability() -> bool:
	if not stats or not stats.ability_resource:
		return false

	var ability = stats.ability_resource
	
	# Get valid targets
	var targets = ability.get_valid_targets(self)
	
	if targets.is_empty():
		if DEBUG_AI_VERBOSE:
			var _range_msg = ""
			if ability.cast_range > 0:
				_range_msg = " (range: %.0f)" % ability.cast_range
		# Don't consume mana if no targets
		return false
	
	# Consume mana
	current_mana = 0
	
	# Execute ability
	ability.execute(self, targets)

	# Start cooldown if needed
	if ability.cooldown > 0:
		ability_on_cooldown = true
		get_tree().create_timer(ability.cooldown).timeout.connect(_on_ability_cooldown_finished)

	return true


## Apply damage to this unit (uniform interface for AI/abilities).
## damage_type controls armor/MR reduction (default PHYSICAL for auto-attacks).
func apply_damage(damage: int, damage_type: UnitStats.DamageType = UnitStats.DamageType.PHYSICAL) -> void:
	var reduced: float = UnitStats.calculate_reduced_damage(
		float(damage), damage_type, stats.armor if stats else 0, stats.magic_resist if stats else 0
	)
	var final_damage: int = roundi(reduced)
	# Per-hit passives (e.g. Vanguard's Iron Skin) apply after armor/MR
	if stats and stats.passive_ability:
		final_damage = stats.passive_ability.modify_incoming_damage(final_damage)
	current_health = max(current_health - final_damage, 0)
	# Reduce incoming_damage since this damage has now landed
	incoming_damage = maxf(incoming_damage - final_damage, 0.0)


## Register damage this unit has dealt to others (for per-unit DPS/damage counters)
func register_damage_dealt(amount: float) -> void:
	damage_dealt += amount
	damage_dealt_changed.emit(damage_dealt)


## Reset per-battle damage counter and notify UI
func reset_damage_dealt() -> void:
	damage_dealt = 0.0
	damage_dealt_changed.emit(damage_dealt)


## Called when ability cooldown finishes
func _on_ability_cooldown_finished() -> void:
	ability_on_cooldown = false
