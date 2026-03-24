extends Control

signal card_activated(card_id: String)
signal end_turn_requested()

const CARD_SCENE = preload("res://scenes/Card.tscn")
const TOTAL_CARDS = 5
const CARD_SPACING = 200.0
const BOTTOM_MARGIN = 50.0

const PLAYER_DISPLAY_SCENE = preload("res://scenes/PlayerDisplay.tscn")

@onready var cards_container = $CardsContainer
@onready var players_container = $TopBar/PlayersContainer
@onready var user_role_label = $UserRoleLabel
@onready var end_turn_button = $TopBar/EndTurnButton
@onready var timer_label = $TopBar/TimerLabel
@onready var turn_timer = $TurnTimer
@onready var placement_options = $TopBar/PlacementMode

var player_role: String = "Unknown"
var time_left = 60
var cards_played_this_turn = 0
var pending_card: Control = null
var instruction_label: Label = null

# Conservationist Tracker UI
var cons_tracker_panel: PanelContainer = null
var cons_green_label: Label = null
var cons_forest_label: Label = null
var cons_status_label: Label = null

# Village Head Tracker UI
var vh_tracker_panel: PanelContainer = null
var vh_cards_label: Label = null
var vh_pop_label: Label = null
var vh_status_label: Label = null

# Plantation Owner Tracker UI
var po_tracker_panel: PanelContainer = null
var po_cards_label: Label = null
var po_plant_label: Label = null
var po_status_label: Label = null

func _ready():
	# NOTE: spawn_cards() and spawn_players() are called from card_table.gd
	# after GameState.player_roles and the deck are initialized.

	if user_role_label:
		user_role_label.text = "My Role: " + player_role

	# IMPORTANT: Do NOT connect end_turn_button.pressed here.
	# The scene has it wired to card_table.gd._on_end_turn_button_pressed already.
	# Connecting again here would double-fire the handler.

	turn_timer.timeout.connect(_on_timer_timeout)
	get_tree().root.size_changed.connect(_on_window_resize)

	# Add instruction banner (shown when player must select a tile)
	var banner = PanelContainer.new()
	banner.name = "_instruction_banner"
	banner.visible = false
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 60
	banner.offset_left = -300
	banner.offset_right = 300

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	banner.add_theme_stylebox_override("panel", style)

	instruction_label = Label.new()
	instruction_label.add_theme_font_size_override("font_size", 28)
	instruction_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner.add_child(instruction_label)
	add_child(banner)

	# Container for all chosen role trackers
	var right_margin = MarginContainer.new()
	right_margin.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right_margin.offset_left = -250
	right_margin.offset_right = -20
	right_margin.offset_top = -300
	right_margin.offset_bottom = 300
	right_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var trackers_vbox = VBoxContainer.new()
	trackers_vbox.add_theme_constant_override("separation", 15)
	trackers_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	trackers_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_margin.add_child(trackers_vbox)
	add_child(right_margin)

	# Add Conservationist tracker
	cons_tracker_panel = PanelContainer.new()
	cons_tracker_panel.name = "_cons_tracker_panel"
	cons_tracker_panel.visible = false
	
	var tracker_style = StyleBoxFlat.new()
	tracker_style.bg_color = Color(0.1, 0.3, 0.1, 0.8) # Dark green transparent
	tracker_style.corner_radius_top_left = 10
	tracker_style.corner_radius_bottom_left = 10
	tracker_style.corner_radius_top_right = 10
	tracker_style.corner_radius_bottom_right = 10
	tracker_style.content_margin_left = 15
	tracker_style.content_margin_right = 15
	tracker_style.content_margin_top = 15
	tracker_style.content_margin_bottom = 15
	cons_tracker_panel.add_theme_stylebox_override("panel", tracker_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	cons_tracker_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Conservationist Goal"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	cons_green_label = Label.new()
	cons_green_label.text = "Green Cards: 0 / 4"
	cons_green_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(cons_green_label)
	
	cons_forest_label = Label.new()
	cons_forest_label.text = "Forest Increase: 0 / 2"
	cons_forest_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(cons_forest_label)
	
	cons_status_label = Label.new()
	cons_status_label.text = "In Progress"
	cons_status_label.add_theme_font_size_override("font_size", 16)
	cons_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Yellow
	cons_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cons_status_label)
	
	trackers_vbox.add_child(cons_tracker_panel)

	# Add Village Head tracker
	vh_tracker_panel = PanelContainer.new()
	vh_tracker_panel.name = "_vh_tracker_panel"
	vh_tracker_panel.visible = false
	
	var vh_tracker_style = StyleBoxFlat.new()
	vh_tracker_style.bg_color = Color(0.3, 0.1, 0.1, 0.8) # Dark red transparent
	vh_tracker_style.corner_radius_top_left = 10
	vh_tracker_style.corner_radius_bottom_left = 10
	vh_tracker_style.corner_radius_top_right = 10
	vh_tracker_style.corner_radius_bottom_right = 10
	vh_tracker_style.content_margin_left = 15
	vh_tracker_style.content_margin_right = 15
	vh_tracker_style.content_margin_top = 15
	vh_tracker_style.content_margin_bottom = 15
	vh_tracker_panel.add_theme_stylebox_override("panel", vh_tracker_style)
	
	var vh_vbox = VBoxContainer.new()
	vh_vbox.add_theme_constant_override("separation", 10)
	vh_tracker_panel.add_child(vh_vbox)
	
	var vh_title = Label.new()
	vh_title.text = "Village Head Goal"
	vh_title.add_theme_font_size_override("font_size", 18)
	vh_title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	vh_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vh_vbox.add_child(vh_title)
	
	vh_cards_label = Label.new()
	vh_cards_label.text = "Action Cards: 0 / 7"
	vh_cards_label.add_theme_font_size_override("font_size", 16)
	vh_vbox.add_child(vh_cards_label)
	
	vh_pop_label = Label.new()
	vh_pop_label.text = "Population: 0 / 16"
	vh_pop_label.add_theme_font_size_override("font_size", 16)
	vh_vbox.add_child(vh_pop_label)
	
	vh_status_label = Label.new()
	vh_status_label.text = "In Progress"
	vh_status_label.add_theme_font_size_override("font_size", 16)
	vh_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Yellow
	vh_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vh_vbox.add_child(vh_status_label)
	
	trackers_vbox.add_child(vh_tracker_panel)

	# Add Plantation Owner tracker
	po_tracker_panel = PanelContainer.new()
	po_tracker_panel.name = "_po_tracker_panel"
	po_tracker_panel.visible = false
	
	var po_tracker_style = StyleBoxFlat.new()
	po_tracker_style.bg_color = Color(0.3, 0.25, 0.1, 0.8) # Brown
	po_tracker_style.corner_radius_top_left = 10
	po_tracker_style.corner_radius_bottom_left = 10
	po_tracker_style.corner_radius_top_right = 10
	po_tracker_style.corner_radius_bottom_right = 10
	po_tracker_style.content_margin_left = 15
	po_tracker_style.content_margin_right = 15
	po_tracker_style.content_margin_top = 15
	po_tracker_style.content_margin_bottom = 15
	po_tracker_panel.add_theme_stylebox_override("panel", po_tracker_style)
	
	var po_vbox = VBoxContainer.new()
	po_vbox.add_theme_constant_override("separation", 10)
	po_tracker_panel.add_child(po_vbox)
	
	var po_title = Label.new()
	po_title.text = "Plantation Owner Goal"
	po_title.add_theme_font_size_override("font_size", 18)
	po_title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	po_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	po_vbox.add_child(po_title)
	
	po_cards_label = Label.new()
	po_cards_label.text = "Cards: 0G, 0R, 0Y / 2G, 1R, 1Y"
	po_cards_label.add_theme_font_size_override("font_size", 16)
	po_vbox.add_child(po_cards_label)
	
	po_plant_label = Label.new()
	po_plant_label.text = "Plantations: 0 / 2"
	po_plant_label.add_theme_font_size_override("font_size", 16)
	po_vbox.add_child(po_plant_label)
	
	po_status_label = Label.new()
	po_status_label.text = "In Progress"
	po_status_label.add_theme_font_size_override("font_size", 16)
	po_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	po_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	po_vbox.add_child(po_status_label)
	
	trackers_vbox.add_child(po_tracker_panel)

func _process(delta: float) -> void:
	if cons_tracker_panel: cons_tracker_panel.visible = false
	if vh_tracker_panel: vh_tracker_panel.visible = false
	if po_tracker_panel: po_tracker_panel.visible = false
	
	var cons_index = GameState.player_roles.find("Conservationist")
	if cons_index != -1:
		if cons_tracker_panel: cons_tracker_panel.visible = true
		var greens_played = GameState.player_stats[cons_index]["green_cards_played"]
		var forest_increase = GameState.get_forest_increase()
		
		cons_green_label.text = "Green Cards: " + str(greens_played) + " / 4"
		cons_forest_label.text = "Forest Increase: " + str(forest_increase) + " / 2"
		
		if greens_played >= 4 and forest_increase >= 2:
			if cons_status_label.text != "GOAL MET!":
				cons_status_label.text = "GOAL MET!"
				cons_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Bright green
		else:
			if cons_status_label.text != "In Progress":
				cons_status_label.text = "In Progress"
				cons_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Yellow

	var vh_index = GameState.player_roles.find("Village Head")
	if vh_index != -1:
		if vh_tracker_panel: vh_tracker_panel.visible = true
		var actions_played = GameState.player_stats[vh_index]["action_cards_played"]
		var current_pop = GameState.get_total_villagers()
		
		vh_cards_label.text = "Action Cards: " + str(actions_played) + " / 7"
		vh_pop_label.text = "Population: " + str(current_pop) + " / 16"
		
		if actions_played >= 7 and current_pop >= 16:
			if vh_status_label.text != "GOAL MET!":
				vh_status_label.text = "GOAL MET!"
				vh_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Bright green
		else:
			if vh_status_label.text != "In Progress":
				vh_status_label.text = "In Progress"
				vh_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Yellow

	var po_index = GameState.player_roles.find("Plantation Owner")
	if po_index != -1:
		if po_tracker_panel: po_tracker_panel.visible = true
		var stats = GameState.player_stats[po_index]
		var g = stats.get("green_cards_played", 0)
		var r = stats.get("red_cards_played", 0)
		var y = stats.get("yellow_cards_played", 0)
		var p = GameState.get_plantation_increase()
		
		po_cards_label.text = "Cards: %dG, %dR, %dY / 2G, 1R, 1Y" % [g, r, y]
		po_plant_label.text = "Plantations: %d / 2" % p
		
		if g >= 2 and r >= 1 and y >= 1 and p >= 2:
			if po_status_label.text != "GOAL MET!":
				po_status_label.text = "GOAL MET!"
				po_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			if po_status_label.text != "In Progress":
				po_status_label.text = "In Progress"
				po_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

func _on_window_resize() -> void:
	reposition_cards()

func reposition_cards() -> void:
	var screen_size = get_viewport_rect().size

	# Exclude nodes already queued for deletion (played card may still be pending free)
	var cards = []
	for c in cards_container.get_children():
		if not c.is_queued_for_deletion():
			cards.append(c)

	var total_current_cards = cards.size()

	if total_current_cards == 0:
		return

	var start_x = (screen_size.x - (float(total_current_cards) - 1) * CARD_SPACING) / 2.0

	for i in range(total_current_cards):
		var card = cards[i]
		if card == pending_card:
			continue

		var card_width = card.custom_minimum_size.x
		var x_pos = start_x + (i * CARD_SPACING) - (card_width / 2.0)
		var y_pos = screen_size.y - card.custom_minimum_size.y - BOTTOM_MARGIN

		card.position = Vector2(x_pos, y_pos)
		card.original_position = card.position

func _on_timer_timeout():
	time_left -= 1
	if time_left < 0:
		end_turn_requested.emit()  # card_table.gd handles the actual turn-end logic
	else:
		timer_label.text = str(time_left)


# --- Player display ---

func spawn_players() -> void:
	# Clear previous
	for child in players_container.get_children():
		child.queue_free()

	# Show other players using GameState roles (skip index 0 = current player)
	var roles = GameState.player_roles
	for i in range(1, GameState.player_count):
		var player = PLAYER_DISPLAY_SCENE.instantiate()
		players_container.add_child(player)
		var role_name = roles[i] if i < roles.size() else "Unknown"
		player.setup("Player " + str(i + 1), role_name)


# --- Card hand management ---

func spawn_cards() -> void:
	# Clear existing cards
	for child in cards_container.get_children():
		child.queue_free()
	pending_card = null

	var hand = GameState.player_hands[GameState.current_player_index]
	for card_id in hand:
		var card = CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.set_card_data(card_id)
		card.card_selected.connect(_on_card_selected)

	call_deferred("reposition_cards")

func remove_played_card_and_draw_replacement() -> void:
	if pending_card:
		pending_card.queue_free()
		pending_card = null

	# Draw a replacement card from the deck
	var new_card_id = GameState.draw_card(GameState.current_player_index)
	if new_card_id != "":
		var card = CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.set_card_data(new_card_id)
		card.card_selected.connect(_on_card_selected)
		call_deferred("reposition_cards")

func _on_card_selected(selected_card) -> void:
	if cards_played_this_turn >= 1:
		print("Cannot play more than 1 card per turn!")
		return

	# Verify card is still in this player's hand
	if not (selected_card.card_id in GameState.player_hands[GameState.current_player_index]):
		return

	cards_played_this_turn += 1
	pending_card = selected_card

	# Move selected card to center
	var screen_size = get_viewport_rect().size
	var target_pos = (screen_size - selected_card.custom_minimum_size) / 2.0

	selected_card.z_index = 10

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(selected_card, "position", target_pos, 0.5)
	tween.tween_property(selected_card, "scale", Vector2(1.5, 1.5), 0.5)

	# Disable end turn until effects resolve
	end_turn_button.disabled = true

	# Trigger effect execution in card_table.gd
	card_activated.emit(selected_card.card_id)


# --- Turn management ---

func _on_turn_changed(player_index: int, role_name: String) -> void:
	# Update whose-turn label
	if user_role_label:
		user_role_label.text = "Player " + str(player_index + 1) + " (" + role_name + ")"

	# Reset timer
	time_left = 60
	if timer_label:
		timer_label.text = str(time_left)

	cards_played_this_turn = 0
	end_turn_button.disabled = false

	# Redraw hand for new current player
	spawn_cards()


# --- Instruction label (shown during tile selection) ---

func show_instruction(text: String) -> void:
	if instruction_label:
		instruction_label.text = text
		instruction_label.get_parent().visible = true

func hide_instruction() -> void:
	if instruction_label:
		instruction_label.get_parent().visible = false
