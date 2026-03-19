extends VBoxContainer

func _ready():
	# Example data
	add_action("+1 elephant", true)
	add_action("-2 villagers", false)

func add_action(text: String, is_positive: bool):
	var label = Label.new()
	label.text = "-> " + text
	
	if is_positive:
		label.add_theme_color_override("font_color", Color.GREEN)
	else:
		label.add_theme_color_override("font_color", Color.RED)
	
	label.add_theme_font_size_override("font_size", 20)
	
	add_child(label)
	
	# Optional: Limit number of log entries
	if get_child_count() > 5:
		get_child(0).queue_free()
