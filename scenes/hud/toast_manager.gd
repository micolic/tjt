class_name ToastManager
extends CanvasLayer

## Simple toast notification system.
## Shows temporary messages at the top-center of the screen.
## Used for permadeath notifications and other gameplay events.

const DEFAULT_DURATION: float = 2.5
const DEFAULT_COLOR: Color = Color(1.0, 0.85, 0.4)
const DEATH_COLOR: Color = Color(1.0, 0.35, 0.35)

@onready var _container: VBoxContainer = $VBoxContainer


func _ready() -> void:
	add_to_group("toast_manager")
	if not _container:
		# Build container dynamically if scene doesn't have one
		_container = VBoxContainer.new()
		_container.name = "VBoxContainer"
		_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_container.position = Vector2(get_viewport().get_visible_rect().size.x / 2.0 - 150, 80)
		_container.size = Vector2(300, 0)
		_container.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(_container)


func show_toast(
		message: String, duration: float = DEFAULT_DURATION, color: Color = DEFAULT_COLOR) -> void:
	var label := Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_container.add_child(label)

	# Fade-in/out tween
	label.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.2)
	tween.chain().tween_interval(duration)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(label.queue_free)
