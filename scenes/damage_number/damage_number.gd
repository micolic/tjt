extends Control
class_name DamageNumber

## Floating damage number that animates upward and fades out

@export var float_speed: float = 50.0
@export var lifetime: float = 1.0
@export var spread: float = 20.0

@onready var label: Label = $Label

var velocity: Vector2
var elapsed_time: float = 0.0
var base_scale: float = 1.0  # Set by setup() before _ready()


func _ready() -> void:
	# Random horizontal spread
	velocity = Vector2(randf_range(-spread, spread), -float_speed)
	
	# Start fully visible
	modulate.a = 1.0
	
	# Scale up slightly at start for impact (using base_scale)
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * base_scale * 1.2, 0.1)
	tween.tween_property(self, "scale", Vector2.ONE * base_scale, 0.1)


func _process(delta: float) -> void:
	elapsed_time += delta
	
	# Move upward
	position += velocity * delta
	
	# Slow down over time
	velocity = velocity.lerp(Vector2.ZERO, delta * 2.0)
	
	# Fade out
	var fade_start = lifetime * 0.5
	if elapsed_time > fade_start:
		var fade_progress = (elapsed_time - fade_start) / (lifetime - fade_start)
		modulate.a = 1.0 - fade_progress
	
	# Delete when lifetime expires
	if elapsed_time >= lifetime:
		queue_free()


## Setup the damage number with a value and optional color
func setup(damage_value: float, color: Color = Color.WHITE) -> void:
	if not label:
		label = $Label
	
	label.text = str(int(damage_value))
	label.modulate = color
	
	# Bigger text for bigger damage
	if damage_value >= 100:
		base_scale = 1.5
	elif damage_value >= 50:
		base_scale = 1.3
	else:
		base_scale = 1.0
