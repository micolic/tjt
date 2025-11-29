class_name BattleManager
extends Node

## Emitted when battle state changes
signal state_changed(new_state: State)
## Emitted when battle starts
signal battle_started
## Emitted when battle ends with winner
signal battle_ended(winner: UnitStats.Team)
## Emitted when preparation phase starts
signal preparation_started

enum State {
	PREPARATION,  ## Players arrange units
	BATTLE,       ## Units fight automatically
	ENDED         ## Battle is over
}

@export var preparation_time: float = 0.0
@export var enemy_area: PlayArea
@export var game_area: PlayArea

var current_state: State = State.PREPARATION
var prep_timer: float = 0.0


## Called when the node enters the scene tree.
func _ready() -> void:
	start_preparation()


## Process timer during preparation phase.
func _process(delta: float) -> void:
	if current_state == State.PREPARATION:
		prep_timer -= delta
		if prep_timer <= 0:
			start_battle()


## Starts the preparation phase.
func start_preparation() -> void:
	_change_state(State.PREPARATION)
	prep_timer = preparation_time
	preparation_started.emit()


## Starts the battle phase.
func start_battle() -> void:
	_change_state(State.BATTLE)
	battle_started.emit()
	
	# Enable AI on all units
	_enable_ai_for_units(true)


## Ends the battle with a winner.
func end_battle(winner: UnitStats.Team) -> void:
	_change_state(State.ENDED)
	battle_ended.emit(winner)
	
	# Disable AI on all units
	_enable_ai_for_units(false)


## Changes the current state and emits signal.
func _change_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(new_state)


## Enables or disables AI on all units.
func _enable_ai_for_units(enabled: bool) -> void:
	var all_units := get_tree().get_nodes_in_group("units")
	
	for unit in all_units:
		if unit.has_node("UnitAI"):
			var ai = unit.get_node("UnitAI")
			ai.enabled = enabled


## Checks win condition - called when a unit dies.
func check_win_condition() -> void:
	if current_state != State.BATTLE:
		return
	
	var enemy_units := enemy_area.unit_grid.get_all_units()
	
	if enemy_units.is_empty():
		end_battle(UnitStats.Team.PLAYER)


## Manual trigger to start battle (for testing or button).
func force_start_battle() -> void:
	if current_state == State.PREPARATION:
		start_battle()
