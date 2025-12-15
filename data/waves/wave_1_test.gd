# Wave 1 - Easy warmup
extends Resource
class_name Wave1

var enemy_groups: Array[WaveEnemyGroup] = []

func _init() -> void:
	# Load enemy stats
	var orc_stats = load("res://data/units/orc_enemy.tres")
	
	# 3 orcs in one group
	var group = WaveEnemyGroup.new()
	group.enemy_type = orc_stats
	group.count = 3
	group.spawn_interval_within_group = 0.5
	
	enemy_groups.append(group)
