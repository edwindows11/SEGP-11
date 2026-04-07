extends Control

signal card_activated(card_id: String)
signal end_turn_requested()
signal request_po_ability()
signal request_gov_ability()
signal request_cons_ability()
signal request_ld_ability()
signal request_ec_ability()

const CARD_SCENE = preload("res://scenes/Card.tscn")
const TOTAL_CARDS = 5       # standard "draw hand" — the end-of-turn refill target
const MAX_HAND_SIZE = 8     # absolute cap — hand can grow up to this via steals/returns
const CARD_SPACING = 200.0
const BOTTOM_MARGIN = 50.0

const PLAYER_DISPLAY_SCENE = preload("res://scenes/PlayerDisplay.tscn")

@onready var cards_container = $CardsContainer
@onready var players_container = $TopBar/PlayersContainer
@onready var user_role_label = $UserRoleLabel
@onready var timer_label = $TopBar/TimerLabel
@onready var turn_timer = $TurnTimer
@onready var placement_options = $TopBar/PlacementMode
@onready var play_btn = $PlayCard
@onready var pause_btn = $TopBar/PauseButton

var _play_btn_is_end_turn: bool = false
const TEX_PLAY_NORMAL   = preload("res://assets/CardTable/PLAY (1).png")
const TEX_PLAY_HOVER    = preload("res://assets/CardTable/PLAY (1) Hover.png")
const TEX_PLAY_DISABLED = preload("res://assets/CardTable/PLAY Disable.png")
const TEX_END_NORMAL    = preload("res://assets/CardTable/End_Turn.png")
const TEX_END_DISABLED  = preload("res://assets/CardTable/End_Turn_Disabled.png")
var recent_cards_toggle_button: Button = null
var recent_cards_overlay_panel: PanelContainer = null
var recent_cards_overlay_blocker: ColorRect = null
var recent_cards_sections_container: HBoxContainer = null
var recent_cards_by_player: Array = []
const RECENT_HISTORY_LIMIT: int = 5
var recent_cards_preview_card: Control = null
var recent_cards_preview_holder: CenterContainer = null
var recent_cards_preview_caption: Label = null
var selected_recent_uid: String = ""
var _recent_uid_counter: int = 0

var player_role: String = "Unknown"
var role_image_rect: TextureRect = null
var time_left = 60
var cards_played_this_turn = 0
var pending_card: Control = null
var instruction_label: Label = null
var play_card: bool = true
var currently_viewing_card: bool = false
var bot_turn_active: bool = false
var vh_villagers_increased_this_turn: bool = false
var po_used_ability_this_turn: bool = false

@onready var special_ability_btn = $"Special Abitlity"
var gov_used_ability_this_turn: bool = false
var cons_used_ability_this_turn: bool = false
var ld_used_ability_this_turn: bool = false
var ec_used_ability_this_turn: bool = false
var ec_choice_popup: PanelContainer = null

# Trackers
var cons_tracker_panel: PanelContainer = null
var cons_green_label: Label = null
var cons_forest_label: Label = null
var cons_status_label: Label = null

var vh_tracker_panel: PanelContainer = null
var vh_cards_label: Label = null
var vh_pop_label: Label = null
var vh_status_label: Label = null

var po_tracker_panel: PanelContainer = null
var po_cards_label: Label = null
var po_plant_label: Label = null
var po_status_label: Label = null

var ld_tracker_panel: PanelContainer = null
var ld_cards_label: Label = null
var ld_human_label: Label = null
var ld_status_label: Label = null

var ec_tracker_panel: PanelContainer = null
var ec_cards_label: Label = null
var ec_vacant_label: Label = null
var ec_status_label: Label = null

var em_tracker_panel: PanelContainer = null
var em_cards_label: Label = null
var em_elephants_label: Label = null
var em_status_label: Label = null

var wd_tracker_panel: PanelContainer = null
var wd_cards_label: Label = null
var wd_elephants_label: Label = null
var wd_status_label: Label = null

var res_tracker_panel: PanelContainer = null
var res_cards_label: Label = null
var res_tiles_label: Label = null
var res_status_label: Label = null

var gov_tracker_panel: PanelContainer = null
var gov_cards_label: Label = null
var gov_ratio_label: Label = null
var gov_status_label: Label = null

# Winning Screen
var win_screen_panel: PanelContainer = null
var win_screen_label: Label = null
var is_game_over: bool = false

# Role card overlay
var _role_card_overlay: ColorRect = null
var _role_card_overlay_rect: TextureRect = null
var _role_card_overlay_tween: Tween = null

# Popups
var steal_popup: PanelContainer = null
var em_choice_popup: PanelContainer = null
var wildlife_discard_popup: PanelContainer = null

# Role ability dropdown
var ability_dropdown_btn: Button = null
var ability_dropdown_panel: PanelContainer = null

const ROLE_ABILITIES: Dictionary = {
	"Wildlife Department": "Draw 2 bonus cards (any colour) at the start of your turn. Discard 1 before ending the turn.",
	"Conservationist":     "Special: Once per turn as an extra action, convert 1 non-forest tile adjacent to a forested tile with an elephant into Forest.\nWin by playing at least 4 Green cards AND increasing forested area by 2 tiles.",
	"Village Head":        "Special: Can play up to 2 colored cards, but max 1 can increase villagers. Must keep >= 1 card in hand.\nWin by playing cards that increase villagers (x2) AND removing 2 constraints.",
	"Plantation Owner":    "Special: Instead of drawing, steal a played colored card, reverse its effects, and play it immediately. Uses your turn action.\nWin by playing 2G + 1R + 1Y cards AND increasing plantation tiles by 2.",
	"Land Developer":      "Special: Once per turn as an extra action, convert 1 non-human tile with at least 3 human-dominated neighbours into a Human-Dominated tile.\nWin by playing (2G+2R) or (2Y+2R) AND increasing human-dominated areas by 2.",
	"Environmental Consultant": "Special: At game start, borrow one special ability from another chosen role and use it for the whole game.\nWin by playing 2G + 2R AND satisfying 2 vacant secondary role goals.",
	"Ecotourism Manager":  "Special: For your played black, yellow, red or green cards that increase elephants or humans, as an extra action, you may choose to move an elephant or a human in your chosen direction.\nWin by playing 3G + 2Y, keeping at least 1 elephant alive with distance >= 3 from humans.",
	"Researcher":          "Special: Played Action cards that add elephants let you move an equal number of elephants.\nWin by playing cards that increase elephants (x2) and villagers (x3) while keeping them >= 2 tiles apart.",
	"Government":          "Special: Instead of drawing a card, steal any played Yellow, Red, or Green card from another player. You may replay it on your current or later turns (once per card).\nWin by playing 2R + 2Y cards AND having Villagers >= 2x Elephants on the board.",
}

func _ready():
	pause_btn.pressed.connect(_pause)
	play_btn.pressed.connect(_on_play_btn_pressed)
	special_ability_btn.pressed.connect(_on_special_ability_pressed)
	special_ability_btn.visible = false
	if user_role_label:
		user_role_label.text = "My Role: " + player_role
		user_role_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		user_role_label.offset_top = 75
		user_role_label.offset_bottom = 110
		user_role_label.offset_right = -20
		user_role_label.offset_left = -600
		user_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		user_role_label.add_theme_font_size_override("font_size", 26)
		user_role_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		user_role_label.add_theme_constant_override("outline_size", 0)
		user_role_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))

	turn_timer.timeout.connect(_on_timer_timeout)
	get_tree().root.size_changed.connect(_on_window_resize)
	
	if placement_options:
		placement_options.visible = false

	_init_all_ui_elements()
	

func _pause():
	var pause_menu = $CanvasLayer/PauseMenu
	if pause_menu:
		pause_menu.toggle_pause()
		return

func _init_all_ui_elements():
	_build_instruction_banner()
	_setup_recent_cards_overlay_ui()
	_build_all_trackers()
	_build_win_screen()
	_build_wildlife_discard_popup()
	_build_steal_popup()
	_build_ec_choice_popup()
	_build_em_choice_popup()
	_build_role_ability_dropdown()
	_build_role_card_overlay()

func _build_role_card_overlay():
	_role_card_overlay = ColorRect.new()
	_role_card_overlay.color = Color(0, 0, 0, 0.75)
	_role_card_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_role_card_overlay.visible = false
	_role_card_overlay.z_index = 200
	_role_card_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_role_card_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_hide_role_card_overlay()
	)
	add_child(_role_card_overlay)

	_role_card_overlay_rect = TextureRect.new()
	_role_card_overlay_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_role_card_overlay_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_role_card_overlay_rect.set_anchors_preset(Control.PRESET_CENTER)
	_role_card_overlay_rect.offset_left = -250
	_role_card_overlay_rect.offset_top = -350
	_role_card_overlay_rect.offset_right = 250
	_role_card_overlay_rect.offset_bottom = 350
	_role_card_overlay_rect.pivot_offset = Vector2(250, 350)
	_role_card_overlay_rect.scale = Vector2.ZERO
	_role_card_overlay_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_role_card_overlay.add_child(_role_card_overlay_rect)

func _show_role_card_overlay(tex: Texture2D):
	_role_card_overlay_rect.texture = tex
	_role_card_overlay.modulate = Color(1, 1, 1, 0)
	_role_card_overlay_rect.scale = Vector2(0.1, 0.1)
	_role_card_overlay.visible = true
	if _role_card_overlay_tween:
		_role_card_overlay_tween.kill()
	_role_card_overlay_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_role_card_overlay_tween.tween_property(_role_card_overlay, "modulate", Color(1, 1, 1, 1), 0.3)
	_role_card_overlay_tween.tween_property(_role_card_overlay_rect, "scale", Vector2(1, 1), 0.4)

func _hide_role_card_overlay():
	if _role_card_overlay_tween:
		_role_card_overlay_tween.kill()
	_role_card_overlay_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_role_card_overlay_tween.tween_property(_role_card_overlay, "modulate", Color(1, 1, 1, 0), 0.25)
	_role_card_overlay_tween.tween_property(_role_card_overlay_rect, "scale", Vector2(0.1, 0.1), 0.25)
	await _role_card_overlay_tween.finished
	_role_card_overlay.visible = false

func _build_instruction_banner():
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

func _build_all_trackers():
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

	# Conservationist
	cons_tracker_panel = _create_tracker_panel("Conservationist Goal", Color(0.1, 0.3, 0.1, 0.8), Color(0.6, 1.0, 0.6), "Conservationist")
	cons_green_label = _add_tracker_label(cons_tracker_panel, "Green Cards: 0 / 4")
	cons_forest_label = _add_tracker_label(cons_tracker_panel, "Forest Increase: 0 / 2")
	cons_status_label = _add_tracker_status(cons_tracker_panel)
	trackers_vbox.add_child(cons_tracker_panel)

	# Village Head
	vh_tracker_panel = _create_tracker_panel("Village Head Goal", Color(0.3, 0.1, 0.1, 0.8), Color(1.0, 0.6, 0.6), "Village Head")
	vh_cards_label = _add_tracker_label(vh_tracker_panel, "Action Cards: 0 / 7")
	vh_pop_label = _add_tracker_label(vh_tracker_panel, "Population: 0 / 16")
	vh_status_label = _add_tracker_status(vh_tracker_panel)
	trackers_vbox.add_child(vh_tracker_panel)

	# Plantation Owner
	po_tracker_panel = _create_tracker_panel("Plantation Owner Goal", Color(0.3, 0.25, 0.1, 0.8), Color(1.0, 0.8, 0.4), "Plantation Owner")
	po_cards_label = _add_tracker_label(po_tracker_panel, "Cards: 0G, 0R, 0Y / 2G, 1R, 1Y")
	po_plant_label = _add_tracker_label(po_tracker_panel, "Plantations: 0 / 2")
	po_status_label = _add_tracker_status(po_tracker_panel)
	trackers_vbox.add_child(po_tracker_panel)

	# Land Developer
	ld_tracker_panel = _create_tracker_panel("Land Developer Goal", Color(0.1, 0.1, 0.3, 0.8), Color(0.6, 0.8, 1.0), "Land Developer")
	ld_cards_label = _add_tracker_label(ld_tracker_panel, "Cards: 0G, 0R, 0Y / (2G+2R) or (2Y+2R)")
	ld_human_label = _add_tracker_label(ld_tracker_panel, "Human Areas: 0 / 2")
	ld_status_label = _add_tracker_status(ld_tracker_panel)
	trackers_vbox.add_child(ld_tracker_panel)

	# Env Consultant
	ec_tracker_panel = _create_tracker_panel("Env Consultant Goal", Color(0.2, 0.4, 0.2, 0.8), Color(0.6, 1.0, 0.6), "Environmental Consultant")
	ec_cards_label = _add_tracker_label(ec_tracker_panel, "Cards: 0G, 0R / 2G, 2R")
	ec_vacant_label = _add_tracker_label(ec_tracker_panel, "Vacant Goals Met: 0 / 2")
	ec_status_label = _add_tracker_status(ec_tracker_panel)
	trackers_vbox.add_child(ec_tracker_panel)

	# Ecotourism Manager
	em_tracker_panel = _create_tracker_panel("Ecotourism Manager Goal", Color(0.1, 0.5, 0.5, 0.8), Color(0.4, 0.9, 0.9), "Ecotourism Manager")
	em_cards_label = _add_tracker_label(em_tracker_panel, "Cards: 0G, 0Y / 3G, 2Y")
	em_elephants_label = _add_tracker_label(em_tracker_panel, "Elephants / Dist: No / <3")
	em_status_label = _add_tracker_status(em_tracker_panel)
	trackers_vbox.add_child(em_tracker_panel)

	# Wildlife Department
	wd_tracker_panel = _create_tracker_panel("Wildlife Dept Goal", Color(0.6, 0.2, 0.0, 0.8), Color(1.0, 0.5, 0.2), "Wildlife Department")
	wd_cards_label = _add_tracker_label(wd_tracker_panel, "Green Cards: 0 / 4")
	wd_elephants_label = _add_tracker_label(wd_tracker_panel, "Forest Elephants: 0 / 4")
	wd_status_label = _add_tracker_status(wd_tracker_panel)
	trackers_vbox.add_child(wd_tracker_panel)

	# Researcher
	res_tracker_panel = _create_tracker_panel("Researcher Goal", Color(0.4, 0.1, 0.5, 0.8), Color(0.8, 0.5, 1.0), "Researcher")
	res_cards_label = _add_tracker_label(res_tracker_panel, "+Ele|+Hum|+Both: 0/0/0")
	res_tiles_label = _add_tracker_label(res_tracker_panel, "Separation: >= 2 tiles")
	res_status_label = _add_tracker_status(res_tracker_panel)
	trackers_vbox.add_child(res_tracker_panel)

	# Government
	gov_tracker_panel = _create_tracker_panel("Government Goal", Color(0.05, 0.1, 0.3, 0.85), Color(0.6, 0.85, 1.0), "Government")
	gov_cards_label = _add_tracker_label(gov_tracker_panel, "Cards: 0R, 0Y / 2R, 2Y")
	gov_ratio_label = _add_tracker_label(gov_tracker_panel, "Villagers / Elephants: 0 / 0")
	gov_status_label = _add_tracker_status(gov_tracker_panel)
	trackers_vbox.add_child(gov_tracker_panel)

func _create_tracker_panel(title_text: String, bg_color: Color, title_color: Color, role_name: String = "") -> PanelContainer:
	var panel = PanelContainer.new()
	panel.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Role card image on the left
	if role_name != "":
		var tex_path = "res://assets/Role Card/%s.png" % role_name
		var tex = load(tex_path)
		if tex != null:
			var tex_rect = TextureRect.new()
			tex_rect.texture = tex
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(60, 80)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
			var captured_tex = tex
			tex_rect.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					_show_role_card_overlay(captured_tex)
			)
			hbox.add_child(tex_rect)
			

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	hbox.add_child(vbox)

	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", title_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	return panel

func _add_tracker_label(panel: PanelContainer, text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	panel.find_child("VBox", true, false).add_child(lbl)
	return lbl

func _add_tracker_status(panel: PanelContainer) -> Label:
	var lbl = Label.new()
	lbl.text = "In Progress"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.find_child("VBox", true, false).add_child(lbl)
	return lbl

func _on_special_ability_pressed():
	if bot_turn_active: return
	match player_role:
		"Plantation Owner":
			if cards_played_this_turn == 0:
				request_po_ability.emit()
		"Government":
			if not gov_used_ability_this_turn:
				request_gov_ability.emit()
		"Conservationist":
			if not cons_used_ability_this_turn:
				request_cons_ability.emit()
		"Land Developer":
			if not ld_used_ability_this_turn:
				request_ld_ability.emit()
		"Environmental Consultant":
			request_ec_ability.emit()

func _build_win_screen():
	win_screen_panel = PanelContainer.new()
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

func _build_wildlife_discard_popup():
	wildlife_discard_popup = PanelContainer.new()
	wildlife_discard_popup.visible = false
	wildlife_discard_popup.set_anchors_preset(Control.PRESET_CENTER)
	wildlife_discard_popup.offset_left = -240
	wildlife_discard_popup.offset_right = 240
	wildlife_discard_popup.offset_top = -190
	wildlife_discard_popup.offset_bottom = 190
	wildlife_discard_popup.z_index = 60
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.14, 0.22, 0.97)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	wildlife_discard_popup.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	wildlife_discard_popup.add_child(vbox)
	var title = Label.new()
	title.text = "Wildlife Department — Special Ability"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0))
	vbox.add_child(title)
	var sub = Label.new()
	sub.text = "Choose ONE card to discard:"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)
	wildlife_discard_popup.set_meta("_vbox", vbox)
	add_child(wildlife_discard_popup)

func _build_steal_popup():
	steal_popup = PanelContainer.new()
	steal_popup.visible = false
	steal_popup.set_anchors_preset(Control.PRESET_CENTER)
	steal_popup.offset_left = -200
	steal_popup.offset_right = 200
	steal_popup.offset_top = -160
	steal_popup.offset_bottom = 160
	steal_popup.z_index = 70
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.18, 0.95)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
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
	steal_popup.set_meta("_btn_vbox", vbox)
	add_child(steal_popup)

func _build_ec_choice_popup():
	ec_choice_popup = PanelContainer.new()
	ec_choice_popup.visible = false
	ec_choice_popup.set_anchors_preset(Control.PRESET_CENTER)
	ec_choice_popup.offset_left = -250
	ec_choice_popup.offset_right = 250
	ec_choice_popup.offset_top = -250
	ec_choice_popup.offset_bottom = 250
	ec_choice_popup.z_index = 80
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.2, 0.2, 0.98)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	ec_choice_popup.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	ec_choice_popup.add_child(vbox)
	var title = Label.new()
	title.text = "Environmental Consultant:\nChoose a Role Ability to Borrow"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.8))
	vbox.add_child(title)
	ec_choice_popup.set_meta("_vbox", vbox)
	add_child(ec_choice_popup)

func show_ec_choice_popup() -> void:
	var vbox = ec_choice_popup.get_meta("_vbox")
	# Clear previously added buttons (keep title at index 0)
	while vbox.get_child_count() > 1:
		vbox.get_child(vbox.get_child_count() - 1).queue_free()

	var borrowable_roles = [
		"Plantation Owner",
		"Government",
		"Conservationist",
		"Land Developer",
		"Wildlife Department",
		"Village Head",
		"Researcher",
	]

	for role in borrowable_roles:
		var btn = Button.new()
		btn.text = role
		btn.pressed.connect(func():
			GameState.ec_borrowed_ability = role
			ec_choice_popup.visible = false
			# Update the special ability button tooltip to reflect the chosen ability
			if special_ability_btn:
				special_ability_btn.tooltip_text = "Use: " + role
		)
		vbox.add_child(btn)

	ec_choice_popup.visible = true

func _build_em_choice_popup():

	em_choice_popup = PanelContainer.new()
	em_choice_popup.visible = false
	em_choice_popup.set_anchors_preset(Control.PRESET_CENTER)
	em_choice_popup.offset_left = -220
	em_choice_popup.offset_right = 220
	em_choice_popup.offset_top = -150
	em_choice_popup.offset_bottom = 150
	em_choice_popup.z_index = 80
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.15, 0.25, 0.97)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	em_choice_popup.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	em_choice_popup.add_child(vbox)
	var title = Label.new()
	title.text = "Ecotourism Manager Action"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	em_choice_popup.set_meta("_vbox", vbox)
	add_child(em_choice_popup)

func _build_role_ability_dropdown():
	ability_dropdown_btn = Button.new()
	ability_dropdown_btn.text = "Role Ability ▾"
	ability_dropdown_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ability_dropdown_btn.offset_right = -20
	ability_dropdown_btn.offset_left = -210
	ability_dropdown_btn.offset_top = 115
	ability_dropdown_btn.offset_bottom = 145
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.2, 0.28, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	ability_dropdown_btn.add_theme_stylebox_override("normal", style)
	ability_dropdown_btn.pressed.connect(_toggle_ability_dropdown)
	add_child(ability_dropdown_btn)
	
	ability_dropdown_panel = PanelContainer.new()
	ability_dropdown_panel.visible = false
	ability_dropdown_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ability_dropdown_panel.offset_right = -20
	ability_dropdown_panel.offset_left = -420   # widened to fit role card image
	ability_dropdown_panel.offset_top = 150
	ability_dropdown_panel.z_index = 80
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	pstyle.content_margin_left = 15
	pstyle.content_margin_right = 15
	pstyle.content_margin_top = 12
	pstyle.content_margin_bottom = 12
	ability_dropdown_panel.add_theme_stylebox_override("panel", pstyle)

# HBox: role card image on the left, text on the right
	var hbox = HBoxContainer.new()
	hbox.name = "DropdownHBox"
	hbox.add_theme_constant_override("separation", 14)
	ability_dropdown_panel.add_child(hbox)

	# Role card TextureRect
	var tex_rect = TextureRect.new()
	tex_rect.name = "RoleCardImage"
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(80, 112)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # ← was IGNORE, must be STOP to receive clicks
	tex_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
			
			if tex_rect.texture != null:
				_show_role_card_overlay(tex_rect.texture)
	)
	hbox.add_child(tex_rect)

	# Ability text label
	var lbl = Label.new()
	lbl.name = "AbilityText"
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)

	add_child(ability_dropdown_panel)

func _toggle_ability_dropdown():
	ability_dropdown_panel.visible = !ability_dropdown_panel.visible
	ability_dropdown_btn.text = "Role Ability ▴" if ability_dropdown_panel.visible else "Role Ability ▾"
	_refresh_role_panel_ui()
	
func _refresh_role_panel_ui():
	var cur = GameState.player_roles[GameState.current_player_index] \
		if GameState.current_player_index < GameState.player_roles.size() else "Unknown"

	ability_dropdown_panel.get_node("DropdownHBox/AbilityText").text = ROLE_ABILITIES.get(cur, "")

	var tex_rect: TextureRect = ability_dropdown_panel.get_node("DropdownHBox/RoleCardImage")
	var tex_path = "res://assets/Role Card/%s.png" % cur
	tex_rect.texture = load(tex_path) if ResourceLoader.exists(tex_path) else null

		
var _trackers_reordered: bool = false

func _process(_delta):
	if is_game_over: return
	if not _trackers_reordered and not GameState.player_roles.is_empty():
		_reorder_trackers_by_player_order()
		_trackers_reordered = true
	_hide_all_trackers()
	_update_goals()

# Reorder the tracker panels inside trackers_vbox so they appear in player
# order (Player 1's role on top, Player 2's next, etc.). Trackers belonging
# to roles that are not in the current game keep their original position
# below the in-game ones — they stay hidden anyway.
func _reorder_trackers_by_player_order() -> void:
	var role_to_panel := {
		"Conservationist": cons_tracker_panel,
		"Village Head": vh_tracker_panel,
		"Plantation Owner": po_tracker_panel,
		"Land Developer": ld_tracker_panel,
		"Environmental Consultant": ec_tracker_panel,
		"Ecotourism Manager": em_tracker_panel,
		"Wildlife Department": wd_tracker_panel,
		"Researcher": res_tracker_panel,
		"Government": gov_tracker_panel,
	}
	var idx := 0
	for role in GameState.player_roles:
		var panel: PanelContainer = role_to_panel.get(role, null)
		if panel and panel.get_parent():
			panel.get_parent().move_child(panel, idx)
			idx += 1

func _hide_all_trackers():
	for p in [cons_tracker_panel, vh_tracker_panel, po_tracker_panel, ld_tracker_panel, ec_tracker_panel, em_tracker_panel, wd_tracker_panel, res_tracker_panel, gov_tracker_panel]:
		if p: p.visible = false

func _update_goals():
	# Conservationist
	var idx = GameState.player_roles.find("Conservationist")
	if idx != -1:
		cons_tracker_panel.visible = true
		var g = GameState.player_stats[idx]["green_cards_played"]
		var f = GameState.get_forest_increase()
		cons_green_label.text = "Green Cards: %d / 4" % g
		cons_forest_label.text = "Forest Increase: %d / 2" % f
		if g >= 4 and f >= 2: _trigger_win(idx, "Conservationist")

	# Village Head
	idx = GameState.player_roles.find("Village Head")
	if idx != -1:
		vh_tracker_panel.visible = true
		var a = GameState.player_stats[idx]["action_cards_played"]
		var p = GameState.get_total_villagers()
		vh_cards_label.text = "Action Cards: %d / 7" % a
		vh_pop_label.text = "Population: %d / 16" % p
		if a >= 7 and p >= 16: _trigger_win(idx, "Village Head")

	# Plantation Owner
	idx = GameState.player_roles.find("Plantation Owner")
	if idx != -1:
		po_tracker_panel.visible = true
		var s = GameState.player_stats[idx]
		var g = s.get("green_cards_played",0); var r = s.get("red_cards_played",0); var y = s.get("yellow_cards_played",0)
		var p = GameState.get_plantation_increase()
		po_cards_label.text = "Cards: %dG, %dR, %dY / 2G, 1R, 1Y" % [g, r, y]
		po_plant_label.text = "Plantations: %d / 2" % p
		if g >= 2 and r >= 1 and y >= 1 and p >= 2: _trigger_win(idx, "Plantation Owner")

	# Land Developer
	idx = GameState.player_roles.find("Land Developer")
	if idx != -1:
		ld_tracker_panel.visible = true
		var s = GameState.player_stats[idx]
		var g = s.get("green_cards_played", 0); var r = s.get("red_cards_played", 0); var y = s.get("yellow_cards_played", 0)
		var h = GameState.get_human_increase()
		ld_cards_label.text = "Cards: %dG, %dR, %dY / (2G+2R) or (2Y+2R)" % [g, r, y]
		ld_human_label.text = "Human Areas: %d / 2" % h
		if ((g >= 2 and r >= 2) or (y >= 2 and r >= 2)) and h >= 2: _trigger_win(idx, "Land Developer")

	# Environmental Consultant
	idx = GameState.player_roles.find("Environmental Consultant")
	if idx != -1:
		ec_tracker_panel.visible = true
		var s = GameState.player_stats[idx]
		var g = s.get("green_cards_played", 0); var r = s.get("red_cards_played", 0)
		var v = GameState.count_vacant_secondary_met()
		ec_cards_label.text = "Cards: %dG, %dR / 2G, 2R" % [g, r]
		ec_vacant_label.text = "Vacant Goals Met: %d / 2" % v
		if g >= 2 and r >= 2 and v >= 2: _trigger_win(idx, "Environmental Consultant")

	# Ecotourism Manager
	idx = GameState.player_roles.find("Ecotourism Manager")
	if idx != -1:
		em_tracker_panel.visible = true
		var s = GameState.player_stats[idx]
		var g = s.get("green_cards_played", 0); var y = s.get("yellow_cards_played", 0)
		var d = GameState.get_shortest_distance_human_elephant()
		var total_e = 0
		for key in GameState.tile_registry:
			if GameState.tile_registry[key]["elephant_nodes"].size() > 0: total_e += 1
		var cond_dist = (total_e > 0 and d >= 3)
		em_cards_label.text = "Cards: %dG, %dY / 3G, 2Y" % [g, y]
		em_elephants_label.text = "Elephants / Dist: %s / %s" % ["Yes" if total_e > 0 else "No", str(d) if d != -1 else "N/A"]
		if g >= 3 and y >= 2 and cond_dist: _trigger_win(idx, "Ecotourism Manager")

	# Wildlife Department
	idx = GameState.player_roles.find("Wildlife Department")
	if idx != -1:
		wd_tracker_panel.visible = true
		var g = GameState.player_stats[idx]["green_cards_played"]
		var e = GameState.get_elephants_in_forest()
		wd_cards_label.text = "Green Cards: %d / 4" % g
		wd_elephants_label.text = "Forest Elephants: %d / 4" % e
		if g >= 4 and e >= 4: _trigger_win(idx, "Wildlife Department")

	# Researcher
	idx = GameState.player_roles.find("Researcher")
	if idx != -1:
		res_tracker_panel.visible = true
		var s = GameState.player_stats[idx]
		var ei = s.get("e_inc_cards", 0); var vi = s.get("v_inc_cards", 0); var both = s.get("both_inc_cards", 0)
		var d = GameState.get_shortest_distance_human_elephant()
		res_cards_label.text = "+Ele|+Hum|+Both: %d/%d/%d (Goal 2/3/0)" % [ei, vi, both]
		res_tiles_label.text = "Separation: %s (Goal >= 2)" % [str(d) if d != -1 else "N/A"]
		if ei >= 2 and vi >= 3 and d >= 2: _trigger_win(idx, "Researcher")

	# Government
	idx = GameState.player_roles.find("Government")
	if idx != -1:
		gov_tracker_panel.visible = true
		var s = GameState.player_stats[idx]
		var r = s.get("red_cards_played", 0); var y = s.get("yellow_cards_played", 0)
		var v_pop = GameState.get_total_villagers()
		var total_e = 0
		for key in GameState.tile_registry:
			total_e += GameState.tile_registry[key]["elephant_nodes"].size()
		gov_cards_label.text = "Cards: %dR, %dY / 2R, 2Y" % [r, y]
		gov_ratio_label.text = "Villagers / Elephants: %d / %d (Goal v>=2e)" % [v_pop, total_e]
		if r >= 2 and y >= 2 and v_pop >= (2 * total_e): _trigger_win(idx, "Government")

func _on_window_resize(): reposition_cards()

func reposition_cards():
	var screen_size = get_viewport_rect().size
	var cards = []
	for c in cards_container.get_children():
		if not c.is_queued_for_deletion(): cards.append(c)
	if cards.is_empty(): return
	var start_x = (screen_size.x - (cards.size() - 1) * CARD_SPACING) / 2.0
	for i in range(cards.size()):
		var card = cards[i]
		if card == pending_card: continue
		card.position = Vector2(start_x + (i * CARD_SPACING) - (card.get_size().x / 2.0), screen_size.y - card.get_size().y - BOTTOM_MARGIN)
		card.original_position = card.position

func _on_timer_timeout():
	time_left -= 1
	if time_left < 0: end_turn_requested.emit()
	else: timer_label.text = str(time_left)

func spawn_players():
	for i in range(1, GameState.player_count):
		var player = PLAYER_DISPLAY_SCENE.instantiate()

func spawn_cards():
	for child in cards_container.get_children(): child.queue_free()
	pending_card = null
	var hand = GameState.player_hands[GameState.current_player_index]
	for card_id in hand:
		var card = CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.set_card_data(card_id)
		card.card_selected.connect(_on_card_selected)
		# If a bot is taking this turn, the displayed hand belongs to the bot —
		# the human player must not be able to click or interact with it.
		if bot_turn_active:
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.is_selected = true  # blocks Card._on_gui_input from re-firing
	call_deferred("reposition_cards")

func _on_card_selected(selected_card):
	if bot_turn_active: return
	if not play_card: return
	var p_idx = GameState.current_player_index
	var r_name = GameState.player_roles[p_idx]
	# Only 1 card may be played per turn for every role.
	var max_c = 1
	if cards_played_this_turn >= max_c: return

	# Black card rule: if the player has any black cards in hand, they MUST
	# play a black card and cannot select anything else this turn. Mirrors the
	# bot's enforcement in bot.gd._bot_take_turn.
	var hand_has_black := false
	for cid in GameState.player_hands[p_idx]:
		if CardData.ALL_CARDS.get(cid, {}).get("color", Color.WHITE) == Color.BLACK:
			hand_has_black = true
			break
	if hand_has_black:
		var sel_color = CardData.ALL_CARDS.get(selected_card.card_id, {}).get("color", Color.WHITE)
		if sel_color != Color.BLACK:
			show_instruction("You must play your black card this turn.")
			return

	# Village Head constraints
	if max_c == 2 and cards_played_this_turn == 1:
		var data = CardData.ALL_CARDS.get(selected_card.card_id, {})
		if not data.get("color", Color.WHITE) in [Color.GREEN, Color.YELLOW, Color.RED]: return
		var adds_v = false
		for fx in data.get("sub_effects", []):
			if fx.get("op", "") in ["add_v", "add_v_in"]: adds_v = true; break
		if adds_v and vh_villagers_increased_this_turn: return
	
	if r_name == "Village Head" and GameState.player_hands[p_idx].size() <= 1 and pending_card == null:
		show_instruction("Village Head must keep at least 1 card in hand.")
		return

	if currently_viewing_card and pending_card:
		var old = pending_card
		old.is_selected = false
		old.z_index = 0
		var t = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		t.tween_property(old, "position", old.original_position, 0.5)
		t.tween_property(old, "scale", Vector2(1,1), 0.5)
	
	currently_viewing_card = true
	pending_card = selected_card
	selected_card.original_position = selected_card.position
	selected_card.z_index = 10
	var win_size = get_viewport_rect().size
	var scale_factor := Vector2(4.0, 4.0)
	# Card.tscn has pivot_offset set to the card's centre, so scaling happens
	# around the card's midpoint. With a centre pivot, the card's centre after
	# scaling is always at `position + pivot_offset` (scale doesn't shift it),
	# so to put that centre at the viewport centre we just need:
	#     position = viewport_centre - pivot_offset
	var target_pos: Vector2 = win_size / 2.0 - selected_card.pivot_offset
	var tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(selected_card, "position", target_pos, 0.5)
	tween.tween_property(selected_card, "scale", scale_factor, 0.5)
	play_btn.disabled = false

func _on_play_btn_pressed():
	if bot_turn_active: return
	if _play_btn_is_end_turn:
		end_turn_requested.emit()
		return

	if not pending_card: return
	var p_idx = GameState.current_player_index
	var r_name = GameState.player_roles[p_idx]
	if (r_name == "Village Head" or (r_name == "Environmental Consultant" and GameState.ec_borrowed_ability == "Village Head")):
		for fx in CardData.ALL_CARDS.get(pending_card.card_id, {}).get("sub_effects", []):
			if fx.get("op", "") in ["add_v", "add_v_in"]: vh_villagers_increased_this_turn = true; break

	if r_name == "Government" and pending_card.card_id in GameState.government_stolen_cards.get(p_idx, []):
		GameState.government_mark_replayed(pending_card.card_id)

	var cid = pending_card.card_id
	pending_card.queue_free()
	pending_card = null
	currently_viewing_card = false
	cards_played_this_turn += 1
	add_recent_card_for_player(GameState.current_player_index, cid)

	# Only 1 card may be played per turn for every role.
	var max_cards = 1
	if cards_played_this_turn >= max_cards:
		_switch_to_end_turn_mode()  # button becomes disabled End Turn, enabled by set_end_turn_ready()
	else:
		# Still has cards to play — reset play button so they can select and play another
		play_btn.disabled = true
		currently_viewing_card = false

	card_activated.emit(cid)

func _close_all_popups() -> void:
	# Dismiss any selection popups that may still be open from the previous
	# turn so a new turn always starts with a clean UI.
	if steal_popup: steal_popup.visible = false
	if em_choice_popup: em_choice_popup.visible = false
	if ec_choice_popup: ec_choice_popup.visible = false
	if wildlife_discard_popup: wildlife_discard_popup.visible = false
	var steal_node = get_node_or_null("Steal")
	if steal_node: steal_node.visible = false
	var convert_popup = get_node_or_null("_convert_type_popup")
	if convert_popup: convert_popup.visible = false
	hide_instruction()

func _on_turn_changed(player_index: int, role_name: String, is_skipped: bool):
	_close_all_popups()
	play_card = not is_skipped
	cards_played_this_turn = 0
	time_left = 60
	if timer_label:
		timer_label.text = str(time_left)
	if is_skipped:
		_switch_to_end_turn_mode()
		timer_label.text = "Skipped"

	var skip_label = $Skipped
	if skip_label:
		skip_label.visible = is_skipped

	vh_villagers_increased_this_turn = false
	po_used_ability_this_turn = false
	gov_used_ability_this_turn = false
	cons_used_ability_this_turn = false
	ld_used_ability_this_turn = false
	ec_used_ability_this_turn = false
	player_role = role_name
	user_role_label.text = "Player %d | %s" % [player_index + 1, role_name]

	var _has_ability = role_name in ["Plantation Owner", "Government", "Conservationist", "Land Developer", "Environmental Consultant"]
	special_ability_btn.visible = _has_ability and not is_skipped

	var _is_wd = (role_name == "Wildlife Department") or (role_name == "Environmental Consultant" and GameState.ec_borrowed_ability == "Wildlife Department")
	if _is_wd and not is_skipped:
		GameState.wildlife_dept_draw_bonus(player_index)

	# Only reset to play mode for an active human turn. Skip when:
	#  - bot_turn_active: bot._on_turn_changed already fired bot_turn_started
	#    and put the button into the disabled End Turn state earlier in this
	#    same dispatch — we must not clobber that.
	#  - is_skipped: the earlier `if is_skipped:` block already switched the
	#    button to End Turn for the skipped player; resetting to Play here
	#    would undo that.
	# bot_turn_active is cleared in _on_bot_turn_ended, not here.
	if not bot_turn_active and not is_skipped:
		_switch_to_play_mode()
	spawn_cards()

func hide_instruction():
	if instruction_label:
		instruction_label.get_parent().visible = false

func show_wildlife_discard_popup():
	var drawn = GameState.wildlife_dept_drawn_cards
	if drawn.is_empty(): end_turn_requested.emit(); return
	var vbox = wildlife_discard_popup.get_meta("_vbox")
	while vbox.get_child_count() > 2: vbox.get_child(vbox.get_child_count()-1).queue_free()
	for cid in drawn:
		var btn = Button.new()
		btn.text = CardData.ALL_CARDS.get(cid,{}).get("name", cid)
		btn.pressed.connect(func():
			wildlife_discard_popup.visible = false
			GameState.wildlife_dept_discard_bonus(GameState.current_player_index, cid)
			GameState.wildlife_dept_drawn_cards.clear()
			spawn_cards()
			end_turn_requested.emit()
		)
		vbox.add_child(btn)
	wildlife_discard_popup.visible = true

func show_player_select_popup(title_text, disabled_func, callback):
	var vbox = steal_popup.get_meta("_btn_vbox")
	vbox.get_child(0).text = title_text
	while vbox.get_child_count() > 1: vbox.get_child(vbox.get_child_count()-1).queue_free()
	for i in range(GameState.player_count):
		if i == GameState.current_player_index: continue
		var btn = Button.new()
		btn.text = "Player %d - %s" % [i+1, GameState.player_roles[i]]
		btn.disabled = disabled_func.call(i)
		btn.pressed.connect(func():
			steal_popup.visible = false
			callback.call(i)
		)
		vbox.add_child(btn)
	steal_popup.visible = true


func spawn_stolen_gov_card():
	# Mark stolen card with tint
	spawn_cards() # refresh
	for c in cards_container.get_children():
		if c.card_id in GameState.government_stolen_cards.get(GameState.current_player_index,[]):
			c.modulate = Color(1.3, 1.1, 0.5, 1.0)

func show_em_choice_popup(callback):
	var vbox = em_choice_popup.get_meta("_vbox")
	while vbox.get_child_count() > 1: vbox.get_child(vbox.get_child_count()-1).queue_free()
	for opt in [{"t":"🐘 Elephant","v":"elephant"},{"t":"🧑 Villager","v":"villager"},{"t":"Skip","v":"skip"}]:
		var b = Button.new(); b.text = opt.t
		b.pressed.connect(func():
			em_choice_popup.visible = false
			callback.call(opt.v)
		)
		vbox.add_child(b)
	em_choice_popup.visible = true

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

	# Fullscreen click-blocker drawn behind the panel. Absorbs every mouse
	# event before it can reach _unhandled_input on the camera or card_table,
	# so the 3D board cannot be interacted with while the overlay is open.
	# Slight dim for visual feedback that the rest of the UI is inert.
	recent_cards_overlay_blocker = ColorRect.new()
	recent_cards_overlay_blocker.name = "_recent_cards_overlay_blocker"
	recent_cards_overlay_blocker.color = Color(0, 0, 0, 0.45)
	recent_cards_overlay_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	recent_cards_overlay_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	recent_cards_overlay_blocker.visible = false
	recent_cards_overlay_blocker.z_index = 89  # one below the panel
	add_child(recent_cards_overlay_blocker)

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
	root_vbox.add_theme_constant_override("separation", 3)
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

	# Push the toggle button to the end of the sibling order so it's drawn
	# (and receives input) on top of the fullscreen blocker. Without this,
	# the blocker — which is added after the button — would absorb clicks on
	# the button area while the overlay is open, and the user could not close
	# the overlay by clicking the button again.
	move_child(recent_cards_toggle_button, get_child_count() - 1)

func _toggle_recent_cards_overlay() -> void:
	if recent_cards_overlay_panel == null:
		return
	recent_cards_overlay_panel.visible = not recent_cards_overlay_panel.visible
	# Show/hide the fullscreen click-blocker in lockstep so all board input is
	# absorbed by GUI dispatch before reaching _unhandled_input.
	if recent_cards_overlay_blocker:
		recent_cards_overlay_blocker.visible = recent_cards_overlay_panel.visible
	# Lock background camera rotation while the overlay is open as a second
	# line of defence (covers Q/E key rotation, which the GUI blocker cannot
	# absorb since keys aren't routed by mouse hit-testing).
	_set_camera_rotation_locked(recent_cards_overlay_panel.visible)
	if recent_cards_overlay_panel.visible:
		_rebuild_recent_cards_overlay()
	else:
		_clear_recent_cards_preview()

func _set_camera_rotation_locked(locked: bool) -> void:
	# UI is at $CanvasLayer/Control under card_table; the camera lives at
	# card_table/Camera3D. Walk up to the card_table root and grab it.
	var card_table_root: Node = get_parent()
	while card_table_root and not card_table_root.has_node("Camera3D"):
		card_table_root = card_table_root.get_parent()
	if card_table_root == null:
		return
	var cam: Node = card_table_root.get_node_or_null("Camera3D")
	if cam == null:
		return
	if "rotation_locked" in cam:
		cam.rotation_locked = locked
	if "zoom_locked" in cam:
		cam.zoom_locked = locked

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
		header.text = "You (Player 1)" if player_index == 0 else "Player %d" % [player_index + 1]
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25) if player_index == 0 else Color(0.92, 0.92, 0.92))
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



func _set_play_btn_disabled(disabled: bool) -> void:
	play_btn.disabled = disabled

func _switch_to_end_turn_mode() -> void:
	_play_btn_is_end_turn = true
	play_btn.texture_normal   = TEX_END_NORMAL
	play_btn.texture_pressed  = TEX_END_NORMAL
	play_btn.texture_hover    = TEX_END_NORMAL
	play_btn.texture_disabled = TEX_END_DISABLED
	play_btn.texture_focused  = TEX_END_NORMAL
	play_btn.disabled = true  # stays disabled until set_end_turn_ready() is called after effects resolve

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

# --- Bot turn lock ---

func _on_bot_turn_started() -> void:
	bot_turn_active = true
	# Show the End Turn texture (disabled) for the entire bot turn so the player
	# can see "End Turn" instead of "Play". The button stays disabled — only the
	# bot itself can end its own turn via _on_bot_turn_ended.
	_switch_to_end_turn_mode()
	# Block input on every currently-displayed card so the player cannot click
	# the bot's hand. spawn_cards() also applies this when it runs after the
	# signal, but doing it here too covers any ordering edge case.
	if cards_container:
		for card in cards_container.get_children():
			if card is Control:
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if "is_selected" in card:
					card.is_selected = true

func _on_bot_turn_ended() -> void:
	bot_turn_active = false

# --- Instruction label (shown during tile selection) ---

func show_instruction(text: String) -> void:
	if instruction_label:
		instruction_label.text = text
		instruction_label.get_parent().visible = true

func show_steal_popup(card_effects_node: Node) -> void:
	var steal_node = get_node_or_null("Steal")
		
	if not steal_node:
		print("Steal popup not working")
		return

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
