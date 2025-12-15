class_name WaveEnemyGroup
extends Resource

## Represents a group of enemies to spawn together

@export var enemy_type: UnitStats  # Which unit to spawn
@export var count: int = 1  # How many of this type
@export var spawn_interval_within_group: float = 0.3  # Delay between individual spawns in group
