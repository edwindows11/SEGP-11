extends Control
 
@onready var start_game_button = $VBoxContainer/StartGameButton
@onready var role_grid = $VBoxContainer/RoleGrid
@onready var player_slots_container = $VBoxContainer/PlayerSlots
 
var roles = [
	"Conservationist",
	"Ecotourism Manager",
	"Environmental Consultant",
	"Government",
	"Land Developer",
	"Plantation",
	"Researcher",
	"Village Head",
	"Wildfire Department"
]
 
var player_selections = [null, null, null, null] # Array to store role for 4 players
var current_player_index = 0 # 0 to 3
var total_players = 4
 
func _ready():
	setup_role_buttons()
	setup_player_slots()
	start_game_button.pressed.connect(_on_start_game_pressed)
	update_ui()
 
func setup_role_buttons():
	for role in roles:
		var button = Button.new()
		button.text = role
		button.custom_minimum_size = Vector2(150, 60)
		button.size_flags_horizontal = 3
		button.size_flags_vertical = 3
		
		# styling
		# Normal Style (Safari Tan/Khaki)
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.82, 0.71, 0.55) # Tan
		style_normal.border_width_bottom = 4
		style_normal.border_color = Color(0.55, 0.47, 0.36) # Darker Tan shadow
		style_normal.corner_radius_top_left = 5
		style_normal.corner_radius_top_right = 5
		style_normal.corner_radius_bottom_right = 5
		style_normal.corner_radius_bottom_left = 5
		
		# Hover Style (Sunset Orange/Gold)
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.96, 0.64, 0.38) # Sandy Orange
		style_hover.border_color = Color(1, 0.84, 0) # Gold Highlight
		
		# Disabled Style (Grayed out)
		var style_disabled = StyleBoxFlat.new()
		style_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.5)
		
		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_normal)
		button.add_theme_stylebox_override("disabled", style_disabled)
		
		button.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05)) # Dark Brown text
		
		button.pressed.connect(_on_role_button_pressed.bind(role))
		role_grid.add_child(button)
 
func setup_player_slots():
	for i in range(total_players):
		var slot = player_slots_container.get_child(i)
		var select_btn = slot.get_node("SelectButton")
		select_btn.pressed.connect(_on_player_slot_pressed.bind(i))
 
func _on_role_button_pressed(role_name: String):
	# Assign role to current player
	# Check if role is already taken by someone else (should be handled by button disable state, but good to be safe)
	if is_role_taken(role_name):
		return
 
	# If current player already had a role, we are replacing it
	player_selections[current_player_index] = role_name
	
	# Auto-advance to next empty slot or stay if all filled manually
	advance_turn()
	update_ui()
 
func _on_player_slot_pressed(player_idx: int):
	current_player_index = player_idx
	update_ui()
 
func advance_turn():
	# Find next player without a role
	var next_idx = -1
	for i in range(total_players):
		var check_idx = (current_player_index + 1 + i) % total_players
		if player_selections[check_idx] == null:
			next_idx = check_idx
			break
	
	if next_idx != -1:
		current_player_index = next_idx
	# If everyone has a role, stay on current (or do nothing)
 
func is_role_taken(role_name) -> bool:
	for r in player_selections:
		if r == role_name:
			return true
	return false
 
func update_ui():
	# Update Player Slots
	for i in range(total_players):
		var slot = player_slots_container.get_child(i)
		var role_label = slot.get_node("RoleDisplay")
		
		# Style based on selection
		var style = slot.get_theme_stylebox("panel")
		if style == null:
			style = StyleBoxFlat.new()
			slot.add_theme_stylebox_override("panel", style)
		
		# Highlight current player
		if i == current_player_index:
			style = style.duplicate() # Unique instance
			style.border_width_bottom = 4
			style.border_color = Color(1, 0.84, 0) # Gold highlight
			style.bg_color = Color(0.82, 0.71, 0.55, 0.9) # Tan opaque
			slot.add_theme_stylebox_override("panel", style)
		else:
			style = style.duplicate()
			style.border_width_bottom = 0
			style.bg_color = Color(0.25, 0.15, 0.05, 0.6) # Dark Brown transparent
			slot.add_theme_stylebox_override("panel", style)
 
		if player_selections[i]:
			role_label.text = player_selections[i]
			role_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05)) # Dark Brown
		else:
			role_label.text = "Select..."
			role_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
 
	# Update Role Buttons
	for btn in role_grid.get_children():
		var role_name = btn.text
		if is_role_taken(role_name):
			btn.disabled = true
			# Optional: check if it's the CURRENT player's role, maybe highlight it?
		else:
			btn.disabled = false
 
	# Check for Start Game
	var all_selected = true
	for r in player_selections:
		if r == null:
			all_selected = false
			break
	
	start_game_button.disabled = not all_selected
 
func _on_start_game_pressed():
	# print("Starting with roles: ", player_selections)
	var card_table_scene = load("res://scenes/CardTable.tscn")
	var card_table = card_table_scene.instantiate()
	
	# Pass the role data - Assuming CardTable script updated to handle array or we just pass P1 for now
	# The user request implies 4 players playing. 
	# CardTable currently has a single property 'player_role'. 
	# We should update CardTable to accept the list or just the local player's role if it's hotseat. 
	# Since full multiplayer logic isn't requested, let's assume we pass Player 1's role as the "Main" view
	# OR update card_table to simple print/store them.
	
	if "player_roles" in card_table:
		card_table.player_roles = player_selections
	else:
		# Fallback to existing single property logic so it doesn't crash
		# Assuming we play as Player 1
		card_table.player_role = player_selections[0] 
	
	get_tree().root.add_child(card_table)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = card_table
