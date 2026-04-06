extends Control

signal card_activated(card_id: String)
signal end_turn_requested()

const CARD_SCENE = preload("res://scenes/Card.tscn")
const TOTAL_CARDS = 5
const CARD_SPACING = 200.0
const BOTTOM_MARGIN = 50.0
const RECENT_HISTORY_LIMIT = 5

const PLAYER_DISPLAY_SCENE = preload("res://scenes/PlayerDisplay.tscn")

const TEX_PLAY_NORMAL   = preload("res://assets/CardTable/PLAY (1).png")
const TEX_PLAY_HOVER    = preload("res://assets/CardTable/PLAY (1) Hover.png")
const TEX_PLAY_DISABLED = preload("res://assets/CardTable/PLAY Disable.png")
const TEX_END_NORMAL    = preload("res://assets/CardTable/End_Turn.png")
const TEX_END_DISABLED  = preload("res://assets/CardTable/End_Turn_Disabled.png")

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
var bot_turn_active: bool = false
var _play_btn_is_end_turn: bool = false
var trackers_vbox: VBoxContainer = null

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

# Recent cards overlay
var recent_cards_by_player: Array = []
var recent_cards_toggle_button: Button = null
var recent_cards_overlay_panel: PanelContainer = null
var recent_cards_sections_container: HBoxContainer = null
var recent_cards_preview_holder: CenterContainer = null
var recent_cards_preview_caption: Label = null
var recent_cards_preview_card: Control = null
var selected_recent_uid: String = ""
var _recent_uid_counter: int = 0

func _ready():
	# NOTE: spawn_cards() and spawn_players() are called from card_table.gd
	# after GameState.player_roles and the deck are initialized.
	_set_play_btn_disabled(true)
	play_btn.pressed.connect(_on_play_btn_pressed)
	if user_role_label:
		user_role_label.text = "My Role: " + player_role

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
	
	trackers_vbox = VBoxContainer.new()
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
	_setup_recent_cards_overlay_ui()

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
		var forest_increase = max(0, GameState.get_forest_increase())

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
		var p = max(0, GameState.get_plantation_increase())

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
		var h = max(0, GameState.get_human_increase())

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


# --- Recent Cards Overlay ---

func _ensure_recent_player_buckets(player_count: int) -> void:
	var target_count: int = maxi(4, player_count)
	if recent_cards_by_player.is_empty():
		recent_cards_by_player = [[], [], [], []]
	while recent_cards_by_player.size() < target_count:
		recent_cards_by_player.append([])
	while recent_cards_by_player.size() > target_count:
		recent_cards_by_player.pop_back()

func _setup_recent_cards_overlay_ui() -> void:
	_ensure_recent_player_buckets(GameState.player_count)

	recent_cards_toggle_button = Button.new()
	recent_cards_toggle_button.name = "_recent_cards_toggle_button"
	recent_cards_toggle_button.text = "Recent Cards"
	recent_cards_toggle_button.custom_minimum_size = Vector2(160, 42)
	recent_cards_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	recent_cards_toggle_button.offset_left = 16
	recent_cards_toggle_button.offset_top = -92
	recent_cards_toggle_button.offset_right = 176
	recent_cards_toggle_button.offset_bottom = -50
	recent_cards_toggle_button.z_index = 90
	recent_cards_toggle_button.pressed.connect(_toggle_recent_cards_overlay)
	add_child(recent_cards_toggle_button)

	recent_cards_overlay_panel = PanelContainer.new()
	recent_cards_overlay_panel.name = "_recent_cards_overlay"
	recent_cards_overlay_panel.visible = false
	recent_cards_overlay_panel.set_anchors_preset(Control.PRESET_CENTER)
	recent_cards_overlay_panel.offset_left = -560
	recent_cards_overlay_panel.offset_top = -380
	recent_cards_overlay_panel.offset_right = 560
	recent_cards_overlay_panel.offset_bottom = 220
	recent_cards_overlay_panel.z_index = 90

	var overlay_style := StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.05, 0.05, 0.05, 0.92)
	overlay_style.corner_radius_top_left = 14
	overlay_style.corner_radius_top_right = 14
	overlay_style.corner_radius_bottom_left = 14
	overlay_style.corner_radius_bottom_right = 14
	overlay_style.content_margin_left = 20
	overlay_style.content_margin_right = 20
	overlay_style.content_margin_top = 16
	overlay_style.content_margin_bottom = 16
	recent_cards_overlay_panel.add_theme_stylebox_override("panel", overlay_style)

	var root_vbox := VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.add_theme_constant_override("separation", 14)
	recent_cards_overlay_panel.add_child(root_vbox)

	var title := Label.new()
	title.text = "Recent Cards Played"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25))
	root_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Click a card to expand it. Click the same card again to minimize."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	root_vbox.add_child(subtitle)

	var cards_scroll := ScrollContainer.new()
	cards_scroll.custom_minimum_size = Vector2(0, 320)
	cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(cards_scroll)

	recent_cards_sections_container = HBoxContainer.new()
	recent_cards_sections_container.name = "RecentCardsSections"
	recent_cards_sections_container.add_theme_constant_override("separation", 14)
	recent_cards_sections_container.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_scroll.add_child(recent_cards_sections_container)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0, 360)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.1, 0.1, 0.1, 0.88)
	preview_style.corner_radius_top_left = 10
	preview_style.corner_radius_top_right = 10
	preview_style.corner_radius_bottom_left = 10
	preview_style.corner_radius_bottom_right = 10
	preview_style.content_margin_left = 12
	preview_style.content_margin_right = 12
	preview_style.content_margin_top = 8
	preview_style.content_margin_bottom = 8
	preview_panel.add_theme_stylebox_override("panel", preview_style)
	root_vbox.add_child(preview_panel)

	var preview_vbox := VBoxContainer.new()
	preview_vbox.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_vbox)

	recent_cards_preview_caption = Label.new()
	recent_cards_preview_caption.text = "Select a recent card to preview"
	recent_cards_preview_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recent_cards_preview_caption.add_theme_font_size_override("font_size", 18)
	recent_cards_preview_caption.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	preview_vbox.add_child(recent_cards_preview_caption)

	recent_cards_preview_holder = CenterContainer.new()
	recent_cards_preview_holder.custom_minimum_size = Vector2(0, 300)
	preview_vbox.add_child(recent_cards_preview_holder)

	add_child(recent_cards_overlay_panel)

func _toggle_recent_cards_overlay() -> void:
	if recent_cards_overlay_panel == null:
		return
	recent_cards_overlay_panel.visible = not recent_cards_overlay_panel.visible
	if recent_cards_overlay_panel.visible:
		_rebuild_recent_cards_overlay()
	else:
		_clear_recent_cards_preview()

func add_recent_card_for_player(player_index: int, card_id: String) -> void:
	if card_id == "":
		return
	_ensure_recent_player_buckets(GameState.player_count)
	if player_index < 0 or player_index >= recent_cards_by_player.size():
		return

	_recent_uid_counter += 1
	var entry_uid: String = str(_recent_uid_counter)
	var entry := {"uid": entry_uid, "card_id": card_id}
	var bucket: Array = recent_cards_by_player[player_index]
	bucket.append(entry)

	while bucket.size() > RECENT_HISTORY_LIMIT:
		var removed_entry: Variant = bucket.pop_front()
		if removed_entry is Dictionary:
			var removed_uid: String = str(removed_entry.get("uid", ""))
			if removed_uid == selected_recent_uid:
				selected_recent_uid = ""
				_clear_recent_cards_preview()

	recent_cards_by_player[player_index] = bucket

	if recent_cards_overlay_panel and recent_cards_overlay_panel.visible:
		_rebuild_recent_cards_overlay()

func _rebuild_recent_cards_overlay() -> void:
	if recent_cards_sections_container == null:
		return

	_ensure_recent_player_buckets(GameState.player_count)

	for child in recent_cards_sections_container.get_children():
		child.queue_free()

	if selected_recent_uid != "" and not _recent_uid_exists(selected_recent_uid):
		selected_recent_uid = ""
		_clear_recent_cards_preview()

	for player_index in range(recent_cards_by_player.size()):
		var section_panel := PanelContainer.new()
		section_panel.custom_minimum_size = Vector2(230, 0)
		var section_style := StyleBoxFlat.new()
		section_style.bg_color = Color(0.12, 0.12, 0.12, 0.85)
		section_style.corner_radius_top_left = 8
		section_style.corner_radius_top_right = 8
		section_style.corner_radius_bottom_left = 8
		section_style.corner_radius_bottom_right = 8
		section_style.content_margin_left = 10
		section_style.content_margin_right = 10
		section_style.content_margin_top = 8
		section_style.content_margin_bottom = 8
		section_panel.add_theme_stylebox_override("panel", section_style)

		var section_vbox := VBoxContainer.new()
		section_vbox.add_theme_constant_override("separation", 6)
		section_panel.add_child(section_vbox)

		var header := Label.new()
		header.text = "Player %d" % [player_index + 1]
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
		section_vbox.add_child(header)

		var cards_column := VBoxContainer.new()
		cards_column.add_theme_constant_override("separation", 6)
		section_vbox.add_child(cards_column)

		var bucket: Array = recent_cards_by_player[player_index]
		if bucket.is_empty():
			var empty_label := Label.new()
			empty_label.text = "No cards played yet"
			empty_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			empty_label.add_theme_font_size_override("font_size", 14)
			cards_column.add_child(empty_label)
		else:
			for entry_index in range(bucket.size() - 1, -1, -1):
				var entry_variant: Variant = bucket[entry_index]
				if not (entry_variant is Dictionary):
					continue
				var entry: Dictionary = entry_variant
				var entry_uid: String = str(entry.get("uid", ""))
				var card_id: String = str(entry.get("card_id", ""))
				var card_name: String = _card_name_from_id(card_id)
				var thumb := TextureButton.new()
				thumb.custom_minimum_size = Vector2(74, 104)
				thumb.texture_normal = _load_card_texture(card_id)
				thumb.texture_hover = thumb.texture_normal
				thumb.texture_pressed = thumb.texture_normal
				thumb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
				thumb.ignore_texture_size = true
				thumb.tooltip_text = card_name
				if entry_uid == selected_recent_uid:
					thumb.modulate = Color(1.0, 1.0, 1.0, 1.0)
				else:
					thumb.modulate = Color(0.85, 0.85, 0.85, 1.0)
				thumb.pressed.connect(_on_recent_card_thumbnail_pressed.bind(entry_uid, card_id))
				cards_column.add_child(thumb)

		recent_cards_sections_container.add_child(section_panel)

func _card_name_from_id(card_id: String) -> String:
	var card_def: Dictionary = CardData.ALL_CARDS.get(card_id, {})
	return str(card_def.get("name", card_id))

func _load_card_texture(card_id: String) -> Texture2D:
	var card_name: String = _card_name_from_id(card_id)
	var texture: Texture2D = load("res://assets/Card/" + card_name + ".png")
	return texture

func _on_recent_card_thumbnail_pressed(entry_uid: String, card_id: String) -> void:
	if entry_uid == selected_recent_uid:
		selected_recent_uid = ""
		_clear_recent_cards_preview()
		_rebuild_recent_cards_overlay()
		return

	selected_recent_uid = entry_uid
	_show_recent_cards_preview(card_id)
	_rebuild_recent_cards_overlay()

func _show_recent_cards_preview(card_id: String) -> void:
	_clear_recent_cards_preview()
	if recent_cards_preview_holder == null:
		return

	var preview_card: Control = CARD_SCENE.instantiate()
	recent_cards_preview_holder.add_child(preview_card)
	preview_card.set_card_data(card_id)
	preview_card.set_anchors_preset(Control.PRESET_CENTER)
	preview_card.offset_left = -90
	preview_card.offset_top = -54
	preview_card.offset_right = 90
	preview_card.offset_bottom = 54
	preview_card.pivot_offset = Vector2(90, 54)
	preview_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_card.scale = Vector2(0.78, 0.78)
	preview_card.modulate = Color(1, 1, 1, 0)
	recent_cards_preview_card = preview_card

	if recent_cards_preview_caption:
		recent_cards_preview_caption.text = _card_name_from_id(card_id)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(preview_card, "scale", Vector2(2.6, 2.6), 0.32)
	tween.parallel().tween_property(preview_card, "modulate", Color(1, 1, 1, 1), 0.2)

func _clear_recent_cards_preview() -> void:
	if recent_cards_preview_card and is_instance_valid(recent_cards_preview_card):
		recent_cards_preview_card.queue_free()
	recent_cards_preview_card = null
	if recent_cards_preview_caption:
		recent_cards_preview_caption.text = "Select a recent card to preview"

func _recent_uid_exists(uid: String) -> bool:
	for bucket_variant in recent_cards_by_player:
		if not (bucket_variant is Array):
			continue
		var bucket: Array = bucket_variant
		for entry_variant in bucket:
			if entry_variant is Dictionary:
				if str(entry_variant.get("uid", "")) == uid:
					return true
	return false


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

	# Reorder tracker panels to match player order (Player 1 at top → Player 4 at bottom)
	var role_to_panel: Dictionary = {
		"Conservationist": cons_tracker_panel,
		"Village Head": vh_tracker_panel,
		"Plantation Owner": po_tracker_panel,
		"Land Developer": ld_tracker_panel,
		"Environmental Consultant": ec_tracker_panel,
		"Ecotourism Manager": em_tracker_panel,
		"Wildfire Department": wd_tracker_panel,
		"Researcher": res_tracker_panel,
	}
	var idx := 0
	for i in range(GameState.player_count):
		var role = roles[i] if i < roles.size() else ""
		var panel = role_to_panel.get(role, null)
		if panel != null and is_instance_valid(panel):
			trackers_vbox.move_child(panel, idx)
			idx += 1


# --- Card hand management ---

func spawn_cards() -> void:
	# Clear existing cards
	for child in cards_container.get_children():
		child.queue_free()
	pending_card = null

	var current_idx = GameState.current_player_index
	var hand = GameState.player_hands[current_idx]

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
	if bot_turn_active:
		return
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

	_set_play_btn_disabled(false)

func _set_play_btn_disabled(value: bool) -> void:
	play_btn.disabled = value
	play_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP

func _switch_to_end_turn_mode() -> void:
	_play_btn_is_end_turn = true
	play_btn.texture_normal   = TEX_END_NORMAL
	play_btn.texture_pressed  = TEX_END_NORMAL
	play_btn.texture_hover    = TEX_END_NORMAL
	play_btn.texture_disabled = TEX_END_DISABLED
	play_btn.texture_focused  = TEX_END_NORMAL
	_set_play_btn_disabled(true)

func _switch_to_play_mode() -> void:
	_play_btn_is_end_turn = false
	currently_viewing_card = false
	pending_card = null
	play_btn.texture_normal   = TEX_PLAY_NORMAL
	play_btn.texture_pressed  = TEX_PLAY_NORMAL
	play_btn.texture_hover    = TEX_PLAY_HOVER
	play_btn.texture_disabled = TEX_PLAY_DISABLED
	play_btn.texture_focused  = TEX_PLAY_NORMAL
	_set_play_btn_disabled(true)

func set_end_turn_ready() -> void:
	if bot_turn_active:
		return
	if _play_btn_is_end_turn:
		_set_play_btn_disabled(false)

func _on_play_btn_pressed():
	if play_btn.disabled:
		return

	if _play_btn_is_end_turn:
		_switch_to_play_mode()
		end_turn_requested.emit()
		return

	if pending_card:
		pending_card.visible = false
		var card_id = pending_card.card_id
		cards_played_this_turn += 1
		_switch_to_end_turn_mode()
		card_activated.emit(card_id)

# --- Bot turn lock ---

func _on_bot_turn_started() -> void:
	bot_turn_active = true
	_set_play_btn_disabled(true)

func _on_bot_turn_ended() -> void:
	bot_turn_active = false

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
	bot_turn_active = false
	_switch_to_play_mode()
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
	var steal_node = get_node_or_null("Steal")
		
	if not steal_node:
		print("Steal popup not working")
	
	var player_buttons = [
		steal_node.get_node("Player1"),
		steal_node.get_node("Player2"),
		steal_node.get_node("Player3")
	]

	for btn in player_buttons:
		for sig in btn.get_signal_connection_list("pressed"):
			btn.disconnect("pressed", sig["callable"])
	
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
		btn_index +=1

  
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

func show_convert_type_popup(card_effects_node: Node, current_type: int) -> void:
	var popup = get_node_or_null("_convert_type_popup")
	if popup == null:
		popup = PanelContainer.new()
		popup.name = "_convert_type_popup"
		popup.set_anchors_preset(Control.PRESET_CENTER)
		popup.offset_left = -220
		popup.offset_top = -110
		popup.offset_right = 220
		popup.offset_bottom = 110

		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.08, 0.08, 0.08, 0.92)
		panel_style.corner_radius_top_left = 12
		panel_style.corner_radius_top_right = 12
		panel_style.corner_radius_bottom_left = 12
		panel_style.corner_radius_bottom_right = 12
		panel_style.content_margin_left = 18
		panel_style.content_margin_right = 18
		panel_style.content_margin_top = 14
		panel_style.content_margin_bottom = 14
		popup.add_theme_stylebox_override("panel", panel_style)

		var root_vbox := VBoxContainer.new()
		root_vbox.name = "RootVBox"
		root_vbox.add_theme_constant_override("separation", 12)
		popup.add_child(root_vbox)

		var title := Label.new()
		title.name = "Title"
		title.text = "Choose New Tile Type"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 24)
		title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		root_vbox.add_child(title)

		var row := HBoxContainer.new()
		row.name = "ButtonsRow"
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		root_vbox.add_child(row)

		var button_specs = [
			{"name": "ForestBtn", "text": "Forest", "type": GameState.TileType.FOREST},
			{"name": "HumanBtn", "text": "Human", "type": GameState.TileType.HUMAN},
			{"name": "PlantationBtn", "text": "Plantation", "type": GameState.TileType.PLANTATION},
		]

		for spec in button_specs:
			var btn := Button.new()
			btn.name = spec["name"]
			btn.text = spec["text"]
			btn.custom_minimum_size = Vector2(120, 44)
			btn.add_theme_font_size_override("font_size", 18)
			btn.pressed.connect(func():
				hide_convert_type_popup()
				card_effects_node.confirm_convert_any_any_type_selected(spec["type"])
			)
			row.add_child(btn)

		add_child(popup)

	var row_node: HBoxContainer = popup.get_node("RootVBox/ButtonsRow")
	for btn in row_node.get_children():
		if btn is Button:
			var button: Button = btn
			match button.name:
				"ForestBtn":
					button.disabled = current_type == GameState.TileType.FOREST
				"HumanBtn":
					button.disabled = current_type == GameState.TileType.HUMAN
				"PlantationBtn":
					button.disabled = current_type == GameState.TileType.PLANTATION

	popup.visible = true

func hide_convert_type_popup() -> void:
	var popup = get_node_or_null("_convert_type_popup")
	if popup:
		popup.visible = false

func _trigger_win(player_index: int, role_name: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	if win_screen_panel:
		win_screen_panel.visible = true
	if win_screen_label:
		win_screen_label.text = "Player " + str(player_index + 1) + " WON!\nRole: " + role_name
