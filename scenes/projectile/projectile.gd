extends Node2D
class_name Projectile

## Base projectile that moves toward a target

@export var speed: float = 300.0
@export var damage: float = 50.0
@export var hit_color: Color = Color.ORANGE_RED
@export var _is_basic_attack: bool = false  ## If true, uses hit_physical VFX not explosion_fire

var target
var caster
var is_setup: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Wait for setup to be called
	# Ensure processing is enabled if this node is active
	set_process(true)


## Reset state for reuse from pool.
func reset() -> void:
	target = null
	caster = null
	is_setup = false
	damage = 50.0
	hit_color = Color.ORANGE_RED
	_is_basic_attack = false
	rotation = 0.0
	global_position = Vector2.ZERO
	if sprite:
		sprite.modulate = Color.ORANGE_RED
		sprite.scale = Vector2(1.5, 1.5)


func _process(delta: float) -> void:
	if not is_setup:
		return
	
	if not target or not is_instance_valid(target):
		_return_to_pool()
		return
	
	# Move toward target - ensure it's a Node2D so it has global_position
	if not (target is Node2D):
		_return_to_pool()
		return
	var direction = global_position.direction_to(target.global_position)
	global_position += direction * speed * delta
	
	# Check if we hit the target
	if global_position.distance_to(target.global_position) < 10.0:
		_hit_target()


func _hit_target() -> void:
	if not target or not is_instance_valid(target):
		_return_to_pool()
		return
	# Dummy targets (like player base) don't take damage — just despawn
	if target.has_meta("is_dummy_target"):
		_return_to_pool()
		return
	# Deal damage via interface if available
	if target.has_method("apply_damage"):
		if _is_basic_attack and caster and is_instance_valid(caster):
			# Basic-attack arrows go through CombatResolver so on-hit passives trigger.
			# Guard against caster dying before projectile lands — fall back to direct damage.
			CombatResolver.resolve_basic_attack(caster, target, int(damage))
		else:
			target.apply_damage(int(damage))
			# Report damage to arena for aggregated output
			var arena: Node = get_tree().get_first_node_in_group("arena")
			if arena and arena.has_method("register_damage_output"):
				arena.call_deferred("register_damage_output", damage)

			# Notify caster about damage dealt (per-unit damage counters)
			if caster and is_instance_valid(caster) and caster.has_method("register_damage_dealt"):
				caster.register_damage_dealt(damage)
	elif target is Unit:
		# Unit-style direct health damage.
		target.current_health = max(target.current_health - damage, 0)
	# Visual feedback if supported
	if target.has_method("flash_skin"):
		target.flash_skin(hit_color)

	# Spawn hit VFX on target (explosion_fire for ability, hit_physical for basic attacks)
	var vfx_spawner = get_tree().get_first_node_in_group("vfx_spawner")
	if vfx_spawner and vfx_spawner.has_method("spawn_vfx_on_unit"):
		# Use hit_physical for basic attacks (smaller), explosion_fire for ability projectiles
		var vfx_type = "hit_physical" if _is_basic_attack else "explosion_fire"
		vfx_spawner.spawn_vfx_on_unit(vfx_type, target)

	# Return to pool instead of freeing
	_return_to_pool()


## Return this projectile to the pool, or queue_free if no pool exists.
func _return_to_pool() -> void:
	var pool_nodes = get_tree().get_nodes_in_group("projectile_pool")
	if not pool_nodes.is_empty() and is_instance_valid(pool_nodes[0]):
		reset()
		pool_nodes[0].release(self, preload("res://scenes/projectile/projectile.tscn"))
	else:
		queue_free()



func setup(from, to, proj_damage: float,
		color: Color = Color.ORANGE_RED, is_basic: bool = false) -> void:
	caster = from
	target = to
	damage = proj_damage
	hit_color = color
	_is_basic_attack = is_basic
	is_setup = true
	
	if sprite:
		sprite.modulate = color
		# Basic attack projectiles are much smaller than ability projectiles
		sprite.scale = Vector2(0.4, 0.4) if is_basic else Vector2(1.5, 1.5)

	# Ensure processing is enabled (some pooled instances may have been disabled)
	set_process(true)
	
	# Face the target
	if target:
		look_at(target.global_position)
