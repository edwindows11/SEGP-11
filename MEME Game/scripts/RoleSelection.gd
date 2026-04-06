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
	"Plantation Owner",
	"Researcher",
	"Village Head",
	"Wildlife Department"
]
 
var player_selections = [null, null, null, null] # Array to store role for 4 players
var current_player_index = 0 # 0 to 3
var total_players = 4

var singleplayer_bot_count = 3
var bot_count_option: OptionButton = null
var bot_speed_option: OptionButton = null
var bot_speed_preset: String = "Normal"
var bot_difficulty_options: Dictionary = {}
var bot_difficulty_panels: Dictionary = {}
var bot_difficulty_by_player: Dictionary = {
	1: 2, # Player 2 starts as HARD
	2: 1, # Player 3 starts as MEDIUM
	3: 0  # Player 4 starts as EASY
}
 
func _ready():
	var root_vbox = $VBoxContainer
	if root_vbox:
		root_vbox.add_theme_constant_override("separation", 24)

	setup_role_buttons()
	setup_player_slots()
	_setup_singleplayer_bot_count_controls()
	if not start_game_button.pressed.is_connected(_on_start_game_pressed):
		start_game_button.pressed.connect(_on_start_game_pressed)
	update_ui()
	_refresh_player_slot_headers()
	_refresh_bot_difficulty_controls()
 
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

func _setup_singleplayer_bot_count_controls():
	var root_vbox = $VBoxContainer
	if root_vbox == null:
		return
	var role_grid_node = root_vbox.get_node_or_null("RoleGrid")
	var insert_index: int = role_grid_node.get_index() if role_grid_node else root_vbox.get_child_count()

	var settings_panel := PanelContainer.new()
	settings_panel.name = "BotSettingsPanel"
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_panel.custom_minimum_size = Vector2(0, 240)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.11, 0.08, 0.86)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(0.42, 0.32, 0.24, 0.95)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	settings_panel.add_theme_stylebox_override("panel", panel_style)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 18)
	outer_margin.add_theme_constant_override("margin_right", 18)
	outer_margin.add_theme_constant_override("margin_top", 14)
	outer_margin.add_theme_constant_override("margin_bottom", 14)
	settings_panel.add_child(outer_margin)

	var settings_vbox := VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 14)
	outer_margin.add_child(settings_vbox)

	var title := Label.new()
	title.text = "Bot Match Settings"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Player 1 stays human. Configure bot count, speed, and each bot difficulty."
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.78, 0.68))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_vbox.add_child(subtitle)

	bot_count_option = OptionButton.new()
	bot_count_option.name = "BotCountOption"
	bot_count_option.custom_minimum_size = Vector2(220, 40)
	bot_count_option.add_item("0 Bots (Hotseat)", 0)
	bot_count_option.add_item("1 Bot", 1)
	bot_count_option.add_item("2 Bots", 2)
	bot_count_option.add_item("3 Bots", 3)
	bot_count_option.select(singleplayer_bot_count)
	bot_count_option.item_selected.connect(_on_bot_count_selected)

	bot_speed_option = OptionButton.new()
	bot_speed_option.name = "BotSpeedOption"
	bot_speed_option.custom_minimum_size = Vector2(220, 40)
	bot_speed_option.add_item("Slow", 0)
	bot_speed_option.add_item("Normal", 1)
	bot_speed_option.add_item("Fast", 2)
	bot_speed_option.select(1)
	bot_speed_option.item_selected.connect(_on_bot_speed_selected)

	var top_grid := GridContainer.new()
	top_grid.columns = 2
	top_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_grid.add_theme_constant_override("h_separation", 18)
	top_grid.add_theme_constant_override("v_separation", 8)
	top_grid.add_child(_make_bot_setting_block("Bot Count", bot_count_option))
	top_grid.add_child(_make_bot_setting_block("Bot Speed", bot_speed_option))
	settings_vbox.add_child(top_grid)

	var diff_title := Label.new()
	diff_title.text = "Per-Bot Difficulty"
	diff_title.add_theme_font_size_override("font_size", 20)
	diff_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	settings_vbox.add_child(diff_title)

	var diff_grid := GridContainer.new()
	diff_grid.columns = 3
	diff_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_grid.add_theme_constant_override("h_separation", 14)
	diff_grid.add_theme_constant_override("v_separation", 10)
	settings_vbox.add_child(diff_grid)

	for player_idx in range(1, total_players):
		var diff_panel := PanelContainer.new()
		diff_panel.name = "BotDifficultyPanel_%d" % [player_idx + 1]
		diff_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diff_panel.custom_minimum_size = Vector2(0, 88)

		var diff_panel_style := StyleBoxFlat.new()
		diff_panel_style.bg_color = Color(0.22, 0.16, 0.11, 0.8)
		diff_panel_style.corner_radius_top_left = 8
		diff_panel_style.corner_radius_top_right = 8
		diff_panel_style.corner_radius_bottom_left = 8
		diff_panel_style.corner_radius_bottom_right = 8
		diff_panel_style.border_width_bottom = 1
		diff_panel_style.border_width_top = 1
		diff_panel_style.border_width_left = 1
		diff_panel_style.border_width_right = 1
		diff_panel_style.border_color = Color(0.43, 0.33, 0.24, 0.85)
		diff_panel.add_theme_stylebox_override("panel", diff_panel_style)

		var diff_margin := MarginContainer.new()
		diff_margin.add_theme_constant_override("margin_left", 10)
		diff_margin.add_theme_constant_override("margin_right", 10)
		diff_margin.add_theme_constant_override("margin_top", 8)
		diff_margin.add_theme_constant_override("margin_bottom", 8)
		diff_panel.add_child(diff_margin)

		var diff_vbox := VBoxContainer.new()
		diff_vbox.add_theme_constant_override("separation", 6)
		diff_margin.add_child(diff_vbox)

		var diff_label := Label.new()
		diff_label.text = "Player %d Bot" % [player_idx + 1]
		diff_label.add_theme_font_size_override("font_size", 17)
		diff_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
		diff_vbox.add_child(diff_label)

		var diff_option := OptionButton.new()
		diff_option.name = "BotDifficultyOption_%d" % [player_idx + 1]
		diff_option.custom_minimum_size = Vector2(0, 34)
		diff_option.add_item("Easy", 0)
		diff_option.add_item("Medium", 1)
		diff_option.add_item("Hard", 2)
		var default_diff: int = int(bot_difficulty_by_player.get(player_idx, 1))
		diff_option.select(default_diff)
		diff_option.item_selected.connect(_on_bot_difficulty_selected.bind(player_idx))
		diff_vbox.add_child(diff_option)

		bot_difficulty_options[player_idx] = diff_option
		bot_difficulty_panels[player_idx] = diff_panel
		diff_grid.add_child(diff_panel)

	root_vbox.add_child(settings_panel)
	root_vbox.move_child(settings_panel, insert_index)

func _make_bot_setting_block(title_text: String, control: Control) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86))
	block.add_child(title)

	block.add_child(control)
	return block

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
			if disabled:
				panel.modulate = Color(1.0, 1.0, 1.0, 0.5)
			else:
				panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

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
		var label = slot.get_node_or_null("Label")
		if label == null:
			continue
		if i == 0:
			label.text = "Player 1 (You)"
		elif i <= singleplayer_bot_count:
			label.text = "Player %d (Bot)" % [i + 1]
		else:
			label.text = "Player %d" % [i + 1]
 
func _on_role_button_pressed(role_name: String):
	if is_role_taken(role_name):
		return
	player_selections[current_player_index] = role_name
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
		var role_label = slot.get_node("RoleDisplay")
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
			slot.add_theme_stylebox_override("panel", style)
		if player_selections[i]:
			role_label.text = player_selections[i]
			role_label.add_theme_color_override("font_color", Color(0.25, 0.15, 0.05))
		else:
			role_label.text = "Select..."
			role_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	for btn in role_grid.get_children():
		var role_name = btn.text
		if is_role_taken(role_name):
			btn.disabled = true
		else:
			btn.disabled = false
	var all_selected = true
	for r in player_selections:
		if r == null:
			all_selected = false
			break
	start_game_button.disabled = not all_selected
 
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
