extends Resource
class_name Ability

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
func execute(_caster: Unit, _targets: Array[Unit]) -> void:
	push_warning("Ability.execute() not implemented for %s" % ability_name)


## Returns valid targets for this ability based on target_type
func get_valid_targets(caster: Unit) -> Array[Unit]:
	var targets: Array[Unit] = []
	
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
	
	return targets


## Filter targets by range
func _filter_by_range(caster: Unit, targets: Array[Unit], max_range: float) -> Array[Unit]:
	var filtered: Array[Unit] = []
	
	for target in targets:
		if caster.global_position.distance_to(target.global_position) <= max_range:
			filtered.append(target)
	
	return filtered


## Helper: Get all enemy units
func _get_enemy_units(caster: Unit) -> Array[Unit]:
	var enemies: Array[Unit] = []
	var group_name = "player_units" if caster.stats.team == UnitStats.Team.ENEMY else "enemy_units"
	
	for unit in caster.get_tree().get_nodes_in_group(group_name):
		if unit is Unit:
			enemies.append(unit)
	
	return enemies


## Helper: Get all ally units (including caster)
func _get_ally_units(caster: Unit) -> Array[Unit]:
	var allies: Array[Unit] = []
	var group_name = "player_units" if caster.stats.team == UnitStats.Team.PLAYER else "enemy_units"
	
	for unit in caster.get_tree().get_nodes_in_group(group_name):
		if unit is Unit:
			allies.append(unit)
	
	return allies


## Helper: Get units within range
func _get_units_in_range(caster: Unit, ability_range: float) -> Array[Unit]:
	var units_in_range: Array[Unit] = []
	
	for unit in caster.get_tree().get_nodes_in_group("units"):
		if unit is Unit and unit != caster:
			if caster.global_position.distance_to(unit.global_position) <= ability_range:
				units_in_range.append(unit)
	
	return units_in_range
