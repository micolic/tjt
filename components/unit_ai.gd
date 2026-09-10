class_name UnitAI
extends Node

## Emitted when unit reaches target
signal movement_finished
## Emitted when unit attacks
signal attack_performed(target)

## Toggle AI debug logging (set to true to see target changes + attacks only)
const DEBUG_AI: bool = false
## Toggle verbose AI logging (every tick scan — very spammy, usually false)
const DEBUG_AI_VERBOSE: bool = false
## Toggle targeting-specific debug (shows WHY targets are picked/switched)
const DEBUG_TARGETING: bool = false
## Toggle movement/occupancy debug (blocked directions, boxed-in units)
const DEBUG_MOVE: bool = false

const CELL_SIZE := Vector2(32, 32)

@export var enabled: bool = false
@export var update_interval: float = 0.5  ## How often AI updates (performance)

## Minimum time (seconds) a unit must keep its current target before switching.
## Makes combat look more natural — units commit to fights briefly.
const TARGET_SWITCH_DELAY := 0.8

var unit
var current_target
var path: Array[Vector2i] = []
var current_path_index: int = 0
var movement_speed: float = 100.0  ## Pixels per second
var attack_timer: float = 0.0
var update_timer: float = 0.0
var _target_lock_timer: float = 0.0  ## Countdown before target switch is allowed

## Stuck detection — tracks whether the unit is making progress toward its target.
var _last_distance_to_target: float = INF
var _stuck_timer: float = 0.0
const STUCK_THRESHOLD := 1.5  ## Seconds without progress before switching target
const STUCK_PROGRESS_MIN := 4.0  ## Must close at least 4px to count as progress

## Reference to play areas for pathfinding
var play_area: PlayArea
var enemy_area: PlayArea
var navigation_agent: NavigationAgent2D
var _battle_manager: Node  ## Cached BattleManager reference
var _arena: Node  ## Cached Arena reference (holds battle_occupancy map)
var _occ_cells: Array[Vector2i] = []  ## 32px tiles this unit currently occupies
var _idle_log_timer: float = 0.0  ## Throttle IDLE log spam
var _move_log_timer: float = 0.0  ## Throttle [MOVE] log spam
var _animator: UnitAnimator  ## Cached animator reference


## Called when the node enters the scene tree.
func _ready() -> void:
	unit = get_parent()
	assert(unit, "UnitAI must be a child of Unit!")
	
	navigation_agent = unit.get_node_or_null("NavigationAgent2D")
	_animator = unit.get_node_or_null("UnitAnimator")
	
	# Find play areas from the scene
	_find_play_areas()
	
	# Initialize stats
	if unit.stats:
		# Combat movement speed - balanced for visible but quick movement
		movement_speed = 50.0  # pixels per second
	
	# Connect navigation signals if available
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)


## Process AI logic.
func _process(delta: float) -> void:
	if not enabled or not unit or not unit.stats:
		return
	
	# Don't run AI when not in BATTLE state (cached lookup)
	if not is_instance_valid(_battle_manager):
		_battle_manager = get_tree().get_first_node_in_group("battle_manager")
	if _battle_manager and _battle_manager.current_state != BattleManager.State.BATTLE:
		return
	
	update_timer -= delta
	if update_timer <= 0:
		update_timer = update_interval
		_update_ai()

	# Register our tiles in the shared battle occupancy map
	_update_occupancy()
	
	# Update attack cooldown
	if attack_timer > 0:
		attack_timer -= delta
	
	# Update target lock timer
	if _target_lock_timer > 0:
		_target_lock_timer -= delta
	
	# Update idle log throttle
	if _idle_log_timer > 0:
		_idle_log_timer -= delta

	# Update movement log throttle
	if _move_log_timer > 0:
		_move_log_timer -= delta

	# Separation logic — gentle push between same-team units only
	_apply_separation(delta)

	# Y-sort: units lower on screen render on top for depth illusion
	# Only update when position changes AND unit is not highlighted (highlight sets z_index=4096)
	if not ("is_hovered" in unit and unit.is_hovered) and not ("is_selected" in unit and unit.is_selected):
		var y_z: int = int(unit.global_position.y)
		if y_z != unit.z_index:
			unit.z_index = y_z

	# ── Leak mechanic: enemies that reach the King deal damage and despawn ──
	if unit.stats and unit.stats.team == UnitStats.Team.ENEMY:
		_check_leak_to_king()

	# Attempt attack if in range and cooldown ready
	if current_target and is_instance_valid(current_target):
		var distance_to_target: float = unit.global_position.distance_to(current_target.global_position)
		var attack_range_pixels: float = unit.stats.attack_range * CELL_SIZE.x
		
		if distance_to_target <= attack_range_pixels and attack_timer <= 0:
			# In range and ready to attack — reset stuck timer
			_try_attack()
			_stuck_timer = 0.0
			_last_distance_to_target = distance_to_target
		elif distance_to_target <= attack_range_pixels:
			# In range but on cooldown — idle
			if _animator:
				_animator.play(UnitAnimator.AnimState.IDLE)
		elif distance_to_target > attack_range_pixels and (
			not current_target.has_meta("is_dummy_target")
			or unit.stats.team == UnitStats.Team.ENEMY
			or current_target.has_meta("is_idle_seek")
		):
			# King is a stationary ranged defender: never move toward targets, just attack when in range
			if unit.stats and unit.stats.is_king:
				if _animator:
					_animator.play(UnitAnimator.AnimState.IDLE)
				return
			# ── Stuck detection: if not making progress, find an alternate target ──
			if _last_distance_to_target - distance_to_target >= STUCK_PROGRESS_MIN:
				# Making progress — reset
				_stuck_timer = 0.0
				_last_distance_to_target = distance_to_target
			else:
				_stuck_timer += delta
			
			if _stuck_timer >= STUCK_THRESHOLD and _target_lock_timer <= 0:
				# Stuck! Try to find an alternate target that we can reach
				var alt_target = _find_alternate_target()
				if alt_target and alt_target != current_target:
					if DEBUG_AI:
						print("[AI] %s: 🔀 stuck for %.1fs, switching %s → %s" % [unit.stats.name, _stuck_timer, _get_target_name(current_target), _get_target_name(alt_target)])
					_switch_target(alt_target)
					_stuck_timer = 0.0
					_last_distance_to_target = INF
					return
				_stuck_timer = 0.0  # Reset even if no alt found, to avoid spamming
			
			# ── Before moving: check if a DIFFERENT enemy is right next to us ──
			# This prevents walking through enemies to reach a farther target.
			# Only check if we're NOT locked to our current target.
			if _target_lock_timer <= 0:
				var nearby: Node = _find_enemy_in_attack_range()
				# For enemy units: also check for ally blockers in the path at 1.5× attack range.
				# Prevents enemies from trying to walk through/past an ally to reach a farther one.
				if not nearby and unit.stats.team == UnitStats.Team.ENEMY:
					nearby = _find_blocker_in_path()
				if nearby and nearby != current_target:
					if DEBUG_AI:
						var old_name = _get_target_name(current_target)
						var new_name = _get_target_name(nearby)
						print("[AI] %s: 🛑 enemy in range! switching %s → %s (won't walk through)" % [unit.stats.name, old_name, new_name])
					_switch_target(nearby)
					return  # Don't move this frame — attack next frame
			
			# Move toward target — probe the shared occupancy map so the unit
			# slides around teammates (or holds) instead of pushing into a wall.
			var desired_dir: Vector2
			if navigation_agent:
				navigation_agent.target_position = current_target.global_position
				var next_position = navigation_agent.get_next_path_position()
				desired_dir = (next_position - unit.global_position).normalized()
			else:
				desired_dir = (current_target.global_position - unit.global_position).normalized()
			var move_dir: Vector2 = _resolve_passable_direction(desired_dir)
			if move_dir == Vector2.ZERO:
				# Boxed in — hold; the stuck timer will try another target
				if _animator:
					_animator.play(UnitAnimator.AnimState.IDLE)
			else:
				unit.global_position += move_dir * movement_speed * delta
				if _animator:
					_animator.play(UnitAnimator.AnimState.WALK)
				if DEBUG_AI_VERBOSE and update_timer <= 0:
					var target_name = _get_target_name(current_target)
					print("[AI] %s: moving → %s (dist=%.0fpx, range=%.0fpx)" % [unit.stats.name, target_name, distance_to_target, attack_range_pixels])
	else:
		# No valid target — idle
		if _animator:
			_animator.play(UnitAnimator.AnimState.IDLE)


## Main AI update logic — runs every update_interval seconds.
func _update_ai() -> void:
	# King is a stationary ranged tower: pick a target in attack range, never move.
	if unit.stats and unit.stats.is_king:
		_update_king_ai()
		return

	# ── Step 1: Target stickiness ──
	# If current target is alive, valid, and in aggro range, keep it.
	if current_target and is_instance_valid(current_target) and not current_target.has_meta("is_dummy_target"):
		# Read the correct HP: Unit (allies) use current_health, EnemyUnit uses stats.health
		var target_hp: float = 0.0
		if "current_health" in current_target:
			target_hp = current_target.current_health
		elif "stats" in current_target and current_target.stats:
			target_hp = current_target.stats.health
		if target_hp > 0:
			var aggro_range_pixels: float = unit.stats.aggro_range * CELL_SIZE.x
			if _is_in_aggro_range(current_target.global_position, aggro_range_pixels):
				# ── Step 1b: Even if sticky, if an enemy is in ATTACK range, prefer it ──
				# This prevents a melee unit from ignoring a touching enemy
				var attack_range_pixels: float = unit.stats.attack_range * CELL_SIZE.x
				var dist_to_current: float = unit.global_position.distance_to(current_target.global_position)
				if dist_to_current <= attack_range_pixels:
					return  # Current target is in attack range — definitely keep
				# Current target alive but far — check if something closer is in attack range
				var nearby: Node = _find_enemy_in_attack_range()
				if nearby and nearby != current_target:
					if DEBUG_TARGETING:
						var nearby_dist: float = unit.global_position.distance_to(nearby.global_position)
						print("[TGT] %s: STICKY OVERRIDE — %s in atk range (dist=%.0fpx), old %s was %.0fpx away" % [unit.stats.name, _get_target_name(nearby), nearby_dist, _get_target_name(current_target), dist_to_current])
					if DEBUG_AI:
						print("[AI] %s: 🔄 closer enemy in attack range: %s → %s" % [unit.stats.name, _get_target_name(current_target), _get_target_name(nearby)])
					_switch_target(nearby)
					return
				return  # Keep current target
			else:
				if DEBUG_TARGETING:
					var dist_to_current2: float = unit.global_position.distance_to(current_target.global_position)
					print("[TGT] %s: STICKY BROKEN — %s left aggro range (dist=%.0fpx, aggro=%.0fpx)" % [unit.stats.name, _get_target_name(current_target), dist_to_current2, aggro_range_pixels])
		else:
			if DEBUG_TARGETING:
				var hp_log: float = 0.0
				if "current_health" in current_target:
					hp_log = current_target.current_health
				elif "stats" in current_target and current_target.stats:
					hp_log = current_target.stats.health
				print("[TGT] %s: STICKY BROKEN — %s is dead (hp=%.0f)" % [unit.stats.name, _get_target_name(current_target), hp_log])

	# ── Step 2: Respect target lock delay ──
	if _target_lock_timer > 0 and current_target and is_instance_valid(current_target):
		if not current_target.has_meta("is_dummy_target"):
			if DEBUG_TARGETING:
				print("[TGT] %s: LOCK active (%.1fs left), keeping %s" % [unit.stats.name, _target_lock_timer, _get_target_name(current_target)])
			return  # Still locked

	# ── Step 3: Find new target ──
	var new_target = _find_nearest_enemy()

	# ── Step 3b: Respond to aggro — allies never roam toward enemies on their
	# own. The only idle movement is toward an enemy that already has aggro on
	# this unit (e.g. a ranged attacker firing from outside our aggro range).
	if not new_target and unit.stats.team == UnitStats.Team.PLAYER:
		new_target = _find_idle_seek_target()

	# Log idle allies during battle — throttled to every 3s to reduce spam
	if not new_target and unit.stats.team == UnitStats.Team.PLAYER:
		var aggro_px: float = unit.stats.aggro_range * CELL_SIZE.x
		var enemies_exist := not get_tree().get_nodes_in_group("enemy_units").is_empty()
		if enemies_exist and DEBUG_AI and _idle_log_timer <= 0:
			var closest_enemy_dist := INF
			for e in get_tree().get_nodes_in_group("enemy_units"):
				if is_instance_valid(e):
					closest_enemy_dist = minf(closest_enemy_dist, unit.global_position.distance_to(e.global_position))
			var y_mult: float = AGGRO_Y_MULTIPLIER_COMBAT if _is_any_ally_in_combat() else AGGRO_Y_MULTIPLIER_IDLE
			var mode: String = "COMBAT" if _is_any_ally_in_combat() else "IDLE"
			print("[AI] %s: ⚠ IDLE — no target (aggro=%.0fpx×X%.1f/Y%.1f [%s], nearest=%.0fpx)" % [unit.stats.name, aggro_px, AGGRO_X_MULTIPLIER, y_mult, mode, closest_enemy_dist])
			_idle_log_timer = 3.0  # Only log every 3 seconds
	
	# For enemy units with no target, walk toward King / player base
	if not new_target and unit.stats.team == UnitStats.Team.ENEMY:
		# Reuse existing dummy (avoids recreating every cycle)
		if current_target and is_instance_valid(current_target) and current_target.has_meta("is_dummy_target"):
			var king = _find_king_unit()
			if king:
				current_target.global_position = king.global_position
			else:
				current_target.global_position = Vector2(unit.global_position.x, 1000)
			return
		new_target = _get_player_base_target()
	
	# ── Step 4: Apply target change ──
	if current_target != new_target:
		var old_is_dummy: bool = current_target != null and is_instance_valid(current_target) and current_target.has_meta("is_dummy_target")
		var new_is_dummy: bool = new_target != null and new_target.has_meta("is_dummy_target")
		
		var reason = ""
		if not current_target or not is_instance_valid(current_target):
			reason = "old target gone"
		elif old_is_dummy:
			reason = "found real enemy"
		else:
			var old_hp: float = 0.0
			if "current_health" in current_target:
				old_hp = current_target.current_health
			elif "stats" in current_target and current_target.stats:
				old_hp = current_target.stats.health
			if old_hp <= 0:
				reason = "old target dead"
			elif not new_target:
				reason = "lost aggro"
			else:
				reason = "new target closer/in-range"
		
		if DEBUG_TARGETING and not (old_is_dummy and new_is_dummy):
			var old_name = _get_target_name(current_target)
			var new_name = _get_target_name(new_target)
			var dist_old := ""
			var dist_new := ""
			if current_target and is_instance_valid(current_target) and not old_is_dummy:
				dist_old = " old_dist=%.0fpx" % unit.global_position.distance_to(current_target.global_position)
			if new_target and is_instance_valid(new_target) and not new_is_dummy:
				dist_new = " new_dist=%.0fpx" % unit.global_position.distance_to(new_target.global_position)
			print("[TGT] %s: SWITCH %s → %s (%s%s%s)" % [unit.stats.name, old_name, new_name, reason, dist_old, dist_new])
		
		if DEBUG_AI and not (old_is_dummy and new_is_dummy):
			var old_name2 = _get_target_name(current_target)
			var new_name2 = _get_target_name(new_target)
			var dist_info := ""
			if new_target and is_instance_valid(new_target):
				var d: float = unit.global_position.distance_to(new_target.global_position)
				dist_info = " [dist=%.0fpx]" % d
			print("[AI] %s: target changed %s → %s (%s)%s" % [unit.stats.name, old_name2, new_name2, reason, dist_info])
		
		_switch_target(new_target)


## Called when this unit is attacked. If we have no real target, retaliate.
func notify_attacked_by(attacker: Node) -> void:
	if not is_instance_valid(attacker) or not enabled:
		return
	# Already have a real, alive target — don't switch
	if current_target and is_instance_valid(current_target) and not current_target.has_meta("is_dummy_target"):
		var target_hp: float = 0.0
		if "current_health" in current_target:
			target_hp = current_target.current_health
		elif "stats" in current_target and current_target.stats:
			target_hp = current_target.stats.health
		if target_hp > 0:
			return
	# Retaliate: target the attacker
	if DEBUG_TARGETING:
		print("[TGT] %s: RETALIATE → %s (no alive target, attacked by ranged)" % [unit.stats.name, _get_target_name(attacker)])
	_switch_target(attacker)


## ── Helper: switch current target and clean up ──
func _switch_target(new_target) -> void:
	if current_target and is_instance_valid(current_target) and current_target.has_meta("is_dummy_target"):
		current_target.queue_free()
	current_target = new_target
	_stuck_timer = 0.0
	_last_distance_to_target = INF
	var is_dummy: bool = new_target != null and new_target.has_meta("is_dummy_target") if new_target else false
	if new_target and not is_dummy:
		_target_lock_timer = TARGET_SWITCH_DELAY


## ── Helper: find any enemy within attack range (for pre-move intercept) ──
func _find_enemy_in_attack_range() -> Node:
	if not unit.stats:
		return null
	var attack_range_pixels: float = unit.stats.attack_range * CELL_SIZE.x
	var target_group: String = UnitStats.TARGET[unit.stats.team]
	var enemies := get_tree().get_nodes_in_group(target_group)
	var closest = null
	var closest_dist := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == unit:
			continue
		var ehp: float = enemy.current_health if "current_health" in enemy else (enemy.stats.health if "stats" in enemy and enemy.stats else 0.0)
		if ehp <= 0:
			continue
		var dist: float = unit.global_position.distance_to(enemy.global_position)
		if dist <= attack_range_pixels and dist < closest_dist:
			closest_dist = dist
			closest = enemy
	return closest


## ── Helper: find an alternate target when stuck behind teammates ──
## Picks the nearest enemy that doesn't have a same-team unit between us and it.
func _find_alternate_target() -> Node:
	if not unit.stats:
		return null
	var target_group: String = UnitStats.TARGET[unit.stats.team]
	var enemies := get_tree().get_nodes_in_group(target_group)
	var same_team_units := get_tree().get_nodes_in_group("units").filter(func(u):
		return is_instance_valid(u) and u != unit and u.stats and u.stats.team == unit.stats.team
	)
	var aggro_range_pixels: float = unit.stats.aggro_range * CELL_SIZE.x

	var best: Node = null
	var best_dist: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == unit:
			continue
		if enemy == current_target:
			continue  # Skip current target (we're stuck on it)
		var ehp2: float = enemy.current_health if "current_health" in enemy else (enemy.stats.health if "stats" in enemy and enemy.stats else 0.0)
		if ehp2 <= 0:
			continue
		if not _is_in_aggro_range(enemy.global_position, aggro_range_pixels):
			continue

		var dist: float = unit.global_position.distance_to(enemy.global_position)
		# Check if the path to this enemy is blocked by a same-team unit in combat
		var blocked := false
		var dir_to_enemy: Vector2 = (enemy.global_position - unit.global_position).normalized()
		for ally in same_team_units:
			var to_ally: Vector2 = ally.global_position - unit.global_position
			var ally_dist: float = to_ally.length()
			if ally_dist >= dist or ally_dist < 1.0:
				continue
			# Is ally roughly in the line toward this enemy?
			if dir_to_enemy.dot(to_ally.normalized()) > 0.7:
				# Is this ally anchored (fighting)?
				var ally_ai = ally.get_node_or_null("UnitAI")
				if ally_ai and ally_ai.current_target and is_instance_valid(ally_ai.current_target):
					var ally_d: float = ally.global_position.distance_to(ally_ai.current_target.global_position)
					var ally_range: float = ally.stats.attack_range * CELL_SIZE.x
					if ally_d <= ally_range:
						blocked = true
						break

		if not blocked and dist < best_dist:
			best_dist = dist
			best = enemy

	return best


## ── Helper: find an ally that is blocking the enemy's path to its current target. ──
## Checks within 1.5× attack range in a forward cone toward the current target.
## Used so enemies commit to attacking blockers instead of trying to walk past them.
func _find_blocker_in_path() -> Node:
	if not unit.stats or unit.stats.team != UnitStats.Team.ENEMY:
		return null
	if not current_target or not is_instance_valid(current_target):
		return null

	var attack_range_px: float = unit.stats.attack_range * CELL_SIZE.x
	var blocker_range: float = attack_range_px * 1.5
	var path_dir: Vector2 = (current_target.global_position - unit.global_position).normalized()
	var target_group: String = UnitStats.TARGET[unit.stats.team]
	var allies := get_tree().get_nodes_in_group(target_group)

	var closest: Node = null
	var closest_dist: float = INF

	for ally in allies:
		if not is_instance_valid(ally) or ally == unit or ally == current_target:
			continue
		var ahp: float = ally.current_health if "current_health" in ally else (ally.stats.health if "stats" in ally and ally.stats else 0.0)
		if ahp <= 0:
			continue
		var to_ally: Vector2 = ally.global_position - unit.global_position
		var dist: float = to_ally.length()
		if dist > blocker_range or dist < 1.0:
			continue
		# Ally must be roughly in the direction toward the current target (within ~72°)
		if path_dir.dot(to_ally.normalized()) > 0.3 and dist < closest_dist:
			closest_dist = dist
			closest = ally

	return closest


## ── Helper: get a displayable name for a target (for logging) ──
func _get_target_name(target) -> String:
	if not target or not is_instance_valid(target):
		return "none"
	if target.has_meta("is_dummy_target"):
		return "[dummy]"
	if "stats" in target and target.stats:
		# Append instance ID suffix to differentiate same-name units (e.g. Orc#3 vs Orc#7)
		return "%s#%d" % [target.stats.name, target.get_instance_id() % 1000]
	return "?"


## Aggro shape multipliers — wider X for the expanded 18-tile-wide arena.
const AGGRO_X_MULTIPLIER := 2.5  ## Horizontal aggro = aggro_range × 2.5
const AGGRO_Y_MULTIPLIER_IDLE := 1.0  ## Y aggro before any ally is fighting (wait for enemies to come)
const AGGRO_Y_MULTIPLIER_COMBAT := 3.0  ## Y aggro once at least one ally engages (back-row joins in)


## Returns true if at least one PLAYER unit is currently in attack range of its target.
## Used to gate the extended Y aggro — allies wait until front-line engages.
func _is_any_ally_in_combat() -> bool:
	var allies := get_tree().get_nodes_in_group("player_units")
	for ally in allies:
		if not is_instance_valid(ally) or ally == unit:
			continue
		var ai = ally.get_node_or_null("UnitAI")
		if not ai or not ai.enabled or not ai.current_target or not is_instance_valid(ai.current_target):
			continue
		if ai.current_target.has_meta("is_dummy_target"):
			continue
		# Is this ally actually in attack range of its target?
		var dist: float = ally.global_position.distance_to(ai.current_target.global_position)
		var atk_range: float = ally.stats.attack_range * CELL_SIZE.x
		if dist <= atk_range:
			return true
	return false


## Checks if an enemy is within aggro range.
## Allies use rectangular (wide X, narrow Y). Y expands once any ally is fighting.
## Enemies use circular.
func _is_in_aggro_range(enemy_pos: Vector2, aggro_range_px: float) -> bool:
	if unit.stats.team == UnitStats.Team.PLAYER:
		var dx: float = absf(unit.global_position.x - enemy_pos.x)
		var dy: float = absf(unit.global_position.y - enemy_pos.y)
		var y_mult: float = AGGRO_Y_MULTIPLIER_COMBAT if _is_any_ally_in_combat() else AGGRO_Y_MULTIPLIER_IDLE
		return dx <= aggro_range_px * AGGRO_X_MULTIPLIER and dy <= aggro_range_px * y_mult
	else:
		var distance: float = unit.global_position.distance_to(enemy_pos)
		return distance <= aggro_range_px


## Finds the nearest enemy unit within rectangular aggro range.
func _find_nearest_enemy():
	if not unit.stats:
		return null
	
	var target_group: String = UnitStats.TARGET[unit.stats.team]
	var enemies := get_tree().get_nodes_in_group(target_group)
	
	if enemies.is_empty():
		if DEBUG_AI_VERBOSE:
			print("[AI] %s: no enemies in group '%s'" % [unit.stats.name, target_group])
		return null
	
	var nearest = null
	var nearest_distance := INF
	var aggro_range_pixels: float = unit.stats.aggro_range * CELL_SIZE.x

	# Two-pass targeting:
	# 1) Prefer enemies that still have effective HP > 0 (not yet overkilled on paper)
	# 2) Among those, pick the nearest one
	# 3) If ALL enemies are overkilled on paper, fall back to plain nearest
	var fallback_nearest = null
	var fallback_distance := INF
	var _tgt_candidates := []  ## For DEBUG_TARGETING: list of all in-range enemies

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# Skip self
		if enemy == unit:
			continue

		var distance: float = unit.global_position.distance_to(enemy.global_position)

		# Check if within rectangular aggro range (wider X, narrower Y)
		if _is_in_aggro_range(enemy.global_position, aggro_range_pixels):
			# Track plain nearest as fallback
			if distance < fallback_distance:
				fallback_distance = distance
				fallback_nearest = enemy

			# Prefer enemies that aren't already "dead on paper"
			var eff_hp: float = 999999.0
			if enemy.has_method("get_effective_health"):
				eff_hp = enemy.get_effective_health()
			if eff_hp > 0.0 and distance < nearest_distance:
				nearest_distance = distance
				nearest = enemy

			# Collect candidate info for debug
			if DEBUG_TARGETING:
				var ename = _get_target_name(enemy)
				var overkill_tag = " OVERKILL" if eff_hp <= 0.0 else ""
				_tgt_candidates.append("%s(d=%.0f,effHP=%.0f%s)" % [ename, distance, eff_hp, overkill_tag])

	# If every in-range enemy is overkilled on paper, still pick nearest
	if not nearest and fallback_nearest:
		nearest = fallback_nearest
		nearest_distance = fallback_distance
		if DEBUG_TARGETING:
			print("[TGT] %s: all candidates overkilled, fallback → %s" % [unit.stats.name, _get_target_name(fallback_nearest)])

	if DEBUG_TARGETING and _tgt_candidates.size() > 0:
		var winner_name = _get_target_name(nearest) if nearest else "NONE"
		print("[TGT] %s: _find_nearest → %s | candidates: %s" % [unit.stats.name, winner_name, ", ".join(_tgt_candidates)])

	if DEBUG_AI_VERBOSE:
		if nearest and "stats" in nearest and nearest.stats:
			print("[AI] %s: found target %s (dist=%.0fpx, aggro=%.0fpx, enemies=%d)" % [unit.stats.name, nearest.stats.name, nearest_distance, aggro_range_pixels, enemies.size()])
		else:
			print("[AI] %s: no enemy within aggro range %.0fpx (enemies=%d)" % [unit.stats.name, aggro_range_pixels, enemies.size()])

	return nearest


## Idle seek: allies are static defenders — they never roam toward the nearest
## enemy. The only idle movement is responding to an enemy that already has
## aggro on this unit (its UnitAI is targeting us, e.g. a ranged attacker).
## Returns a dummy Node2D tracking that enemy's position so the unit walks
## toward it. Reuses an existing dummy if present, frees it when nothing
## targets us anymore.
func _find_idle_seek_target():
	var target_enemy = _find_enemy_targeting_me()
	if not target_enemy:
		# Nothing is aggroed on us — drop an existing seek dummy and stay idle
		if current_target and is_instance_valid(current_target) \
				and current_target.has_meta("is_idle_seek"):
			current_target.queue_free()
			current_target = null
		return null

	# Reuse the existing dummy — just refresh its position to track the enemy
	if current_target and is_instance_valid(current_target) \
			and current_target.has_meta("is_idle_seek"):
		current_target.global_position = target_enemy.global_position
		return current_target

	var seek_dummy := Node2D.new()
	seek_dummy.global_position = target_enemy.global_position
	seek_dummy.set_meta("is_dummy_target", true)
	seek_dummy.set_meta("is_idle_seek", true)
	unit.get_tree().current_scene.add_child(seek_dummy)
	if DEBUG_AI:
		print("[AI] %s: 🧭 AGGRO RESPONSE → %s (dist=%.0fpx)" % [
			unit.stats.name, _get_target_name(target_enemy),
			unit.global_position.distance_to(target_enemy.global_position)
		])
	return seek_dummy


## Finds an enemy whose UnitAI is targeting this unit.
func _find_enemy_targeting_me():
	if not unit.stats:
		return null
	var target_group: String = UnitStats.TARGET[unit.stats.team]
	var enemies := get_tree().get_nodes_in_group(target_group)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var ai = enemy.get_node_or_null("UnitAI")
		if ai and ai.current_target == unit:
			return enemy
	return null


## Returns a dummy target representing the player base for enemy units.
## NOTE: The returned dummy node is added to the scene tree so it can be freed
## properly when the target changes (see _update_ai).
func _get_player_base_target():
	# Try to find the King and walk toward it
	var king = _find_king_unit()
	if king:
		var king_target := Node2D.new()
		king_target.global_position = king.global_position
		king_target.set_meta("is_dummy_target", true)
		unit.get_tree().current_scene.add_child(king_target)
		return king_target
	# Fallback: walk straight down
	var fallback_target := Node2D.new()
	fallback_target.global_position = Vector2(unit.global_position.x, 1000)
	fallback_target.set_meta("is_dummy_target", true)
	unit.get_tree().current_scene.add_child(fallback_target)
	return fallback_target


## Find the King unit among player units.
func _find_king_unit() -> Node:
	var player_units = unit.get_tree().get_nodes_in_group("player_units")
	for u in player_units:
		if is_instance_valid(u) and u.stats and u.stats.is_king:
			return u
	return null


## King-specific AI update: stationary ranged defender.
## Picks the closest enemy within the King's attack range and never moves to engage.
func _update_king_ai() -> void:
	var new_target := _find_enemy_in_attack_range()
	if current_target != new_target:
		if DEBUG_AI or DEBUG_TARGETING:
			var old_name := _get_target_name(current_target)
			var new_name := _get_target_name(new_target)
			print("[AI] %s: King target %s → %s" % [unit.stats.name, old_name, new_name])
		_switch_target(new_target)


## Moves towards the current target.

## Performs an attack on the target.
func _move_along_path(delta: float) -> void:
	if path.is_empty() or current_path_index >= path.size():
		path.clear()
		movement_finished.emit()
		return
	
	var target_tile := path[current_path_index]
	var target_pos := play_area.get_global_from_tile(target_tile)
	
	var direction: Vector2 = (target_pos - unit.global_position).normalized()
	var move_distance: float = movement_speed * delta
	
	if unit.global_position.distance_to(target_pos) <= move_distance:
		# Reached waypoint
		unit.global_position = target_pos
		current_path_index += 1
		
		if current_path_index >= path.size():
			path.clear()
			movement_finished.emit()
	else:
		# Move towards waypoint
		unit.global_position += direction * move_distance


## Attempts to attack the current target.
func _try_attack() -> void:
	if not current_target or not is_instance_valid(current_target):
		return
	
	if attack_timer > 0:
		return  # Still on cooldown
	
	# Don't attack dummy targets (like player base)
	if not current_target.has_meta("is_dummy_target"):
		_perform_attack(current_target)
		# Set cooldown
		if unit.stats:
			attack_timer = unit.stats.get_time_between_attacks()


## Performs an attack on the target.
func _perform_attack(target) -> void:
	if not target or not target.stats:
		return

	# Prevent unit from attacking itself
	if target == unit:
		return

	# Play attack animation
	if _animator:
		_animator.play(UnitAnimator.AnimState.ATTACK)

	# Calculate damage
	var damage: int = unit.stats.get_attack_damage()

	if DEBUG_AI:
		var target_hp = target.current_health if "current_health" in target else target.stats.health
		print("[AI] %s: ⚔ attacks %s for %d dmg (target HP: %d → %d)" % [unit.stats.name, target.stats.name, damage, int(target_hp), int(max(target_hp - damage, 0))])

	# Register incoming damage so other units don't overkill this target
	if "incoming_damage" in target:
		target.incoming_damage += damage

	# Ranged units spawn a projectile; melee units apply damage instantly
	if unit.stats and not unit.stats.is_melee():
		_spawn_basic_attack_projectile(target, damage)
	else:
		_apply_attack_damage(target, damage)

	attack_performed.emit(target)

	# Retaliation — notify the target's AI that it was attacked
	var target_ai = target.get_node_or_null("UnitAI")
	if target_ai and target_ai.has_method("notify_attacked_by"):
		target_ai.notify_attacked_by(unit)

	# Flash attacker
	_flash_unit(unit)
	# Flash target only for melee (ranged flashes on projectile hit)
	if unit.stats and unit.stats.is_melee():
		_flash_unit(target, Color.RED)

	# Spawn physical hit VFX on target (only for melee — ranged uses projectiles)
	if unit.stats and unit.stats.is_melee():
		var vfx_spawner = unit.get_tree().get_first_node_in_group("vfx_spawner")
		if vfx_spawner and vfx_spawner.has_method("spawn_vfx_on_unit"):
			vfx_spawner.spawn_vfx_on_unit("hit_physical", target)


## Spawns a basic attack projectile for ranged units.
func _spawn_basic_attack_projectile(target, damage: int) -> void:
	var ProjectileScene = load("res://scenes/projectile/projectile.tscn")
	if not ProjectileScene:
		push_warning("[AI] Could not load projectile scene — applying direct damage")
		_apply_attack_damage(target, damage)
		return

	# Use object pool if available
	var pool_nodes = unit.get_tree().get_nodes_in_group("projectile_pool")
	var projectile: Node
	if not pool_nodes.is_empty() and is_instance_valid(pool_nodes[0]):
		projectile = pool_nodes[0].acquire(ProjectileScene)
	else:
		projectile = ProjectileScene.instantiate()
		unit.get_tree().current_scene.add_child(projectile)

	projectile.global_position = unit.global_position

	# Ensure the runtime script is attached
	var proj_script = load("res://scenes/projectile/projectile.gd")
	if not projectile.has_method("setup") and proj_script:
		projectile.set_script(proj_script)

	# Determine projectile color based on unit faction
	var proj_color: Color = Color(1.0, 0.9, 0.6)  # Default golden
	if unit.stats and "faction" in unit.stats:
		match unit.stats.faction:
			UnitStats.Faction.WARRIOR:
				proj_color = Color(1.0, 0.7, 0.3)  # Orange
			UnitStats.Faction.MYSTIC:
				proj_color = Color(0.4, 0.6, 1.0)  # Blue
			UnitStats.Faction.WARDEN:
				proj_color = Color(0.3, 0.9, 0.4)  # Green

	if projectile.has_method("setup"):
		projectile.setup(unit, target, float(damage), proj_color, true)
	else:
		push_warning("[AI] Projectile missing setup() — applying direct damage")
		_apply_attack_damage(target, damage)
		if is_instance_valid(projectile):
			projectile.queue_free()


## Applies attack damage directly (melee or projectile fallback).
func _apply_attack_damage(target, damage: int) -> void:
	if UnitUtils.is_unit_node(target) and target.has_method("apply_damage"):
		# CombatResolver applies the hit, damage counters and the attacker's on-hit passives
		CombatResolver.resolve_basic_attack(unit, target, damage)
	else:
		# Fallback: adjust resource health which will emit signals
		if target.stats:
			target.stats.health = max(target.stats.health - damage, 0)


## A* pathfinding on the unit grid.
## Returns an ordered list of tiles from start to goal, avoiding occupied tiles.
## Uses Manhattan distance as heuristic (no diagonal movement).
func _find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	if not play_area or not play_area.unit_grid:
		return result

	var grid_size: Vector2i = play_area.unit_grid.size

	# If goal is out of bounds, clamp it to nearest valid tile
	var clamped_goal := Vector2i(
		clampi(goal.x, 0, grid_size.x - 1),
		clampi(goal.y, 0, grid_size.y - 1)
	)

	# If start equals goal, nothing to do
	if start == clamped_goal:
		return result

	# A* data structures
	# open_set: priority queue as Array of [f_score, tile]
	var open_set: Array = [[_heuristic(start, clamped_goal), start]]
	var came_from: Dictionary = {}  # tile -> parent tile
	var g_score: Dictionary = {start: 0}  # tile -> cost from start
	var closed_set: Dictionary = {}  # tile -> true

	# Directions: up, down, left, right (no diagonals for grid movement)
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]

	var max_iterations := grid_size.x * grid_size.y * 2  # Safety limit
	var iterations := 0

	while not open_set.is_empty() and iterations < max_iterations:
		iterations += 1

		# Find node with lowest f_score (simple linear scan — grid is small)
		var best_idx := 0
		for i in range(1, open_set.size()):
			if open_set[i][0] < open_set[best_idx][0]:
				best_idx = i

		var current_entry = open_set[best_idx]
		var current: Vector2i = current_entry[1]
		open_set.remove_at(best_idx)

		# Reached the goal — reconstruct path
		if current == clamped_goal:
			var path_tile := current
			while path_tile != start:
				result.insert(0, path_tile)
				path_tile = came_from[path_tile]
			return result

		closed_set[current] = true

		# Explore neighbors
		for dir in directions:
			var neighbor: Vector2i = current + dir

			# Bounds check
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= grid_size.x or neighbor.y >= grid_size.y:
				continue

			# Already evaluated
			if closed_set.has(neighbor):
				continue

			# Occupied check (skip goal tile — we want to path TO it even if occupied by enemy)
			if neighbor != clamped_goal:
				if play_area.unit_grid.units.has(neighbor) and play_area.unit_grid.is_tile_occupied(neighbor):
					continue

			var tentative_g: int = g_score[current] + 1

			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var f: int = tentative_g + _heuristic(neighbor, clamped_goal)
				open_set.append([f, neighbor])

	# No path found — return empty (unit will use direct movement fallback)
	return result


## Manhattan distance heuristic for A*.
func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Finds the play areas from the scene tree.
func _find_play_areas() -> void:
	# Get arena node
	var arena: Node = get_tree().get_first_node_in_group("arena")
	if not arena:
		return
	
	# Find play areas based on unit's team
	if unit.stats:
		if unit.stats.team == UnitStats.Team.PLAYER:
			play_area = arena.get_node_or_null("GameArea")
			enemy_area = arena.get_node_or_null("EnemyArea")
		else:
			play_area = arena.get_node_or_null("EnemyArea")
			enemy_area = arena.get_node_or_null("GameArea")


## Flashes a unit sprite with a color for visual feedback.
func _flash_unit(target_unit, color: Color = Color.WHITE) -> void:
	if target_unit and target_unit.has_method("flash_skin"):
		target_unit.flash_skin(color)
	else:
		# Fallback for units without flash_skin method
		if not target_unit or not target_unit.has_node("Visuals/Skin"):
			return
		
		var skin = target_unit.get_node("Visuals/Skin")
		var original_color = skin.modulate
		skin.modulate = color
		
		# Reset color after short delay
		await get_tree().create_timer(0.08).timeout
		if is_instance_valid(skin):
			skin.modulate = original_color


## Adjusts movement direction to steer around same-team units blocking the path.
## Treats teammates that are actively fighting (anchored) as hard obstacles.
func _apply_avoidance_steering(desired_dir: Vector2) -> Vector2:
	var look_ahead: float = CELL_SIZE.x * 2.5  # Check 2.5 tiles ahead
	var all_units := get_tree().get_nodes_in_group("units")

	for other_unit in all_units:
		if other_unit == unit or not is_instance_valid(other_unit) or not other_unit.stats:
			continue
		# Only avoid same-team units (don't steer around enemies)
		if other_unit.stats.team != unit.stats.team:
			continue

		var to_other: Vector2 = other_unit.global_position - unit.global_position
		var dist: float = to_other.length()
		if dist > look_ahead or dist < 1.0:
			continue

		# Is this unit roughly in the direction we're moving? (dot > 0.3 ≈ within 72°)
		var dot: float = desired_dir.dot(to_other.normalized())
		if dot > 0.3:
			# Teammate is in our path — steer perpendicular to go around
			var perpendicular: Vector2 = Vector2(-desired_dir.y, desired_dir.x)
			# Pick the side that moves AWAY from the blocking unit
			if perpendicular.dot(to_other) > 0:
				perpendicular = -perpendicular
			# Stronger avoidance when closer; teammates in combat are hard obstacles
			var avoidance_strength: float = 1.0 - (dist / look_ahead)
			var other_ai = other_unit.get_node_or_null("UnitAI")
			var other_anchored := false
			if other_ai and other_ai.current_target and is_instance_valid(other_ai.current_target):
				var other_dist_to_target: float = other_unit.global_position.distance_to(other_ai.current_target.global_position)
				var other_attack_range: float = other_unit.stats.attack_range * CELL_SIZE.x
				other_anchored = other_dist_to_target <= other_attack_range
			# Anchored teammates are hard obstacles — steer much more aggressively
			var weight: float = 1.8 if other_anchored else 1.0
			desired_dir = (desired_dir + perpendicular * avoidance_strength * weight).normalized()

	return desired_dir


## Occupancy granularity for battle movement — one visual tile.
const MOVE_TILE_PX := 32.0

## Registers this unit's tiles in the shared battle_occupancy map so other units
## can check passability before moving instead of pushing into teammates.
func _update_occupancy() -> void:
	if not is_instance_valid(_arena):
		_arena = get_tree().get_first_node_in_group("arena")
		if not _arena:
			return
	var cells := _covered_cells(unit.global_position)
	if cells == _occ_cells:
		return
	_remove_occupancy()
	_occ_cells = cells
	for c in cells:
		if not _arena.battle_occupancy.has(c):
			_arena.battle_occupancy[c] = [unit]
		else:
			_arena.battle_occupancy[c].append(unit)


func _exit_tree() -> void:
	_remove_occupancy()


func _remove_occupancy() -> void:
	if not is_instance_valid(_arena):
		return
	for c in _occ_cells:
		if not _arena.battle_occupancy.has(c):
			continue
		var list: Array = _arena.battle_occupancy[c]
		list.erase(unit)
		if list.is_empty():
			_arena.battle_occupancy.erase(c)
	_occ_cells.clear()


## All MOVE_TILE_PX tiles touched by the unit's visual box centered at `pos`.
func _covered_cells(pos: Vector2) -> Array[Vector2i]:
	var half: Vector2 = Vector2(unit.stats.tile_size) * 0.5 - Vector2.ONE
	var tl := Vector2i(((pos - half) / MOVE_TILE_PX).floor())
	var br := Vector2i(((pos + half) / MOVE_TILE_PX).floor())
	var cells: Array[Vector2i] = []
	for x in range(tl.x, br.x + 1):
		for y in range(tl.y, br.y + 1):
			cells.append(Vector2i(x, y))
	return cells


## Returns true if the unit's box at `pos` overlaps no HARD obstacle: only
## same-team units that are "anchored" (fighting a real target in range) or the
## King block movement. Moving teammates are soft — they stream past each other
## and separation keeps spacing, so the wave flow never deadlocks on density.
func _is_position_free(pos: Vector2) -> bool:
	if not is_instance_valid(_arena):
		return true
	for c in _covered_cells(pos):
		if not _arena.battle_occupancy.has(c):
			continue
		for o in _arena.battle_occupancy[c]:
			if o == unit or not is_instance_valid(o) or not o.stats:
				continue
			if o.stats.team != unit.stats.team:
				continue
			if _is_hard_obstacle(o):
				return false
	return true


## A unit is a hard obstacle when it is anchored: fighting a real target within
## its attack range, or it is the King (units must never path through him).
func _is_hard_obstacle(o: Node) -> bool:
	if o.stats.is_king:
		return true
	var o_ai = o.get_node_or_null("UnitAI")
	if not o_ai or not o_ai.current_target or not is_instance_valid(o_ai.current_target):
		return false
	if o_ai.current_target.has_meta("is_dummy_target"):
		return false
	var o_dist: float = o.global_position.distance_to(o_ai.current_target.global_position)
	var o_range: float = o.stats.attack_range * CELL_SIZE.x
	return o_dist <= o_range


## Picks a passable movement direction: steered direction first, then wider
## detours (±45°, ±90°, ±135°, reverse). Returns ZERO when boxed in — the unit
## holds position and lets the stuck timer switch target instead of endlessly
## pushing into teammates.
func _resolve_passable_direction(desired: Vector2) -> Vector2:
	if desired == Vector2.ZERO:
		return Vector2.ZERO
	var probe: float = MOVE_TILE_PX * 0.75
	var steered: Vector2 = _apply_avoidance_steering(desired)
	var dest: Vector2 = unit.global_position + steered * probe
	if _is_position_free(dest):
		return steered
	if DEBUG_MOVE and _move_log_timer <= 0:
		_move_log_timer = 1.0
		print("[MOVE] %s steered=%s blocked by: %s" % [
			unit.stats.name, steered, _describe_blockers(dest)])
	for angle in [0.7854, -0.7854, 1.5708, -1.5708, 2.3562, -2.3562]:
		var dir: Vector2 = desired.rotated(angle)
		if _is_position_free(unit.global_position + dir * probe):
			if DEBUG_MOVE and _move_log_timer <= 0:
				_move_log_timer = 1.0
				print("[MOVE] %s detour %.0fdeg → %s" % [
					unit.stats.name, rad_to_deg(angle), dir])
			return dir
	if DEBUG_MOVE and _move_log_timer <= 0:
		_move_log_timer = 1.0
		print("[MOVE] %s BOXED at %s — all detours blocked by: %s" % [
			unit.stats.name, unit.global_position,
			_describe_blockers(unit.global_position)])
	return Vector2.ZERO


## Names of living same-team units occupying the tiles covered at `pos` (debug).
## Anchored blockers are marked with *.
func _describe_blockers(pos: Vector2) -> String:
	if not is_instance_valid(_arena):
		return "no-arena"
	var names: Array[String] = []
	for c in _covered_cells(pos):
		if not _arena.battle_occupancy.has(c):
			continue
		for o in _arena.battle_occupancy[c]:
			if o != unit and is_instance_valid(o) and o.stats \
					and o.stats.team == unit.stats.team:
				var n: String = "%s%s@%s" % [
					_get_target_name(o), "*" if _is_hard_obstacle(o) else "", c]
				if not names.has(n):
					names.append(n)
	return ", ".join(names) if names.size() > 0 else "none"


## Apply separation force to avoid unit overlap.
## Units actively attacking a target are "anchored" and resist being pushed.
func _apply_separation(delta: float) -> void:
	if not unit or not unit.stats:
		return

	# ── Anchored check: if this unit is within attack range AND attacking, skip separation ──
	# This prevents fighting units from being shoved by teammates walking up behind them.
	if current_target and is_instance_valid(current_target) and not current_target.has_meta("is_dummy_target"):
		var dist_to_target: float = unit.global_position.distance_to(current_target.global_position)
		var attack_range_px: float = unit.stats.attack_range * CELL_SIZE.x
		if dist_to_target <= attack_range_px:
			return  # Anchored — don't let teammates push us off our target

	# Only apply separation to prevent perfect overlap.
	# Use a distance close to the visual tile size (32px) so units don't stack.
	var min_distance: float = 28.0
	var separation_force: float = 120.0

	var all_units = get_tree().get_nodes_in_group("units")
	var separation_vector: Vector2 = Vector2.ZERO
	var neighbor_count: int = 0

	for other_unit in all_units:
		if other_unit == unit or not is_instance_valid(other_unit) or not other_unit.stats:
			continue

		# Only separate from allies, not enemies
		if other_unit.stats.team != unit.stats.team:
			continue

		var distance: float = unit.global_position.distance_to(other_unit.global_position)
		if distance < min_distance:
			# Perfect overlap has no separation direction — push deterministically
			# by instance id so stacked units fan out instead of deadlocking.
			var direction: Vector2
			if distance > 0.1:
				direction = (unit.global_position - other_unit.global_position).normalized()
			else:
				var ang: float = float(unit.get_instance_id() % 628) / 100.0
				direction = Vector2(cos(ang), sin(ang))
			var strength: float = 1.0 - (distance / min_distance)
			separation_vector += direction * strength
			neighbor_count += 1

	if neighbor_count > 0:
		separation_vector = separation_vector.normalized()
		var push_distance: float = separation_force * delta
		unit.global_position += separation_vector * push_distance


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	# Apply computed velocity from navigation
	unit.global_position += safe_velocity * get_process_delta_time()


## Leak mechanic: when an enemy reaches the King, it stops and fights the King.
## The King fights back — this is how Legion TD works (King is a powerful defender).
## The enemy attacks the King, the King attacks the enemy. When the enemy dies,
## it's counted as killed. If the King dies, game over.
func _check_leak_to_king() -> void:
	if not unit or not is_instance_valid(unit):
		return
	if not unit.stats or unit.stats.team != UnitStats.Team.ENEMY:
		return
	var king = _find_king_unit()
	if not king or not is_instance_valid(king):
		return
	var dist_to_king: float = unit.global_position.distance_to(king.global_position)
	# When enemy is within the King's attack range, switch target to the King
	# so both fight each other through normal combat (no instant leak).
	if dist_to_king <= CELL_SIZE.x * 2.0:
		# Switch from dummy target to the actual King node
		if current_target == null or not is_instance_valid(current_target) or current_target.has_meta("is_dummy_target"):
			_switch_target(king)
			if DEBUG_AI:
				print("[AI] %s: 👑 reached King's pit — engaging King in combat" % unit.stats.name)
