extends Ability
class_name FireballAbility

## Fireball ability - deals damage to a single enemy

@export var damage: float = 50.0

const ProjectileScene = preload("res://scenes/projectile/projectile.tscn")


func execute(caster: Unit, targets: Array[Unit]) -> void:
	if targets.is_empty():
		print("[Fireball] No valid targets!")
		return
	
	# Pick closest enemy if single target
	var target = targets[0]
	if target_type == TargetType.SINGLE_ENEMY and targets.size() > 1:
		target = _get_closest_target(caster, targets)
	
	print("[Fireball] %s casts Fireball on %s for %d damage!" % [caster.stats.name, target.stats.name, damage])
	
	# Spawn projectile
	_spawn_projectile(caster, target)


func _get_closest_target(caster: Unit, targets: Array[Unit]) -> Unit:
	var closest = targets[0]
	var closest_dist = caster.global_position.distance_to(closest.global_position)
	
	for target in targets:
		var dist = caster.global_position.distance_to(target.global_position)
		if dist < closest_dist:
			closest = target
			closest_dist = dist
	
	return closest


func _spawn_projectile(caster: Unit, target: Unit) -> void:
	if not ProjectileScene:
		# Fallback to instant damage
		target.current_health -= damage
		target.flash_skin(Color.ORANGE_RED)
		return
	
	var projectile = ProjectileScene.instantiate()
	caster.get_tree().current_scene.add_child(projectile)
	
	projectile.global_position = caster.global_position
	projectile.setup(caster, target, damage, Color.ORANGE_RED)
