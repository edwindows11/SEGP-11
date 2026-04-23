## Opens the How To Play scene when clicked.
extends Button

func _ready():
	pressed.connect(_on_pressed)

## Switches to the How To Play scene.
func _on_pressed():
	get_tree().change_scene_to_file("res://scenes/How to Play.tscn")
