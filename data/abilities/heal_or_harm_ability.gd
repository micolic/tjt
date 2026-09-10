extends Ability
class_name HealOrHarmAbility

## Smart mage ability: heals wounded allies, or damages enemies if everyone is full HP.
## If an ally has HP < max HP → heals the most wounded ally.
## If no ally needs healing → deals 50% of heal_amount as damage to nearest enemy.

@export var heal_amount: float = 60.0


## Override get_valid_targets to implement custom dual-targeting logic.
## Returns allies that need healing, OR enemies if no allies are hurt.
func get_valid_targets(caster: Unit) -> Array:
	# First: check for wounded allies
	var wounded_allies := _get_wounded_allies(caster)
	if not wounded_allies.is_empty():
		return wounded_allies

	# No wounded allies — target enemies instead
	var enemies := _get_enemy_units(caster)
	if cast_range > 0:
		enemies = _filter_by_range(caster, enemies, cast_range)
	return enemies


func execute(caster: Unit, targets: Array) -> void:
	if targets.is_empty():
		return

	var first_target = targets[0]

	# Determine if we're healing or damaging based on team
	var is_ally := false
	if "stats" in first_target and first_target.stats:
		is_ally = first_target.stats.team == caster.stats.team

	if is_ally:
		_execute_heal(caster, targets)
	else:
		_execute_damage(caster, targets)


## Heal the most wounded ally (uses effective missing HP to avoid overheal stacking).
func _execute_heal(caster: Unit, targets: Array) -> void:
	# Find ally with the most *effective* missing HP
	var most_wounded = targets[0]
	var biggest_need: float = 0.0

	for target in targets:
		var need: float = 0.0
		if target.has_method("get_effective_missing_health"):
			need = target.get_effective_missing_health()
		else:
			# Fallback: raw missing HP
			var hp: float = target.current_health if "current_health" in target \
					else target.stats.health
			need = target.stats.max_health - hp

		if need > biggest_need:
			biggest_need = need
			most_wounded = target

	# Calculate actual heal (don't overheal)
	var current_hp: float
	var max_hp: float
	if "current_health" in most_wounded:
		current_hp = most_wounded.current_health
		max_hp = most_wounded.stats.max_health
	else:
		current_hp = most_wounded.stats.health
		max_hp = most_wounded.stats.max_health

	var actual_heal: float = min(heal_amount, max_hp - current_hp)

	# Register incoming heal so other healers pick a different target
	if "incoming_healing" in most_wounded:
		most_wounded.incoming_healing += actual_heal

	# Apply heal
	if "current_health" in most_wounded:
		most_wounded.current_health += actual_heal
		# Clear the incoming heal since it just landed
		if "incoming_healing" in most_wounded:
			most_wounded.incoming_healing = maxf(most_wounded.incoming_healing - actual_heal, 0.0)
	elif "stats" in most_wounded and most_wounded.stats:
		most_wounded.stats.health = int(min(most_wounded.stats.health + actual_heal, max_hp))
		if "incoming_healing" in most_wounded:
			most_wounded.incoming_healing = maxf(most_wounded.incoming_healing - actual_heal, 0.0)

	# Green flash on healed target
	if most_wounded.has_method("flash_skin"):
		most_wounded.flash_skin(Color.GREEN)

	# Spawn heal VFX on target
	var vfx_spawner = caster.get_tree().get_first_node_in_group("vfx_spawner")
	if vfx_spawner and vfx_spawner.has_method("spawn_vfx_on_unit"):
		vfx_spawner.spawn_vfx_on_unit("explosion_heal", most_wounded)

	# Spawn green heal number
	UnitVisuals.spawn_damage_number(
		caster.get_tree(), most_wounded.global_position, actual_heal, Color.GREEN
	)

	# Blue flash on caster
	caster.flash_skin(Color.CYAN)


## Damage the nearest enemy (50% of heal value).
func _execute_damage(caster: Unit, targets: Array) -> void:
	var damage: float = heal_amount * 0.5

	# Pick closest enemy
	var target = targets[0]
	if targets.size() > 1:
		var closest_dist := INF
		for t in targets:
			var dist = caster.global_position.distance_to(t.global_position)
			if dist < closest_dist:
				closest_dist = dist
				target = t

	# Register incoming damage so other units don't overkill
	if "incoming_damage" in target:
		target.incoming_damage += damage

	# Apply damage
	if target.has_method("apply_damage"):
		target.apply_damage(int(damage), UnitStats.DamageType.MAGICAL)
	elif "current_health" in target:
		target.current_health = max(target.current_health - damage, 0)
	elif "stats" in target and target.stats:
		target.stats.health = int(max(target.stats.health - damage, 0))

	# Purple flash for arcane damage
	if target.has_method("flash_skin"):
		target.flash_skin(Color.MEDIUM_PURPLE)

	# Spawn dark magic VFX on target
	var vfx_spawner = caster.get_tree().get_first_node_in_group("vfx_spawner")
	if vfx_spawner and vfx_spawner.has_method("spawn_vfx_on_unit"):
		vfx_spawner.spawn_vfx_on_unit("explosion_dark", target)

	# Caster flash
	caster.flash_skin(Color.MEDIUM_PURPLE)


## Helper: Get all allies that have HP < max HP (excluding fully healed ones).
func _get_wounded_allies(caster: Unit) -> Array:
	var wounded := []
	var group_name = "player_units" if caster.stats.team == UnitStats.Team.PLAYER else "enemy_units"
	var nodes := caster.get_tree().get_nodes_in_group(group_name)

	for ally in nodes:
		if not is_instance_valid(ally) or not UnitUtils.is_unit_node(ally):
			continue

		var current_hp: float
		var max_hp: float

		if "current_health" in ally:
			current_hp = ally.current_health
			max_hp = ally.stats.max_health
		elif "stats" in ally and ally.stats:
			current_hp = ally.stats.health
			max_hp = ally.stats.max_health
		else:
			continue

		# Only include if effectively wounded (accounting for incoming heals)
		var effective_missing: float = max_hp - current_hp
		if ally.has_method("get_effective_missing_health"):
			effective_missing = ally.get_effective_missing_health()
		if effective_missing > 0.0:
			wounded.append(ally)

	# Filter by range if specified
	if cast_range > 0 and not wounded.is_empty():
		wounded = _filter_by_range(caster, wounded, cast_range)

	return wounded
