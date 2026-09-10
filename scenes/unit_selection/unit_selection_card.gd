class_name UnitSelectionCard
extends PanelContainer

## A clickable card that shows a unit's name, sprite preview, and key stats.
## Clicking selects this unit type for placement on the arena.

signal card_clicked(unit_stats: UnitStats)
signal card_drag_started(unit_stats: UnitStats)

@onready var name_label: Label = $VBox/NameLabel
@onready var sprite_preview: TextureRect = $VBox/SpriteContainer/SpritePreview
@onready var stats_label: Label = $VBox/StatsLabel
@onready var cost_label: Label = $VBox/CostLabel

var unit_stats: UnitStats
var is_selected: bool = false
var can_afford: bool = true

# Drag detection
var _press_position := Vector2.ZERO
var _is_pressing := false
const DRAG_THRESHOLD := 8.0


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func setup(stats: UnitStats) -> void:
	unit_stats = stats
	_update_display()
	tooltip_text = _build_tooltip()


func _update_display() -> void:
	if not unit_stats or not is_inside_tree():
		return

	name_label.text = unit_stats.name

	# Set sprite preview from spritesheet using AtlasTexture
	if sprite_preview:
		var spritesheet: Texture2D = UnitStats.TEAM_SPRITESHEET.get(unit_stats.team)
		if spritesheet:
			var atlas := AtlasTexture.new()
			atlas.atlas = spritesheet
			atlas.region = Rect2(
				Vector2(unit_stats.skin_coordinates) * Vector2(unit_stats.tile_size),
				Vector2(unit_stats.tile_size)
			)
			sprite_preview.texture = atlas

	# Stats summary
	var range_text := "Melee" if unit_stats.is_melee() else "Range %d" % unit_stats.attack_range
	stats_label.text = "HP:%d ATK:%d\n%s" % [
		unit_stats.max_health, unit_stats.attack_damage, range_text]

	# Gold cost
	if cost_label:
		cost_label.text = "%d 💰" % unit_stats.gold_cost

	_update_style()
	tooltip_text = _build_tooltip()


func set_can_afford(affordable: bool) -> void:
	can_afford = affordable
	_update_style()


func _update_style() -> void:
	if not unit_stats:
		return
	var style := StyleBoxFlat.new()
	if not can_afford:
		style.bg_color = Color(0.12, 0.12, 0.12, 0.95)
		style.border_color = Color(0.4, 0.4, 0.4)
	elif is_selected:
		style.bg_color = Color(0.2, 0.25, 0.35, 0.95)
		style.border_color = Color(1.0, 1.0, 0.4)
	else:
		style.bg_color = Color(0.15, 0.18, 0.22, 0.95)
		style.border_color = Color(0.5, 0.5, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	add_theme_stylebox_override("panel", style)
	# Dim the whole card if unaffordable
	if not is_selected:
		modulate = Color.WHITE if can_afford else Color(0.5, 0.5, 0.5)


func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_style()
	modulate = Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not can_afford:
			return
		if event.pressed:
			_is_pressing = true
			_press_position = event.global_position
		else:
			if _is_pressing:
				_is_pressing = false
				card_clicked.emit(unit_stats)
		accept_event()
	elif event is InputEventMouseMotion and _is_pressing:
		if _press_position.distance_to(event.global_position) > DRAG_THRESHOLD:
			_is_pressing = false
			card_drag_started.emit(unit_stats)
			accept_event()


func _on_mouse_entered() -> void:
	if not is_selected:
		modulate = Color(1.15, 1.15, 1.15)


func _on_mouse_exited() -> void:
	if not is_selected:
		modulate = Color.WHITE


func _build_tooltip() -> String:
	if not unit_stats:
		return ""

	var lines: Array[String] = []
	lines.append(unit_stats.name)
	lines.append("Tier %d | Cost: %d gold" % [unit_stats.tier, unit_stats.gold_cost])
	lines.append("Team: %s" % _team_name(unit_stats.team))
	lines.append("HP: %d | ATK: %d | Range: %d" % [
		unit_stats.max_health, unit_stats.attack_damage, unit_stats.attack_range])
	lines.append("Armor: %d | MR: %d | SPD: %.1f" % [
		unit_stats.armor, unit_stats.magic_resist, unit_stats.attack_speed])
	if unit_stats.ability_resource:
		lines.append("Ability: %s" % unit_stats.ability_resource.ability_name)
	if unit_stats.passive_ability:
		lines.append("Passive: %s" % unit_stats.passive_ability.passive_name)
	if unit_stats.faction != UnitStats.Faction.NONE:
		lines.append("Synergy: %s" % _faction_tooltip(unit_stats.faction))
	for upgrade in unit_stats.upgrades:
		if upgrade:
			lines.append("Select placed unit to upgrade: %s (+%d gold)" % [
				upgrade.name, unit_stats.get_upgrade_cost(upgrade)])
	return "\n".join(lines)


func _team_name(team: UnitStats.Team) -> String:
	match team:
		UnitStats.Team.PLAYER: return "Player"
		UnitStats.Team.ENEMY: return "Enemy"
	return "Unknown"


func _faction_tooltip(faction: UnitStats.Faction) -> String:
	match faction:
		UnitStats.Faction.WARRIOR:
			return "Warrior: +20% attack damage at 3 unique warriors."
		UnitStats.Faction.MYSTIC:
			return "Mystic: +20% ability power at 3 unique mystics."
		UnitStats.Faction.WARDEN:
			return "Warden: +15% attack speed at 2 unique wardens."
	return "No synergy"
