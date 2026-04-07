extends Button

# --- Setup ---

func _ready():
	# Wire the button's built-in pressed signal to our handler
	pressed.connect(_on_pressed)

# --- Signal Handlers ---

# Start button leads into the scenario selection screen
func _on_pressed():
	get_tree().change_scene_to_file("res://scenes/ScenarioSelect.tscn")
