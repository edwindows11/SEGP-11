extends Control

signal card_activated(card_id: String)
signal end_turn_requested()
signal request_po_ability()

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
var vh_villagers_increased_this_turn: bool = false
var po_used_ability_this_turn: bool = false

var po_ability_btn: Button = null

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

# Wildlife Department discard popup
var wildlife_discard_popup: PanelContainer = null

# Role ability dropdown
var ability_dropdown_btn: Button = null
var ability_dropdown_panel: PanelContainer = null

const ROLE_ABILITIES: Dictionary = {
	"Wildlife Department": "Draw 2 bonus cards (any colour) at the start of your turn. Discard 1 before ending the turn.",
	"Conservationist":     "Win by playing at least 4 Green cards AND increasing forested area by 2 tiles.",
	"Village Head":        "Special: Can play up to 2 colored cards, but max 1 can increase villagers. Must keep >= 1 card in hand.\nWin by playing cards that increase villagers (x2) AND removing 2 constraints.",
	"Plantation Owner":    "Special: Instead of drawing, steal a played colored card, reverse its effects, and play it immediately. Uses your turn action.\nWin by playing 2G + 1R + 1Y cards AND increasing plantation tiles by 2.",
	"Land Developer":      "Win by playing (2G+2R) or (2Y+2R) AND increasing human-dominated areas by 2.",
	"Environmental Consultant": "Win by playing 2G + 2R AND satisfying 2 vacant secondary role goals.",
	"Ecotourism Manager":  "Win by playing 3G + 2Y, keeping at least 1 elephant alive with distance >= 3 from humans.",
	"Researcher":          "Special: Played Action cards that add elephants let you move an equal number of elephants.\nWin by playing cards that increase elephants (x2) and villagers (x3) while keeping them >= 2 tiles apart.",
	"Government":          "No special ability.",
}

func _ready():
	# NOTE: spawn_cards() and spawn_players() are called from card_table.gd
	# after GameState.player_roles and the deck are initialized.
	play_btn.disabled = true
	play_btn.pressed.connect(_on_play_btn_pressed)
	if user_role_label:
		user_role_label.text = "My Role: " + player_role
		user_role_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		# Move to top right, slightly further down so it clears the End Turn button
		user_role_label.offset_top = 75
		user_role_label.offset_bottom = 110
		user_role_label.offset_right = -20
		user_role_label.offset_left = -600
		user_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		# Make it bigger and remove outline
		user_role_label.add_theme_font_size_override("font_size", 26)
		user_role_label.add_theme_color_override("font_color", Color(1, 1, 1, 1)) # White text
		user_role_label.add_theme_constant_override("outline_size", 0) # Remove white outline
		user_role_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5)) # Soft dark shadow

	# IMPORTANT: Do NOT connect end_turn_button.pressed here.
	# The scene has it wired to card_table.gd._on_end_turn_button_pressed already.
	# Connecting again here would double-fire the handler.

	turn_timer.timeout.connect(_on_timer_timeout)
	get_tree().root.size_changed.connect(_on_window_resize)
	
	if placement_options:
		placement_options.visible = false

	_build_steal_popup()
	_build_role_ability_dropdown()

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

	# Setup Plantation Owner Ability Button
	po_ability_btn = Button.new()
	po_ability_btn.text = "Steal & Reverse Card"
	po_ability_btn.visible = false
	po_ability_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	po_ability_btn.offset_left = 30
	po_ability_btn.offset_bottom = -30
	po_ability_btn.offset_top = -80
	po_ability_btn.offset_right = 280
	po_ability_btn.z_index = 50
	
	var po_style = StyleBoxFlat.new()
	po_style.bg_color = Color(0.1, 0.4, 0.2, 0.95)
	po_style.corner_radius_top_left = 10
	po_style.corner_radius_top_right = 10
	po_style.corner_radius_bottom_left = 10
	po_style.corner_radius_bottom_right = 10
	po_style.content_margin_left = 15
	po_style.content_margin_right = 15
	po_style.content_margin_top = 10
	po_style.content_margin_bottom = 10
	po_ability_btn.add_theme_stylebox_override("normal", po_style)
	
	po_ability_btn.pressed.connect(_on_po_ability_btn_pressed)
	# Push it into the CanvasLayer (or just add_child, which will be in the top-level Control)
	add_child(po_ability_btn)

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

	# --- Wildlife Department discard popup ---
	wildlife_discard_popup = PanelContainer.new()
	wildlife_discard_popup.name = "_wl_discard_popup"
	wildlife_discard_popup.visible = false
	wildlife_discard_popup.set_anchors_preset(Control.PRESET_CENTER)
	wildlife_discard_popup.offset_left  = -240
	wildlife_discard_popup.offset_right =  240
	wildlife_discard_popup.offset_top   = -190
	wildlife_discard_popup.offset_bottom = 190
	wildlife_discard_popup.z_index = 60
	var wl_popup_style = StyleBoxFlat.new()
	wl_popup_style.bg_color = Color(0.04, 0.14, 0.22, 0.97)
	wl_popup_style.corner_radius_top_left    = 14
	wl_popup_style.corner_radius_top_right   = 14
	wl_popup_style.corner_radius_bottom_left = 14
	wl_popup_style.corner_radius_bottom_right = 14
	wl_popup_style.border_width_top    = 2
	wl_popup_style.border_width_bottom = 2
	wl_popup_style.border_width_left   = 2
	wl_popup_style.border_width_right  = 2
	wl_popup_style.border_color = Color(0.2, 0.7, 1.0, 0.9)
	wl_popup_style.content_margin_left   = 24
	wl_popup_style.content_margin_right  = 24
	wl_popup_style.content_margin_top    = 20
	wl_popup_style.content_margin_bottom = 20
	wildlife_discard_popup.add_theme_stylebox_override("panel", wl_popup_style)
	var wl_popup_vbox = VBoxContainer.new()
	wl_popup_vbox.add_theme_constant_override("separation", 14)
	wildlife_discard_popup.add_child(wl_popup_vbox)
	var wl_popup_title = Label.new()
	wl_popup_title.text = "Wildlife Department — Special Ability"
	wl_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wl_popup_title.add_theme_font_size_override("font_size", 20)
	wl_popup_title.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0))
	wl_popup_vbox.add_child(wl_popup_title)
	var wl_popup_sub = Label.new()
	wl_popup_sub.text = "You drew 2 bonus cards this turn.\nChoose ONE to discard:"
	wl_popup_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wl_popup_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl_popup_sub.add_theme_font_size_override("font_size", 15)
	wl_popup_sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	wl_popup_vbox.add_child(wl_popup_sub)
	# Card buttons added dynamically in show_wildlife_discard_popup(); store ref via meta
	wildlife_discard_popup.set_meta("_vbox", wl_popup_vbox)
	add_child(wildlife_discard_popup)

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

	var wd_index = GameState.player_roles.find("Wildlife Department")
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


func _on_card_selected(selected_card) -> void:
	if not play_card:
		return
	
	var r_name = GameState.player_roles[GameState.current_player_index] if GameState.current_player_index < GameState.player_roles.size() else ""
	var max_cards = 2 if r_name == "Village Head" else 1

	if cards_played_this_turn >= max_cards:
		if pending_card:
			pass
		show_instruction("You cannot play any more cards this turn.")
		return
		
	if r_name == "Village Head" and cards_played_this_turn == 1:
		var c_data = CardData.ALL_CARDS.get(selected_card.card_id, {})
		var c_col = c_data.get("color", Color.WHITE)
		if not c_col in [Color.GREEN, Color.YELLOW, Color.RED]:
			show_instruction("Village Head's second card must be Green, Yellow, or Red.")
			return
		var adds_v = false
		for fx in c_data.get("sub_effects", []):
			if fx.get("op", "") in ["add_v", "add_v_in"]:
				adds_v = true
				break
		if adds_v and vh_villagers_increased_this_turn:
			show_instruction("Village Head can only play one card that adds villagers per turn.")
			return
			
	if r_name == "Village Head":
		# Must keep at least 1 card in hand. Hand size includes selected card until it's played.
		var current_hand_size = GameState.player_hands[GameState.current_player_index].size()
		if pending_card:
			current_hand_size -= 1
		# If we play this selected card, we will lose 1 from hand.
		# Wait, if pending_card == null, current_hand_size is the total.
		# If current_hand_size <= 1, playing it leaves 0. Block it.
		if pending_card == null and current_hand_size <= 1:
			show_instruction("Village Head must keep at least 1 card in hand.")
			return
		elif pending_card != null and selected_card != pending_card and current_hand_size <= 1:
			# Swapping cards is fine.
			pass
			
	hide_instruction()
		
	if currently_viewing_card == true:
		var card_to_return = pending_card
		if card_to_return:
			card_to_return.is_selected = false
			card_to_return.z_index = 0
		pending_card = null
		end_turn_button.disabled = false
		var old_btn = get_node_or_null("_play_card_btn")
		if old_btn:
			old_btn.queue_free()
		for c in cards_container.get_children():
			c.z_index = 0
		if card_to_return:
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
		var cur_role = GameState.player_roles[GameState.current_player_index] if GameState.current_player_index < GameState.player_roles.size() else ""
		if cur_role == "Village Head":
			var c_data = CardData.ALL_CARDS.get(pending_card.card_id, {})
			for fx in c_data.get("sub_effects", []):
				if fx.get("op", "") in ["add_v", "add_v_in"]:
					vh_villagers_increased_this_turn = true
					break
					
		play_btn.disabled = true
		var card_id = pending_card.card_id   
		pending_card.queue_free()
		pending_card = null
		currently_viewing_card = false
		cards_played_this_turn += 1
		card_activated.emit(card_id)

# --- Turn management ---

func _on_turn_changed(player_index: int, role_name: String, is_skipped: bool) -> void:
	play_card = not is_skipped

	# Clear any leftover bonus cards from the previous Wildlife Dept turn
	GameState.wildlife_dept_drawn_cards = []
	vh_villagers_increased_this_turn = false
	po_used_ability_this_turn = false

	var skip_label = $Skipped
	if skip_label:
		skip_label.visible = is_skipped

	time_left = 60
	if timer_label:
		timer_label.text = str(time_left)
	cards_played_this_turn = 0
	end_turn_button.disabled = false
	
	# Update the role text
	player_role = role_name
	if user_role_label:
		user_role_label.text = "Player " + str(player_index + 1) + " | " + role_name
		
	# Close the dropdown if open
	if ability_dropdown_panel and ability_dropdown_panel.visible:
		ability_dropdown_panel.visible = false
		if ability_dropdown_btn:
			ability_dropdown_btn.text = "Role Ability ▾"
			
	if po_ability_btn:
		po_ability_btn.visible = (role_name == "Plantation Owner" and not is_skipped)

	# Wildlife Department special ability: draw 2 bonus cards at the start of their turn
	if role_name == "Wildlife Department" and not is_skipped:
		GameState.wildlife_dept_draw_bonus(player_index)
		spawn_cards()
		_show_wildlife_bonus_banner()
	else:
		spawn_cards()


# --- Instruction label (shown during tile selection) ---

func show_instruction(text: String) -> void:
	if instruction_label:
		instruction_label.text = text
		instruction_label.get_parent().visible = true

func hide_instruction() -> void:
	if instruction_label:
		instruction_label.get_parent().visible = false

# --- Wildlife Department special ability ---

func _show_wildlife_bonus_banner() -> void:
	var banner = PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top   = 65
	banner.offset_left  = -280
	banner.offset_right =  280
	banner.z_index = 40
	var bs = StyleBoxFlat.new()
	bs.bg_color = Color(0.04, 0.14, 0.22, 0.92)
	bs.corner_radius_top_left    = 10
	bs.corner_radius_top_right   = 10
	bs.corner_radius_bottom_left = 10
	bs.corner_radius_bottom_right = 10
	bs.border_width_top    = 1
	bs.border_width_bottom = 1
	bs.border_width_left   = 1
	bs.border_width_right  = 1
	bs.border_color = Color(0.2, 0.7, 1.0, 0.7)
	bs.content_margin_left  = 20
	bs.content_margin_right = 20
	bs.content_margin_top   = 10
	bs.content_margin_bottom = 10
	banner.add_theme_stylebox_override("panel", bs)
	var lbl = Label.new()
	lbl.text = "Wildlife Dept: +2 bonus cards drawn — discard 1 before ending your turn!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	banner.add_child(lbl)
	add_child(banner)
	var t = get_tree().create_timer(3.5)
	t.timeout.connect(func(): if is_instance_valid(banner): banner.queue_free())

func show_wildlife_discard_popup() -> void:
	if not wildlife_discard_popup:
		return
	var drawn = GameState.wildlife_dept_drawn_cards
	# If nothing to discard, just emit end turn directly
	if drawn.is_empty():
		end_turn_requested.emit()
		return

	var vbox = wildlife_discard_popup.get_meta("_vbox")
	# Clear old card buttons (keep title at 0 and subtitle at 1)
	while vbox.get_child_count() > 2:
		vbox.get_child(vbox.get_child_count() - 1).queue_free()

	for card_id in drawn:
		var data = CardData.ALL_CARDS.get(card_id, {})
		var cname: String = data.get("name", card_id)
		var ccol: Color  = data.get("color", Color.WHITE)
		var color_label := "?"
		if   ccol == Color.GREEN:  color_label = "Green"
		elif ccol == Color.RED:    color_label = "Red"
		elif ccol == Color.YELLOW: color_label = "Yellow"
		elif ccol == Color.BLACK:  color_label = "Black"

		var btn = Button.new()
		btn.text = "[%s] %s" % [color_label, cname]
		btn.custom_minimum_size = Vector2(400, 52)
		btn.add_theme_font_size_override("font_size", 16)

		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = ccol.darkened(0.5)
		btn_normal.corner_radius_top_left    = 8
		btn_normal.corner_radius_top_right   = 8
		btn_normal.corner_radius_bottom_left = 8
		btn_normal.corner_radius_bottom_right = 8
		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = ccol.darkened(0.25)
		btn.add_theme_stylebox_override("normal", btn_normal)
		btn.add_theme_stylebox_override("hover",  btn_hover)

		var cid: String = card_id  # capture loop variable
		btn.pressed.connect(func():
			wildlife_discard_popup.visible = false
			# Discard the chosen card and clear all remaining bonus card tracking
			# so the end-turn guard sees 0 and lets the turn advance
			GameState.wildlife_dept_discard_bonus(GameState.current_player_index, cid)
			GameState.wildlife_dept_drawn_cards.clear()
			# Re-enable the end turn button before emitting so the handler can run
			end_turn_button.disabled = false
			spawn_cards()
			end_turn_requested.emit()
		)
		vbox.add_child(btn)

	wildlife_discard_popup.visible = true

func _build_steal_popup() -> void:
	steal_popup = PanelContainer.new()
	steal_popup.name = "_steal_popup"
	steal_popup.visible = false
	steal_popup.set_anchors_preset(Control.PRESET_CENTER)
	steal_popup.offset_left  = -200
	steal_popup.offset_right =  200
	steal_popup.offset_top   = -160
	steal_popup.offset_bottom = 160

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.18, 0.95)
	style.corner_radius_top_left    = 14
	style.corner_radius_top_right   = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right= 14
	style.content_margin_left   = 24
	style.content_margin_right  = 24
	style.content_margin_top    = 20
	style.content_margin_bottom = 20
	steal_popup.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	steal_popup.add_child(vbox)

	var title = Label.new()
	title.text = "Steal a card from:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	vbox.add_child(title)

	# Placeholder — buttons are rebuilt each time the popup is shown
	# so we store the vbox reference to fill it dynamically.
	steal_popup.set_meta("_btn_vbox", vbox)
	add_child(steal_popup)

func show_player_select_popup(title_text: String, disabled_func: Callable, callback: Callable) -> void:
	if not steal_popup:
		return

	var vbox = steal_popup.get_meta("_btn_vbox")
	var title = vbox.get_child(0)
	title.text = title_text
	
	# Remove old buttons
	while vbox.get_child_count() > 1:
		vbox.get_child(vbox.get_child_count() - 1).queue_free()

	var thief = GameState.current_player_index
	var any_valid_options = false

	for i in range(GameState.player_count):
		if i == thief:
			continue
		var hand_size = GameState.player_hands[i].size()
		var role = GameState.player_roles[i] if i < GameState.player_roles.size() else "Unknown"
		var btn = Button.new()
		btn.text = "Player %d – %s (%d card%s)" % [i + 1, role, hand_size, "s" if hand_size != 1 else ""]
		
		# Apply custom disable logic
		var is_disabled = disabled_func.call(i)
		btn.disabled = is_disabled
		if not is_disabled:
			any_valid_options = true
			
		btn.add_theme_font_size_override("font_size", 17)
		btn.custom_minimum_size = Vector2(320, 44)

		# Capture loop variable properly
		var target_index := i
		btn.pressed.connect(func():
			if steal_popup: steal_popup.visible = false
			callback.call(target_index)
		)
		vbox.add_child(btn)

	# If there are no valid players to choose from, show a single disabled label instead
	if not any_valid_options:
		while vbox.get_child_count() > 1:
			vbox.get_child(vbox.get_child_count() - 1).queue_free()
		var lbl_btn = Button.new()
		lbl_btn.text = "No valid options available!"
		lbl_btn.disabled = true
		lbl_btn.add_theme_font_size_override("font_size", 17)
		lbl_btn.custom_minimum_size = Vector2(320, 44)
		vbox.add_child(lbl_btn)
		
		# Add a cancel button so they aren't totally hardlocked if required
		var cancel_btn = Button.new()
		cancel_btn.text = "Cancel"
		cancel_btn.add_theme_font_size_override("font_size", 17)
		cancel_btn.custom_minimum_size = Vector2(320, 44)
		cancel_btn.pressed.connect(func():
			if steal_popup: steal_popup.visible = false
		)
		vbox.add_child(cancel_btn)

	steal_popup.visible = true

func hide_steal_popup() -> void:
	if steal_popup:
		steal_popup.visible = false

func _on_po_ability_btn_pressed() -> void:
	if cards_played_this_turn >= 1:
		show_instruction("You have already played a card this turn.")
		return
	request_po_ability.emit()

func _build_role_ability_dropdown() -> void:
	# Add the button
	ability_dropdown_btn = Button.new()
	ability_dropdown_btn.name = "_ability_dropdown_btn"
	ability_dropdown_btn.text = "Role Ability ▾"
	ability_dropdown_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ability_dropdown_btn.offset_right = -20
	ability_dropdown_btn.offset_left = -210
	ability_dropdown_btn.offset_top = 115
	ability_dropdown_btn.offset_bottom = 145
	ability_dropdown_btn.custom_minimum_size = Vector2(190, 30)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.2, 0.28, 0.9)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.2, 0.6, 0.8, 1)
	ability_dropdown_btn.add_theme_stylebox_override("normal", btn_style)
	
	var hover = btn_style.duplicate()
	hover.bg_color = Color(0.18, 0.3, 0.4, 0.9)
	ability_dropdown_btn.add_theme_stylebox_override("hover", hover)
	ability_dropdown_btn.focus_mode = Control.FOCUS_NONE
	
	ability_dropdown_btn.pressed.connect(_toggle_ability_dropdown)
	add_child(ability_dropdown_btn)
	
	# Add the dropdown panel
	ability_dropdown_panel = PanelContainer.new()
	ability_dropdown_panel.name = "_ability_dropdown_panel"
	ability_dropdown_panel.visible = false
	ability_dropdown_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ability_dropdown_panel.offset_right = -20
	ability_dropdown_panel.offset_left = -300
	ability_dropdown_panel.offset_top = 150
	ability_dropdown_panel.offset_bottom = 250
	ability_dropdown_panel.custom_minimum_size = Vector2(280, 0)
	ability_dropdown_panel.z_index = 80
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_top_right = 8
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.3, 0.5, 0.6, 0.6)
	panel_style.content_margin_left = 15
	panel_style.content_margin_right = 15
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 12
	ability_dropdown_panel.add_theme_stylebox_override("panel", panel_style)
	
	var lbl = Label.new()
	lbl.name = "AbilityText"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	ability_dropdown_panel.add_child(lbl)
	add_child(ability_dropdown_panel)

func _toggle_ability_dropdown() -> void:
	if not ability_dropdown_panel:
		return
		
	if ability_dropdown_panel.visible:
		ability_dropdown_panel.visible = false
		ability_dropdown_btn.text = "Role Ability ▾"
	else:
		ability_dropdown_panel.visible = true
		ability_dropdown_btn.text = "Role Ability ▴"
		var lbl: Label = ability_dropdown_panel.get_node("AbilityText")
		var current_role = GameState.player_roles[GameState.current_player_index] if GameState.current_player_index < GameState.player_roles.size() else "Unknown"
		lbl.text = ROLE_ABILITIES.get(current_role, "Ability description not found.")

func _trigger_win(player_index: int, role_name: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	if win_screen_panel:
		win_screen_panel.visible = true
	if win_screen_label:
		win_screen_label.text = "Player " + str(player_index + 1) + " WON!\nRole: " + role_name
