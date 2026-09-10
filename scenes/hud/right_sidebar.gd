class_name RightSidebar
extends PanelContainer

## Unified right HUD panel: wave progress, synergies, and action buttons.

@onready var wave_label: Label = $Margin/VBox/WaveSection/WaveLabel
@onready var wave_progress_bar: ProgressBar = $Margin/VBox/WaveSection/WaveProgressBar
@onready var enemy_count_label: Label = $Margin/VBox/WaveSection/EnemyCountLabel
@onready var difficulty_label: Label = $Margin/VBox/WaveSection/DifficultyLabel
@onready var timer_label: Label = $Margin/VBox/WaveSection/TimerLabel
@onready var rewards_label: Label = $Margin/VBox/WaveSection/RewardsLabel
@onready var next_wave_label: Label = $Margin/VBox/WaveSection/NextWaveLabel
@onready var synergy_rows: VBoxContainer = $Margin/VBox/SynergySection/SynergyRows
@onready var start_battle_button: Button = $Margin/VBox/ButtonSection/StartBattleButton
@onready var toggle_units_button: Button = $Margin/VBox/ButtonSection/ToggleUnitsButton
@onready var quit_game_button: Button = $Margin/VBox/ButtonSection/QuitGameButton

var wave_manager: Node
var synergy_manager: SynergyManager

var _prep_timer: float = 0.0
var _is_prep_phase: bool = false


func _ready() -> void:
	wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if wave_manager:
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.wave_completed.connect(_on_wave_completed)
		wave_manager.wave_difficulty_changed.connect(_on_difficulty_changed)
		wave_manager.wave_rewards_earned.connect(_on_rewards_earned)
		wave_manager.all_waves_completed.connect(_on_all_waves_completed)
		_update_wave_display()
	rewards_label.text = ""
	next_wave_label.text = ""
	_setup_tooltips()


func setup_synergy(mgr: SynergyManager) -> void:
	synergy_manager = mgr
	if mgr:
		mgr.synergies_updated.connect(_on_synergies_updated)
	_build_synergy_rows()
	_refresh_synergies()


func _process(delta: float) -> void:
	if wave_manager:
		_update_wave_display()
	if _is_prep_phase and _prep_timer > 0.0:
		_prep_timer -= delta
		if _prep_timer <= 0.0:
			_is_prep_phase = false
			timer_label.text = ""
		else:
			timer_label.text = "Next wave in: %ds" % int(ceil(_prep_timer))


# ── Wave ──

func _on_wave_started(wave_number: int, _wave_config: WaveConfig) -> void:
	_is_prep_phase = false
	_prep_timer = 0.0
	_update_wave_display()
	var lbl: String = "Wave %d / %d" % [wave_number, wave_manager.get_total_waves()]
	if wave_manager.is_boss_wave():
		lbl += "  ⚠ BOSS"
	wave_label.text = lbl
	rewards_label.text = ""
	next_wave_label.text = ""


func _on_wave_completed(_wave_number: int) -> void:
	_is_prep_phase = true
	_prep_timer = wave_manager.preparation_between_waves if wave_manager else 15.0
	enemy_count_label.text = "Wave Complete!"
	_show_next_wave_preview()


func _on_difficulty_changed(difficulty: float) -> void:
	difficulty_label.text = "Difficulty: %.1fx" % difficulty


func _on_rewards_earned(gold: int, xp: int) -> void:
	rewards_label.text = "+%d Gold  +%d XP" % [gold, xp]


func _on_all_waves_completed() -> void:
	wave_label.text = "VICTORY!"
	enemy_count_label.text = "All waves cleared"
	timer_label.text = ""


func _update_wave_display() -> void:
	if not wave_manager:
		return
	if not _is_prep_phase:
		enemy_count_label.text = "Enemies: %d" % wave_manager.remaining_enemies
	if wave_manager.current_wave_number > 0 and not _is_prep_phase:
		var lbl: String = "Wave %d / %d" % [
			wave_manager.current_wave_number,
			wave_manager.get_total_waves()]
		if wave_manager.is_boss_wave():
			lbl += "  ⚠ BOSS"
		wave_label.text = lbl
	wave_progress_bar.value = wave_manager.get_progress() * 100.0


func _show_next_wave_preview() -> void:
	if not wave_manager:
		return
	var next_config: WaveConfig = wave_manager.get_next_wave_config()
	if not next_config:
		next_wave_label.text = "Last wave cleared!"
		return
	var parts: Array[String] = []
	for group in next_config.enemy_groups:
		if group.enemy_type:
			parts.append("%d× %s" % [group.count, group.enemy_type.name])
	next_wave_label.text = "Next: " + ", ".join(parts) if not parts.is_empty() else ""


# ── Synergy ──

func _on_synergies_updated() -> void:
	_refresh_synergies()


func _refresh_synergies() -> void:
	if not synergy_manager:
		return
	var counts: Dictionary = synergy_manager.get_all_counts()
	var i := 0
	for faction in SynergyManager.SYNERGY_DEFS.keys():
		var def: Dictionary = SynergyManager.SYNERGY_DEFS[faction]
		var count: int = counts.get(faction, 0)
		var threshold: int = def.threshold
		var active: bool = synergy_manager.is_synergy_active(faction)
		var row: Label = synergy_rows.get_child(i) if i < synergy_rows.get_child_count() else null
		if not row:
			break
		var dots := ""
		for d in range(threshold):
			dots += "●" if d < count else "○"
		row.text = "%s %s %s %d/%d" % [dots, _faction_icon(faction), def.name, count, threshold]
		row.add_theme_color_override(
				"font_color",
				Color(1.0, 0.87, 0.35) if active else Color(0.76, 0.76, 0.76))
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = _synergy_tooltip(faction, def, count, threshold, active)
		i += 1


func _build_synergy_rows() -> void:
	for child in synergy_rows.get_children():
		child.queue_free()
	for _faction in SynergyManager.SYNERGY_DEFS.keys():
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 12)
		synergy_rows.add_child(row)


func _faction_icon(faction: UnitStats.Faction) -> String:
	match faction:
		UnitStats.Faction.WARRIOR: return "⚔"
		UnitStats.Faction.MYSTIC:  return "✨"
		UnitStats.Faction.WARDEN:  return "🏹"
	return ""


func _setup_tooltips() -> void:
	wave_label.mouse_filter = Control.MOUSE_FILTER_STOP
	wave_progress_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	enemy_count_label.mouse_filter = Control.MOUSE_FILTER_STOP
	difficulty_label.mouse_filter = Control.MOUSE_FILTER_STOP
	timer_label.mouse_filter = Control.MOUSE_FILTER_STOP
	rewards_label.mouse_filter = Control.MOUSE_FILTER_STOP
	next_wave_label.mouse_filter = Control.MOUSE_FILTER_STOP

	wave_label.tooltip_text = "Current wave and boss status."
	wave_progress_bar.tooltip_text = "Battle progress for the current wave."
	enemy_count_label.tooltip_text = "Enemies still alive in the current wave."
	difficulty_label.tooltip_text = "Current wave difficulty multiplier."
	timer_label.tooltip_text = "Countdown until the next wave starts."
	rewards_label.tooltip_text = "Gold and XP earned from the previous wave."
	next_wave_label.tooltip_text = "Preview of the next wave composition."
	start_battle_button.tooltip_text = "Start the battle, or skip the prep timer between waves."
	toggle_units_button.tooltip_text = "Show or hide the unit roster on the left."
	quit_game_button.tooltip_text = "Quit the game immediately."


func _synergy_tooltip(
		faction: UnitStats.Faction,
		def: Dictionary,
		count: int,
		threshold: int,
		active: bool) -> String:
	var bonus := ""
	match faction:
		UnitStats.Faction.WARRIOR:
			bonus = "Bonus: +20% attack damage."
		UnitStats.Faction.MYSTIC:
			bonus = "Bonus: +20% ability power."
		UnitStats.Faction.WARDEN:
			bonus = "Bonus: +15% attack speed."
	var state := "Active" if active else "Inactive"
	return "%s\n%s\nCount: %d/%d\n%s" % [def.name, state, count, threshold, bonus]
