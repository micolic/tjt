@tool
class_name EnemyUnit
extends Area2D

@export var stats: UnitStats : set = set_stats

@onready var skin: Node2D = $Visuals/Skin
@onready var health_bar: ProgressBar = $HealthBar
@onready var mana_bar: ProgressBar = $ManaBar
@onready var velocity_based_rotation: VelocityBasedRotation = $VelocityBasedRotation
@onready var animator: UnitAnimator = $UnitAnimator

var _health_flash_id: int = 0
var _skin_flash_id: int = 0
var _is_dead: bool = false  ## Guard: prevents multiple death signal emissions

## Returns true if the unit has died and is queued for deletion.
func is_dead() -> bool:
	return _is_dead

## Current health — synced with stats.health for interface compatibility with Unit.
## This allows abilities and AI to use `current_health` uniformly on both Unit and EnemyUnit.
var current_health: float :
	get:
		return float(stats.health) if stats else 0.0
	set(value):
		if stats:
			stats.health = int(maxi(value, 0.0))

## Current mana — synced with stats.mana for interface compatibility with Unit.
var current_mana: float :
	get:
		return float(stats.mana) if stats else 0.0
	set(value):
		if stats:
			stats.mana = int(clampi(value, 0.0, float(stats.max_mana)))

signal damage_dealt_changed(new_damage: float)

## Track damage dealt by this unit (useful for analytics / debugging)
var damage_dealt: float = 0.0

## Threat bookkeeping — lets AI avoid overkill / overheal
var incoming_damage: float = 0.0
var incoming_healing: float = 0.0

func get_effective_health() -> float:
	return maxf(current_health - incoming_damage, 0.0)

func get_effective_missing_health() -> float:
	if stats:
		var effective_hp: float = minf(current_health + incoming_healing, stats.max_health)
		return maxf(stats.max_health - effective_hp, 0.0)
	return 0.0

## Called when the node enters the scene tree.
func _ready() -> void:
	if not Engine.is_editor_hint():
		# Connect stats signals
		if stats:
			_connect_stats_signals()
		
		# Setup animator
		if animator:
			animator.setup(skin, $Visuals)
			animator.play(UnitAnimator.AnimState.IDLE)


## Connects to unit stats signals.
func _connect_stats_signals() -> void:
	if not stats:
		return

	# Prevent duplicate connections
	if stats.health_reached_zero.is_connected(_on_health_reached_zero):
		return

	stats.health_reached_zero.connect(_on_health_reached_zero)

	# Connect health_changed signal
	stats.health_changed.connect(func(_new_health): _update_health_bar())

	# Add to team groups via shared helper
	UnitVisuals.setup_team_groups(self, stats)

	# Initialize health and mana
	stats.reset_health()
	stats.reset_mana()
	_update_health_bar()
	_update_mana_bar()


var _last_health_value: float = -1.0

## Updates health bar display.
func _update_health_bar() -> void:
	if not stats or not health_bar:
		return

	health_bar.max_value = stats.get_max_health()
	health_bar.value = stats.health

	# Update health bar color based on health percentage
	_update_health_bar_color()

	# Flash effect only when actually taking damage (health decreased)
	if _last_health_value > 0 and stats.health < _last_health_value:
		_flash_health_bar()
	_last_health_value = stats.health


## Update health bar color gradient based on health percentage.
func _update_health_bar_color() -> void:
	if not stats or not health_bar:
		return
	var health_percent: float = float(stats.health) / float(stats.get_max_health())
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
	mana_bar.value = stats.mana


## Called when unit's health reaches zero.
func _on_health_reached_zero() -> void:
	if _is_dead:
		return
	_is_dead = true
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
		animator.death_animation_finished.connect(
			func(): UnitVisuals.handle_unit_death(self), CONNECT_ONE_SHOT
		)
	else:
		UnitVisuals.handle_unit_death(self)


## Apply damage to this enemy unit (uniform interface for AI/abilities).
## damage_type controls armor/MR reduction (default PHYSICAL for auto-attacks).
func apply_damage(
	damage: int,
	damage_type: UnitStats.DamageType = UnitStats.DamageType.PHYSICAL
) -> void:
	if not stats:
		return
	var reduced: float = UnitStats.calculate_reduced_damage(
		float(damage), damage_type, stats.armor, stats.magic_resist
	)
	var final_damage: int = roundi(reduced)
	current_health = maxf(current_health - final_damage, 0.0)
	# Reduce incoming_damage since this damage has now landed
	incoming_damage = maxf(incoming_damage - damage, 0.0)


## Register damage dealt by this unit (for parity with `Unit` interface)
func register_damage_dealt(amount: float) -> void:
	damage_dealt += amount
	damage_dealt_changed.emit(damage_dealt)


## Reset per-battle damage counter and notify UI
func reset_damage_dealt() -> void:
	damage_dealt = 0.0
	damage_dealt_changed.emit(damage_dealt)


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

	# Apply visual scale (e.g. larger enemies)
	if value.visual_scale != 1.0:
		$Visuals.scale = Vector2(value.visual_scale, value.visual_scale)
		if animator:
			animator.set_base_scale($Visuals.scale)

	# Position HP/Mana bars above the (visually scaled) sprite, centered on the unit.
	_update_bar_positions()

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
	# Re-setup animator with new skin and play idle
	if animator:
		animator.setup(skin, $Visuals)
		animator.play(UnitAnimator.AnimState.IDLE)
	# Play "idle" directly on the sprite as well (in case animator doesn't handle it)
	var anims = value.sprite_frames.get_animation_names()
	if "idle" in anims:
		anim_sprite.play("idle")
