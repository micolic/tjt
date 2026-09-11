extends Ability
class_name ChainDamageAbility

## Chain damage — hits the nearest enemy, then bounces to the next nearest enemy up to
## `max_bounces` times, each bounce dealing `bounce_falloff`× the previous hit.
## Modelled on Legion TD's Druid "Wrath of Nature" (100 dmg, bounces up to 5×) — now "Nature's
## Fury".
## Royal Griffin's "Storm Hammers" (bounces twice with reduced damage).

@export var damage: float = 100.0
## Max chain bounces after the first hit.
@export_range(0, 10) var max_bounces: int = 5
## Damage multiplier applied on every bounce (0.75 = each jump deals 75% of the previous one).
@export_range(0.1, 1.0) var bounce_falloff: float = 0.75
## Max distance (px) between consecutive chain targets. 0 = unlimited.
@export var bounce_range: float = 96.0
## Damage type for armor/MR reduction (PHYSICAL / MAGICAL / PURE).
@export var damage_type: UnitStats.DamageType = UnitStats.DamageType.MAGICAL


func execute(caster: Unit, targets: Array) -> void:
	if targets.is_empty():
		return

	var vfx_spawner = caster.get_tree().get_first_node_in_group("vfx_spawner")
	var remaining: Array = targets.duplicate()
	var current: Node = _closest_to(caster.global_position, remaining)
	var current_damage: float = damage
	var hits: int = 0

	while current and hits <= max_bounces:
		remaining.erase(current)
		var dmg: int = maxi(roundi(current_damage), 1)
		if "incoming_damage" in current:
			current.incoming_damage += dmg
		if current.has_method("apply_damage"):
			current.apply_damage(dmg, damage_type)
		elif "current_health" in current:
			current.current_health = maxf(current.current_health - dmg, 0.0)
		if caster.has_method("register_damage_dealt"):
			caster.register_damage_dealt(dmg)
		if current.has_method("flash_skin"):
			current.flash_skin(Color.CHARTREUSE)
		if vfx_spawner and vfx_spawner.has_method("spawn_vfx_on_unit"):
			vfx_spawner.spawn_vfx_on_unit("explosion_magic", current)
		hits += 1

		# Next link: nearest remaining enemy within bounce_range of the current one
		var next: Node = _closest_to(current.global_position, remaining, bounce_range)
		current = next
		current_damage *= bounce_falloff

	var arena: Node = caster.get_tree().get_first_node_in_group("arena")
	if arena and arena.has_method("register_damage_output"):
		arena.call_deferred("register_damage_output", _total_damage(hits))
	caster.flash_skin(Color.CHARTREUSE)


func _closest_to(origin: Vector2, candidates: Array, max_distance: float = 0.0) -> Node:
	var best: Node = null
	var best_dist: float = INF
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var dist: float = origin.distance_to(c.global_position)
		if max_distance > 0.0 and dist > max_distance:
			continue
		if dist < best_dist:
			best_dist = dist
			best = c
	return best


func _total_damage(hits: int) -> float:
	var total: float = 0.0
	var d: float = damage
	for i in hits:
		total += roundi(d)
		d *= bounce_falloff
	return total
