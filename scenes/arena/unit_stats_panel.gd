class_name UnitStatsPanel
extends PanelContainer

## Lightweight panel that displays live stats for a single unit.
## Intended for compact UI spaces where the full SelectedUnitPanel is not needed.

@onready var _name_label: Label = $VBoxContainer/NameLabel
@onready var _health_label: Label = $VBoxContainer/HealthLabel
@onready var _mana_label: Label = $VBoxContainer/ManaLabel
@onready var _damage_label: Label = $VBoxContainer/DamageLabel
@onready var _attack_label: Label = $VBoxContainer/AttackLabel
@onready var _armor_label: Label = $VBoxContainer/ArmorLabel
@onready var _magic_resist_label: Label = $VBoxContainer/MagicResistLabel
@onready var _attack_speed_label: Label = $VBoxContainer/AttackSpeedLabel

var _unit: Unit = null


func _ready() -> void:
	print("[UnitStatsPanel] Initialized")
	refresh()


func set_unit(unit: Unit) -> void:
	if _unit == unit:
		refresh()
		return
	_disconnect_unit()
	_unit = unit
	_connect_unit()
	refresh()
	visible = is_instance_valid(_unit)


func refresh() -> void:
	if not is_node_ready():
		return
	if not is_instance_valid(_unit) or not _unit.stats:
		visible = false
		return
	visible = true
	var stats: UnitStats = _unit.stats
	_name_label.text = stats.name
	_health_label.text = "HP: %d / %d" % [ceili(maxf(_unit.current_health, 0.0)), stats.get_max_health()]
	_mana_label.text = "MP: %d / %d" % [floori(maxf(_unit.current_mana, 0.0)), stats.max_mana]
	_damage_label.text = "DMG: %.0f" % _unit.damage_dealt
	_attack_label.text = "ATK: %d" % stats.get_attack_damage()
	_armor_label.text = "AR: %d" % stats.armor
	_magic_resist_label.text = "MR: %d" % stats.magic_resist
	_attack_speed_label.text = "SPD: %.1f" % stats.attack_speed


func _connect_unit() -> void:
	if not is_instance_valid(_unit):
		return
	if not _unit.health_changed.is_connected(_on_health_changed):
		_unit.health_changed.connect(_on_health_changed)
	if not _unit.mana_changed.is_connected(_on_mana_changed):
		_unit.mana_changed.connect(_on_mana_changed)
	if not _unit.damage_dealt_changed.is_connected(_on_damage_dealt_changed):
		_unit.damage_dealt_changed.connect(_on_damage_dealt_changed)
	if not _unit.tree_exiting.is_connected(_on_unit_exiting):
		_unit.tree_exiting.connect(_on_unit_exiting)


func _disconnect_unit() -> void:
	if not is_instance_valid(_unit):
		return
	if _unit.health_changed.is_connected(_on_health_changed):
		_unit.health_changed.disconnect(_on_health_changed)
	if _unit.mana_changed.is_connected(_on_mana_changed):
		_unit.mana_changed.disconnect(_on_mana_changed)
	if _unit.damage_dealt_changed.is_connected(_on_damage_dealt_changed):
		_unit.damage_dealt_changed.disconnect(_on_damage_dealt_changed)
	if _unit.tree_exiting.is_connected(_on_unit_exiting):
		_unit.tree_exiting.disconnect(_on_unit_exiting)


func _on_health_changed(_new_health: int) -> void:
	_refresh_values()


func _on_mana_changed(_new_mana: int) -> void:
	_refresh_values()


func _on_damage_dealt_changed(_new_damage: float) -> void:
	_refresh_values()


func _refresh_values() -> void:
	if not is_instance_valid(_unit) or not _unit.stats:
		return
	_health_label.text = "HP: %d / %d" % [ceili(maxf(_unit.current_health, 0.0)), _unit.stats.get_max_health()]
	_mana_label.text = "MP: %d / %d" % [floori(maxf(_unit.current_mana, 0.0)), _unit.stats.max_mana]
	_damage_label.text = "DMG: %.0f" % _unit.damage_dealt


func _on_unit_exiting() -> void:
	set_unit(null)
