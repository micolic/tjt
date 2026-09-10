class_name LoadingScreen
extends CanvasLayer

## Loading screen with random gameplay tips.
## Usage: LoadingScreen.transition_to(scene_path) from anywhere.

const TIPS: Array[String] = [
	"Place melee units at the front to absorb damage for your ranged allies.",
	"Clerics heal nearby allies — keep them safe behind your frontline.",
	"Acolytes deal AoE damage with ember bolts. Protect them from flanking enemies.",
	"Units won't target enemies far above or below them — position wisely.",
	"Sell units you don't need to earn gold for stronger replacements.",
	"Enemies get stronger each wave — upgrade your army between rounds.",
	"Grunt is a tough frontliner that gets faster as HP drops. Great for holding chokepoints.",
	"Watch for overkill — your units avoid wasting damage on dying enemies.",
	"Use the prep phase to reposition your units before the next wave.",
	"Ranged units attack from a distance but have less health. Guard them.",
]

## Minimum time the loading screen stays visible (seconds).
const MIN_DISPLAY_TIME := 0.8

@onready var tip_label: Label = $Panel/VBoxContainer/TipLabel
@onready var loading_label: Label = $Panel/VBoxContainer/LoadingLabel

var _target_scene: String = ""
var _elapsed: float = 0.0
var _scene_ready: bool = false

## Static helper: creates a loading screen, adds it to tree, and transitions.
static func transition_to(tree: SceneTree, scene_path: String) -> void:
	var screen_scene: PackedScene = load("res://scenes/menu/loading_screen.tscn")
	var screen = screen_scene.instantiate()
	screen._target_scene = scene_path
	tree.root.add_child(screen)


func _ready() -> void:
	# Show random tip
	tip_label.text = TIPS[randi() % TIPS.size()]

	# Start loading the target scene in background
	if _target_scene != "":
		ResourceLoader.load_threaded_request(_target_scene)


func _process(delta: float) -> void:
	_elapsed += delta

	# Animate dots on "Loading..."
	var dots := ".".repeat(int(_elapsed * 3.0) % 4)
	loading_label.text = "Loading" + dots

	# Check if resource is loaded
	if not _scene_ready and _target_scene != "":
		var status := ResourceLoader.load_threaded_get_status(_target_scene)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_scene_ready = true
		elif status == ResourceLoader.THREAD_LOAD_FAILED \
				or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			# Fallback: direct load
			push_warning("[LoadingScreen] Threaded load failed, using direct change_scene_to_file.")
			get_tree().change_scene_to_file(_target_scene)
			queue_free()
			return

	# Switch once both time and load are ready
	if _scene_ready and _elapsed >= MIN_DISPLAY_TIME:
		var packed: PackedScene = ResourceLoader.load_threaded_get(_target_scene)
		get_tree().change_scene_to_packed(packed)
		queue_free()
