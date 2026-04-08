extends Control

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure it runs when game is paused

	$CenterContainer/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$CenterContainer/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	$CenterContainer/VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

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

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false # Unpause before changing scene
	var scene_path = "res://scenes/MainMenu.tscn"
	# In Godot 4:
	get_tree().change_scene_to_file(scene_path)

func _on_exit_pressed() -> void:
	get_tree().quit()
