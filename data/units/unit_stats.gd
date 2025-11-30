class_name UnitStats
extends Resource

signal health_reached_zero
signal health_changed(new_health: int)
signal mana_bar_filled

@export var name: String

enum Rarity {COMMON, UNCOMMON, RARE, LEGENDARY}
enum Team {PLAYER, ENEMY}

const RARITY_COLORS := {
	Rarity.COMMON: Color("124a2e"),
	Rarity.UNCOMMON: Color("1c527c"),
	Rarity.RARE: Color("ab0979"),
	Rarity.LEGENDARY: Color("ea940b"),
}

const TARGET := {
	Team.PLAYER: "enemy_units",
	Team.ENEMY: "player_units"
}

const TEAM_SPRITESHEET := {
	Team.PLAYER: preload("res://asset/sprites/rogues.png"),
	Team.ENEMY: preload("res://asset/sprites/monsters.png")
}

const MAX_ATTACK_RANGE := 5
const MANA_PER_ATTACK := 10
const MOVE_ONE_TILE_SPEED := 1.0

@export_category("Data")
@export var rarity: Rarity
@export var gold_cost := 1
@export_range(1, 3) var tier := 1 : set = _set_tier
@export var pool_count := 5

@export_category("Visuals")
@export var skin_coordinates: Vector2i

@export_category("Battle")
@export var team: Team
@export var max_health: int
@export var health_regen: float
@export var max_mana: int
@export var starting_mana: int
@export var mana_regen: float
@export var attack_damage: int
@export var ability_power: int
@export var attack_speed: float
@export var armor: int
@export var magic_resist: int
@export_range(1, MAX_ATTACK_RANGE) var attack_range: int
@export_range(1, 10) var aggro_range: int = 3
@export var melee_attack: PackedScene
@export var ranged_attack: PackedScene
@export var ability: PackedScene  # Legacy - keeping for compatibility
@export var ability_resource: Ability  # New ability system
@export var passive_ability: PassiveAbility  # Passive ability (stat bonuses)
@export var auto_attack_sound: AudioStream

var health: int : set = _set_health
var mana: int : set = _set_mana


func reset_health() -> void:
	health = get_max_health()


func reset_mana() -> void:
	mana = starting_mana


## Returns the number of units combined based on tier (3^(tier-1)).
func get_combined_unit_count() -> int:
	return 3 ** (tier - 1)

## Returns the total gold value of this unit (cost × combined count).
func get_gold_value() -> int:
	return gold_cost * get_combined_unit_count()


func get_max_health() -> int:
	return max_health


func get_attack_damage() -> int:
	return attack_damage


func get_time_between_attacks() -> float:
	return 1 / attack_speed


func get_team_collision_layer() -> int:
	return team + 1


func get_team_collision_mask() -> int:
	return 2 - team


func is_melee() -> bool:
	return attack_range == 1


## Sets the tier value and emits a changed signal for resource updates.
func _set_tier(value: int) -> void:
	tier = value
	emit_changed()


## Sets health and emits signal if zero.
func _set_health(value: int) -> void:
	health = value
	health_changed.emit(health)
	if health <= 0:
		health_reached_zero.emit()


## Sets mana and emits signal if full.
func _set_mana(value: int) -> void:
	mana = value
	if mana >= max_mana:
		mana_bar_filled.emit()


## Returns a string representation of the unit stats (the unit's name).
func _to_string() -> String:
	return name
