## Closes the game when clicked.
extends Button

func _ready():
	pressed.connect(_on_pressed)

## Quits the game.
func _on_pressed():
	get_tree().quit()
