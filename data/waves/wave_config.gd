class_name WaveConfig
extends Resource

## Definiše jednu wave sa grupama neprijatelja
## Inspirisano Legion TD 2 sistemom

@export var wave_name: String = "Wave"
@export var wave_description: String = ""

## Enemy groups in this wave
@export var enemy_groups: Array[WaveEnemyGroup] = []

## Spawn timing
@export var spawn_interval_between_groups: float = 1.0  # Delay between groups
@export var total_estimated_duration: float = 15.0  # How long wave should take (for UI)

## Rewards
@export var gold_reward: int = 50
@export var experience_reward: int = 10


func get_total_enemies() -> int:
	var total = 0
	for group in enemy_groups:
		total += group.count
	return total


func get_difficulty_estimate() -> float:
	var difficulty = 0.0
	for group in enemy_groups:
		if group.enemy_type:
			var enemy_value = group.enemy_type.max_health + group.enemy_type.attack_damage
			difficulty += enemy_value * group.count
	return difficulty
