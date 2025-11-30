extends Node2D
class_name Projectile

## Base projectile that moves toward a target

@export var speed: float = 300.0
@export var damage: float = 50.0
@export var hit_color: Color = Color.ORANGE_RED

var target: Unit
var caster: Unit
var is_setup: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Wait for setup to be called
	pass


func _process(delta: float) -> void:
	if not is_setup:
		return
	
	if not target or not is_instance_valid(target):
		queue_free()
		return
	
	# Move toward target
	var direction = global_position.direction_to(target.global_position)
	global_position += direction * speed * delta
	
	# Check if we hit the target
	if global_position.distance_to(target.global_position) < 10.0:
		_hit_target()


func _hit_target() -> void:
	if not target or not is_instance_valid(target):
		print("[Projectile] Hit but target invalid!")
		queue_free()
		return
	
	print("[Projectile] HIT! Dealing %d damage to %s (current HP: %d)" % [damage, target.stats.name, target.current_health])
	
	# Deal damage
	target.current_health -= damage
	
	print("[Projectile] After damage, HP: %d" % target.current_health)
	
	# Visual feedback
	target.flash_skin(hit_color)
	
	# Cleanup
	queue_free()


func setup(from: Unit, to: Unit, proj_damage: float, color: Color = Color.ORANGE_RED) -> void:
	caster = from
	target = to
	damage = proj_damage
	hit_color = color
	is_setup = true
	
	if sprite:
		sprite.modulate = color
	
	# Face the target
	if target:
		look_at(target.global_position)
	
	print("[Projectile] Spawned from %s to %s, damage: %d" % [caster.stats.name if caster else "?", target.stats.name if target else "?", damage])
