class_name UnitStatsPanel
extends PanelContainer

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var health_label: Label = $VBoxContainer/HealthLabel
@onready var mana_label: Label = $VBoxContainer/ManaLabel
@onready var attack_label: Label = $VBoxContainer/AttackLabel
@onready var armor_label: Label = $VBoxContainer/ArmorLabel
@onready var magic_resist_label: Label = $VBoxContainer/MagicResistLabel
@onready var attack_speed_label: Label = $VBoxContainer/AttackSpeedLabel

var unit: Unit

func set_unit(new_unit: Unit) -> void:
	if unit:
		disconnect_signals()
	
	unit = new_unit
	if unit:
		connect_signals()
		update_stats()

func connect_signals() -> void:
	if unit.health_changed.is_connected(update_stats):
		return
	unit.health_changed.connect(update_stats)
	unit.mana_changed.connect(update_stats)

func disconnect_signals() -> void:
	if unit.health_changed.is_connected(update_stats):
		unit.health_changed.disconnect(update_stats)
	if unit.mana_changed.is_connected(update_stats):
		unit.mana_changed.disconnect(update_stats)

func update_stats(_new_value: int = -1) -> void:
	if not unit or not unit.stats:
		return
	
	name_label.text = unit.stats.name
	health_label.text = "Health: %d/%d" % [unit.current_health, unit.stats.max_health]
	mana_label.text = "Mana: %d/%d" % [unit.current_mana, unit.stats.max_mana]
	attack_label.text = "Attack: %d" % unit.stats.attack_damage
	armor_label.text = "Armor: %d" % unit.stats.armor
	magic_resist_label.text = "Magic Resist: %d" % unit.stats.magic_resist
	attack_speed_label.text = "Attack Speed: %.1f" % unit.stats.attack_speed