extends Resource
class_name PassiveAbility

## Base class for passive abilities that modify unit stats or react to combat events.
##
## Two families of passives:
##   1. STAT passives — baked into unit.stats once in apply() (regen, damage, armor, ...).
##   2. COMBAT passives — evaluated per event through the hooks below, called by
##      CombatResolver (basic attacks) and Unit (incoming damage / health changes).
##
## All combat passives are deterministic (every Nth attack, HP thresholds, flat values).
## Legion TD uses % chances for many of these; TJT converts them per GDD Pillar 6
## ("No RNG should decide a match").

enum PassiveType {
	HEALTH_REGEN_BONUS,    # +value% health regen                    (Warrior's Endurance)
	MANA_REGEN_BONUS,      # +value% mana regen
	DAMAGE_BONUS,          # +value% attack damage                   (Deadly Focus)
	ARMOR_BONUS,           # +value flat armor                       (Iron Bastion)
	SPEED_BONUS,           # +value% attack speed                    (Chemical Rage-lite)
	MAX_HEALTH_BONUS,      # +value% max health
	DAMAGE_REDUCTION,      # every hit -value flat (after armor/MR)  (Harden Armor)
	NTH_ATTACK_MULTIPLIER, # every `interval`-th attack deals value× (Precision, Vital Slice)
	MAGIC_MISSILE,         # every attack +value flat MAGICAL dmg    (Sentry's Magic Missile)
	LIFESTEAL,             # heal value of damage dealt per hit      (Frenzy Ghoul)
	ARMOR_SHRED,           # every hit removes value armor (min 0)   (Corruption/Faerie Fire)
	SPLASH,                # every hit: value× to enemies near target (Circle Splash)
	MULTISHOT,             # every hit: +extra_targets for value×    (Burst Shot)
	BERSERK,               # +value% atk spd per HP threshold        (Ravager's Bloodrage)
}

## Floor for DAMAGE_REDUCTION — a hit can never be reduced to zero so no unit is fully immune.
const MIN_DAMAGE_AFTER_REDUCTION: int = 1
## BERSERK thresholds: each one crossed adds `value` attack speed (as a fraction of base).
const BERSERK_THRESHOLDS: Array[float] = [0.6, 0.4, 0.2]
## Meta keys stored on the unit node (stats are duplicated per unit, but counters live on the node).
const META_ATTACK_COUNT := "passive_attack_count"
const META_BASE_ATTACK_SPEED := "passive_base_attack_speed"

@export var passive_name: String = "Unnamed Passive"
@export_multiline var description: String = ""
@export var passive_type: PassiveType = PassiveType.HEALTH_REGEN_BONUS
## Percentage (0.2 = 20%), multiplier (1.6 = 160%) or flat value depending on passive_type.
@export var value: float = 0.0
## NTH_ATTACK_MULTIPLIER: which attack triggers (3 = every third attack).
@export_range(2, 10) var interval: int = 3
## SPLASH: radius in pixels around the primary target (32 px = one tile).
@export var radius: float = 48.0
## MULTISHOT: how many additional targets are struck.
@export_range(1, 5) var extra_targets: int = 2


## Apply passive effect to unit (called once per unit instance when stats are connected).
func apply(unit: Node) -> void:
	if not unit or not unit.stats:
		return
	match passive_type:
		PassiveType.HEALTH_REGEN_BONUS:
			unit.stats.health_regen += unit.stats.health_regen * value
		PassiveType.MANA_REGEN_BONUS:
			unit.stats.mana_regen += unit.stats.mana_regen * value
		PassiveType.DAMAGE_BONUS:
			unit.stats.attack_damage += int(unit.stats.attack_damage * value)
		PassiveType.ARMOR_BONUS:
			unit.stats.armor += int(value)
		PassiveType.SPEED_BONUS:
			unit.stats.attack_speed *= 1.0 + value
		PassiveType.MAX_HEALTH_BONUS:
			var bonus: int = int(unit.stats.max_health * value)
			unit.stats.max_health += bonus
			if "current_health" in unit:
				unit.current_health += bonus
		PassiveType.BERSERK:
			# Remember the un-enraged attack speed; thresholds are re-evaluated on every HP change.
			unit.set_meta(META_BASE_ATTACK_SPEED, unit.stats.attack_speed)
		_:
			# Combat passives have nothing to bake in — they run through the hooks below.
			pass


## Remove passive effect from unit (for temporary passives). Only stat passives are reversible.
func remove(unit: Node) -> void:
	if not unit or not unit.stats:
		return
	match passive_type:
		PassiveType.HEALTH_REGEN_BONUS:
			unit.stats.health_regen -= (unit.stats.health_regen / (1.0 + value)) * value
		PassiveType.MANA_REGEN_BONUS:
			unit.stats.mana_regen -= (unit.stats.mana_regen / (1.0 + value)) * value
		PassiveType.DAMAGE_BONUS:
			unit.stats.attack_damage -= int((unit.stats.attack_damage / (1.0 + value)) * value)
		PassiveType.ARMOR_BONUS:
			unit.stats.armor -= int(value)
		PassiveType.SPEED_BONUS:
			unit.stats.attack_speed /= 1.0 + value
		PassiveType.MAX_HEALTH_BONUS:
			unit.stats.max_health -= int((unit.stats.max_health / (1.0 + value)) * value)
		PassiveType.BERSERK:
			if unit.has_meta(META_BASE_ATTACK_SPEED):
				unit.stats.attack_speed = unit.get_meta(META_BASE_ATTACK_SPEED)
				unit.remove_meta(META_BASE_ATTACK_SPEED)


# ── Combat hooks ────────────────────────────────────────────────────────────────

## Applies per-hit modifiers to damage that has already been reduced by armor/MR.
func modify_incoming_damage(damage: int) -> int:
	if passive_type != PassiveType.DAMAGE_REDUCTION or damage <= 0:
		return damage
	return maxi(damage - int(value), MIN_DAMAGE_AFTER_REDUCTION)


## Modifies the raw damage of a basic attack BEFORE it is applied to the target.
## Also advances the unit's attack counter used by "every Nth attack" passives.
func modify_outgoing_damage(unit: Node, damage: int) -> int:
	if passive_type != PassiveType.NTH_ATTACK_MULTIPLIER:
		return damage
	var count: int = unit.get_meta(META_ATTACK_COUNT, 0) + 1
	unit.set_meta(META_ATTACK_COUNT, count)
	if count % interval != 0:
		return damage
	var boosted: int = roundi(damage * value)
	return boosted


## Called after a basic attack has landed. `damage_dealt` is the post-mitigation damage.
func on_attack_hit(unit: Node, target: Node, damage_dealt: int) -> void:
	if not is_instance_valid(unit) or not is_instance_valid(target):
		return
	match passive_type:
		PassiveType.MAGIC_MISSILE:
			if target.has_method("apply_damage"):
				target.apply_damage(int(value), UnitStats.DamageType.MAGICAL)
				_report_damage(unit, int(value))
				if target.has_method("flash_skin"):
					target.flash_skin(Color.MEDIUM_PURPLE)
		PassiveType.LIFESTEAL:
			var heal: float = damage_dealt * value
			if heal > 0.0 and "current_health" in unit and unit.stats:
				var before: float = unit.current_health
				unit.current_health = minf(unit.current_health + heal, unit.stats.max_health)
				var healed: float = unit.current_health - before
				if healed > 0.0:
					UnitVisuals.spawn_damage_number(
							unit.get_tree(), unit.global_position, healed, Color.GREEN)
		PassiveType.ARMOR_SHRED:
			if target.stats and target.stats.armor > 0:
				target.stats.armor = maxi(target.stats.armor - int(value), 0)
				if target.has_method("flash_skin"):
					target.flash_skin(Color.DARK_ORCHID)
		PassiveType.SPLASH:
			var splash: int = roundi(damage_dealt * value)
			if splash <= 0:
				return
			for enemy in _get_other_enemies_near(unit, target, radius, 0):
				enemy.apply_damage(splash, UnitStats.DamageType.PHYSICAL)
				_report_damage(unit, splash)
				if enemy.has_method("flash_skin"):
					enemy.flash_skin(Color.ORANGE)
		PassiveType.MULTISHOT:
			var extra: int = roundi(damage_dealt * value)
			if extra <= 0:
				return
			for enemy in _get_other_enemies_near(unit, target, 0.0, extra_targets):
				enemy.apply_damage(extra, UnitStats.DamageType.PHYSICAL)
				_report_damage(unit, extra)
				if enemy.has_method("flash_skin"):
					enemy.flash_skin(Color.YELLOW)
		_:
			pass


## Called whenever the unit's health changes (damage, heal, between-wave reset).
## BERSERK: attack speed = base × (1 + value × thresholds crossed).
func on_health_changed(unit: Node) -> void:
	if passive_type != PassiveType.BERSERK or not unit.stats \
			or not unit.has_meta(META_BASE_ATTACK_SPEED):
		return
	var hp_fraction: float = 1.0
	if unit.stats.max_health > 0 and "current_health" in unit:
		hp_fraction = unit.current_health / float(unit.stats.max_health)
	var stacks: int = 0
	for threshold in BERSERK_THRESHOLDS:
		if hp_fraction < threshold:
			stacks += 1
	var base: float = unit.get_meta(META_BASE_ATTACK_SPEED)
	var new_speed: float = base * (1.0 + value * stacks)
	if not is_equal_approx(new_speed, unit.stats.attack_speed):
		unit.stats.attack_speed = new_speed


# ── Helpers ─────────────────────────────────────────────────────────────────────

## Returns living enemies of `unit` other than `primary`, sorted by distance to `primary`.
## max_distance 0 = unlimited; max_count 0 = unlimited.
func _get_other_enemies_near(
		unit: Node, primary: Node, max_distance: float, max_count: int) -> Array:
	var group_name: String = "enemy_units" if unit.stats.team == UnitStats.Team.PLAYER \
			else "player_units"
	var candidates: Array = []
	for enemy in unit.get_tree().get_nodes_in_group(group_name):
		if enemy == primary or not is_instance_valid(enemy) or not enemy.has_method("apply_damage"):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if "current_health" in enemy and enemy.current_health <= 0.0:
			continue
		var dist: float = primary.global_position.distance_to(enemy.global_position)
		if max_distance > 0.0 and dist > max_distance:
			continue
		candidates.append({"node": enemy, "dist": dist})
	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	var result: Array = []
	for entry in candidates:
		if max_count > 0 and result.size() >= max_count:
			break
		result.append(entry.node)
	return result


## Feeds bonus damage into the same counters basic attacks use (per-unit + arena readout).
func _report_damage(unit: Node, amount: int) -> void:
	if unit.has_method("register_damage_dealt"):
		unit.register_damage_dealt(amount)
	var arena: Node = unit.get_tree().get_first_node_in_group("arena")
	if arena and arena.has_method("register_damage_output"):
		arena.call_deferred("register_damage_output", amount)
