extends Ability
class_name AOEDamageAbility

## AOE Damage ability - damages all enemies

@export var damage: float = 25.0


func execute(caster: Unit, targets: Array) -> void:
	if targets.is_empty():
		print("[AOE] No valid targets!")
		return
	
	print("[AOE] %s casts AOE attack, hitting %d enemies!" % [caster.stats.name, targets.size()])
	
	# Damage all targets
	for target in targets:
		target.current_health -= damage
		target.flash_skin(Color.PURPLE)
	
	# Visual effect (TODO: spawn area particle effect)
	caster.flash_skin(Color.PURPLE)
