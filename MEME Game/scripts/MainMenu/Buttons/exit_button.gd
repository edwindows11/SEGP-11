## Script for the Exit button on the Main Menu.
## Closes the game when clicked.
extends Button

func _ready():
	pressed.connect(_on_pressed)

## Quits the game.
func _on_pressed():
	get_tree().quit()
