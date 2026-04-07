extends Control

# --- Setup ---

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure it runs when game is paused

	# Hook up the three pause-menu buttons to their handlers
	$CenterContainer/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$CenterContainer/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	$CenterContainer/VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)

# --- Input Handling ---

# Listen for the Esc / cancel action to toggle the pause overlay
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

# --- Pause State ---

# Flips paused state and shows/hides this overlay accordingly
func toggle_pause() -> void:
	var tree = get_tree()
	tree.paused = not tree.paused
	visible = tree.paused

	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Restore mouse mode if needed (e.g. if we were capturing it for camera)
		# For this game, we mostly use visible mouse, but camera drag might capture it.
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# --- Signal Handlers ---

func _on_resume_pressed() -> void:
	toggle_pause()

# Returns to the main menu, making sure to unpause first so the new scene runs
func _on_main_menu_pressed() -> void:
	get_tree().paused = false # Unpause before changing scene
	var scene_path = "res://scenes/MainMenu.tscn"
	# In Godot 4:
	get_tree().change_scene_to_file(scene_path)

func _on_exit_pressed() -> void:
	get_tree().quit()
