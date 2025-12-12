extends Ability
class_name HealAbility

## Heal ability - restores health to self or ally

@export var heal_amount: float = 30.0


func execute(caster: Unit, targets: Array) -> void:
	if targets.is_empty():
		print("[Heal] No valid targets!")
		return
	
	# Heal each target (usually self or single ally)
	for target in targets:
		var actual_heal = min(heal_amount, target.stats.max_health - target.current_health)
		target.current_health += actual_heal
		
		print("[Heal] %s heals %s for %d HP!" % [caster.stats.name, target.stats.name, actual_heal])
		
		# Visual effect
		target.flash_skin(Color.GREEN)
		
		# Spawn heal number (green)
		if target.has_method("_spawn_heal_number"):
			target._spawn_heal_number(actual_heal)
