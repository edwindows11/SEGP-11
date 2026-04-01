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
@onready var play_btn = $PlayCard

var player_role: String = "Unknown"
var time_left = 60
var cards_played_this_turn = 0
var pending_card: Control = null
var instruction_label: Label = null
var play_card: bool = true
var currently_viewing_card: bool = false

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

# Land Developer Tracker UI
var ld_tracker_panel: PanelContainer = null
var ld_cards_label: Label = null
var ld_human_label: Label = null
var ld_status_label: Label = null

# Environmental Consultant Tracker UI
var ec_tracker_panel: PanelContainer = null
var ec_cards_label: Label = null
var ec_vacant_label: Label = null
var ec_status_label: Label = null

# Ecotourism Manager Tracker UI
var em_tracker_panel: PanelContainer = null
var em_cards_label: Label = null
var em_elephants_label: Label = null
var em_status_label: Label = null

# Wildfire Department Tracker UI
var wd_tracker_panel: PanelContainer = null
var wd_cards_label: Label = null
var wd_elephants_label: Label = null
var wd_status_label: Label = null

# Researcher Tracker UI
var res_tracker_panel: PanelContainer = null
var res_cards_label: Label = null
var res_tiles_label: Label = null
var res_status_label: Label = null

# Winning Screen
var win_screen_panel: PanelContainer = null
var win_screen_label: Label = null
var is_game_over: bool = false

# Steal popup
var steal_popup: PanelContainer = null

func _ready():
	# NOTE: spawn_cards() and spawn_players() are called from card_table.gd
	# after GameState.player_roles and the deck are initialized.
	play_btn.disabled = true
	play_btn.pressed.connect(_on_play_btn_pressed)
	if user_role_label:
		user_role_label.text = "My Role: " + player_role

	# IMPORTANT: Do NOT connect end_turn_button.pressed here.
	# The scene has it wired to card_table.gd._on_end_turn_button_pressed already.
	# Connecting again here would double-fire the handler.

	turn_timer.timeout.connect(_on_timer_timeout)
	get_tree().root.size_changed.connect(_on_window_resize)
	
	if placement_options:
		placement_options.visible = false


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
	right_margin.offset_left = -350
	right_margin.offset_right = -120
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

	# Add Land Developer tracker
	ld_tracker_panel = PanelContainer.new()
	ld_tracker_panel.name = "_ld_tracker_panel"
	ld_tracker_panel.visible = false
	
	var ld_tracker_style = StyleBoxFlat.new()
	ld_tracker_style.bg_color = Color(0.1, 0.1, 0.3, 0.8) # Dark blue/urban
	ld_tracker_style.corner_radius_top_left = 10
	ld_tracker_style.corner_radius_bottom_left = 10
	ld_tracker_style.corner_radius_top_right = 10
	ld_tracker_style.corner_radius_bottom_right = 10
	ld_tracker_style.content_margin_left = 15
	ld_tracker_style.content_margin_right = 15
	ld_tracker_style.content_margin_top = 15
	ld_tracker_style.content_margin_bottom = 15
	ld_tracker_panel.add_theme_stylebox_override("panel", ld_tracker_style)
	
	var ld_vbox = VBoxContainer.new()
	ld_vbox.add_theme_constant_override("separation", 10)
	ld_tracker_panel.add_child(ld_vbox)
	
	var ld_title = Label.new()
	ld_title.text = "Land Developer Goal"
	ld_title.add_theme_font_size_override("font_size", 18)
	ld_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	ld_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ld_vbox.add_child(ld_title)
	
	ld_cards_label = Label.new()
	ld_cards_label.text = "Cards: 0G, 0R, 0Y / (2G+2R) or (2Y+2R)"
	ld_cards_label.add_theme_font_size_override("font_size", 16)
	ld_vbox.add_child(ld_cards_label)
	
	ld_human_label = Label.new()
	ld_human_label.text = "Human Areas: 0 / 2"
	ld_human_label.add_theme_font_size_override("font_size", 16)
	ld_vbox.add_child(ld_human_label)
	
	ld_status_label = Label.new()
	ld_status_label.text = "In Progress"
	ld_status_label.add_theme_font_size_override("font_size", 16)
	ld_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	ld_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ld_vbox.add_child(ld_status_label)
	
	trackers_vbox.add_child(ld_tracker_panel)

	# Add Environmental Consultant tracker
	ec_tracker_panel = PanelContainer.new()
	ec_tracker_panel.name = "_ec_tracker_panel"
	ec_tracker_panel.visible = false
	var ec_style = ld_tracker_style.duplicate()
	ec_style.bg_color = Color(0.2, 0.4, 0.2, 0.8) # Dark greenish
	ec_tracker_panel.add_theme_stylebox_override("panel", ec_style)
	var ec_vbox = VBoxContainer.new()
	ec_vbox.add_theme_constant_override("separation", 10)
	ec_tracker_panel.add_child(ec_vbox)
	var ec_title = Label.new()
	ec_title.text = "Environmental Consultant"
	ec_title.add_theme_font_size_override("font_size", 18)
	ec_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	ec_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ec_vbox.add_child(ec_title)
	ec_cards_label = Label.new()
	ec_cards_label.text = "Cards: 0G, 0R / 2G, 2R"
	ec_cards_label.add_theme_font_size_override("font_size", 16)
	ec_vbox.add_child(ec_cards_label)
	ec_vacant_label = Label.new()
	ec_vacant_label.text = "Vacant Goals Met: 0 / 2"
	ec_vacant_label.add_theme_font_size_override("font_size", 16)
	ec_vbox.add_child(ec_vacant_label)
	ec_status_label = Label.new()
	ec_status_label.text = "In Progress"
	ec_status_label.add_theme_font_size_override("font_size", 16)
	ec_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	ec_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ec_vbox.add_child(ec_status_label)
	trackers_vbox.add_child(ec_tracker_panel)

	# Add Ecotourism Manager tracker
	em_tracker_panel = PanelContainer.new()
	em_tracker_panel.name = "_em_tracker_panel"
	em_tracker_panel.visible = false
	var em_style = ld_tracker_style.duplicate()
	em_style.bg_color = Color(0.1, 0.5, 0.5, 0.8) # Teal
	em_tracker_panel.add_theme_stylebox_override("panel", em_style)
	var em_vbox = VBoxContainer.new()
	em_vbox.add_theme_constant_override("separation", 10)
	em_tracker_panel.add_child(em_vbox)
	var em_title = Label.new()
	em_title.text = "Ecotourism Manager"
	em_title.add_theme_font_size_override("font_size", 18)
	em_title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.9))
	em_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	em_vbox.add_child(em_title)
	em_cards_label = Label.new()
	em_cards_label.text = "Cards: 0G, 0Y / 3G, 2Y"
	em_cards_label.add_theme_font_size_override("font_size", 16)
	em_vbox.add_child(em_cards_label)
	em_elephants_label = Label.new()
	em_elephants_label.text = "Elephants / Dist: No / <3"
	em_elephants_label.add_theme_font_size_override("font_size", 16)
	em_vbox.add_child(em_elephants_label)
	em_status_label = Label.new()
	em_status_label.text = "In Progress"
	em_status_label.add_theme_font_size_override("font_size", 16)
	em_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	em_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	em_vbox.add_child(em_status_label)
	trackers_vbox.add_child(em_tracker_panel)

	# Add Wildfire Department tracker
	wd_tracker_panel = PanelContainer.new()
	wd_tracker_panel.name = "_wd_tracker_panel"
	wd_tracker_panel.visible = false
	var wd_style = ld_tracker_style.duplicate()
	wd_style.bg_color = Color(0.6, 0.2, 0.0, 0.8) # Burnt orange
	wd_tracker_panel.add_theme_stylebox_override("panel", wd_style)
	var wd_vbox = VBoxContainer.new()
	wd_vbox.add_theme_constant_override("separation", 10)
	wd_tracker_panel.add_child(wd_vbox)
	var wd_title = Label.new()
	wd_title.text = "Wildfire Department"
	wd_title.add_theme_font_size_override("font_size", 18)
	wd_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	wd_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wd_vbox.add_child(wd_title)
	wd_cards_label = Label.new()
	wd_cards_label.text = "Green Cards: 0 / 4"
	wd_cards_label.add_theme_font_size_override("font_size", 16)
	wd_vbox.add_child(wd_cards_label)
	wd_elephants_label = Label.new()
	wd_elephants_label.text = "Forest Elephants: 0 / 4"
	wd_elephants_label.add_theme_font_size_override("font_size", 16)
	wd_vbox.add_child(wd_elephants_label)
	wd_status_label = Label.new()
	wd_status_label.text = "In Progress"
	wd_status_label.add_theme_font_size_override("font_size", 16)
	wd_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	wd_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wd_vbox.add_child(wd_status_label)
	trackers_vbox.add_child(wd_tracker_panel)

	# Add Researcher tracker
	res_tracker_panel = PanelContainer.new()
	res_tracker_panel.name = "_res_tracker_panel"
	res_tracker_panel.visible = false
	var res_style = ld_tracker_style.duplicate()
	res_style.bg_color = Color(0.4, 0.1, 0.5, 0.8) # Purple
	res_tracker_panel.add_theme_stylebox_override("panel", res_style)
	var res_vbox = VBoxContainer.new()
	res_vbox.add_theme_constant_override("separation", 10)
	res_tracker_panel.add_child(res_vbox)
	var res_title = Label.new()
	res_title.text = "Researcher"
	res_title.add_theme_font_size_override("font_size", 18)
	res_title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_vbox.add_child(res_title)
	res_cards_label = Label.new()
	res_cards_label.text = "+Ele|+Hum|+Both: 0/0/0"
	res_cards_label.add_theme_font_size_override("font_size", 16)
	res_vbox.add_child(res_cards_label)
	res_tiles_label = Label.new()
	res_tiles_label.text = "Separation: >= 2 tiles"
	res_tiles_label.add_theme_font_size_override("font_size", 16)
	res_vbox.add_child(res_tiles_label)
	res_status_label = Label.new()
	res_status_label.text = "In Progress"
	res_status_label.add_theme_font_size_override("font_size", 16)
	res_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	res_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_vbox.add_child(res_status_label)
	trackers_vbox.add_child(res_tracker_panel)

	# Add winning screen
	win_screen_panel = PanelContainer.new()
	win_screen_panel.name = "_win_screen_panel"
	win_screen_panel.visible = false
	win_screen_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_screen_panel.z_index = 100
	
	var win_style = StyleBoxFlat.new()
	win_style.bg_color = Color(0, 0, 0, 0.85)
	win_screen_panel.add_theme_stylebox_override("panel", win_style)
	
	var win_vbox = VBoxContainer.new()
	win_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	win_screen_panel.add_child(win_vbox)
	
	win_screen_label = Label.new()
	win_screen_label.text = "PLAYER X WON!"
	win_screen_label.add_theme_font_size_override("font_size", 64)
	win_screen_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	win_screen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_vbox.add_child(win_screen_label)
	
	add_child(win_screen_panel)

func _process(delta: float) -> void:
	if is_game_over:
		return
		
	if cons_tracker_panel: cons_tracker_panel.visible = false
	if vh_tracker_panel: vh_tracker_panel.visible = false
	if po_tracker_panel: po_tracker_panel.visible = false
	if ld_tracker_panel: ld_tracker_panel.visible = false
	if ec_tracker_panel: ec_tracker_panel.visible = false
	if em_tracker_panel: em_tracker_panel.visible = false
	if wd_tracker_panel: wd_tracker_panel.visible = false
	if res_tracker_panel: res_tracker_panel.visible = false
	
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
				_trigger_win(cons_index, "Conservationist")
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
				_trigger_win(vh_index, "Village Head")
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
				_trigger_win(po_index, "Plantation Owner")
		else:
			if po_status_label.text != "In Progress":
				po_status_label.text = "In Progress"
				po_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

	var ld_index = GameState.player_roles.find("Land Developer")
	if ld_index != -1:
		if ld_tracker_panel: ld_tracker_panel.visible = true
		var stats = GameState.player_stats[ld_index]
		var g = stats.get("green_cards_played", 0)
		var r = stats.get("red_cards_played", 0)
		var y = stats.get("yellow_cards_played", 0)
		var h = GameState.get_human_increase()
		
		ld_cards_label.text = "Cards: %dG, %dR, %dY / (2G+2R) or (2Y+2R)" % [g, r, y]
		ld_human_label.text = "Human Areas: %d / 2" % h
		
		var cond1 = (g >= 2 and r >= 2)
		var cond2 = (y >= 2 and r >= 2)
		var cards_met = cond1 or cond2
		
		if cards_met and h >= 2:
			if ld_status_label.text != "GOAL MET!":
				ld_status_label.text = "GOAL MET!"
				ld_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
				_trigger_win(ld_index, "Land Developer")
		else:
			if ld_status_label.text != "In Progress":
				ld_status_label.text = "In Progress"
				ld_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

	var ec_index = GameState.player_roles.find("Environmental Consultant")
	if ec_index != -1:
		if ec_tracker_panel: ec_tracker_panel.visible = true
		var stats = GameState.player_stats[ec_index]
		var g = stats.get("green_cards_played", 0)
		var r = stats.get("red_cards_played", 0)
		var met = GameState.count_vacant_secondary_met()
		
		ec_cards_label.text = "Cards: %dG, %dR / 2G, 2R" % [g, r]
		ec_vacant_label.text = "Vacant Goals Met: %d / 2" % met
		
		if g >= 2 and r >= 2 and met >= 2:
			if ec_status_label.text != "GOAL MET!":
				ec_status_label.text = "GOAL MET!"
				ec_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
				_trigger_win(ec_index, "Environmental Consultant")
		else:
			if ec_status_label.text != "In Progress":
				ec_status_label.text = "In Progress"
				ec_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

	var em_index = GameState.player_roles.find("Ecotourism Manager")
	if em_index != -1:
		if em_tracker_panel: em_tracker_panel.visible = true
		var stats = GameState.player_stats[em_index]
		var g = stats.get("green_cards_played", 0)
		var y = stats.get("yellow_cards_played", 0)
		var dist = GameState.get_shortest_distance_human_elephant()
		
		var total_e = 0
		for key in GameState.tile_registry:
			if GameState.tile_registry[key]["elephant_nodes"].size() > 0:
				total_e += 1
				
		em_cards_label.text = "Cards: %dG, %dY / 3G, 2Y" % [g, y]
		em_elephants_label.text = "Elephants / Dist: %s / %d" % ["Yes" if total_e > 0 else "No", dist]
		
		if g >= 3 and y >= 2 and total_e > 0 and dist >= 3:
			if em_status_label.text != "GOAL MET!":
				em_status_label.text = "GOAL MET!"
				em_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
				_trigger_win(em_index, "Ecotourism Manager")
		else:
			if em_status_label.text != "In Progress":
				em_status_label.text = "In Progress"
				em_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

	var wd_index = GameState.player_roles.find("Wildfire Department")
	if wd_index != -1:
		if wd_tracker_panel: wd_tracker_panel.visible = true
		var stats = GameState.player_stats[wd_index]
		var g = stats.get("green_cards_played", 0)
		var e_forest = GameState.get_elephants_in_forest()
		
		wd_cards_label.text = "Green Cards: %d / 4" % g
		wd_elephants_label.text = "Forest Elephants: %d / 4" % e_forest
		
		if g >= 4 and e_forest >= 4:
			if wd_status_label.text != "GOAL MET!":
				wd_status_label.text = "GOAL MET!"
				wd_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
				_trigger_win(wd_index, "Wildfire Department")
		else:
			if wd_status_label.text != "In Progress":
				wd_status_label.text = "In Progress"
				wd_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

	var res_index = GameState.player_roles.find("Researcher")
	if res_index != -1:
		if res_tracker_panel: res_tracker_panel.visible = true
		var stats = GameState.player_stats[res_index]
		var e_inc = stats.get("e_inc_cards", 0)
		var v_inc = stats.get("v_inc_cards", 0)
		var both_inc = stats.get("both_inc_cards", 0)
		var dist = GameState.get_shortest_distance_human_elephant()
		
		res_cards_label.text = "+Ele|+Hum|+Both: %d/%d/%d" % [e_inc, v_inc, both_inc]
		res_tiles_label.text = "Separation Dist: %d (Need >=2)" % dist
		
		# Condition: >= 2 e, >= 3 v, without double dipping the both cards
		var cards_met = false
		if (e_inc + both_inc >= 2) and (v_inc + both_inc >= 3) and (e_inc + v_inc + both_inc >= 5):
			cards_met = true
			
		if cards_met and dist >= 2:
			if res_status_label.text != "GOAL MET!":
				res_status_label.text = "GOAL MET!"
				res_status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
				_trigger_win(res_index, "Researcher")
		else:
			if res_status_label.text != "In Progress":
				res_status_label.text = "In Progress"
				res_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))

func _on_window_resize() -> void:
	reposition_cards()

func reposition_cards() -> void:
	var screen_size = get_viewport_rect().size
	var cards = []
	for c in cards_container.get_children():
		if not c.is_queued_for_deletion():
			cards.append(c)

	var total_current_cards = cards.size()
	if total_current_cards == 0:
		return

	var start_x = (screen_size.x - (total_current_cards - 1) * CARD_SPACING) / 2.0

	for i in range(total_current_cards):
		var card = cards[i]
		if card == pending_card:
			continue

		var card_size = card.get_size()
		var x_pos = start_x + (i * CARD_SPACING) - (card_size.x / 2.0)
		var y_pos = screen_size.y - card_size.y - BOTTOM_MARGIN

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

func spawn_stolen_card() -> void:
	# Count how many cards are already displayed (excluding the pending/played card)
	var displayed_ids: Array = []
	for child in cards_container.get_children():
		if not child.is_queued_for_deletion() and child != pending_card:
			displayed_ids.append(child.card_id)

	# Find which card in the hand isn't displayed yet
	var hand = GameState.player_hands[GameState.current_player_index]
	for card_id in hand:
		if not (card_id in displayed_ids):
			var card = CARD_SCENE.instantiate()
			cards_container.add_child(card)
			card.set_card_data(card_id)
			card.card_selected.connect(_on_card_selected)
			break

	call_deferred("reposition_cards")

func remove_played_card_and_draw_replacement() -> void:
	if pending_card:
		pending_card.queue_free()
		pending_card = null

	# Draw a replacement card if hand size is below 5
	if GameState.player_hands[GameState.current_player_index].size() < 5:
		var new_card_id = GameState.draw_card(GameState.current_player_index)
		if new_card_id != "":
			var card = CARD_SCENE.instantiate()
			cards_container.add_child(card)
			card.set_card_data(new_card_id)
			card.card_selected.connect(_on_card_selected)

	call_deferred("reposition_cards")

func _on_card_selected(selected_card) -> void:
	if not play_card:
		return
	
	if cards_played_this_turn >= 1:
		if pending_card:
			pass
		return
		
	if currently_viewing_card == true && pending_card != null:
		if pending_card.background.color == Color.BLACK:
			return
		var card_to_return = pending_card
		card_to_return.is_selected = false
		card_to_return.z_index = 0
		pending_card = null
		end_turn_button.disabled = false
		var old_btn = get_node_or_null("_play_card_btn")
		if old_btn:
			old_btn.queue_free()
		for c in cards_container.get_children():
			c.z_index = 0
		var tween_back = create_tween()
		tween_back.set_parallel(true)
		tween_back.set_ease(Tween.EASE_OUT)
		tween_back.set_trans(Tween.TRANS_BACK)
		tween_back.tween_property(card_to_return, "position", card_to_return.original_position, 0.5)
		tween_back.tween_property(card_to_return, "scale", Vector2(1.0, 1.0), 0.5)
	currently_viewing_card = true
	

	if not (selected_card.card_id in GameState.player_hands[GameState.current_player_index]):
		return

	# Snapshot position before tween moves it
	selected_card.original_position = selected_card.position
	pending_card = selected_card

	var screen_size = get_viewport_rect().size
	var target_pos = (screen_size - selected_card.custom_minimum_size) / 2.0

	selected_card.z_index = 10

	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(selected_card, "position", target_pos, 0.5)
	tween.tween_property(selected_card, "scale", Vector2(3, 3), 0.5)

	end_turn_button.disabled = true
	
	play_btn.disabled = false
	
func _on_play_btn_pressed():
	if play_btn.disabled:
		return
		
	if pending_card:
		play_btn.disabled = true
		pending_card.visible = false
		var card_id = pending_card.card_id   
		cards_played_this_turn += 1
		card_activated.emit(card_id)

# --- Turn management ---

func _on_turn_changed(player_index: int, role_name: String, is_skipped: bool) -> void:
	if user_role_label:
		user_role_label.text = "Player " + str(player_index + 1) + " (" + role_name + ")"
	play_card = not is_skipped

	var skip_label = $Skipped
	if skip_label:
		skip_label.visible = is_skipped

	time_left = 60
	if timer_label:
		timer_label.text = str(time_left)
	cards_played_this_turn = 0
	end_turn_button.disabled = false
	spawn_cards()


# --- Instruction label (shown during tile selection) ---

func show_instruction(text: String) -> void:
	if instruction_label:
		instruction_label.text = text
		instruction_label.get_parent().visible = true

func hide_instruction() -> void:
	if instruction_label:
		instruction_label.get_parent().visible = false

func show_steal_popup(card_effects_node: Node) -> void:
	pending_card.queue_free()
	pending_card = null
	var steal_node = get_node_or_null("Steal")
		
	if not steal_node:
		print("Steal popup not working")
	
	var player_buttons = [
		steal_node.get_node("Player1"),
		steal_node.get_node("Player2"),
		steal_node.get_node("Player3"),
		steal_node.get_node("Player4"),
	]

	var thief := GameState.current_player_index
	var btn_index := 0

	for i in range(GameState.player_count):
		if i == thief:
			continue
		if btn_index >= player_buttons.size():
			break
	
		var hand_size = GameState.player_hands[i].size()
		var role = GameState.player_roles[i] if i < GameState.player_roles.size() else "Unknown"

		var btn = player_buttons[btn_index]
		steal_node.visible = true
		btn.disabled = hand_size == 0
		btn_index += 1

  
		var label = btn.get_node("Label")
		label.text = "Player %d (%d card%s)" % [i + 1, hand_size, "s" if hand_size != 1 else ""]

		var target_index := i
		btn.pressed.connect(func():
			hide_steal_popup(steal_node)
			card_effects_node.confirm_steal_target(target_index)
		)
		
		steal_node.visible = true

func hide_steal_popup(steal_node) -> void:
	if steal_node:
		steal_node.visible = false

func _trigger_win(player_index: int, role_name: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	if win_screen_panel:
		win_screen_panel.visible = true
	if win_screen_label:
		win_screen_label.text = "Player " + str(player_index + 1) + " WON!\nRole: " + role_name
