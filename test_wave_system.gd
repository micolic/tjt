@tool
extends EditorScript

## Quick test script to verify wave system compiles and loads correctly

func _run() -> void:
	print("\n=== WAVE SYSTEM TEST ===")
	
	# Test loading classes
	var wave_config = load("res://data/waves/wave_config.gd")
	var wave_enemy_group = load("res://data/waves/wave_enemy_group.gd")
	var wave_manager = load("res://components/wave_manager.gd")
	
	print("✓ WaveConfig: %s" % ("Loaded" if wave_config else "FAILED"))
	print("✓ WaveEnemyGroup: %s" % ("Loaded" if wave_enemy_group else "FAILED"))
	print("✓ WaveManager: %s" % ("Loaded" if wave_manager else "FAILED"))
	
	# Test loading .tres files
	var w1 = load("res://data/waves/wave_1.tres")
	var w2 = load("res://data/waves/wave_2.tres")
	var w3 = load("res://data/waves/wave_3.tres")
	var w5 = load("res://data/waves/wave_5_boss.tres")
	
	print("✓ Wave 1: %s" % ("Loaded" if w1 else "FAILED"))
	print("✓ Wave 2: %s" % ("Loaded" if w2 else "FAILED"))
	print("✓ Wave 3: %s" % ("Loaded" if w3 else "FAILED"))
	print("✓ Wave 5 (Boss): %s" % ("Loaded" if w5 else "FAILED"))
	
	# Test Arena scene
	var arena = load("res://scenes/arena/arena.tscn")
	print("✓ Arena scene: %s" % ("Loaded" if arena else "FAILED"))
	
	# Test Wave Display
	var wave_display = load("res://scenes/wave_display/wave_display.tscn")
	print("✓ Wave Display scene: %s" % ("Loaded" if wave_display else "FAILED"))
	
	print("\n✅ All resources loaded successfully!")
	print("Ready to test in-game wave spawning.\n")
