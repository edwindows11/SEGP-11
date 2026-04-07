extends Button

# --- Setup ---

func _ready():
	pressed.connect(_on_pressed)

# --- Signal Handlers ---

# Switches to the How To Play / tutorial scene
func _on_pressed():
	get_tree().change_scene_to_file("res://scenes/How to Play.tscn")
