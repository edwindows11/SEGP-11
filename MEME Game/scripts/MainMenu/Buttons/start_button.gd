extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	get_tree().change_scene_to_file("res://scenes/RoleSelection.tscn")


func _on_button_mouse_entered():
	scale = Vector2(1.05, 1.05)


func _on_button_mouse_exited():
	scale = Vector2(1, 1)


func _on_button_pressed() -> void:
	$"../../../HowToPlay".visible = false
