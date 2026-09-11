class_name WaveEnemyGroup
extends Resource

## Represents a group of enemies to spawn together

## UnitStats resource of the spawned enemy.
@export var enemy_type: UnitStats
## How many of this enemy spawn.
@export var count: int = 1
## Delay in seconds between individual spawns in this group.
@export var spawn_interval_within_group: float = 0.3
