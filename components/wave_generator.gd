@tool
extends Node

## Helper script to create wave configurations programmatically
## Run this once in editor to generate wave .tres files

func _ready() -> void:
	if Engine.is_editor_hint():
		create_demo_waves()


func create_demo_waves() -> void:
	var orc_stats = load("res://data/units/orc_enemy.tres")
	var necro_stats = load("res://data/units/necro_enemy.tres")
	
	if not orc_stats or not necro_stats:
		print("Error: Could not load unit stats")
		return
	
	# Wave 1 - 3 Orcs
	var wave1 = WaveConfig.new()
	wave1.wave_name = "Wave 1 - First Blood"
	wave1.wave_description = "An easy first wave with a few weak enemies"
	
	var group1_1 = WaveEnemyGroup.new()
	group1_1.enemy_type = orc_stats
	group1_1.count = 3
	group1_1.spawn_interval_within_group = 0.3
	wave1.enemy_groups.append(group1_1)
	wave1.spawn_interval_between_groups = 0.0
	wave1.gold_reward = 40
	wave1.experience_reward = 5
	ResourceSaver.save(wave1, "res://data/waves/wave_01_first_blood.tres")
	print("✓ Created wave_01_first_blood.tres")
	
	# Wave 2 - Mixed
	var wave2 = WaveConfig.new()
	wave2.wave_name = "Wave 2 - Reinforcements"
	wave2.wave_description = "More orcs and a couple of necromancers"
	
	var group2_1 = WaveEnemyGroup.new()
	group2_1.enemy_type = orc_stats
	group2_1.count = 4
	group2_1.spawn_interval_within_group = 0.3
	wave2.enemy_groups.append(group2_1)
	
	var group2_2 = WaveEnemyGroup.new()
	group2_2.enemy_type = necro_stats
	group2_2.count = 2
	group2_2.spawn_interval_within_group = 0.5
	wave2.enemy_groups.append(group2_2)
	
	wave2.spawn_interval_between_groups = 1.5
	wave2.gold_reward = 60
	wave2.experience_reward = 10
	ResourceSaver.save(wave2, "res://data/waves/wave_02_reinforcements.tres")
	print("✓ Created wave_02_reinforcements.tres")
	
	# Wave 3 - Hard
	var wave3 = WaveConfig.new()
	wave3.wave_name = "Wave 3 - Assault"
	wave3.wave_description = "Heavy assault with multiple groups"
	
	var group3_1 = WaveEnemyGroup.new()
	group3_1.enemy_type = orc_stats
	group3_1.count = 3
	group3_1.spawn_interval_within_group = 0.2
	wave3.enemy_groups.append(group3_1)
	
	var group3_2 = WaveEnemyGroup.new()
	group3_2.enemy_type = necro_stats
	group3_2.count = 4
	group3_2.spawn_interval_within_group = 0.4
	wave3.enemy_groups.append(group3_2)
	
	var group3_3 = WaveEnemyGroup.new()
	group3_3.enemy_type = orc_stats
	group3_3.count = 2
	group3_3.spawn_interval_within_group = 0.3
	wave3.enemy_groups.append(group3_3)
	
	wave3.spawn_interval_between_groups = 1.0
	wave3.gold_reward = 100
	wave3.experience_reward = 20
	ResourceSaver.save(wave3, "res://data/waves/wave_03_assault.tres")
	print("✓ Created wave_03_assault.tres")
	
	# Wave 4 - Boss Wave
	var wave4 = WaveConfig.new()
	wave4.wave_name = "Wave 5 - BOSS WAVE 👑"
	wave4.wave_description = "A terrifying boss appears! Multiple powerful enemies!"
	
	var group4_1 = WaveEnemyGroup.new()
	group4_1.enemy_type = necro_stats
	group4_1.count = 6
	group4_1.spawn_interval_within_group = 0.4
	wave4.enemy_groups.append(group4_1)
	
	var group4_2 = WaveEnemyGroup.new()
	group4_2.enemy_type = orc_stats
	group4_2.count = 4
	group4_2.spawn_interval_within_group = 0.3
	wave4.enemy_groups.append(group4_2)
	
	wave4.spawn_interval_between_groups = 2.0
	wave4.gold_reward = 300
	wave4.experience_reward = 50
	ResourceSaver.save(wave4, "res://data/waves/wave_05_boss.tres")
	print("✓ Created wave_05_boss.tres")
	
	print("\n✅ All demo waves created successfully!")
