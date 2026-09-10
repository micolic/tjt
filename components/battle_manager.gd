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
	add_to_group("battle_manager")
	start_preparation()


## Process timer during preparation phase.
func _process(delta: float) -> void:
	if current_state == State.PREPARATION:
		# Only auto-decrement timer when a positive preparation_time was configured.
		# If preparation_time == 0, preparation waits until manually started (button).
		if prep_timer > 0:
			prep_timer -= delta
			if prep_timer <= 0:
				start_battle()


## Starts the preparation phase.
func start_preparation() -> void:
	_change_state(State.PREPARATION)
	prep_timer = preparation_time
	preparation_started.emit()
	# Tile highlighters are enabled on demand by Arena placement and UnitMover
	# drag handlers, not for the whole preparation phase.


## Starts the battle phase.
func start_battle() -> void:
	_change_state(State.BATTLE)
	battle_started.emit()
	# NOTE: AI enabling is performed after any dynamic spawns (e.g. Arena)
	# Consumers should call `enable_ai_for_all(true)` once all units are present.
	
	# Disable tile highlighters during battle
	_enable_tile_highlighters(false)
	
	# Clear hover highlights while preserving the selected unit's outline
	_clear_all_unit_highlights()


## Ends the battle with a winner.
func end_battle(winner: UnitStats.Team) -> void:
	if current_state == State.ENDED:
		return
	_change_state(State.ENDED)
	battle_ended.emit(winner)
	
	# Disable AI on all units
	_enable_ai_for_units(false)


## Public helper to enable/disable AI on all units. Useful when units are spawned
## dynamically (Arena spawns enemies after battle_started) so caller can enable AI
## after spawns complete.
func enable_ai_for_all(enabled: bool) -> void:
	_enable_ai_for_units(enabled)


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


## Enables or disables tile highlighters in play areas.
## Only the game area is highlighted during player placement.
func _enable_tile_highlighters(enabled: bool) -> void:
	if game_area and game_area.tile_highlighter:
		game_area.tile_highlighter.enabled = enabled


## Clears hover highlights on all units without losing persistent selection.
func _clear_all_unit_highlights() -> void:
	var all_units := get_tree().get_nodes_in_group("units")
	
	for unit in all_units:
		if unit is Unit:
			unit.is_hovered = false
			unit.refresh_highlight()
		elif unit.has_node("OutlineHighlighter"):
			var highlighter = unit.get_node("OutlineHighlighter")
			highlighter.clear_highlight()


## Checks win/lose condition - called when a unit dies.
## Defeat condition: King HP reaches 0 (King is no longer alive).
## Victory condition: delegated to WaveManager (remaining_enemies counter).
## King death is checked regardless of battle state — the King dying during
## a death animation after the wave was cleared should still end the game.
func check_win_condition() -> void:
	# Always check King death, even outside BATTLE state (death animation
	# may finish after WaveManager already ended the wave)
	var player_units := game_area.unit_grid.get_all_units()
	var king_alive := false
	for u in player_units:
		if is_instance_valid(u) and u.stats and u.stats.is_king:
			if u.current_health > 0.0:
				king_alive = true
			break
	
	# Also check player_units group — King may have been removed from grid
	# but not yet freed (queue_free is deferred)
	if not king_alive:
		for u in get_tree().get_nodes_in_group("player_units"):
			if is_instance_valid(u) and u is Unit and u.stats and u.stats.is_king:
				if u.current_health > 0.0:
					king_alive = true
				break
	
	if not king_alive:
		print("[Battle] 👑 The King has fallen!")
		end_battle(UnitStats.Team.ENEMY)
		return
	
	# Wave completion check only applies during BATTLE
	if current_state != State.BATTLE:
		return
	
	# Check enemy win condition via WaveManager (enemies are free-moving, not on grid)
	var wave_mgr = get_tree().get_first_node_in_group("wave_manager")
	if wave_mgr:
		# Let WaveManager handle wave completion via remaining_enemies count
		return
	
	# Fallback: legacy grid-based check
	var enemy_units := enemy_area.unit_grid.get_all_units()
	if enemy_units.is_empty():
		end_battle(UnitStats.Team.PLAYER)


## Manual trigger to start battle (for testing or button).
func force_start_battle() -> void:
	if current_state == State.PREPARATION:
		start_battle()
