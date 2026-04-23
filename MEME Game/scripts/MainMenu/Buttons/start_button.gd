## Script for the Start button on the Main Menu.
## Opens the Scenario Select scene when clicked.
extends Button

func _ready():
	pressed.connect(_on_pressed)

## Switches to the Scenario Select screen to start a new game.
func _on_pressed():
	get_tree().change_scene_to_file("res://scenes/ScenarioSelect.tscn")
