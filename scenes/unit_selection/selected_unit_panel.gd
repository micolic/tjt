class_name SelectedUnitPanel
extends PanelContainer

signal upgrade_requested(unit: Unit, target: UnitStats)
signal removal_requested(unit: Unit)
signal deselection_requested

var unit: Unit = null
var _player_stats: PlayerStats = null
var _upgrades_enabled: bool = false
var _displayed_stats: UnitStats = null
var _upgrade_targets: Array[UnitStats] = []
var _upgrade_buttons: Array[Button] = []

@onready var _portrait: TextureRect = %UnitPortrait
@onready var _name_label: Label = %UnitName
@onready var _identity_label: Label = %IdentityLabel
@onready var _damage_label: Label = %DamageLabel
@onready var _health_label: Label = %HealthLabel
@onready var _mana_label: Label = %ManaLabel
@onready var _combat_label: Label = %CombatLabel
@onready var _active_name: Label = %ActiveName
@onready var _active_description: Label = %ActiveDescription
@onready var _passive_name: Label = %PassiveName
@onready var _passive_description: Label = %PassiveDescription
@onready var _upgrade_header: Label = %UpgradeHeader
@onready var _upgrade_scroll: ScrollContainer = %UpgradeScroll
@onready var _upgrade_container: VBoxContainer = %UpgradeButtons
@onready var _no_upgrades: Label = %NoUpgradesLabel
@onready var _remove_button: Button = %RemoveButton


func _ready() -> void:
	_connect_listeners()
	visible = is_instance_valid(unit)
	refresh()


func _exit_tree() -> void:
	_disconnect_listeners()
	unit = null
	_displayed_stats = null
	_player_stats = null


func set_unit(new_unit: Unit) -> void:
	if is_instance_valid(new_unit) and new_unit == unit:
		show()
		refresh()
		return
	_disconnect_listeners()
	unit = new_unit if is_instance_valid(new_unit) else null
	_displayed_stats = null
	_clear_upgrades()
	if unit == null:
		hide()
		return
	_connect_listeners()
	show()
	refresh()


func set_player_stats(stats: PlayerStats) -> void:
	_disconnect_listeners()
	_player_stats = stats
	_connect_listeners()
	refresh()


func set_upgrades_enabled(enabled: bool) -> void:
	if _upgrades_enabled == enabled:
		return
	_upgrades_enabled = enabled
	refresh()


func refresh() -> void:
	if not is_node_ready() or not is_inside_tree():
		return
	if not _has_valid_unit():
		set_unit(null)
		return
	var stats: UnitStats = unit.stats
	if _displayed_stats != stats:
		_displayed_stats = stats
		_portrait.texture = _get_portrait(stats)
	_name_label.text = stats.name
	_identity_label.text = "Tier %d | %s" % [stats.tier, _faction_name(stats.faction)]
	_name_label.tooltip_text = "%s\n%s\nTotal value: %d gold" % [
		stats.name, _identity_label.text, stats.gold_cost
	]
	_identity_label.tooltip_text = _name_label.tooltip_text
	_set_ability(_active_name, _active_description, "Active",
		stats.ability_resource.ability_name if stats.ability_resource else "None",
		stats.ability_resource.description if stats.ability_resource else "No active ability.")
	_set_ability(_passive_name, _passive_description, "Passive",
		stats.passive_ability.passive_name if stats.passive_ability else "None",
		stats.passive_ability.description if stats.passive_ability else "No passive ability.")
	_refresh_live_values()
	_refresh_upgrades(stats)
	_refresh_remove_button()


func _refresh_live_values() -> void:
	if not is_node_ready() or not is_inside_tree():
		return
	if not _has_valid_unit():
		set_unit(null)
		return
	var stats: UnitStats = unit.stats
	_health_label.text = "HP %d / %d" % [
		ceili(maxf(unit.current_health, 0.0)), stats.get_max_health()
	]
	_mana_label.text = "Mana %d / %d" % [floori(maxf(unit.current_mana, 0.0)), stats.max_mana]
	_health_label.tooltip_text = "Health: %.1f / %d\nRegeneration: %.2f HP/s" % [
		maxf(unit.current_health, 0.0), stats.get_max_health(), stats.health_regen
	]
	_mana_label.tooltip_text = "Mana: %.1f / %d\nRegeneration: %.2f mana/s" % [
		maxf(unit.current_mana, 0.0), stats.max_mana, stats.mana_regen
	]
	_combat_label.text = "ATK %d  |  AS %.2f\nArmor %d%%  |  MR %d%%\nRange %d  |  AP %d" % [
		stats.get_attack_damage(), stats.attack_speed, stats.armor,
		stats.magic_resist, stats.attack_range, stats.ability_power
	]
	_damage_label.text = "Damage %.0f" % unit.damage_dealt
	_damage_label.tooltip_text = "Damage dealt this battle: %.1f" % unit.damage_dealt
	if unit.is_dead() or unit.current_health <= 0.0:
		for button: Button in _upgrade_buttons:
			button.disabled = true
	_refresh_remove_button()


func _has_valid_unit() -> bool:
	return is_instance_valid(unit) and not unit.is_queued_for_deletion() \
		and unit.is_inside_tree() and is_instance_valid(unit.stats) \
		and unit.stats.team == UnitStats.Team.PLAYER


func _connect_listeners() -> void:
	if not is_instance_valid(unit):
		return
	var callback: Callable = _refresh_live_values.unbind(1)
	var value_signals: Array[Signal] = [
		unit.health_changed, unit.mana_changed, unit.damage_dealt_changed
	]
	for value_signal: Signal in value_signals:
		if not value_signal.is_connected(callback):
			value_signal.connect(callback)
	if is_instance_valid(_player_stats) and not _player_stats.changed.is_connected(refresh):
		_player_stats.changed.connect(refresh)


func _disconnect_listeners() -> void:
	if is_instance_valid(unit):
		var callback: Callable = _refresh_live_values.unbind(1)
		var value_signals: Array[Signal] = [
		unit.health_changed, unit.mana_changed, unit.damage_dealt_changed
	]
		for value_signal: Signal in value_signals:
			if value_signal.is_connected(callback):
				value_signal.disconnect(callback)
	if is_instance_valid(_player_stats) and _player_stats.changed.is_connected(refresh):
		_player_stats.changed.disconnect(refresh)


func _get_portrait(stats: UnitStats) -> Texture2D:
	if stats.sprite_frames:
		var animations: PackedStringArray = stats.sprite_frames.get_animation_names()
		var animation: StringName = &"idle"
		if not stats.sprite_frames.has_animation(animation) and not animations.is_empty():
			animation = StringName(animations[0])
		if stats.sprite_frames.has_animation(animation) \
				and stats.sprite_frames.get_frame_count(animation) > 0:
			return stats.sprite_frames.get_frame_texture(animation, 0)
	var spritesheet: Texture2D = UnitStats.TEAM_SPRITESHEET.get(stats.team) as Texture2D
	if not spritesheet:
		return null
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = spritesheet
	atlas.region = Rect2(
		Vector2(stats.skin_coordinates) * Vector2(stats.tile_size),
		Vector2(stats.tile_size)
	)
	return atlas


func _faction_name(faction: UnitStats.Faction) -> String:
	if faction == UnitStats.Faction.NONE:
		return "No faction"
	var key: String = UnitStats.Faction.keys()[faction]
	return String(key).capitalize()


func _set_ability(
	title: Label, description_label: Label,
	kind: String, ability_name: String, description: String
) -> void:
	title.text = "%s: %s" % [kind, ability_name]
	description_label.text = description
	title.tooltip_text = _wrap_tooltip("%s\n%s" % [title.text, description])
	description_label.tooltip_text = title.tooltip_text


func _refresh_upgrades(stats: UnitStats) -> void:
	if is_instance_valid(_player_stats):
		_upgrade_header.text = "Upgrades | Gold %d" % _player_stats.gold
	else:
		_upgrade_header.text = "Upgrades | Gold unavailable"
	var targets: Array[UnitStats] = []
	if not stats.is_king:
		for target: UnitStats in stats.upgrades:
			if is_instance_valid(target):
				targets.append(target)
	if targets != _upgrade_targets:
		_clear_upgrades()
		_upgrade_targets = targets
		for target: UnitStats in _upgrade_targets:
			var button: Button = Button.new()
			button.custom_minimum_size = Vector2(0.0, 23.0)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.clip_text = true
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.pressed.connect(_on_upgrade_pressed.bind(weakref(unit), target))
			_upgrade_container.add_child(button)
			_upgrade_buttons.append(button)
	var has_upgrades: bool = not _upgrade_targets.is_empty()
	_upgrade_scroll.visible = has_upgrades
	_no_upgrades.visible = not has_upgrades
	_no_upgrades.text = "The King cannot be upgraded." if stats.is_king else "No further upgrades."
	if not has_upgrades:
		return
	var block_reason: String = _upgrade_block_reason()
	var can_upgrade: bool = false
	for index: int in range(_upgrade_targets.size()):
		var target: UnitStats = _upgrade_targets[index]
		var cost: int = stats.get_upgrade_cost(target)
		var reason: String = block_reason
		if reason.is_empty() and _player_stats.gold < cost:
			reason = "Need %d more gold." % (cost - _player_stats.gold)
		var button: Button = _upgrade_buttons[index]
		button.text = "%s   +%d gold" % [target.name, cost]
		button.disabled = not reason.is_empty()
		button.tooltip_text = _build_upgrade_tooltip(target, cost)
		if not reason.is_empty():
			button.tooltip_text += "\n\n%s" % reason
		can_upgrade = can_upgrade or not button.disabled


func _clear_upgrades() -> void:
	for button: Button in _upgrade_buttons:
		if is_instance_valid(button):
			button.get_parent().remove_child(button)
			button.queue_free()
	_upgrade_buttons.clear()
	_upgrade_targets.clear()


func _upgrade_block_reason() -> String:
	if not _has_valid_unit() or unit.is_dead() or unit.current_health <= 0.0:
		return "Unit is no longer alive."
	if unit.stats.is_king:
		return "The King cannot be upgraded."
	var dragging: bool = unit.is_in_group("dragging")
	dragging = dragging or (is_instance_valid(unit.drag_and_drop) and unit.drag_and_drop.dragging)
	if dragging:
		return "Finish moving the unit first."
	if not _upgrades_enabled:
		return "Upgrades require preparation."
	if not is_instance_valid(_player_stats):
		return "Gold is unavailable."
	return ""


func _build_upgrade_tooltip(target: UnitStats, cost: int) -> String:
	var lines: PackedStringArray = [
		"%s (+%d gold)" % [target.name, cost],
		"Tier %d | %s | Total value: %d gold" % [
			target.tier, _faction_name(target.faction), target.gold_cost
		],
		"Base stats, before passive and faction bonuses:",
		"HP %d | Mana %d | ATK %d | AS %.2f" % [
			target.get_max_health(), target.max_mana,
			target.get_attack_damage(), target.attack_speed
		],
		"Armor %d%% | MR %d%% | Range %d | AP %d" % [
			target.armor, target.magic_resist, target.attack_range, target.ability_power
		],
		"HP regen %.2f/s | Mana regen %.2f/s" % [
			target.health_regen, target.mana_regen
		],
	]
	if target.ability_resource:
		lines.append("\nActive: %s\n%s" % [
			target.ability_resource.ability_name, target.ability_resource.description
		])
	else:
		lines.append("\nActive: None")
	if target.passive_ability:
		lines.append("\nPassive: %s\n%s" % [
			target.passive_ability.passive_name, target.passive_ability.description
		])
	else:
		lines.append("\nPassive: None")
	return _wrap_tooltip("\n".join(lines))


func _wrap_tooltip(text: String) -> String:
	var lines: PackedStringArray = []
	for paragraph: String in text.split("\n"):
		var line: String = ""
		for word: String in paragraph.split(" ", false):
			if not line.is_empty() and line.length() + word.length() + 1 > 72:
				lines.append(line)
				line = ""
			line += (" " if not line.is_empty() else "") + word
		lines.append(line)
	return "\n".join(lines)


func _on_upgrade_pressed(source: WeakRef, target: UnitStats) -> void:
	var stale: bool = not _has_valid_unit() or source.get_ref() != unit
	stale = stale or not is_instance_valid(target) or not unit.stats.upgrades.has(target)
	if stale:
		refresh()
		return
	var reason: String = _upgrade_block_reason()
	var cost: int = unit.stats.get_upgrade_cost(target)
	if reason.is_empty() and _player_stats.gold < cost:
		reason = "Not enough gold."
	if not reason.is_empty():
		refresh()
		return
	upgrade_requested.emit(unit, target)


func _on_remove_pressed() -> void:
	if not _has_valid_unit():
		return
	var reason: String = _removal_block_reason()
	if not reason.is_empty():
		refresh()
		return
	removal_requested.emit(unit)


func _refresh_remove_button() -> void:
	if not is_node_ready() or _remove_button == null:
		return
	if not _has_valid_unit():
		_remove_button.visible = false
		return
	_remove_button.visible = true
	var reason: String = _removal_block_reason()
	_remove_button.disabled = not reason.is_empty()
	if reason.is_empty():
		_remove_button.text = "Remove"
		_remove_button.tooltip_text = "Remove this unit and refund %d gold." % unit.stats.gold_cost
	else:
		_remove_button.tooltip_text = reason


func _removal_block_reason() -> String:
	if not _has_valid_unit() or unit.is_dead() or unit.current_health <= 0.0:
		return "Unit is no longer alive."
	if unit.stats.is_king:
		return "The King cannot be removed."
	var dragging: bool = unit.is_in_group("dragging")
	dragging = dragging or (is_instance_valid(unit.drag_and_drop) and unit.drag_and_drop.dragging)
	if dragging:
		return "Finish moving the unit first."
	if not _upgrades_enabled:
		return "Removal requires preparation."
	return ""


func _request_deselection() -> void:
	if not visible:
		return
	deselection_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		_request_deselection()
