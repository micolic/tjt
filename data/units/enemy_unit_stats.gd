class_name EnemyUnitStats
extends Resource

signal health_reached_zero
signal health_changed(new_health: int)
signal mana_bar_filled

@export var name: String

const TEAM_SPRITESHEET := preload("res://asset/sprites/monsters.png")

const MAX_ATTACK_RANGE := 5
const MANA_PER_ATTACK := 10
const MOVE_ONE_TILE_SPEED := 1.0

@export_category("Data")
@export_range(1, 3) var tier := 1 : set = _set_tier

@export_category("Visuals")
@export var skin_coordinates: Vector2i

@export_category("Battle")
@export var max_health: int
@export var max_mana: int
@export var starting_mana: int
@export var attack_damage: int
@export var ability_power: int
@export var attack_speed: float
@export var armor: int
@export var magic_resist: int
@export_range(1, MAX_ATTACK_RANGE) var attack_range: int
@export_range(1, 10) var aggro_range: int = 12
@export var melee_attack: PackedScene
@export var ranged_attack: PackedScene
@export var ability: PackedScene
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


func get_max_health() -> int:
	return max_health


func get_attack_damage() -> int:
	return attack_damage


func get_time_between_attacks() -> float:
	return 1 / attack_speed


func get_team_collision_layer() -> int:
	return 2  # ENEMY


func get_team_collision_mask() -> int:
	return 1  # PLAYER


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
