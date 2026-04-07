extends Button

# --- Setup ---

func _ready():
	pressed.connect(_on_pressed)

# --- Signal Handlers ---

# Quits the application entirely
func _on_pressed():
	get_tree().quit()
