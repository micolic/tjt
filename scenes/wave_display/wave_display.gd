extends Control

## Wave UI Display - pokazuje trenutni talas i napredak

@onready var wave_label: Label = $VBoxContainer/WaveLabel
@onready var enemy_count_label: Label = $VBoxContainer/EnemyCountLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var difficulty_label: Label = $VBoxContainer/DifficultyLabel
@onready var timer_label: Label = $VBoxContainer/TimerLabel
@onready var rewards_label: Label = $VBoxContainer/RewardsLabel

var wave_manager: Node
var prep_timer: float = 0.0
var is_prep_phase: bool = false


func _ready() -> void:
	wave_manager = get_tree().get_first_node_in_group("wave_manager")
	
	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.wave_completed.connect(_on_wave_completed)
		wave_manager.wave_difficulty_changed.connect(_on_difficulty_changed)
		wave_manager.wave_rewards_earned.connect(_on_rewards_earned)
		wave_manager.all_waves_completed.connect(_on_all_waves_completed)
		
		# Initial update
		_update_display()
	
	# Hide rewards label initially
	if rewards_label:
		rewards_label.text = ""


func _process(_delta: float) -> void:
	if wave_manager:
		_update_display()
	
	# Update prep timer
	if is_prep_phase and prep_timer > 0:
		prep_timer -= _delta
		if prep_timer <= 0:
			is_prep_phase = false
			if timer_label:
				timer_label.text = "Battle!"
		else:
			if timer_label:
				timer_label.text = "Next wave in: %.1fs" % prep_timer


func _on_wave_started(wave_number: int, _wave_config: WaveConfig) -> void:
	is_prep_phase = false
	prep_timer = 0.0
	_update_display()
	if wave_label:
		var label_text = "Wave %d" % wave_number
		if wave_manager.is_boss_wave():
			label_text += " - BOSS! 👑"
		wave_label.text = label_text
	
	# Clear rewards display
	if rewards_label:
		rewards_label.text = ""


func _on_wave_completed(_wave_number: int) -> void:
	is_prep_phase = true
	prep_timer = wave_manager.preparation_between_waves if wave_manager else 15.0
	if enemy_count_label:
		enemy_count_label.text = "Wave Complete!"


func _on_difficulty_changed(difficulty: float) -> void:
	if difficulty_label:
		difficulty_label.text = "Difficulty: %.2fx" % difficulty


func _on_rewards_earned(gold: int, xp: int) -> void:
	if rewards_label:
		rewards_label.text = "💰 +%d Gold | ⭐ +%d XP" % [gold, xp]


func _on_all_waves_completed() -> void:
	if wave_label:
		wave_label.text = "🏆 VICTORY!"
	if enemy_count_label:
		enemy_count_label.text = "All waves defeated!"
	if timer_label:
		timer_label.text = "You won!"


func _update_display() -> void:
	if not wave_manager:
		return
	
	# Update enemy count
	if enemy_count_label and not is_prep_phase:
		enemy_count_label.text = "Enemies: %d" % wave_manager.remaining_enemies
	
	# Update progress bar
	if progress_bar:
		progress_bar.value = wave_manager.get_progress() * 100
	
	# Update current wave label
	if wave_label and wave_manager.current_wave_number > 0:
		var label_text = "Wave %d / %d" % [wave_manager.current_wave_number, wave_manager.get_total_waves()]
		if wave_manager.is_boss_wave():
			label_text += " 👑"
		wave_label.text = label_text
