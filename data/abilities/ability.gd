extends Resource
class_name Ability

# Toggle verbose ability target debugging
const DEBUG_ABILITY: bool = false

## Base class for all unit abilities

enum TargetType {
	SELF,           # Targets only the caster
	SINGLE_ENEMY,   # Targets one enemy
	ALL_ENEMIES,    # Targets all enemies
	SINGLE_ALLY,    # Targets one ally
	ALL_ALLIES,     # Targets all allies (including self)
	AREA            # Area effect around caster
}

@export var ability_name: String = "Unnamed Ability"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var mana_cost: float = 100.0
@export var cooldown: float = 0.0  # Seconds before ability can be used again
@export var cast_time: float = 0.0  # Animation/cast delay
@export var cast_range: float = 0.0  # Max range for targeting (0 = unlimited)


## Called when ability is cast - override this in specific abilities
func execute(_caster: Unit, _targets: Array) -> void:
	push_warning("Ability.execute() not implemented for %s" % ability_name)


## Returns valid targets for this ability based on target_type
func get_valid_targets(caster: Unit) -> Array:
	var targets := []
	if DEBUG_ABILITY:
		print("[AbilityDebug] get_valid_targets called for '%s' (team=%s) target_type=%s cast_range=%s" % [caster.stats.name, caster.stats.team, target_type, cast_range])
	
	match target_type:
		TargetType.SELF:
			targets.append(caster)
		
		TargetType.SINGLE_ENEMY:
			targets = _get_enemy_units(caster)
		
		TargetType.ALL_ENEMIES:
			targets = _get_enemy_units(caster)
		
		TargetType.SINGLE_ALLY:
			targets = _get_ally_units(caster)
		
		TargetType.ALL_ALLIES:
			targets = _get_ally_units(caster)
		
		TargetType.AREA:
			# Get all units in range (both allies and enemies)
			targets = _get_units_in_range(caster, 100.0)
	
	# Filter by cast range if specified
	if cast_range > 0:
		targets = _filter_by_range(caster, targets, cast_range)
	if DEBUG_ABILITY:
		print("[AbilityDebug] get_valid_targets returning %d targets" % targets.size())

	return targets


## Filter targets by range
func _filter_by_range(caster: Unit, targets: Array, max_range: float) -> Array:
	var filtered := []
	
	for target in targets:
		var dist = caster.global_position.distance_to(target.global_position)
		if DEBUG_ABILITY:
			print("[AbilityDebug] _filter_by_range: caster=%s target=%s dist=%.1f max=%.1f" % [caster.stats.name, target, dist, max_range])
		if dist <= max_range:
			filtered.append(target)
	
	return filtered


## Helper: Get all enemy units
func _get_enemy_units(caster: Unit) -> Array:
	var enemies := []
	var group_name = "player_units" if caster.stats.team == UnitStats.Team.ENEMY else "enemy_units"
	var nodes := caster.get_tree().get_nodes_in_group(group_name)
	if DEBUG_ABILITY:
		print("[AbilityDebug] _get_enemy_units: looking in group '%s' found %d nodes" % [group_name, nodes.size()])
	for unit in nodes:
		if DEBUG_ABILITY:
			print("[AbilityDebug] candidate: %s (class=%s)" % [unit, unit.get_class()])
		# Accept nodes that implement the unit interface via UnitUtils
		if UnitUtils.is_unit_node(unit):
			enemies.append(unit)
	
	return enemies


## Helper: Get all ally units (including caster)
func _get_ally_units(caster: Unit) -> Array:
	var allies := []
	var group_name = "player_units" if caster.stats.team == UnitStats.Team.PLAYER else "enemy_units"
	var nodes := caster.get_tree().get_nodes_in_group(group_name)
	if DEBUG_ABILITY:
		print("[AbilityDebug] _get_ally_units: looking in group '%s' found %d nodes" % [group_name, nodes.size()])
	for unit in nodes:
		if DEBUG_ABILITY:
			print("[AbilityDebug] candidate: %s (class=%s)" % [unit, unit.get_class()])
		# Accept nodes that implement the unit interface via UnitUtils
		if UnitUtils.is_unit_node(unit):
			allies.append(unit)
	
	return allies


## Helper: Get units within range
func _get_units_in_range(caster: Unit, ability_range: float) -> Array:
	var units_in_range := []
	var nodes := caster.get_tree().get_nodes_in_group("units")
	if DEBUG_ABILITY:
		print("[AbilityDebug] _get_units_in_range: scanning 'units' group, %d nodes" % nodes.size())
	for unit in nodes:
		if DEBUG_ABILITY:
			print("[AbilityDebug] range candidate: %s (class=%s) pos=%s" % [unit, unit.get_class(), unit.global_position])
		# Accept nodes that implement the unit interface via UnitUtils
		if UnitUtils.is_unit_node(unit) and unit != caster:
			var dist := caster.global_position.distance_to(unit.global_position)
			if DEBUG_ABILITY:
				print("[AbilityDebug] dist to %s = %.1f (range=%.1f)" % [unit, dist, ability_range])
			if dist <= ability_range:
				units_in_range.append(unit)
	
	return units_in_range
