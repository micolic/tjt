class_name UnitAnimator
extends Node

## Procedural animation controller for units.
## Provides idle, walk, attack, and death animations using tweens on the Skin node.
## When sprite_frames are available on the unit's stats, it swaps the Sprite2D
## for an AnimatedSprite2D and plays named animations instead.

enum AnimState { IDLE, WALK, ATTACK, DEATH }

const IDLE_BOB_AMOUNT := 1.5       ## Pixels to bob up/down during idle
const IDLE_BOB_SPEED := 1.5        ## Full bob cycles per second
const WALK_BOB_AMOUNT := 2.5       ## Pixels to bob during walk
const WALK_BOB_SPEED := 4.0        ## Full bob cycles per second while walking
const WALK_TILT_DEGREES := 5.0     ## Lean angle while walking
const ATTACK_LUNGE_PX := 6.0       ## Pixels to lunge forward on attack
const ATTACK_SQUASH_X := 1.3       ## Horizontal squash on attack wind-up
const ATTACK_SQUASH_Y := 0.75      ## Vertical squash on attack wind-up
const ATTACK_DURATION := 0.15      ## Seconds for the attack animation
const DEATH_DURATION := 0.4        ## Seconds for the death animation
const DEATH_SPIN_DEGREES := 90.0   ## Rotation on death
const DEATH_JUMP_PX := 12.0        ## Upward jump on death before falling

var current_state: AnimState = AnimState.IDLE
var skin: Node2D  ## Either Sprite2D or AnimatedSprite2D
var visuals: Node2D  ## Parent "Visuals" CanvasGroup
var _base_offset: Vector2  ## Original skin offset
var _base_scale: Vector2   ## Original visuals scale
var _idle_time: float = 0.0
var _walk_time: float = 0.0
var _attack_tween: Tween
var _death_tween: Tween
var _using_sprite_frames: bool = false
var _is_dead: bool = false

signal death_animation_finished


func setup(p_skin: Node2D, p_visuals: Node2D) -> void:
	skin = p_skin
	visuals = p_visuals
	_base_offset = skin.offset if skin is Sprite2D else Vector2.ZERO
	_base_scale = visuals.scale
	_using_sprite_frames = skin is AnimatedSprite2D


func _process(delta: float) -> void:
	if not skin or not is_instance_valid(skin) or _is_dead:
		return

	match current_state:
		AnimState.IDLE:
			_process_idle(delta)
		AnimState.WALK:
			_process_walk(delta)


func play(state: AnimState) -> void:
	if _is_dead:
		return

	if state == current_state and state != AnimState.ATTACK:
		return

	var _old_state := current_state
	current_state = state

	if _using_sprite_frames:
		_play_sprite_frames_animation(state)
		return

	match state:
		AnimState.IDLE:
			_start_idle()
		AnimState.WALK:
			_start_walk()
		AnimState.ATTACK:
			_start_attack()
		AnimState.DEATH:
			_start_death()


## Returns true if the death animation is playing or finished.
func is_dead() -> bool:
	return _is_dead


## Overrides the captured base scale (used when the unit's visual scale changes).
func set_base_scale(new_scale: Vector2) -> void:
	_base_scale = new_scale


## Overrides the captured base offset (used when set_stats changes skin.offset
## after the animator has already been set up in _ready).
func set_base_offset(new_offset: Vector2) -> void:
	_base_offset = new_offset


# ── Sprite Frames path (used when real spritesheets are available) ──

func _play_sprite_frames_animation(state: AnimState) -> void:
	var anim_sprite := skin as AnimatedSprite2D
	var anim_name: String
	match state:
		AnimState.IDLE:
			anim_name = "idle"
			# Ensure procedural timers are reset when switching to idle
			_start_idle()
		AnimState.WALK:
			anim_name = "walk"
			_start_walk()
		AnimState.ATTACK:
			anim_name = "attack"
			# Make sure any procedural attack tweens are cleared when using sprite frames
			_kill_attack_tween()
		AnimState.DEATH:
			anim_name = "death"
			_is_dead = true

	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		# Reset the sprite playback speed to the default in case it was modified elsewhere
		anim_sprite.speed_scale = 1.0
		anim_sprite.play(anim_name)
		if state == AnimState.DEATH:
			if not anim_sprite.animation_finished.is_connected(_on_sprite_death_finished):
				anim_sprite.animation_finished.connect(_on_sprite_death_finished, CONNECT_ONE_SHOT)
	else:
		# Fallback to procedural if animation name is missing
		_using_sprite_frames = false
		play(state)


func _on_sprite_death_finished() -> void:
	death_animation_finished.emit()


# ── Procedural idle ──

func _start_idle() -> void:
	_idle_time = 0.0
	_kill_attack_tween()
	# Reset any walk tilt
	if skin:
		skin.rotation = 0.0


func _process_idle(_delta: float) -> void:
	_idle_time += _delta
	# Wrap to avoid float precision issues over long sessions
	if _idle_time > 1000.0:
		_idle_time = fmod(_idle_time, 1.0 / IDLE_BOB_SPEED)
	var bob := sin(_idle_time * IDLE_BOB_SPEED * TAU) * IDLE_BOB_AMOUNT
	if skin is Sprite2D:
		skin.offset.y = _base_offset.y + bob
	else:
		skin.position.y = bob


# ── Procedural walk ──

func _start_walk() -> void:
	_walk_time = 0.0
	_kill_attack_tween()


func _process_walk(_delta: float) -> void:
	_walk_time += _delta
	var bob: float = abs(sin(_walk_time * WALK_BOB_SPEED * TAU)) * WALK_BOB_AMOUNT
	var tilt: float = sin(_walk_time * WALK_BOB_SPEED * TAU) * deg_to_rad(WALK_TILT_DEGREES)
	if skin is Sprite2D:
		skin.offset.y = _base_offset.y - bob
	else:
		skin.position.y = -bob
	skin.rotation = tilt


# ── Procedural attack ──

func _start_attack() -> void:
	_kill_attack_tween()
	_attack_tween = create_tween()
	_attack_tween.set_ease(Tween.EASE_OUT)
	_attack_tween.set_trans(Tween.TRANS_BACK)

	# Wind-up: squash + lunge forward
	_attack_tween.tween_property(visuals, "scale",
		Vector2(_base_scale.x * ATTACK_SQUASH_X, _base_scale.y * ATTACK_SQUASH_Y),
		ATTACK_DURATION * 0.4)
	_attack_tween.parallel().tween_property(skin, "offset:x" if skin is Sprite2D else "position:x",
		(_base_offset.x if skin is Sprite2D else 0.0) + ATTACK_LUNGE_PX * _get_facing_sign(),
		ATTACK_DURATION * 0.4)

	# Strike: snap back
	_attack_tween.tween_property(visuals, "scale", _base_scale, ATTACK_DURATION * 0.6)
	_attack_tween.parallel().tween_property(skin, "offset:x" if skin is Sprite2D else "position:x",
		_base_offset.x if skin is Sprite2D else 0.0,
		ATTACK_DURATION * 0.6)

	_attack_tween.tween_callback(func():
		if not _is_dead:
			current_state = AnimState.IDLE
			_idle_time = 0.0
	)


# ── Procedural death ──

func _start_death() -> void:
	_is_dead = true
	_kill_attack_tween()
	_death_tween = create_tween()
	_death_tween.set_ease(Tween.EASE_IN)
	_death_tween.set_trans(Tween.TRANS_QUAD)

	# Jump up
	var jump_prop: String = "offset:y" if skin is Sprite2D else "position:y"
	var base_y: float = _base_offset.y if skin is Sprite2D else 0.0
	_death_tween.tween_property(skin, jump_prop, base_y - DEATH_JUMP_PX, DEATH_DURATION * 0.4)
	_death_tween.parallel().tween_property(
			skin, "rotation", deg_to_rad(DEATH_SPIN_DEGREES), DEATH_DURATION)
	_death_tween.parallel().tween_property(skin, "modulate:a", 0.0, DEATH_DURATION)

	# Fall down
	_death_tween.tween_property(skin, jump_prop, base_y + 4.0, DEATH_DURATION * 0.6)

	_death_tween.tween_callback(func():
		death_animation_finished.emit()
	)


# ── Helpers ──

func _get_facing_sign() -> float:
	if not skin:
		return 1.0
	return -1.0 if skin.flip_h else 1.0


func _kill_attack_tween() -> void:
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	_attack_tween = null
	# Restore scale and position in case tween was interrupted mid-squash
	if visuals:
		visuals.scale = _base_scale
	if skin:
		if skin is Sprite2D:
			skin.offset.x = _base_offset.x
		else:
			skin.position.x = 0.0


func cleanup() -> void:
	_is_dead = true
	if _attack_tween and _attack_tween.is_valid():
		_attack_tween.kill()
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
