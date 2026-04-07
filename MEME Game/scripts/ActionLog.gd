extends VBoxContainer

# --- Setup ---

func _ready():
	# Seed the log with sample entries so it isn't empty on game start
	add_action("+1 elephant", true)
	add_action("-2 villagers", false)

# --- Log Entry API ---

# Append a coloured log line; green for positive actions, red for negative
func add_action(text: String, is_positive: bool):
	var label = Label.new() #create label to show cards played by user
	label.text = "-> " + text

	if is_positive:
		label.add_theme_color_override("font_color", Color.GREEN)
	else:
		label.add_theme_color_override("font_color", Color.RED)

	label.add_theme_font_size_override("font_size", 20)

	add_child(label)

	# Optional: Limit number of log entries
	# Drop the oldest entry once we exceed the cap so the log doesn't grow forever
	if get_child_count() > 5:
		get_child(0).queue_free()
