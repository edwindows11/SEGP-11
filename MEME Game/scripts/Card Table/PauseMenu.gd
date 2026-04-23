## Shows Resume / Main Menu / Exit buttons.
## Opens with the Pause button or the Esc key. While paused, tree.paused is
## true so the rest of the game stops updating.
extends Control

func _ready() -> void:
	visible = false
	# Keep running while the game is paused so buttons stay clickable.
	process_mode = Node.PROCESS_MODE_ALWAYS

	$CenterContainer/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$CenterContainer/VBoxContainer/MainMenuButton.pressed.connect(_on_main_menu_pressed)
	$CenterContainer/VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)

## Listens for the Esc key to toggle the pause menu.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

## Turns the pause menu on or off and pauses / unpauses the game.
## When opening, it also closes the Played Cards overlay so its PanelContainer
## doesn't cover the Resume button and swallow clicks.
func toggle_pause() -> void:
	var tree = get_tree()
	tree.paused = not tree.paused
	visible = tree.paused

	if visible:
		# Close any UI overlay that would render on top of the pause menu		
		var ui = get_parent()
		if ui and ui.has_method("_close_recent_cards_overlay"):
			ui._close_recent_cards_overlay()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Restore mouse mode if needed
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## Closes the pause menu and resumes the game.
func _on_resume_pressed() -> void:
	toggle_pause()

## Resets the game and goes back to the Main Menu.
func _on_main_menu_pressed() -> void:
	get_tree().paused = false # Unpause before changing scene
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

## Closes the whole game.
func _on_exit_pressed() -> void:
	get_tree().quit()
