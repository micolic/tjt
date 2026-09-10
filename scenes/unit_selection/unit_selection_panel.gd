class_name UnitSelectionPanel
extends PanelContainer

## Bottom panel that shows all available ally units as clickable cards.
## Clicking a card enters placement mode — the player then clicks a tile on the arena.

const UnitSelectionCardScene = preload("res://scenes/unit_selection/unit_selection_card.tscn")

## Emitted when a card is clicked and the player should place a unit.
signal unit_selected(unit_stats: UnitStats)
## Emitted when a card is dragged — enters drag-placement mode.
signal unit_drag_started(unit_stats: UnitStats)
## Emitted when placement is cancelled (right-click / ESC).
signal placement_cancelled

## All available ally unit resources the player can choose from.
@export var available_units: Array[UnitStats] = []

## Max units allowed on the field at once.
@export var max_deployed_units: int = 8

@onready var card_container: HBoxContainer = $MarginContainer/HBox/CardContainer

## Currently selected card (highlighted yellow)
var _selected_card = null
var _selected_stats: UnitStats = null

## Current deployed count (managed externally by arena)
var deployed_count: int = 0
 
## Player stats resource for gold tracking
var player_stats: PlayerStats = null

## Map from UnitStats resource path → card node
var _cards: Dictionary = {}


func _ready() -> void:
	add_to_group("unit_selection_panel")
	_build_cards()


## Replaces the available units and rebuilds cards. Called by Arena when
## loading a deck from DeckManager.
func set_available_units(units: Array[UnitStats]) -> void:
	available_units = units
	_build_cards()


func _build_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()
	_cards.clear()

	for stats in available_units:
		if not stats:
			continue
		var card = UnitSelectionCardScene.instantiate()
		card_container.add_child(card)
		card.setup(stats)
		card.card_clicked.connect(_on_card_clicked)
		card.card_drag_started.connect(_on_card_drag_started)
		_cards[stats.resource_path] = card


func _on_card_clicked(unit_stats: UnitStats) -> void:
	# Check gold
	if player_stats and player_stats.gold < unit_stats.gold_cost:
		return

	# If clicking the same card again, deselect
	var card = _cards.get(unit_stats.resource_path)
	if _selected_card == card:
		cancel_selection()
		return

	# Deselect previous
	if _selected_card:
		_selected_card.set_selected(false)

	# Select new
	_selected_card = card
	_selected_stats = unit_stats
	if card:
		card.set_selected(true)

	unit_selected.emit(unit_stats)


func _on_card_drag_started(unit_stats: UnitStats) -> void:
	if player_stats and player_stats.gold < unit_stats.gold_cost:
		return
	# Select the card visually
	var card = _cards.get(unit_stats.resource_path)
	if _selected_card and _selected_card != card:
		_selected_card.set_selected(false)
	_selected_card = card
	_selected_stats = unit_stats
	if card:
		card.set_selected(true)
	unit_drag_started.emit(unit_stats)


## Called by arena after a unit is successfully placed.
func on_unit_placed(unit_stats: UnitStats = null) -> void:
	deployed_count += 1
	# Deduct gold
	if player_stats and unit_stats:
		player_stats.gold -= unit_stats.gold_cost
	_update_affordability()
	# Keep selected for rapid multi-placement of same type
	# (user can click multiple tiles to place more)
	# Auto-cancel if can no longer afford the selected unit
	if player_stats and _selected_stats and player_stats.gold < _selected_stats.gold_cost:
		cancel_selection()


## Called by arena when a unit is removed from the field.
func on_unit_removed() -> void:
	deployed_count = max(0, deployed_count - 1)


## Deselect the current card and cancel placement mode.
func cancel_selection() -> void:
	if _selected_card:
		_selected_card.set_selected(false)
		_selected_card = null
	_selected_stats = null
	placement_cancelled.emit()


func get_selected_stats() -> UnitStats:
	return _selected_stats


## Update which cards the player can afford.
func _update_affordability() -> void:
	if not player_stats:
		return
	for card in _cards.values():
		if card and card.unit_stats:
			card.set_can_afford(player_stats.gold >= card.unit_stats.gold_cost)


## Sets the player stats resource (called by arena).
func set_player_stats(stats: PlayerStats) -> void:
	if player_stats and player_stats.changed.is_connected(_on_player_stats_changed):
		player_stats.changed.disconnect(_on_player_stats_changed)
	player_stats = stats
	if player_stats:
		player_stats.changed.connect(_on_player_stats_changed)
	_on_player_stats_changed()


func _on_player_stats_changed() -> void:
	_update_affordability()


func _exit_tree() -> void:
	if player_stats and player_stats.changed.is_connected(_on_player_stats_changed):
		player_stats.changed.disconnect(_on_player_stats_changed)


## Disables interaction during battle.
func set_interactable(enabled: bool) -> void:
	if not enabled:
		cancel_selection()
	for card in _cards.values():
		if card is Control:
			card.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
			if enabled:
				# Respect affordability when re-enabling
				_update_affordability()
			else:
				card.modulate = Color(0.5, 0.5, 0.5)
