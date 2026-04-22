extends Control

@onready var start_game_button = $StartGameButton
@onready var role_grid = $RoleGrid
@onready var player_slots_container = $PlayerSlots
@onready var bot_count = $"Bot Container/VBoxContainer/Bot Count and Speed/GridContainer/Bot Count/Option"
@onready var bot_speed = $"Bot Container/VBoxContainer/Bot Count and Speed/GridContainer/Bot Speed/Option"
@onready var bot_player2 = $"Bot Container/VBoxContainer/Bot Difficulty/VBoxContainer/MarginContainer/GridContainer/Player 2/Option"
@onready var bot_player3 = $"Bot Container/VBoxContainer/Bot Difficulty/VBoxContainer/MarginContainer/GridContainer/Player 3/Option"
@onready var bot_player4 = $"Bot Container/VBoxContainer/Bot Difficulty/VBoxContainer/MarginContainer/GridContainer/Player 4/Option"

var roles = [
	"Conservationist",
	"Ecotourism Manager",
	"Environmental Consultant",
	"Government",
	"Land Developer",
	"Plantation Owner",
	"Researcher",
	"Village Head",
	"Wildlife Department"
]

var role_colors = {
	"Conservationist": Color(0.725, 0.651, 0.855, 1.0),
	"Ecotourism Manager": Color(0.91, 0.922, 0.361, 1.0),
	"Environmental Consultant": Color(0.835, 0.804, 0.227, 1.0),
	"Government": Color(0.369, 0.663, 0.745, 1.0),
	"Land Developer": Color(0.859, 0.843, 0.737, 1.0),
	"Plantation Owner": Color(0.788, 0.886, 0.396, 1.0),
	"Researcher": Color(0.22, 0.714, 1.0, 1.0),
	"Village Head": Color(0.898, 0.718, 0.502, 1.0),
	"Wildlife Department": Color(1.0, 0.741, 0.349, 1.0)
}

var player_selections = [null, null, null, null]
var current_player_index = 0
var total_players = 4

var singleplayer_bot_count = 3
var bot_count_option: OptionButton = null
var bot_speed_option: OptionButton = null
var bot_speed_preset: String = "Normal"
var bot_difficulty_options: Dictionary = {}
var bot_difficulty_panels: Dictionary = {}
var bot_difficulty_by_player: Dictionary = {
	1: 2,
	2: 1,
	3: 0
}

# Stores the texture for each role so we only load it once
var role_textures: Dictionary = {}

func _ready():
	var root_vbox = $VBoxContainer
	if root_vbox:
		root_vbox.add_theme_constant_override("separation", 24)

	# Pre-load all role card images 
	_preload_role_textures()

	setup_role_buttons()
	setup_player_slots()
	if not start_game_button.pressed.is_connected(_on_start_game_pressed):
		start_game_button.pressed.connect(_on_start_game_pressed)
	update_ui()
	_refresh_player_slot_headers()
	_refresh_bot_difficulty_controls()
	_connect_bot_container_controls() 

# Loads every role's card image into memory at the start
func _preload_role_textures():
	for role in roles:
		var path = "res://assets/Role Card/%s.png" % role
		var tex = load(path)
		if tex != null:
			role_textures[role] = tex
		else:
			print("WARNING: Could not load texture for role: ", role, " at path: ", path)


# BOT
func _connect_bot_container_controls():
	bot_count_option = bot_count
	bot_speed_option = bot_speed

	if bot_count_option:
		bot_count_option.select(singleplayer_bot_count)
		bot_count_option.item_selected.connect(_on_bot_count_selected)

	if bot_speed_option:
		bot_speed_option.select(1)
		bot_speed_option.item_selected.connect(_on_bot_speed_selected)

	_connect_difficulty_option(bot_player2, 1)
	_connect_difficulty_option(bot_player3, 2)
	_connect_difficulty_option(bot_player4, 3)


# Choose Difficulty
func _connect_difficulty_option(option_node: OptionButton, player_idx: int):
	if option_node == null:
		return

	var default_diff: int = int(bot_difficulty_by_player.get(player_idx, 1))
	option_node.select(default_diff)
	option_node.item_selected.connect(_on_bot_difficulty_selected.bind(player_idx))
	bot_difficulty_options[player_idx] = option_node

	var parent_container = option_node.get_parent()
	if parent_container:
		bot_difficulty_panels[player_idx] = parent_container


#  ROLE BUTTON SETUP 
# Creates buttons AND wires up hover signals so the active player slot
# previews whichever role the mouse is currently over
func setup_role_buttons():
	var border_width = 5
	var border_radius = 5

	for role in roles:
		var button = Button.new()
		button.text = role
		button.custom_minimum_size = Vector2(150, 60)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var base_color = role_colors.get(role, Color(0.5, 0.5, 0.5))

		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = base_color
		style_normal.border_color = Color.WHITE
		style_normal.set_border_width_all(border_width)
		style_normal.set_corner_radius_all(border_radius)

		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = base_color.lightened(0.2)
		style_hover.border_color = Color.WHITE
		style_hover.set_border_width_all(border_width)
		style_hover.set_corner_radius_all(border_radius)

		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = base_color.darkened(0.2)
		style_pressed.border_color = Color.WHITE
		style_pressed.set_border_width_all(border_width)
		style_pressed.set_corner_radius_all(border_radius)

		var style_disabled = StyleBoxFlat.new()
		style_disabled.bg_color = Color(0.3, 0.3, 0.3, 0.5)
		style_disabled.border_color = Color.WHITE
		style_disabled.set_border_width_all(border_width)
		style_disabled.set_corner_radius_all(border_radius)

		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_pressed)
		button.add_theme_stylebox_override("disabled", style_disabled)
		button.add_theme_color_override("font_color", Color.BLACK)

		button.pressed.connect(_on_role_button_pressed.bind(role))

		# when mouse hovers
		button.mouse_entered.connect(_on_role_button_hovered.bind(role))
		button.mouse_exited.connect(_on_role_button_unhovered)

		role_grid.add_child(button)


# SHOW PREVIEW WHEN HOVER
# Called when mouse enters a role button
# Temporarily swaps the active player slot's card image to this role's image
func _on_role_button_hovered(role_name: String):
	if is_role_taken(role_name):
		return

	var tex = role_textures.get(role_name)
	if tex == null:
		return

	# Only preview in the active slot if it hasn't picked yet
	# If they already picked, their card stays
	# DO NOT OVERWRITE
	if player_selections[current_player_index] == null:
		var texture_rect = _get_slot_texture_rect(current_player_index)
		if texture_rect:
			texture_rect.texture = tex
			texture_rect.visible = true  # Reveal the card on hover


# RESTORE ORIGINAL WHEN UNHOVERED
# Called when mouse leaves a role button
# Puts the slot's image back to whatever role is actually selected (or blank/default)
func _on_role_button_unhovered():
	var texture_rect = _get_slot_texture_rect(current_player_index)
	if texture_rect == null:
		return

	var confirmed_role = player_selections[current_player_index]
	if confirmed_role != null:
		# They have a confirmed pick - keep their card visible and correct
		texture_rect.texture = role_textures.get(confirmed_role)
		texture_rect.visible = true
	else:
		# No confirmed pick - hide the card entirely until they hover again
		texture_rect.texture = null
		texture_rect.visible = false

#Texture rect to show player role when hovered
func _get_slot_texture_rect(slot_index: int) -> TextureRect:
	var slot = player_slots_container.get_child(slot_index)
	if slot == null:
		return null
	var tex_rect = slot.get_node_or_null("SelectButton/PlayerRole")
	if tex_rect == null:
		tex_rect = slot.get_node_or_null("PlayerRole")
	return tex_rect
	
# In case texture rect does not show
func _get_slot_role_label(slot_index: int) -> Label:
	var slot = player_slots_container.get_child(slot_index)
	if slot == null:
		return null

	var label = slot.get_node_or_null("SelectButton/RoleDisplay")
	if label == null:
		label = slot.get_node_or_null("RoleDisplay")

	return label


func setup_player_slots():
	for i in range(total_players):
		var slot = player_slots_container.get_child(i)
		var select_btn = slot.get_node("SelectButton")
		select_btn.pressed.connect(_on_player_slot_pressed.bind(i))

# count how many bot is selected
func _on_bot_count_selected(index: int):
	if bot_count_option == null:
		return
	singleplayer_bot_count = bot_count_option.get_item_id(index)
	_refresh_player_slot_headers()
	_refresh_bot_difficulty_controls()


func _on_bot_speed_selected(index: int):
	if bot_speed_option == null:
		return
	var speed_id: int = bot_speed_option.get_item_id(index)
	match speed_id:
		0:
			bot_speed_preset = "Slow"
		2:
			bot_speed_preset = "Fast"
		_:
			bot_speed_preset = "Normal"


func _on_bot_difficulty_selected(index: int, player_index: int):
	var option = bot_difficulty_options.get(player_index)
	if option == null:
		return
	var difficulty_id: int = option.get_item_id(index)
	bot_difficulty_by_player[player_index] = difficulty_id


func _refresh_bot_difficulty_controls():
	for player_idx in range(1, total_players):
		var option = bot_difficulty_options.get(player_idx)
		if option == null:
			continue
		var disabled: bool = player_idx > singleplayer_bot_count
		option.disabled = disabled

		var panel = bot_difficulty_panels.get(player_idx)
		if panel != null:
			panel.modulate = Color(1, 1, 1, 0.5) if disabled else Color(1, 1, 1, 1)


func _build_active_bot_difficulty_map() -> Dictionary:
	var result: Dictionary = {}
	for player_idx in range(1, total_players):
		if player_idx > singleplayer_bot_count:
			continue
		result[player_idx] = int(bot_difficulty_by_player.get(player_idx, 1))
	return result


func _refresh_player_slot_headers():
	for i in range(total_players):
		var slot = player_slots_container.get_child(i)
		var label = slot.get_node_or_null("SelectButton/Label")
		if label == null:
			continue
		if i == 0:
			label.text = "Player 1 (You)"
		elif i <= singleplayer_bot_count:
			label.text = "Player %d (Bot)" % [i + 1]
		else:
			label.text = "Player %d" % [i + 1]


# ---- ROLE BUTTON PRESSED ----
# Confirms the selection - card stays locked to this role from now on
func _on_role_button_pressed(role_name: String):
	if is_role_taken(role_name):
		return
	player_selections[current_player_index] = role_name

	# Lock the card image in - it will stay visible permanently now
	var texture_rect = _get_slot_texture_rect(current_player_index)
	if texture_rect and role_textures.has(role_name):
		texture_rect.texture = role_textures[role_name]
		texture_rect.visible = true

	advance_turn()
	update_ui()


func _on_player_slot_pressed(player_idx: int):
	current_player_index = player_idx
	update_ui()


func advance_turn():
	var next_idx = -1
	for i in range(total_players):
		var check_idx = (current_player_index + 1 + i) % total_players
		if player_selections[check_idx] == null:
			next_idx = check_idx
			break
	if next_idx != -1:
		current_player_index = next_idx


func is_role_taken(role_name) -> bool:
	for r in player_selections:
		if r == role_name:
			return true
	return false


func update_ui():
	for i in range(total_players):
		var slot = player_slots_container.get_child(i)
		var role_label = _get_slot_role_label(i)
		var style = slot.get_theme_stylebox("panel")
		if style == null:
			style = StyleBoxFlat.new()
			slot.add_theme_stylebox_override("panel", style)

		if i == current_player_index:
			style = style.duplicate()
			style.border_width_bottom = 4
			style.border_color = Color(1, 0.84, 0)
			style.bg_color = Color(0.82, 0.71, 0.55, 0.9)
			slot.add_theme_stylebox_override("panel", style)
		else:
			style = style.duplicate()
			style.border_width_bottom = 0
			style.bg_color = Color(0.25, 0.15, 0.05, 0.6)
			style.bg_color = Color(0.25, 0.15, 0.05, 0.6)
			slot.add_theme_stylebox_override("panel", style)

		if role_label == null:
			role_label = slot.get_node_or_null("SelectButton/RoleDisplay")
		if role_label == null:
			continue

		if player_selections[i]:
			role_label.text = player_selections[i]
			role_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05))
		else:
			role_label.text = "Select..."
			role_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

		# Drive card visibility purely from confirmed selection state
		# Hover is handled separately by _on_role_button_hovered/unhovered
		var texture_rect = _get_slot_texture_rect(i)
		if texture_rect:
			var confirmed = player_selections[i]
			if confirmed != null and role_textures.has(confirmed):
				# Confirmed pick - show their card
				texture_rect.texture = role_textures[confirmed]
				texture_rect.visible = true
			else:
				# No pick yet - hide unless the hover logic is currently showing a preview
				# We only hide if it's NOT the active slot being hovered over
				# (hover functions manage visibility for the active slot themselves)
				if i != current_player_index:
					texture_rect.texture = null
					texture_rect.visible = false
				# If i == current_player_index, leave it alone - hover controls it

	for btn in role_grid.get_children():
		btn.disabled = is_role_taken(btn.text)

	var all_selected = player_selections.all(func(r): return r != null)
	start_game_button.disabled = not all_selected

# start game and set values to card table
func _on_start_game_pressed():
	var card_table_scene = load("res://scenes/CardTable.tscn")
	var card_table = card_table_scene.instantiate()

	if "player_roles" in card_table:
		card_table.player_roles = player_selections
	else:
		card_table.player_role = player_selections[0]

	if "singleplayer_bot_count" in card_table:
		card_table.singleplayer_bot_count = singleplayer_bot_count
	if "human_player_index" in card_table:
		card_table.human_player_index = 0
	if "bot_speed_preset" in card_table:
		card_table.bot_speed_preset = bot_speed_preset
	if "bot_difficulty_by_player" in card_table:
		card_table.bot_difficulty_by_player = _build_active_bot_difficulty_map()

	get_tree().root.add_child(card_table)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = card_table
