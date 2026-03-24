extends Panel

var icon = null:
	set(value):
		icon = value
		$TextureButton.texture_normal = value
		
signal pressed

func _ready():
	$Select.hide()
	
func _button_pressed() -> void:
	for slot in get_parent().get_children():
		slot.deselect()
		
	$Select.show()
	pressed.emit()

func deselect():
	$Select.hide()
