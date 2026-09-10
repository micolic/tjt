extends Node

# gdlint: disable=private-access,max-line-length,max-file-lines
# White-box regression test — it intentionally reads private state (selection,
# pending drag, placement) and calls private handlers to simulate real input.
# The IDE may still report [private-access] warnings — they are expected here.

const ARENA_SCENE: PackedScene = preload("res://scenes/arena/arena.tscn")
const PLAYER_TEMPLATE: PlayerStats = preload("res://data/player/player_stats.tres")
const GRUNT: UnitStats = preload("res://data/units/grunt_ally.tres")
const SENTINEL: UnitStats = preload("res://data/units/sentinel_ally.tres")
const SLAYER: UnitStats = preload("res://data/units/slayer_ally.tres")
const VIEWPORT_SIZE: Vector2i = Vector2i(960, 540)
const UPGRADE_NAMES: Array[String] = ["Bloodfang", "Ravager"]
const UPGRADE_COSTS: Array[int] = [1, 3]
## Anchors on the 8 px logical grid (4 cells = one old 32 px tile).
const FIRST_TILE: Vector2i = Vector2i(24, 16)
const SECOND_TILE: Vector2i = Vector2i(32, 16)

class FailingSpawner:
	extends UnitSpawner

	var attempts: int = 0

	func spawn_unit(_stats: UnitStats, _tile: Vector2i = Vector2i(-1, -1)) -> Node:
		attempts += 1
		return null

var _arena: Arena = null
var _failures: PackedStringArray = []
var _checks: int = 0
var _case_name: String = "initialization"
var _upgrade_signal_fallbacks: int = 0
var _case_completed: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	get_tree().root.size = VIEWPORT_SIZE
	get_tree().root.content_scale_size = VIEWPORT_SIZE
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().create_timer(45.0).timeout.connect(_on_timeout)
	var template_gold: int = PLAYER_TEMPLATE.gold
	var template_attack: int = GRUNT.attack_damage
	var template_speed: float = GRUNT.attack_speed
	var cases: Array[Callable] = [
		_test_selection_and_panels,
		_test_viewport_clicks,
		_test_drag_threshold_and_restoration,
		_test_upgrade_guards_and_king,
		_test_upgrade_branches_and_synergy,
		_test_failed_upgrade_rollback,
		_test_battle_gates,
		_test_live_panel_refresh,
		_test_selection_lifetime,
		_test_bloodrage_thresholds,
		_test_bloodrage_attack_timing,
		_test_remove_button,
	]
	for test_case: Callable in cases:
		_case_name = String(test_case.get_method())
		print("[ArenaSelectionTest] Running %s" % _case_name)
		_case_completed = false
		if _check(await _create_arena(), "Arena fixture completes setup"):
			await test_case.call()
			_check(_case_completed, "Case reached completion without an interrupted coroutine")
		await _destroy_arena()
	_case_name = "shared templates"
	_check(PLAYER_TEMPLATE.gold == template_gold, "PlayerStats template gold is unchanged")
	_check(
		GRUNT.attack_damage == template_attack
		and is_equal_approx(GRUNT.attack_speed, template_speed),
		"Grunt template stats are unchanged")
	print("[ArenaSelectionTest] %d checks, %d failures, %d fallbacks" % [
		_checks, _failures.size(), _upgrade_signal_fallbacks])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _create_arena() -> bool:
	_arena = ARENA_SCENE.instantiate() as Arena
	if not _check(is_instance_valid(_arena), "Real arena scene instantiates"):
		return false
	if not _check(_arena.player_stats != null, "Arena has PlayerStats"):
		return false
	var shared_stats: PlayerStats = _arena.player_stats
	_arena.player_stats = shared_stats.duplicate(true) as PlayerStats
	_arena.player_stats.gold = 100
	get_tree().root.add_child(_arena)
	get_tree().current_scene = _arena
	if not _check(
		_arena.battle_manager != null and _arena.selected_unit_panel != null
		and _arena.unit_selection_panel != null,
		"Arena managers and both panels are ready"):
		return false
	var waves: WaveManager = _arena.wave_manager as WaveManager
	if waves:
		waves.set_process(false)
		if _arena.battle_manager.battle_started.is_connected(waves.get("_on_battle_started")):
			_arena.battle_manager.battle_started.disconnect(waves.get("_on_battle_started"))
	await _frames(4)
	_check(_arena.player_stats != shared_stats, "Fixture owns a duplicated PlayerStats resource")
	_check(
		get_tree().root.get_visible_rect().size.is_equal_approx(Vector2(VIEWPORT_SIZE)),
		"Headless viewport is 960x540")
	return true


func _destroy_arena() -> void:
	if is_instance_valid(_arena):
		if is_instance_valid(_arena.selected_unit_panel):
			_arena.call("_clear_unit_selection")
		get_tree().current_scene = self
		_arena.queue_free()
		_arena = null
	await _frames(3)
	_check(
		get_tree().get_nodes_in_group("player_units").is_empty(),
		"Fixture player units are freed between cases")
	_check(get_tree().get_nodes_in_group("dragging").is_empty(), "No drag survives fixture cleanup")


func _frames(count: int = 3) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		var failure: String = "[%s] %s" % [_case_name, message]
		_failures.append(failure)
		push_error("[ArenaSelectionTest] %s" % failure)
	return condition


func _on_timeout() -> void:
	_check(false, "Runner exceeded its 45 second watchdog")
	await _destroy_arena()
	get_tree().quit(1)


func _spawn(stats: UnitStats, tile: Vector2i) -> Unit:
	if not _check(
		_arena.game_area.is_tile_within_bounds(tile)
		and not _arena.game_area.unit_grid.is_tile_occupied(tile),
		"Fixture spawn tile is available: %s" % tile):
		return null
	var unit: Unit = _arena.unit_spawner.spawn_unit(stats, tile) as Unit
	if _check(is_instance_valid(unit), "Spawned %s with the real UnitSpawner" % stats.name):
		_arena.unit_selection_panel.on_unit_placed(stats)
		_check(unit.stats != stats, "Spawned unit owns independent UnitStats")
	return unit


func _unit_at(tile: Vector2i) -> Unit:
	return _arena.game_area.unit_grid.units.get(tile) as Unit


func _mouse_button(button: MouseButton, pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event


func _send_input(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _move_pointer(position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = position - get_tree().root.get_mouse_position()
	event.position = position
	event.global_position = position
	_send_input(event)


func _screen_position(world_position: Vector2) -> Vector2:
	return _arena.game_area.get_canvas_transform() * world_position


func _press_unit(unit: Unit) -> Vector2:
	var position: Vector2 = _screen_position(unit.global_position + Vector2(16.0, 8.0))
	_move_pointer(position)
	unit.input_event.emit(get_tree().root, _mouse_button(MOUSE_BUTTON_LEFT, true, position), 0)
	return position


func _release_mouse(position: Vector2) -> void:
	_send_input(_mouse_button(MOUSE_BUTTON_LEFT, false, position))


func _select(unit: Unit) -> void:
	_release_mouse(_press_unit(unit))


func _selected_count() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("player_units"):
		if node is Unit and node.is_selected:
			count += 1
	return count


func _outline_thickness(unit: Unit) -> float:
	var material: ShaderMaterial = unit.outline_highlighter.visuals.material as ShaderMaterial
	if not _check(material != null, "Unit has an outline ShaderMaterial"):
		return 0.0
	return float(material.get_shader_parameter("line_thickness"))


func _target(unit: Unit, target_name: String) -> UnitStats:
	for target: UnitStats in unit.stats.upgrades:
		if target != null and target.name == target_name:
			return target
	_check(false, "Upgrade target exists: %s" % target_name)
	return null


func _upgrade_button(target: UnitStats) -> Button:
	for node: Node in _arena.selected_unit_panel.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if not button.is_queued_for_deletion() and button.text.contains(target.name):
			return button
	return null


func _check_upgrade_buttons(unit: Unit, enabled: bool) -> void:
	for target: UnitStats in unit.stats.upgrades:
		var button: Button = _upgrade_button(target)
		if _check(button != null, "Upgrade button exists for %s" % target.name):
			_check(
				button.disabled == (not enabled),
				"%s upgrade button enabled=%s" % [target.name, enabled])


func _check_no_upgrades(unit: Unit) -> void:
	_check(not unit.stats.has_upgrades(), "%s has no further upgrade paths" % unit.stats.name)
	var container: Node = _arena.selected_unit_panel.find_child("UpgradeButtons", true, false)
	if _check(container != null, "Upgrade button container exists"):
		_check(
			container.find_children("*", "Button", true, false).is_empty(),
			"%s has no upgrade buttons" % unit.stats.name)


func _activate_upgrade(unit: Unit, target: UnitStats) -> void:
	var button: Button = _upgrade_button(target)
	if button != null:
		if _check(not button.disabled, "Actual %s upgrade button is enabled" % target.name):
			button.pressed.emit()
	else:
		_upgrade_signal_fallbacks += 1
		print("[ArenaSelectionTest] Button lookup unavailable for "
				+ "%s; emitting upgrade_requested" % target.name)
		_arena.selected_unit_panel.upgrade_requested.emit(unit, target)


func _panel_text(node_name: String) -> String:
	var label: Label = _arena.selected_unit_panel.find_child(node_name, true, false) as Label
	if not _check(label != null, "Panel label exists: %s" % node_name):
		return ""
	return label.text


func _check_panel_bounds() -> void:
	var panel: SelectedUnitPanel = _arena.selected_unit_panel
	var minimum: Vector2 = panel.get_combined_minimum_size()
	_check(
		minimum.x <= 200.0 and minimum.y <= 540.0,
		"Selected panel minimum fits left vertical bounds: %s" % minimum)
	_check(
		panel.size.x <= 200.0 and panel.size.y <= 540.0,
		"Selected panel actual size fits left vertical bounds: %s" % panel.size)
	_check(
		get_tree().root.get_visible_rect().grow(0.5).encloses(panel.get_global_rect()),
		"Selected panel stays within the viewport")
	var bounds: Rect2 = panel.get_global_rect().grow(0.5)
	for node: Node in panel.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.is_visible_in_tree() and (control is Label or control is Button):
			_check(
				bounds.encloses(control.get_global_rect()),
				("Panel contains visible text/button %s: "
					+ "%s") % [panel.get_path_to(control), control.get_global_rect()])


func _test_selection_and_panels() -> void:
	_check(
		not _arena.selected_unit_panel.visible and not _arena.unit_selection_panel.visible,
		"Both panels start hidden")
	_check(_arena.get("_selected_unit") == null, "No initial selection")
	_check(not InputMap.has_action("upgrade_unit"), "Legacy U upgrade action is removed")
	var first: Unit = _spawn(GRUNT, FIRST_TILE)
	var second: Unit = _spawn(GRUNT, SECOND_TILE)
	if first == null or second == null:
		return
	var gold: int = _arena.player_stats.gold
	_check(
		first.selection_requested.is_connected(_arena.get("_on_unit_selection_requested")),
		"Unit selection signal is wired to Arena")
	_select(first)
	await _frames()
	_check(
		_arena.get("_selected_unit") == first and first.is_selected,
		"Actual Unit input signal selects the unit")
	_check(
		_arena.selected_unit_panel.visible and not _arena.unit_selection_panel.visible,
		"Selection shows the info panel; deck stays hidden")
	first.mouse_entered.emit()
	first.mouse_exited.emit()
	_check(
		not first.is_hovered and _outline_thickness(first) > 0.0,
		"Selected outline survives mouse exit")
	_check_panel_bounds()
	_select(second)
	_check(
		_arena.get("_selected_unit") == second and not first.is_selected and second.is_selected
		and _selected_count() == 1,
		"Switching selects exactly one unit")
	_check(is_zero_approx(_outline_thickness(first)), "Previous selection loses its outline")
	_arena.selected_unit_panel.deselection_requested.emit()
	_check(
		_arena.get("_selected_unit") == null and not _arena.selected_unit_panel.visible
		and _selected_count() == 0,
		"Panel deselection clears selection and hides info")
	_check(
		_unit_at(FIRST_TILE) == first and _unit_at(SECOND_TILE) == second
		and _arena.player_stats.gold == gold,
		"Deselecting does not sell units")
	var ui_position: Vector2 = _arena.hud_bar.get_global_rect().get_center()
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	var cancel_events: Array[InputEvent] = [_mouse_button(
		MOUSE_BUTTON_RIGHT,
		true,
		ui_position), escape]
	for event: InputEvent in cancel_events:
		_select(first)
		_move_pointer(ui_position)
		_check(event.is_action_pressed("cancel_drag"), "Physical cancel input maps to cancel_drag")
		_send_input(event)
		_check(
			_arena.get("_selected_unit") == null and not _arena.selected_unit_panel.visible,
			"Global cancel deselects over HUD controls")
		_check(
			_unit_at(FIRST_TILE) == first and not first.is_queued_for_deletion()
			and _arena.player_stats.gold == gold,
			"Cancel over UI preserves the unit and gold")
		var release: InputEvent = event.duplicate() as InputEvent
		release.set("pressed", false)
		_send_input(release)
	_select(first)
	_arena.call("_on_toggle_units_pressed")
	_check(
		_arena.unit_selection_panel.visible and _arena.selected_unit_panel.visible
		and _arena.get("_selected_unit") == first and first.is_selected,
		"Opening the deck while a unit is selected keeps both panels "
			+ "visible and preserves selection")
	_select(second)
	_check(
		_arena.unit_selection_panel.visible and _arena.selected_unit_panel.visible
		and _arena.get("_selected_unit") == second and second.is_selected and not first.is_selected,
		"Selecting another unit while the deck is open keeps both panels "
			+ "visible and switches selection")
	_arena.call("_on_toggle_units_pressed")
	_check(
		not _arena.unit_selection_panel.visible and _arena.selected_unit_panel.visible
		and _arena.get("_selected_unit") == second and second.is_selected,
		"Toggling the deck closed keeps the selected unit info visible")
	_arena.call("_on_toggle_units_pressed")
	_check(
		_arena.unit_selection_panel.visible and _arena.selected_unit_panel.visible
		and _arena.get("_selected_unit") == second and second.is_selected,
		"Toggling the deck open again preserves both panels and selection")
	_case_completed = true


func _click_at(position: Vector2) -> void:
	_move_pointer(position)
	await get_tree().physics_frame
	_send_input(_mouse_button(MOUSE_BUTTON_LEFT, true, position))
	await get_tree().physics_frame
	await _frames()
	_release_mouse(position)
	await _frames()


func _test_viewport_clicks() -> void:
	var unit: Unit = _spawn(GRUNT, FIRST_TILE)
	var covered: Unit = _spawn(GRUNT, Vector2i(8, 40))
	if unit == null or covered == null:
		return
	var position: Vector2 = _screen_position(unit.global_position + Vector2(16.0, 8.0))
	await _click_at(position)
	if not _check(
		_arena.get("_selected_unit") == unit and _arena.selected_unit_panel.visible,
		"Viewport physics picking selects the clicked unit without a synthetic unit signal"):
		return
	_check(
		not unit.drag_and_drop.dragging and _unit_at(FIRST_TILE) == unit,
		"Real click selects without dragging or removing grid occupancy")
	await _click_at(_screen_position(covered.global_position + Vector2(16.0, 8.0)))
	_check(
		_arena.get("_selected_unit") == unit and not covered.drag_and_drop.get("_pending_drag"),
		"Info panel blocks click-through to units underneath it")
	var target: UnitStats = _target(unit, "Bloodfang")
	var button: Button = _upgrade_button(target)
	if not _check(button != null, "Viewport test can find the Bloodfang button"):
		return
	var gold: int = _arena.player_stats.gold
	button.grab_focus()
	var space: InputEventKey = InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.keycode = KEY_SPACE
	space.pressed = true
	_send_input(space)
	_check(
		_arena.unit_selection_panel.visible and _arena.get("_selected_unit") == unit
		and _arena.player_stats.gold == gold,
		"Space opens the deck instead of activating a focused upgrade button "
			+ "while keeping the unit selected")
	var space_release: InputEventKey = space.duplicate() as InputEventKey
	space_release.pressed = false
	_send_input(space_release)
	await _click_at(position)
	_check(
		_arena.get("_selected_unit") == unit and _arena.unit_selection_panel.visible,
		"Real world click keeps selection while the deck remains open")
	button = _upgrade_button(target)
	if not _check(button != null, "Upgrade button is rebuilt after reopening selection"):
		return
	await _click_at(button.get_global_rect().get_center())
	var upgraded: Unit = _unit_at(FIRST_TILE)
	_check(
		is_instance_valid(upgraded) and upgraded != unit and upgraded.stats.name == "Bloodfang",
		"Real GUI mouse click activates the chosen upgrade button")
	_check(
		_arena.player_stats.gold == gold - 1 and _arena.get("_selected_unit") == upgraded
		and upgraded.is_selected,
		"Real GUI upgrade charges once and keeps replacement selected")
	_case_completed = true


func _test_drag_threshold_and_restoration() -> void:
	var unit: Unit = _spawn(GRUNT, FIRST_TILE)
	if unit == null:
		return
	var drag: DragAndDrop = unit.drag_and_drop
	var origin: Vector2 = unit.global_position
	var press: Vector2 = _press_unit(unit)
	_check(
		drag.get("_pending_drag") and not drag.dragging and _unit_at(FIRST_TILE) == unit,
		"Mouse press only arms a pending drag")
	_release_mouse(press)
	_check(
		not drag.get("_pending_drag") and not drag.dragging
		and unit.global_position.is_equal_approx(origin) and _unit_at(FIRST_TILE) == unit,
		"A single click never moves or removes the unit")
	press = _press_unit(unit)
	_move_pointer(press + Vector2(7.0, 0.0))
	_check(
		not drag.dragging and drag.get("_pending_drag") and _unit_at(FIRST_TILE) == unit,
		"Seven pixels do not start a drag")
	_move_pointer(press + Vector2(8.0, 0.0))
	_check(
		drag.dragging and unit.is_in_group("dragging") and _unit_at(FIRST_TILE) == null,
		"Eight pixels start a drag and release the grid tile")
	var destination: Vector2 = _arena.game_area.get_unit_position(SECOND_TILE, unit.stats.footprint)
	var destination_mouse: Vector2 = _screen_position(destination)
	_move_pointer(destination_mouse)
	drag.call("_process", 0.0)
	_check(unit.global_position.is_equal_approx(destination), "Active drag follows the pointer")
	_release_mouse(destination_mouse)
	await _frames()
	_check(
		not drag.dragging and _unit_at(FIRST_TILE) == null and _unit_at(SECOND_TILE) == unit
		and unit.global_position.is_equal_approx(destination),
		"Drop moves the unit into the destination grid tile")
	_check(
		unit.is_selected and _outline_thickness(unit) > 0.0,
		"Dropped selection keeps its outline")
	for disable_drag: bool in [false, true]:
		press = _press_unit(unit)
		_move_pointer(press + Vector2(8.0, 0.0))
		_check(
			drag.dragging and _unit_at(SECOND_TILE) == null,
			"Restoration fixture has an active drag")
		unit.global_position += Vector2(48.0, 32.0)
		if disable_drag:
			drag.enabled = false
		else:
			drag.cancel()
		_check(
			not drag.dragging and not drag.get("_pending_drag")
			and not unit.is_in_group("dragging"),
			"Cancel or disabling ends the active drag")
		_check(
			_unit_at(SECOND_TILE) == unit and unit.global_position.is_equal_approx(destination),
			"Cancel or disabling restores position and grid occupancy")
		_release_mouse(get_tree().root.get_mouse_position())
	press = _press_unit(unit)
	_move_pointer(press + Vector2(16.0, 0.0))
	_check(
		not drag.dragging and not drag.get("_pending_drag") and _unit_at(SECOND_TILE) == unit,
		"A disabled DragAndDrop cannot arm or start")
	_release_mouse(get_tree().root.get_mouse_position())
	_case_completed = true


func _test_upgrade_guards_and_king() -> void:
	var first: Unit = _spawn(GRUNT, FIRST_TILE)
	var second: Unit = _spawn(GRUNT, SECOND_TILE)
	if first == null or second == null:
		return
	_select(first)
	await _frames()
	var target: UnitStats = _target(first, "Bloodfang")
	if target == null:
		return
	var stats: UnitStats = first.stats
	var position: Vector2 = first.global_position
	var health: float = first.current_health
	var deployed: int = _arena.unit_selection_panel.deployed_count
	_arena.player_stats.gold = 0
	_check_upgrade_buttons(first, false)
	_arena.selected_unit_panel.upgrade_requested.emit(first, target)
	_check(
		_unit_at(FIRST_TILE) == first and first.stats == stats
		and not first.is_queued_for_deletion(),
		"Insufficient gold retains the original node and resource")
	_check(
		_arena.player_stats.gold == 0 and first.current_health == health
		and first.global_position == position and stats.gold_cost == 1
		and stats.upgrades.has(target),
		"Rejected upgrade leaves gold, health, position, and upgrade data unchanged")
	_check(
		_arena.unit_selection_panel.deployed_count == deployed,
		"Rejected upgrade leaves deployed count unchanged")
	_arena.player_stats.gold = 20
	_select(second)
	_arena.selected_unit_panel.upgrade_requested.emit(first, target)
	_check(
		_unit_at(FIRST_TILE) == first and _unit_at(SECOND_TILE) == second
		and _arena.get("_selected_unit") == second and _arena.player_stats.gold == 20,
		"Late upgrade request for a previously selected unit is ignored")
	_select(first)
	_arena.call("_upgrade_placed_unit", FIRST_TILE, SLAYER)
	_check(
		_unit_at(FIRST_TILE) == first and first.stats == stats and _arena.player_stats.gold == 20,
		"An unrelated upgrade target is rejected")
	_arena.set("_is_match_over", true)
	_check(
		not _arena.call("_can_modify_units"),
		"Match-over blocks modification even in preparation")
	_arena.call("_on_upgrade_requested", first, target)
	_arena.call("_remove_placed_unit", FIRST_TILE)
	_arena.call("_on_toggle_units_pressed")
	_check(
		_unit_at(FIRST_TILE) == first and _arena.player_stats.gold == 20
		and not _arena.unit_selection_panel.visible,
		"Match-over blocks upgrading, selling, and opening the deck")
	_arena.set("_is_match_over", false)
	var king: Unit = get_tree().get_first_node_in_group("king") as Unit
	if not _check(king != null, "Real arena spawns a King"):
		return
	_select(king)
	await _frames()
	var king_tile: Vector2i = _arena.game_area.get_tile_from_global(king.global_position)
	var king_stats: UnitStats = king.stats
	_check_no_upgrades(king)
	_arena.call("_on_upgrade_requested", king, target)
	_arena.call("_remove_placed_unit", king_tile)
	_check(
		_unit_at(king_tile) == king and king.stats == king_stats
		and not king.is_queued_for_deletion() and _arena.player_stats.gold == 20,
		"King cannot be upgraded or sold")
	_case_completed = true


func _test_upgrade_branches_and_synergy() -> void:
	var sentinel: Unit = _spawn(SENTINEL, Vector2i(40, 16))
	var slayer: Unit = _spawn(SLAYER, Vector2i(48, 16))
	if sentinel == null or slayer == null:
		return
	for index: int in range(UPGRADE_NAMES.size()):
		var tile: Vector2i = FIRST_TILE + Vector2i(index * 4, 0)
		var original: Unit = _spawn(GRUNT, tile)
		if original == null:
			continue
		original.global_position += Vector2(2.0, 3.0)
		_select(original)
		await _frames()
		_check(original.stats.upgrades.size() == 2, "Grunt presents both upgrade branches")
		var target: UnitStats = _target(original, UPGRADE_NAMES[index])
		if target == null:
			continue
		_check(
			original.stats.get_upgrade_cost(target) == UPGRADE_COSTS[index],
			"%s incremental price is %d" % [target.name, UPGRADE_COSTS[index]])
		_check(
			_arena.synergy_manager.is_synergy_active(UnitStats.Faction.WARRIOR),
			"Warrior synergy is active before upgrading")
		_check(
			_arena.synergy_manager.get_faction_count(UnitStats.Faction.WARRIOR) == 3,
			"Base and upgraded Grunts share one synergy identity")
		_check_panel_bounds()
		var original_id: int = original.get_instance_id()
		var position: Vector2 = original.global_position
		var gold: int = _arena.player_stats.gold
		var deployed: int = _arena.unit_selection_panel.deployed_count
		_activate_upgrade(original, target)
		await _frames(4)
		var upgraded: Unit = _unit_at(tile)
		if not _check(
			is_instance_valid(upgraded) and upgraded.get_instance_id() != original_id,
			"%s replaces the original node" % target.name):
			continue
		_check(not is_instance_valid(original), "Replaced Grunt is freed")
		_check(
			upgraded.stats.name == target.name and upgraded.stats != target,
			"Replacement owns the chosen branch's duplicated stats")
		_check(
			_arena.player_stats.gold == gold - UPGRADE_COSTS[index],
			"%s charges only its incremental price" % target.name)
		_check(
			upgraded.global_position.is_equal_approx(position)
			and _arena.unit_selection_panel.deployed_count == deployed,
			"Upgrade preserves exact position, tile, and deployed count")
		_check(
			_arena.get("_selected_unit") == upgraded and upgraded.is_selected
			and _selected_count() == 1
			and _arena.selected_unit_panel.visible,
			"Selection transfers to the replacement")
		upgraded.mouse_exited.emit()
		_check(_outline_thickness(upgraded) > 0.0, "Replacement retains its selected outline")
		_check(
			upgraded.stats.tier == GRUNT.tier
			and upgraded.stats.get_unit_line() == GRUNT.get_unit_line(),
			"Upgrade retains the Grunt tier and unit line")
		_check(
			_arena.synergy_manager.is_synergy_active(UnitStats.Faction.WARRIOR)
			and _arena.synergy_manager.get_faction_count(UnitStats.Faction.WARRIOR) == 3,
			"Warrior identity count and activation survive replacement")
		_check(
			upgraded.has_meta("syn_base_atk"),
			"Already-active Warrior bonus is applied to the new unit")
		var base_attack: int = int(upgraded.get_meta("syn_base_atk", 0))
		var warrior_definition: Dictionary = SynergyManager.SYNERGY_DEFS[UnitStats.Faction.WARRIOR]
		_check(
			upgraded.stats.attack_damage == int(
				base_attack * float(warrior_definition["attack_damage_mult"])),
			"Replacement has the configured active Warrior attack bonus")
		_check_no_upgrades(upgraded)
		_check_panel_bounds()
	_case_completed = true


func _test_failed_upgrade_rollback() -> void:
	var unit: Unit = _spawn(GRUNT, FIRST_TILE)
	if unit == null:
		return
	_select(unit)
	await _frames()
	var target: UnitStats = _target(unit, "Bloodfang")
	if target == null:
		return
	var stats: UnitStats = unit.stats
	var position: Vector2 = unit.global_position
	var gold: int = _arena.player_stats.gold
	var deployed: int = _arena.unit_selection_panel.deployed_count
	var real_spawner: UnitSpawner = _arena.unit_spawner
	var failed_spawner: FailingSpawner = FailingSpawner.new()
	_arena.add_child(failed_spawner)
	_arena.unit_spawner = failed_spawner
	_arena.call("_on_upgrade_requested", unit, target)
	_arena.unit_spawner = real_spawner
	_check(failed_spawner.attempts == 1, "Rollback test reaches the failing spawn")
	_check(
		_unit_at(FIRST_TILE) == unit and not unit.is_queued_for_deletion()
		and unit.stats == stats and unit.global_position == position,
		"Failed spawn retains the original node, resource, position, and grid entry")
	_check(
		_arena.player_stats.gold == gold and _arena.unit_selection_panel.deployed_count == deployed,
		"Failed spawn refunds payment without changing deployed count")
	_check(
		_arena.get("_selected_unit") == unit and unit.is_selected
		and _arena.selected_unit_panel.visible,
		"Failed spawn preserves selection and info")
	failed_spawner.queue_free()
	await _frames()
	_case_completed = true


func _test_battle_gates() -> void:
	var first: Unit = _spawn(GRUNT, FIRST_TILE)
	var second: Unit = _spawn(GRUNT, SECOND_TILE)
	if first == null or second == null:
		return
	_select(first)
	await _frames()
	var gold: int = _arena.player_stats.gold
	var stats: UnitStats = first.stats
	var position: Vector2 = first.global_position
	var press: Vector2 = _press_unit(first)
	_move_pointer(press + Vector2(8.0, 0.0))
	_check(first.drag_and_drop.dragging, "Battle-start fixture has an active drag")
	_arena.battle_manager.start_battle()
	await _frames()
	_check(
		_arena.battle_manager.current_state == BattleManager.State.BATTLE
		and not _arena.call("_can_modify_units"),
		"Real battle start blocks modification")
	_check(
		_unit_at(FIRST_TILE) == first and first.global_position == position
		and not first.drag_and_drop.dragging and not first.drag_and_drop.enabled,
		"Battle start cancels and restores an active drag")
	_check(
		_arena.get("_selected_unit") == first and first.is_selected
		and _arena.selected_unit_panel.visible and _outline_thickness(first) > 0.0,
		"Selection and outline survive battle start")
	_check_upgrade_buttons(first, false)
	for target: UnitStats in first.stats.upgrades:
		_arena.selected_unit_panel.upgrade_requested.emit(first, target)
	_check(
		_unit_at(FIRST_TILE) == first and first.stats == stats and _arena.player_stats.gold == gold,
		"Battle upgrade callbacks cannot replace units or spend gold")
	_arena.call("_on_toggle_units_pressed")
	_arena.call("_on_panel_unit_selected", GRUNT)
	_arena.call("_on_panel_unit_drag_started", GRUNT)
	_check(
		not _arena.unit_selection_panel.visible and _arena.get("_placement_stats") == null,
		"Battle cannot open the deck or enter placement")
	press = _press_unit(second)
	_move_pointer(press + Vector2(16.0, 0.0))
	_release_mouse(get_tree().root.get_mouse_position())
	_check(
		_arena.get("_selected_unit") == second and second.is_selected and not first.is_selected
		and _selected_count() == 1,
		"Unit selection still works during battle")
	_check(
		not second.drag_and_drop.enabled and not second.drag_and_drop.dragging
		and not second.drag_and_drop.get("_pending_drag") and _unit_at(SECOND_TILE) == second,
		"Battle-disabled dragging cannot arm, move, or remove a unit")
	second.mouse_exited.emit()
	_check(_outline_thickness(second) > 0.0, "Battle selection remains outlined after mouse exit")
	_arena.battle_manager.call("_change_state", BattleManager.State.ENDED)
	_check(not _arena.call("_can_modify_units"), "ENDED also blocks modification")
	_check_upgrade_buttons(second, false)
	var ended_target: UnitStats = _target(second, "Bloodfang")
	if ended_target != null:
		_arena.call("_on_upgrade_requested", second, ended_target)
	_arena.call("_on_toggle_units_pressed")
	_check(
		_unit_at(SECOND_TILE) == second and _arena.player_stats.gold == gold
		and not _arena.unit_selection_panel.visible,
		"ENDED rejects upgrades and deck opening")
	_arena.battle_manager.start_preparation()
	_check(
		_arena.call("_can_modify_units") and second.drag_and_drop.enabled and second.is_selected,
		"Preparation restores modifications without losing selection")
	_check_upgrade_buttons(second, true)
	_case_completed = true


func _test_live_panel_refresh() -> void:
	var unit: Unit = _spawn(GRUNT, FIRST_TILE)
	if unit == null:
		return
	_select(unit)
	await _frames()
	unit.current_health = maxf(1.0, float(unit.stats.get_max_health()) - 7.25)
	_check(
		_panel_text("HealthLabel") == "HP %d / %d" % [
			ceili(unit.current_health), unit.stats.get_max_health()],
		"Health signal refreshes live HP text")
	unit.current_mana = minf(21.5, float(unit.stats.max_mana) * 0.4)
	_check(
		_panel_text("ManaLabel") == "Mana %d / %d" % [
			floori(unit.current_mana), unit.stats.max_mana],
		"Mana signal refreshes live mana text")
	unit.register_damage_dealt(17.0)
	_check(
		_panel_text("DamageLabel").contains("17"),
		"Damage signal refreshes the selected unit readout")
	unit.stats.attack_speed += 0.37
	_arena.call("_process", 0.26)
	_check(
		_panel_text("CombatLabel").contains("AS %.2f" % unit.stats.attack_speed),
		"Arena's quarter-second refresh updates attack speed without a health signal")
	_arena.player_stats.gold = 0
	_check(
		_panel_text("UpgradeHeader").contains("Gold 0"),
		"PlayerStats change refreshes panel gold")
	_check_upgrade_buttons(unit, false)
	_arena.player_stats.gold = 1
	for target: UnitStats in unit.stats.upgrades:
		var button: Button = _upgrade_button(target)
		if _check(button != null, "Affordability button exists: %s" % target.name):
			_check(
				button.disabled == (unit.stats.get_upgrade_cost(target) > 1),
				"Gold signal updates each branch's affordability")
	_arena.player_stats.gold = 3
	_check_upgrade_buttons(unit, true)
	await _frames()
	_check_panel_bounds()
	_case_completed = true


func _test_selection_lifetime() -> void:
	var first: Unit = _spawn(GRUNT, FIRST_TILE)
	var second: Unit = _spawn(GRUNT, SECOND_TILE)
	if first == null or second == null:
		return
	_select(first)
	await _frames()
	var gold: int = _arena.player_stats.gold
	_arena.game_area.unit_grid.remove_unit(FIRST_TILE)
	_arena.unit_selection_panel.on_unit_removed()
	first.queue_free()
	await _frames(4)
	_check(
		not is_instance_valid(first) and _arena.get("_selected_unit") == null
		and not _arena.selected_unit_panel.visible,
		"Freeing the selected node clears selection and closes info")
	_select(second)
	await _frames()
	second.current_health = 0.0
	_check(
		_arena.get("_selected_unit") == null and not _arena.selected_unit_panel.visible
		and not second.is_selected,
		"HP zero closes info immediately before death animation completes")
	_check(is_zero_approx(_outline_thickness(second)), "Dead selected unit loses its outline")
	_select(second)
	_check(
		_arena.get("_selected_unit") == null and not _arena.selected_unit_panel.visible,
		"Dead units cannot be reselected")
	_check(
		_arena.player_stats.gold == gold,
		"Freeing or killing a selected unit does not grant a sell refund")
	await _frames()
	_case_completed = true


func _test_bloodrage_thresholds() -> void:
	var templates: Array[UnitStats] = [GRUNT, GRUNT.upgrades[0], GRUNT.upgrades[1]]
	var bonuses: Array[float] = [0.2, 0.2, 0.3]
	var fractions: Array[float] = [1.0, 0.6, 0.599, 0.4, 0.399, 0.2,
		0.199, 0.1, 0.21, 0.41, 0.61, 1.0]
	var stacks: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 2, 1, 0, 0]
	var untouched: Unit = _spawn(GRUNT.upgrades[0], Vector2i(56, 16))
	if untouched == null:
		return
	for index: int in range(templates.size()):
		var template: UnitStats = templates[index]
		var unit: Unit = _spawn(template, FIRST_TILE + Vector2i(index * 8, 0))
		if unit == null:
			continue
		_select(unit)
		_check(
			unit.stats.passive_ability.passive_type == PassiveAbility.PassiveType.BERSERK,
			"%s uses the BERSERK health-reactive passive" % template.name)
		_check(
			is_equal_approx(unit.stats.passive_ability.value, bonuses[index]),
			"%s uses a fractional attack-speed bonus of %.2f" % [template.name, bonuses[index]])
		_check(
			is_equal_approx(unit.stats.mana_regen, template.mana_regen),
			"%s Bloodrage does not modify mana regeneration" % template.name)
		for step: int in range(fractions.size()):
			unit.current_health = template.max_health * fractions[step]
			var expected_speed: float = template.attack_speed \
					* (1.0 + bonuses[index] * stacks[step])
			_check(
				is_equal_approx(unit.stats.attack_speed, expected_speed),
				("%s at %.1f%% HP has AS %.2f (got "
					+ "%.2f)") % [
						template.name, fractions[step] * 100.0,
						expected_speed, unit.stats.attack_speed])
			_check(
				is_equal_approx(unit.stats.get_time_between_attacks(), 1.0 / expected_speed),
				"%s attack interval uses the current Bloodrage speed" % template.name)
			_check(
				_panel_text("CombatLabel").contains("AS %.2f" % expected_speed),
				"Selected panel shows %s Bloodrage speed immediately" % template.name)
			_check(
				is_equal_approx(untouched.stats.attack_speed, GRUNT.upgrades[0].attack_speed),
				"Bloodrage does not affect another unit sharing its resource")
		unit.current_health = template.max_health * 0.1
		var enraged_speed: float = unit.stats.attack_speed
		unit.call("_connect_stats_signals")
		_check(
			is_equal_approx(unit.stats.attack_speed, enraged_speed),
			"Reconnecting %s does not stack or reset its passive" % template.name)
		_arena.wave_manager.call("_reset_ally_stats")
		_check(
			is_equal_approx(unit.stats.attack_speed, template.attack_speed)
			and is_equal_approx(unit.current_health, float(template.max_health)),
			"%s returns to base attack speed after wave reset" % template.name)
	_check(
		GRUNT.upgrades[1].passive_ability != GRUNT.upgrades[0].passive_ability,
		"Ravager owns a stronger passive without changing Bloodfang's shared resource")
	_case_completed = true


func _test_bloodrage_attack_timing() -> void:
	var enemy_stats: UnitStats = load("res://data/units/orc_enemy.tres") \
			.duplicate(true) as UnitStats
	enemy_stats.max_health = 10000
	var enemy: EnemyUnit = _arena.unit_spawner.spawn_unit(enemy_stats, Vector2i(40, 4)) as EnemyUnit
	if not _check(is_instance_valid(enemy), "Spawned a real target for Bloodrage combat checks"):
		return
	for index: int in range(GRUNT.upgrades.size()):
		var template: UnitStats = GRUNT.upgrades[index]
		var bonus: float = 0.2 if index == 0 else 0.3
		var unit: Unit = _spawn(template, FIRST_TILE + Vector2i(index * 8, 0))
		if unit == null:
			continue
		var ai: UnitAI = unit.get_node("UnitAI") as UnitAI
		ai.current_target = enemy
		enemy.global_position = unit.global_position + Vector2(32.0, 0.0)
		unit.apply_damage(roundi(unit.stats.max_health * 0.9), UnitStats.DamageType.PURE)
		var expected_speed: float = template.attack_speed * (1.0 + bonus * 3)
		_check(
			is_equal_approx(unit.stats.attack_speed, expected_speed),
			"Taking damage activates %s's maximum Bloodrage bonus" % template.name)
		var before: float = enemy.current_health
		ai.call("_try_attack")
		_check(
			enemy.current_health < before,
			"%s basic attack lands through the real combat pipeline" % template.name)
		_check(
			is_equal_approx(ai.attack_timer, 1.0 / expected_speed),
			"%s AI schedules its next attack using Bloodrage speed" % template.name)
		before = enemy.current_health
		ai.call("_try_attack")
		_check(
			is_equal_approx(enemy.current_health, before),
			"Bloodrage still respects the attack cooldown")
		unit.current_health = unit.stats.max_health
		ai.attack_timer = 0.0
		ai.call("_try_attack")
		_check(
			is_equal_approx(ai.attack_timer, 1.0 / template.attack_speed),
			"Healing %s to full restores its normal AI attack interval" % template.name)
	_case_completed = true


func _test_remove_button() -> void:
	var unit: Unit = _spawn(GRUNT, FIRST_TILE)
	if unit == null:
		return
	var starting_gold: int = _arena.player_stats.gold
	_select(unit)
	var remove_button: Button = _arena.selected_unit_panel.get_node("%RemoveButton") as Button
	if not _check(
		remove_button != null and remove_button.is_visible_in_tree(),
		"Remove button appears when a unit is selected"):
		return
	_check(not remove_button.disabled, "Remove button is enabled during preparation")
	_check(
		remove_button.tooltip_text.contains("refund"),
		"Remove button tooltip explains the refund")

	var deployed: int = _arena.unit_selection_panel.deployed_count
	remove_button.pressed.emit()
	await _frames()
	_check(_unit_at(FIRST_TILE) == null, "Remove button deletes the selected unit from the grid")
	_check(
		_arena.get("_selected_unit") == null and not _arena.selected_unit_panel.visible,
		"Remove button clears selection and hides the panel")
	_check(
		_arena.player_stats.gold == starting_gold + GRUNT.gold_cost,
		"Remove button refunds the unit's gold cost")
	_check(
		_arena.unit_selection_panel.deployed_count == deployed - 1,
		"Remove button decrements deployed count")

	var king: Unit = get_tree().get_first_node_in_group("king") as Unit
	if _check(king != null, "Real arena spawns a King"):
		_select(king)
		remove_button = _arena.selected_unit_panel.get_node("%RemoveButton") as Button
		_check(
			is_instance_valid(remove_button) and remove_button.is_visible_in_tree()
			and remove_button.disabled,
			"Remove button is disabled for the King")
		_check(
			remove_button.tooltip_text.contains("King"),
			"Remove button explains that the King cannot be removed")

	var second: Unit = _spawn(GRUNT, SECOND_TILE)
	if second == null:
		_case_completed = true
		return
	_select(second)
	remove_button = _arena.selected_unit_panel.get_node("%RemoveButton") as Button
	_arena.battle_manager.start_battle()
	await _frames()
	_check(remove_button.disabled, "Remove button is disabled during battle")
	_check(
		_unit_at(SECOND_TILE) == second and not second.is_queued_for_deletion(),
		"Disabled remove button does not delete the unit")
	_case_completed = true
