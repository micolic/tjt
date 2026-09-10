class_name CombatResolver
extends RefCounted

## Single entry point for resolving a BASIC ATTACK hit (melee strike or basic-attack projectile).
##
## Order of operations:
##   1. attacker passive `modify_outgoing_damage`  (every-Nth-attack multipliers)
##   2. target.apply_damage(PHYSICAL)              (armor + target's own DAMAGE_REDUCTION passive)
##   3. damage counters                            (per-unit + Arena readout)
##   4. attacker passive `on_attack_hit`           (magic missile, lifesteal, splash, multishot,
## shred)
##
## Ability damage (Fireball, Wrath of Nature, ...) does NOT go through here — abilities are
## not "attacks" and must not trigger on-hit passives. Works for both Unit and EnemyUnit.


## Resolves one basic attack. Returns the post-mitigation damage that actually landed.
static func resolve_basic_attack(attacker: Node, target: Node, base_damage: int) -> int:
	if not is_instance_valid(target) or not target.has_method("apply_damage"):
		return 0

	var passive: PassiveAbility = _get_passive(attacker)
	var damage: int = base_damage
	if passive:
		damage = passive.modify_outgoing_damage(attacker, damage)

	var hp_before: float = target.current_health if "current_health" in target else 0.0
	target.apply_damage(damage, UnitStats.DamageType.PHYSICAL)
	var hp_after: float = target.current_health\
			if ("current_health" in target and is_instance_valid(target))\
			else 0.0
	var dealt: int = maxi(roundi(hp_before - hp_after), 0)

	if is_instance_valid(attacker):
		if attacker.has_method("register_damage_dealt"):
			attacker.register_damage_dealt(damage)
		var arena: Node = attacker.get_tree().get_first_node_in_group("arena")
		if arena and arena.has_method("register_damage_output"):
			arena.call_deferred("register_damage_output", damage)
		if passive:
			passive.on_attack_hit(attacker, target, dealt)

	return dealt


static func _get_passive(attacker: Node) -> PassiveAbility:
	if not is_instance_valid(attacker) or not ("stats" in attacker) or not attacker.stats:
		return null
	return attacker.stats.passive_ability
