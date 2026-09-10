extends Ability
class_name ChainHealAbility

## Chain heal — heals the most wounded ally, then bounces to the next most wounded ally
## up to `max_bounces` times, each bounce healing `bounce_falloff`× the previous amount.
## Modelled on Legion TD's Medicine Man "Healing Wave" (90 HP, bounces up to 4×, -25% per bounce).
## Uses effective missing HP so several healers don't stack on the same target.

@export var heal_amount: float = 90.0
@export_range(0, 10) var max_bounces: int = 4
@export_range(0.1, 1.0) var bounce_falloff: float = 0.75


## Only allies that are actually wounded are valid targets (no cast on a full-HP team).
func get_valid_targets(caster: Unit) -> Array:
	var wounded: Array = []
	for ally in _get_ally_units(caster):
		if _missing_health(ally) > 0.0:
			wounded.append(ally)
	if cast_range > 0:
		wounded = _filter_by_range(caster, wounded, cast_range)
	return wounded


func execute(caster: Unit, targets: Array) -> void:
	if targets.is_empty():
		return

	var vfx_spawner = caster.get_tree().get_first_node_in_group("vfx_spawner")
	var remaining: Array = targets.duplicate()
	var current_heal: float = heal_amount
	var hops: int = 0

	while hops <= max_bounces and not remaining.is_empty():
		var target: Node = _most_wounded(remaining)
		if not target:
			break
		remaining.erase(target)
		var actual: float = minf(current_heal, _missing_health(target))
		if actual <= 0.0:
			break
		if "incoming_healing" in target:
			target.incoming_healing += actual
		if "current_health" in target:
			target.current_health = minf(target.current_health + actual, target.stats.max_health)
		else:
			target.stats.health = mini(int(target.stats.health + actual), target.stats.max_health)
		if "incoming_healing" in target:
			target.incoming_healing = maxf(target.incoming_healing - actual, 0.0)
		if target.has_method("flash_skin"):
			target.flash_skin(Color.GREEN)
		if vfx_spawner and vfx_spawner.has_method("spawn_vfx_on_unit"):
			vfx_spawner.spawn_vfx_on_unit("explosion_heal", target)
		UnitVisuals.spawn_damage_number(
				caster.get_tree(), target.global_position, actual, Color.GREEN)
		hops += 1
		current_heal *= bounce_falloff

	caster.flash_skin(Color.CYAN)


func _missing_health(unit: Node) -> float:
	if not is_instance_valid(unit) or not unit.stats:
		return 0.0
	if unit.has_method("get_effective_missing_health"):
		return unit.get_effective_missing_health()
	var hp: float = unit.current_health if "current_health" in unit else float(unit.stats.health)
	return maxf(unit.stats.max_health - hp, 0.0)


func _most_wounded(candidates: Array) -> Node:
	var best: Node = null
	var best_missing: float = 0.0
	for c in candidates:
		var missing: float = _missing_health(c)
		if missing > best_missing:
			best_missing = missing
			best = c
	return best
