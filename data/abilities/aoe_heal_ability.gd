extends Ability
class_name AoEHealAbility

## AoE Heal ability - heals all allies in range

@export var heal_amount: float = 40.0
## Max allies healed, most wounded first. 0 = all. (Legion TD "Sacred Blessing" heals up to 4.)
@export_range(0, 20) var max_targets: int = 0


func execute(caster: Unit, targets: Array) -> void:
	if targets.is_empty():
		return
	if max_targets > 0 and targets.size() > max_targets:
		targets = targets.duplicate()
		targets.sort_custom(func(a, b):
			return _missing(a) > _missing(b)
		)
		targets = targets.slice(0, max_targets)

	var _healed_count: int = 0
	for target in targets:
		if not is_instance_valid(target):
			continue
		# Only heal allies that are actually wounded
		var current_hp: float = target.current_health if "current_health" in target \
				else target.stats.health
		var max_hp: float = target.stats.max_health
		if current_hp >= max_hp:
			continue

		var actual_heal: float = minf(heal_amount, max_hp - current_hp)
		if "current_health" in target:
			target.current_health = minf(target.current_health + actual_heal, max_hp)
		else:
			target.stats.health = mini(int(target.stats.health + actual_heal), int(max_hp))

		# Register incoming healing for anti-overheal
		if "incoming_healing" in target:
			target.incoming_healing += actual_heal

		if target.has_method("flash_skin"):
			target.flash_skin(Color.GREEN)
		_healed_count += 1

	caster.flash_skin(Color.GREEN)


func _missing(unit: Node) -> float:
	if not is_instance_valid(unit) or not unit.stats:
		return 0.0
	var hp: float = unit.current_health if "current_health" in unit else float(unit.stats.health)
	return maxf(unit.stats.max_health - hp, 0.0)
