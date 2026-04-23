## Top-level UI for the game board (everything on screen except the 3D board).
##
## Handles the player's hand, the Play / End Turn button, the turn timer,
## the Special Ability button, goal tracker panels, the Played Cards
## overlay, the Win screen, and every popup (steal target, EC borrow, EM
## choice, Wildlife discard, Land-Use Planning type pick). Card-effect
## logic lives in CardEffects.gd; turn-advancing and piece spawning live in
## card_table.gd. This script only turns clicks into signals for them to act on.
extends Control

## Emitted when the player confirms a card (clicked Play).
signal card_activated(card_id: String)
## Emitted when the player manually presses the End Turn button.
signal end_turn_requested()
## Emitted when the turn timer runs out. Handled separately so end-of-turn
## cleanup (Wildlife discard, auto-complete) can differ from a normal click.
signal end_turn_timer_expired()
## One signal per button-ability role. card_table.gd connects these to the
## right CardEffects call.
signal request_po_ability()
signal request_gov_ability()
signal request_cons_ability()
signal request_ld_ability()
signal request_ec_ability()
signal request_em_ability()

const CARD_SCENE = preload("res://scenes/Card.tscn")
## Maximum cards a player can hold in their hand.
const TOTAL_CARDS = 5
## Horizontal gap between cards in the hand.
const CARD_SPACING = 200.0
## Distance from the bottom of the screen to the hand row.
const BOTTOM_MARGIN = 50.0

@onready var cards_container = $CardsContainer
@onready var players_container = $TopBar/PlayersContainer
@onready var user_role_label = $UserRoleLabel
@onready var timer_label = $TopBar/TimerLabel
@onready var turn_timer = $TurnTimer
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
var is_bot_turn: bool = false
var currently_viewing_card: bool = false
var bot_turn_active: bool = false
var vh_villagers_increased_this_turn: bool = false
var vh_used_ability_this_turn: bool = false
var po_used_ability_this_turn: bool = false

@onready var special_ability_btn = $"Special Abitlity"
var gov_used_ability_this_turn: bool = false
var cons_used_ability_this_turn: bool = false
var ld_used_ability_this_turn: bool = false
var ec_used_ability_this_turn: bool = false
var em_used_ability_this_turn: bool = false
var ec_choice_popup: PanelContainer = null

# Goal trackers — one panel per player slot, populated via RoleEffect.compute_goal.
# Each entry is { panel: PanelContainer, title: Label, line1: Label, line2: Label,
# status: Label, role: String, image: TextureRect }.
var _player_tracker_panels: Array = []
var _trackers_vbox_ref: VBoxContainer = null

# Winning Screen
var win_screen_panel: PanelContainer = null
var win_screen_label: Label = null
var is_game_over: bool = false

# Role card overlay
var _role_card_overlay: ColorRect = null
var _role_card_overlay_rect: TextureRect = null
var _role_card_overlay_tween: Tween = null

# Popups
var em_choice_popup: PanelContainer = null
var wildlife_discard_popup: PanelContainer = null

# Role ability dropdown
var ability_dropdown_btn: Button = null
var ability_dropdown_panel: PanelContainer = null

const ROLE_ABILITIES: Dictionary = {
	"Wildlife Department": "Draw 2 bonus cards (any colour) at the start of your turn. Discard 1 before ending the turn.",
	"Conservationist":     "Special: Once per turn as an extra action, convert 1 non-forest tile adjacent to a forested tile with an elephant into Forest.\nWin by playing at least 4 Green cards AND increasing forested area by 2 tiles.",
	"Village Head":        "Special: Activate to play a 2nd colored card this turn (max 1 can increase villagers). Must keep >= 1 card in hand.\nWin by playing cards that increase villagers (x2) AND removing 2 constraints.",
	"Plantation Owner":    "Special: Instead of drawing, steal a played colored card, reverse its effects, and play it immediately. Uses your turn action.\nWin by playing 2G + 1R + 1Y cards AND increasing plantation tiles by 2.",
	"Land Developer":      "Special: Once per turn as an extra action, convert 1 non-human tile with at least 3 human-dominated neighbours into a Human-Dominated tile.\nWin by playing (2G+2R) or (2Y+2R) AND increasing human-dominated areas by 2.",
	"Environmental Consultant": "Special: At game start, borrow one special ability from another chosen role and use it for the whole game.\nWin by playing 2G + 2R AND satisfying 2 vacant secondary role goals.",
	"Ecotourism Manager":  "Special: For your played black, yellow, red or green cards that increase elephants or humans, as an extra action, you may choose to move an elephant or a human in your chosen direction.\nWin by playing 3G + 2Y, keeping at least 1 elephant alive with distance >= 3 from humans.",
	"Researcher":          "Special: Played Action cards that add elephants let you move an equal number of elephants.\nWin by playing cards that increase elephants (x2) and villagers (x3) while keeping them >= 2 tiles apart.",
	"Government":          "Special: Instead of drawing a card, steal any played Yellow, Red, or Green card from another player. You may replay it on your current or later turns (once per card).\nWin by playing 2R + 2Y cards AND having Villagers >= 2x Elephants on the board.",
}

## Wires up button signals, the turn timer, the window-resize handler, and
## builds all of the runtime UI widgets (popups, overlays, trackers, win screen).
func _ready():
	pause_btn.pressed.connect(_pause)
	play_btn.pressed.connect(_on_play_btn_pressed)
	special_ability_btn.pressed.connect(_on_special_ability_pressed)
	special_ability_btn.visible = false
	if user_role_label:
		user_role_label.visible = false

	turn_timer.timeout.connect(_on_timer_timeout)
	get_tree().root.size_changed.connect(_on_window_resize)

	_init_all_ui_elements()
	

func _pause():
	var pause_menu = $PauseMenu
	if pause_menu:
		pause_menu.toggle_pause()
		return

func _init_all_ui_elements():
	if has_node("TopBar/TimerLabel"):
		timer_label.set_anchors_preset(Control.PRESET_CENTER)
		timer_label.offset_left = -50
		timer_label.offset_right = 50
	
	if has_node("TopBar/PlayersContainer"):
		var pcon = get_node("TopBar/PlayersContainer")
		pcon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		pcon.offset_left = -1000
		pcon.offset_right = -260
		pcon.offset_top = 0
		pcon.offset_bottom = 60
		pcon.alignment = BoxContainer.ALIGNMENT_END

	_build_instruction_banner()
	_setup_recent_cards_overlay_ui()
	_build_all_trackers()
	_build_win_screen()
	_build_wildlife_discard_popup()
	_build_ec_choice_popup()
	_build_em_choice_popup()
	_build_role_ability_dropdown()
	_build_role_card_overlay()

	_update_dropdown_btn_text()

func _build_role_card_overlay(): #appears in the middle of the screen when a role card is pressed
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

func _show_role_card_overlay(tex: Texture2D): # to show
	_role_card_overlay_rect.texture = tex
	_role_card_overlay.modulate = Color(1, 1, 1, 0)
	_role_card_overlay_rect.scale = Vector2(0.1, 0.1)
	_role_card_overlay.visible = true
	if _role_card_overlay_tween:
		_role_card_overlay_tween.kill()
	_role_card_overlay_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_role_card_overlay_tween.tween_property(_role_card_overlay, "modulate", Color(1, 1, 1, 1), 0.3)
	_role_card_overlay_tween.tween_property(_role_card_overlay_rect, "scale", Vector2(1, 1), 0.4)

func _hide_role_card_overlay(): # to hide
	if _role_card_overlay_tween:
		_role_card_overlay_tween.kill()
	_role_card_overlay_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_role_card_overlay_tween.tween_property(_role_card_overlay, "modulate", Color(1, 1, 1, 0), 0.25)
	_role_card_overlay_tween.tween_property(_role_card_overlay_rect, "scale", Vector2(0.1, 0.1), 0.25)
	await _role_card_overlay_tween.finished
	_role_card_overlay.visible = false

func _build_instruction_banner(): #intrustion banner is on the top middle with black background and yellow words
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

func _build_all_trackers(): #trackers are the ones under objective
	var right_margin = MarginContainer.new()
	right_margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	right_margin.offset_left = 20
	right_margin.offset_right = 320
	right_margin.offset_top = 55
	right_margin.offset_bottom = 300
	right_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_margin.visible = false # Hidden initially
	
	var trackers_vbox = VBoxContainer.new()
	trackers_vbox.add_theme_constant_override("separation", 15)
	trackers_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	trackers_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_margin.add_child(trackers_vbox)
	add_child(right_margin)

	var trackers_toggle_btn = Button.new()
	trackers_toggle_btn.text = "Objectives ▾"
	trackers_toggle_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	trackers_toggle_btn.offset_right = 160
	trackers_toggle_btn.offset_left = 20
	trackers_toggle_btn.offset_top = 10
	trackers_toggle_btn.offset_bottom = 50
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.2, 0.28, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	trackers_toggle_btn.add_theme_stylebox_override("normal", style)
	trackers_toggle_btn.z_index = 10
	
	trackers_toggle_btn.pressed.connect(func():
		right_margin.visible = !right_margin.visible
		trackers_toggle_btn.text = "Objectives ▴" if right_margin.visible else "Objectives ▾"
	)
	add_child(trackers_toggle_btn)

	# Build tracker panel per player slot. The role-specific

	_trackers_vbox_ref = trackers_vbox

# Holds a reference to the trackers VBox built in the same function as the panels.
## Creates one goal-tracker panel per player slot. Called from card_table.gd
## after roles are assigned.
func build_player_trackers() -> void:
	if _trackers_vbox_ref == null:
		return
	for entry in _player_tracker_panels:
		if entry.has("panel") and is_instance_valid(entry["panel"]):
			entry["panel"].queue_free()
	_player_tracker_panels.clear()

	for i in range(GameState.player_count):
		var role: String = GameState.player_roles[i] if i < GameState.player_roles.size() else ""
		var entry := _create_player_tracker_panel(i, role)
		_trackers_vbox_ref.add_child(entry["panel"])
		_player_tracker_panels.append(entry)

# Create one tracker panel for each player
func _create_player_tracker_panel(player_index: int, role: String) -> Dictionary:
	var title_color: Color = RoleEffect.goal_color(role)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.88)
	style.border_width_left = 4
	style.border_color = title_color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 3
	style.shadow_offset = Vector2(1, 2)
	panel.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)

	# Role card image on the left
	var image_rect: TextureRect = null
	if role != "":
		var tex: Texture2D = null
		var tex_path = "res://assets/Role Card/%s.png" % role
		if ResourceLoader.exists(tex_path):
			tex = load(tex_path)
		elif ResourceLoader.exists("res://assets/Roles/%s.png" % role):
			tex = load("res://assets/Roles/%s.png" % role)
		if tex != null:
			image_rect = TextureRect.new()
			image_rect.texture = tex
			image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image_rect.custom_minimum_size = Vector2(60, 80)
			image_rect.mouse_filter = Control.MOUSE_FILTER_STOP
			var captured_tex := tex
			image_rect.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
					_show_role_card_overlay(captured_tex)
			)
			hbox.add_child(image_rect)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_vbox.add_theme_constant_override("separation", 8)
	hbox.add_child(inner_vbox)

	var title_label := Label.new()
	title_label.text = "Player %d — %s" % [player_index + 1, RoleEffect.goal_title(role)]
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", title_color)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(title_label)

	var line1 := Label.new()
	line1.add_theme_font_size_override("font_size", 12)
	inner_vbox.add_child(line1)

	var line2 := Label.new()
	line2.add_theme_font_size_override("font_size", 12)
	inner_vbox.add_child(line2)

	var status := Label.new()
	status.text = "In Progress"
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(status)

	return {
		"panel": panel,
		"title": title_label,
		"line1": line1,
		"line2": line2,
		"status": status,
		"role":  role,
		"image": image_rect,
	}

## Runs when the Special Ability button is clicked. Emits the right
## request_*_ability signal based on the current player's role and marks
## the per-turn used flag.
func _on_special_ability_pressed():
	if is_bot_turn:
		return
	# Environmental Consultant always opens the borrow popup
	if player_role == RoleEffect.ENVIRONMENTAL_CONSULT:
		request_ec_ability.emit()
		return
	if not RoleEffect.can_use_button(player_role, self):
		return
	match player_role:
		RoleEffect.PLANTATION_OWNER:    request_po_ability.emit()
		RoleEffect.GOVERNMENT:          request_gov_ability.emit()
		RoleEffect.CONSERVATIONIST:     request_cons_ability.emit()
		RoleEffect.LAND_DEVELOPER:      request_ld_ability.emit()
		RoleEffect.ECOTOURISM_MANAGER:  request_em_ability.emit()
		RoleEffect.VILLAGE_HEAD:
			vh_used_ability_this_turn = true
			show_instruction("Village Head ability activated — you may play a 2nd card this turn.")
			if _play_btn_is_end_turn:
				_switch_to_play_mode()
			_update_special_ability_button_state()


# Wildlife Discard Card Popup
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

## Shows the Environmental Consultant "borrow an ability" popup at game start.
## The chosen role name is saved in GameState.ec_borrowed_ability.
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
		var chosen_role = role
		btn.pressed.connect(func():
			GameState.ec_borrowed_ability = chosen_role
			ec_choice_popup.visible = false
			# Update the special ability button tooltip to reflect the chosen ability
			if special_ability_btn:
				special_ability_btn.tooltip_text = "Use: " + chosen_role
			_refresh_role_panel_ui()
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
	ability_dropdown_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ability_dropdown_btn.offset_right = -93
	ability_dropdown_btn.offset_left = -353
	ability_dropdown_btn.offset_top = 10
	ability_dropdown_btn.offset_bottom = 50
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.2, 0.28, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	ability_dropdown_btn.add_theme_stylebox_override("normal", style)
	ability_dropdown_btn.clip_text = true
	ability_dropdown_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ability_dropdown_btn.pressed.connect(_toggle_ability_dropdown)

	# Set initial text with player + role
	var initial_role = GameState.player_roles[0] if GameState.player_roles.size() > 0 else "Unknown"
	ability_dropdown_btn.text = "Player 1 | %s ▾" % initial_role
	add_child(ability_dropdown_btn)

	ability_dropdown_panel = PanelContainer.new()
	ability_dropdown_panel.visible = false
	ability_dropdown_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ability_dropdown_panel.offset_right = -93
	ability_dropdown_panel.offset_left = -353
	ability_dropdown_panel.offset_top = 55
	ability_dropdown_panel.z_index = 80
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	pstyle.corner_radius_top_left = 10
	pstyle.corner_radius_top_right = 10
	pstyle.corner_radius_bottom_left = 10
	pstyle.corner_radius_bottom_right = 10
	pstyle.content_margin_left = 10
	pstyle.content_margin_right = 10
	pstyle.content_margin_top = 10
	pstyle.content_margin_bottom = 10
	ability_dropdown_panel.add_theme_stylebox_override("panel", pstyle)

	var tex_rect = TextureRect.new()
	tex_rect.name = "RoleCardImage"
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(240, 336)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	tex_rect.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if tex_rect.texture != null:
				_show_role_card_overlay(tex_rect.texture)
	)
	
	ability_dropdown_panel.add_child(tex_rect)
	add_child(ability_dropdown_panel)

func _toggle_ability_dropdown():
	ability_dropdown_panel.visible = !ability_dropdown_panel.visible
	_update_dropdown_btn_text()
	if ability_dropdown_panel.visible:
		_refresh_role_panel_ui()

func _update_dropdown_btn_text():
	var p_idx = GameState.current_player_index
	var role = GameState.player_roles[p_idx] if p_idx < GameState.player_roles.size() else "Unknown"
	var arrow = "▴" if ability_dropdown_panel.visible else "▾"
	ability_dropdown_btn.text = "Player %d | %s %s" % [p_idx + 1, role, arrow]
	
## Enables or disables the Special Ability button based on role, per-turn
## used flags, and hand size (some roles need cards in hand).
func _update_special_ability_button_state() -> void:
	if not special_ability_btn:
		return
	if not special_ability_btn.visible:
		return
	# EC's borrow popup is always available; everyone else routes through RoleEffect.
	if player_role == RoleEffect.ENVIRONMENTAL_CONSULT:
		special_ability_btn.disabled = false
	else:
		special_ability_btn.disabled = not RoleEffect.can_use_button(player_role, self)

	# Black cards must resolve before any ability can trigger
	if not special_ability_btn.disabled and currently_viewing_card and pending_card \
			and CardData.ALL_CARDS.get(pending_card.card_id, {}).get("color", Color.WHITE) == Color.BLACK:
		special_ability_btn.disabled = true
	
func _refresh_role_panel_ui():
	var cur = GameState.player_roles[GameState.current_player_index] \
		if GameState.current_player_index < GameState.player_roles.size() else "Unknown"

	if cur == "Environmental Consultant" and GameState.ec_borrowed_ability != "":
		cur = GameState.ec_borrowed_ability

	var tex_path = "res://assets/Role Card/%s.png" % cur
	var tex_rect: TextureRect = ability_dropdown_panel.get_node("RoleCardImage")
	
	if ResourceLoader.exists(tex_path):
		tex_rect.texture = load(tex_path)
	elif ResourceLoader.exists("res://assets/Roles/%s.png" % cur):
		tex_rect.texture = load("res://assets/Roles/%s.png" % cur)
	else:
		tex_rect.texture = null

		
# to make sure the goal doesn't update every single time
const _GOALS_UPDATE_INTERVAL: float = 0.2
var _goals_update_accum: float = 0.0

## Polls goal-tracker progress every 0.2 s (instead of every frame) to keep
## the UI cheap. The check stops entirely once the game is over.
func _process(delta):
	if is_game_over: return
	_goals_update_accum += delta
	if _goals_update_accum < _GOALS_UPDATE_INTERVAL: return
	_goals_update_accum = 0.0
	_update_goals()

# track goal for player tracker panels and refresh each from RoleEffect
## Refreshes every goal-tracker panel by asking RoleEffect.compute_goal for
## fresh data. Also detects the first player to meet their win condition and
## triggers the win screen.
func _update_goals():
	for i in range(_player_tracker_panels.size()):
		var entry: Dictionary = _player_tracker_panels[i]
		var data: Dictionary = RoleEffect.compute_goal(i)
		if data.is_empty():
			continue
		entry["line1"].text = data.line1
		entry["line2"].text = data.line2
		if data.won:
			entry["status"].text = "WON"
			entry["status"].add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
			_trigger_win(i, entry["role"])

func _on_window_resize(): reposition_cards()

## Lays out the cards in the player's hand along the bottom of the screen.
## Re-runs on window resize and after cards are added or removed.
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

## Turn-timer tick. Counts down each second. When time runs out it stops
## the timer and emits end_turn_timer_expired so card_table.gd can handle
## Wildlife-discard and mid-card auto-completion.
func _on_timer_timeout():
	time_left -= 1
	if time_left < 0:
		# emit only once — repeated calls cause double advance_turn / bot collisions
		turn_timer.stop()
		end_turn_timer_expired.emit()
	else:
		timer_label.text = str(time_left)

## Rebuilds the hand display from the current player's GameState.player_hands.
## Called on turn change and after any effect that changes the hand.
func spawn_cards():
	for child in cards_container.get_children(): child.queue_free()
	pending_card = null
	var hand = GameState.player_hands[GameState.current_player_index]
	for card_id in hand:
		var card = CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.set_card_data(card_id)
		card.card_selected.connect(_on_card_selected)
	call_deferred("reposition_cards")

func _collapse_pending_card_preview() -> void:
	if not currently_viewing_card and pending_card == null:
		return
	if pending_card == null or not is_instance_valid(pending_card):
		currently_viewing_card = false
		pending_card = null
		return
	var old: Control = pending_card
	pending_card = null
	currently_viewing_card = false
	old.set("is_selected", false)
	old.z_index = 0
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(old, "position", old.original_position, 0.2)
	tween.tween_property(old, "scale", Vector2(1, 1), 0.2)
	if not _play_btn_is_end_turn:
		_set_play_btn_disabled(true)
	_update_special_ability_button_state()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if not currently_viewing_card or pending_card == null or not is_instance_valid(pending_card):
		return

	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered and _is_control_inside(hovered, pending_card):
		return

	# Black cards must be played (or end-turn), not dismissed by side-clicking
	if CardData.ALL_CARDS.get(pending_card.card_id, {}).get("color", Color.WHITE) == Color.BLACK:
		return

	_collapse_pending_card_preview()

func _is_control_inside(control: Control, container: Control) -> bool:
	var current: Node = control
	while current:
		if current == container:
			return true
		current = current.get_parent()
	return false

func _focus_card_for_play(selected_card: Control, enable_play_button: bool = true) -> Tween:
	_collapse_pending_card_preview()
	currently_viewing_card = true
	pending_card = selected_card
	selected_card.original_position = selected_card.position
	selected_card.z_index = 10
	var win_size := get_viewport_rect().size
	var scale_factor := Vector2(4.0, 4.0)
	var target_pos: Vector2 = win_size / 2 - selected_card.pivot_offset
	target_pos.x += 10
	var tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(selected_card, "position", target_pos, 0.2)
	tween.tween_property(selected_card, "scale", scale_factor, 0.2)
	if enable_play_button:
		play_btn.disabled = false
	else:
		_set_play_btn_disabled(true)
	_update_special_ability_button_state()
	return tween

## Shows the bot's chosen card in a big pop-in preview so the player can
## see what the bot is about to play. Waits for the tween to finish.
func animate_bot_card_popup(card_id: String) -> bool:
	if card_id == "":
		return false
	var selected_card: Control = null
	for child in cards_container.get_children():
		if child is Control and not child.is_queued_for_deletion():
			if str(child.get("card_id")) == card_id:
				selected_card = child
				break
	if selected_card == null:
		return false
	selected_card.set("is_selected", true)
	var tween := _focus_card_for_play(selected_card, false)
	if tween:
		await tween.finished
		return true
	return false

## Called when a Card emits its card_selected signal. Animates the card up
## and enables the Play button. Black cards are auto-played after a short
## pause since they must be played.
func _on_card_selected(selected_card):
	if not play_card or is_bot_turn: return
	
	# If a BLACK card is already being viewed, don't allow selecting another one
	if currently_viewing_card and pending_card:
		var pending_color = CardData.ALL_CARDS.get(pending_card.card_id, {}).get("color", Color.WHITE)
		if pending_color == Color.BLACK:
			return
	
	var p_idx = GameState.current_player_index
	var r_name = GameState.player_roles[p_idx]
	var max_c = RoleEffect.max_cards_per_turn(r_name, self)
	if cards_played_this_turn >= max_c: return

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
	_focus_card_for_play(selected_card)

## Runs when the Play button is clicked. In Play mode it confirms the
## selected card by emitting card_activated. In End Turn mode it emits
## end_turn_requested instead.
func _on_play_btn_pressed():
	if _play_btn_is_end_turn:
		end_turn_requested.emit()
		return

	if is_bot_turn or bot_turn_active: return
	
	if not pending_card: return
	
	var p_idx = GameState.current_player_index
	var r_name = GameState.player_roles[p_idx]
	
	if (r_name == "Village Head" or (r_name == "Environmental Consultant" and GameState.ec_borrowed_ability == "Village Head")):
		for fx in CardData.ALL_CARDS.get(pending_card.card_id, {}).get("sub_effects", []):
			if fx.get("op", "") in ["add_v", "add_v_in"]: vh_villagers_increased_this_turn = true; break

	if r_name == "Government" and pending_card.card_id in GameState.government_stolen_cards.get(p_idx, []):
		GameState.government_mark_replayed(pending_card.card_id)

	# Determine how many cards this role can play per turn
	var max_cards = RoleEffect.max_cards_per_turn(r_name, self)

	var cid = pending_card.card_id
	var card_color = CardData.ALL_CARDS.get(cid, {}).get("color", Color.WHITE)
	# Wildlife Dept : playing a bonus-drawn card counts as the mandatory discard, so remove it from the drawn list.
	GameState.wildlife_dept_drawn_cards.erase(cid)
	pending_card.queue_free()
	pending_card = null
	currently_viewing_card = false
	cards_played_this_turn += 1
	
	# Black cards always end the turn
	if card_color == Color.BLACK:
		cards_played_this_turn = max_cards
	
	add_recent_card_for_player(GameState.current_player_index, cid)

	if cards_played_this_turn >= max_cards:
		_switch_to_end_turn_mode()  # button becomes disabled End Turn, enabled by set_end_turn_ready()
	else:
		# Still has cards to play — reset play button so they can select and play another
		play_btn.disabled = true
		currently_viewing_card = false

	_update_special_ability_button_state()

	card_activated.emit(cid)

## Updates the UI's "is this a bot's turn" flag. Called by card_table.gd on
## each turn change so card clicks are locked out during bot turns.
func set_bot_turn(bot_turn: bool) -> void:
	is_bot_turn = bot_turn

## Runs every time the turn advances. Resets per-turn flags, updates the
## role label and Special Ability button, refreshes goal panels, handles
## Wildlife Department's bonus draw, and spawns the new hand.
func _on_turn_changed(player_index: int, role_name: String, is_skipped: bool):
	play_card = not is_bot_turn and not is_skipped
	
	cards_played_this_turn = 0
	time_left = 60
	if timer_label:
		timer_label.text = str(time_left)
	if is_skipped:
		timer_label.text = "Skipped"
	# restart the timer for the new turn (it may have been stopped on timeout)
	turn_timer.start()

	var skip_label = $Skipped
	if skip_label:
		skip_label.visible = is_skipped

	vh_villagers_increased_this_turn = false
	vh_used_ability_this_turn = false
	po_used_ability_this_turn = false
	gov_used_ability_this_turn = false
	cons_used_ability_this_turn = false
	ld_used_ability_this_turn = false
	ec_used_ability_this_turn = false
	em_used_ability_this_turn = false
	player_role = role_name
	user_role_label.text = "Player %d | %s" % [player_index + 1, role_name]
	if ability_dropdown_btn:
		_update_dropdown_btn_text()

	var _has_ability = RoleEffect.has_button_ability(role_name)
	special_ability_btn.visible = _has_ability and not is_skipped and not is_bot_turn
	if special_ability_btn.visible:
		match role_name:
			"Plantation Owner":
				special_ability_btn.disabled = cards_played_this_turn != 0
			"Government":
				special_ability_btn.disabled = gov_used_ability_this_turn
			"Conservationist":
				special_ability_btn.disabled = cons_used_ability_this_turn
			"Land Developer":
				special_ability_btn.disabled = ld_used_ability_this_turn
			"Ecotourism Manager":
				special_ability_btn.disabled = em_used_ability_this_turn
			"Environmental Consultant":
				special_ability_btn.disabled = false
			_:
				special_ability_btn.disabled = false
	
	_refresh_role_panel_ui()
	_update_special_ability_button_state()

	var _is_wd = (role_name == "Wildlife Department") or (role_name == "Environmental Consultant" and GameState.ec_borrowed_ability == "Wildlife Department")
	if not _is_wd:
		# Stale bonus state from a prior WD/EC-borrow turn would otherwise
		# trigger the discard popup for non-WD players on End Turn.
		GameState.wildlife_dept_drawn_cards.clear()
	if _is_wd and not is_skipped:
		GameState.wildlife_dept_draw_bonus(player_index)

	bot_turn_active = false
	if is_skipped:
		_switch_to_end_turn_mode()
		_set_play_btn_disabled(false)
	else:
		_switch_to_play_mode()
	spawn_cards()

## Hides the yellow-on-black instruction banner at the top of the screen.
func hide_instruction():
	if instruction_label:
		instruction_label.get_parent().visible = false

## Opens the Wildlife Department discard popup listing the 2 bonus cards
## just drawn. Lets the player pick which one to discard before ending the turn.
func show_wildlife_discard_popup():
	var drawn = GameState.wildlife_dept_drawn_cards
	if drawn.is_empty(): end_turn_requested.emit(); return
	var vbox = wildlife_discard_popup.get_meta("_vbox")
	# remove_child (immediate) instead of queue_free inside a while-loop —
	# queue_free defers removal, so get_child_count never drops → infinite loop
	while vbox.get_child_count() > 2:
		var old = vbox.get_child(vbox.get_child_count() - 1)
		vbox.remove_child(old)
		old.queue_free()
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

# reuse the scene $Steal node to show a player-select popup with player + last card name
## Opens the player-select popup used by Plantation Owner's ability to
## choose whose last card to reverse. `disabled_func` decides which targets
## aren't valid; `callback` runs with the chosen player index.
func show_player_select_popup(_title_text, disabled_func, callback, card_effects_node = null):
	var steal_node = get_node_or_null("Steal")
	if not steal_node:
		print("Steal popup node not found")
		return

	var player_buttons = [
		steal_node.get_node("Player1"),
		steal_node.get_node("Player2"),
		steal_node.get_node("Player3")
	]

	# disconnect old signals and hide all buttons first
	for btn in player_buttons:
		for sig in btn.get_signal_connection_list("pressed"):
			btn.disconnect("pressed", sig["callable"])
		btn.visible = false
		btn.disabled = false
		btn.modulate = Color(1, 1, 1, 1)

	var btn_index := 0
	for i in range(GameState.player_count):
		if i == GameState.current_player_index:
			continue
		if btn_index >= player_buttons.size():
			break

		var btn = player_buttons[btn_index]
		btn.visible = true
		btn_index += 1

		var label = btn.get_node("Label")
		# show player name, role, and last card played
		var role_name: String = GameState.player_roles[i] if i < GameState.player_roles.size() else "Unknown"
		var last_card_name := "None"
		if card_effects_node and "lastCard" in card_effects_node and i < card_effects_node.lastCard.size():
			var last_card_id = card_effects_node.lastCard[i]
			if last_card_id:
				last_card_name = CardData.ALL_CARDS.get(last_card_id, {}).get("name", last_card_id)
		label.text = "Player %d (%s)\nLast Card: %s" % [i + 1, role_name, last_card_name]

		var is_disabled = disabled_func.call(i)
		if is_disabled:
			btn.modulate = Color(0.5, 0.5, 0.5, 0.6)

		var target_index := i
		btn.pressed.connect(func():
			steal_node.visible = false
			callback.call(target_index)
		)

	steal_node.visible = true


func spawn_stolen_gov_card():
	spawn_cards() # refresh

## Opens the Ecotourism Manager choice popup ("Move an elephant / villager /
## Skip"). `callback` runs with the picked string.
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
	recent_cards_toggle_button.text = "Played Cards"
	recent_cards_toggle_button.custom_minimum_size = Vector2(160, 42)
	recent_cards_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	recent_cards_toggle_button.offset_left = 16
	recent_cards_toggle_button.offset_top = -92
	recent_cards_toggle_button.offset_right = 176
	recent_cards_toggle_button.offset_bottom = -50
	recent_cards_toggle_button.z_index = 10
	recent_cards_toggle_button.pressed.connect(_toggle_recent_cards_overlay)
	add_child(recent_cards_toggle_button)

	recent_cards_overlay_panel = PanelContainer.new()
	recent_cards_overlay_panel.name = "_recent_cards_overlay"
	recent_cards_overlay_panel.add_to_group("blocks_board_input")
	recent_cards_overlay_panel.visible = false
	recent_cards_overlay_panel.set_anchors_preset(Control.PRESET_CENTER)
	recent_cards_overlay_panel.offset_left = -560
	recent_cards_overlay_panel.offset_top = -380
	recent_cards_overlay_panel.offset_right = 560
	recent_cards_overlay_panel.offset_bottom = 220
	recent_cards_overlay_panel.z_index = 10

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

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(header_hbox)

	var left_spacer := Control.new()
	left_spacer.custom_minimum_size = Vector2(44, 0)
	header_hbox.add_child(left_spacer)

	var title := Label.new()
	title.text = "Played Cards"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.25))
	header_hbox.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(44, 36)
	close_button.pressed.connect(_close_recent_cards_overlay)
	header_hbox.add_child(close_button)

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

func _close_recent_cards_overlay() -> void:
	if recent_cards_overlay_panel == null:
		return
	recent_cards_overlay_panel.visible = false
	_clear_recent_cards_preview()

## Records a card the given player just played so it shows up in the
## Played Cards overlay. Trimmed to the last RECENT_HISTORY_LIMIT entries
## per player so the list doesn't grow without bound.
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
	if bucket.size() > RECENT_HISTORY_LIMIT:
		bucket = bucket.slice(bucket.size() - RECENT_HISTORY_LIMIT)

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

## Flips the Play button into End Turn mode and enables it. Called after a
## card effect finishes so the player can confirm the turn.
func set_end_turn_ready() -> void:
	if bot_turn_active:
		return
	if _play_btn_is_end_turn:
		_set_play_btn_disabled(false)

# --- Bot turn lock ---

func _on_bot_turn_started() -> void:
	bot_turn_active = true
	is_bot_turn = true
	play_card = false
	_set_play_btn_disabled(true)

func _on_bot_turn_ended() -> void:
	bot_turn_active = false
	is_bot_turn = false

# --- Instruction label ---

## Shows a yellow-on-black instruction banner at the top of the screen.
## Used by card effects to tell the player what to click next.
func show_instruction(text: String) -> void:
	if instruction_label:
		instruction_label.text = text
		instruction_label.get_parent().visible = true

## Opens the steal-target popup. `mode` is "steal" (regular card steal) or
## "gov" (Government ability). Clicking a target sends the pick back to
## CardEffects via the correct confirm method.
func show_steal_popup(card_effects_node: Node, mode: String = "steal") -> void:
	if is_bot_turn: return

	var steal_node = get_node_or_null("Steal") #gSteal popup node

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

		var btn = player_buttons[btn_index]
		steal_node.visible = true
		btn_index += 1

		var label = btn.get_node("Label")
		var target_index := i

		if mode == "gov":
			# Government: pick a previously played green/yellow/red card.
			var lastCardeffect = card_effects_node.lastCard[i] if i < card_effects_node.lastCard.size() else null
			var card_def = CardData.ALL_CARDS.get(lastCardeffect, {}) if lastCardeffect != null else {}
			var col = card_def.get("color", Color.WHITE)
			var valid: bool = lastCardeffect != null and (col in [Color.GREEN, Color.YELLOW, Color.RED])
			btn.disabled = not valid
			var hand_size = GameState.player_hands[i].size()
			label.text = "Player %d (%d card%s)" % [i + 1, hand_size, "s" if hand_size != 1 else ""]
			btn.pressed.connect(func():
				hide_steal_popup(steal_node)
				card_effects_node.confirm_gov_steal_target(target_index)
			)
		else:
			# Default: Corruption — random card from a player's hand.
			var hand_size = GameState.player_hands[i].size()
			btn.disabled = hand_size == 0
			label.text = "Player %d (%d card%s)" % [i + 1, hand_size, "s" if hand_size != 1 else ""]
			btn.pressed.connect(func():
				hide_steal_popup(steal_node)
				card_effects_node.confirm_steal_target(target_index)
			)

		steal_node.visible = true

func hide_steal_popup(steal_node) -> void:
	if is_bot_turn: return
	if steal_node:
		steal_node.visible = false

## Opens the Land-Use Planning type-pick popup for the convert_any_any op.
## Hides whichever option matches the tile's current type so the player
## can't pick "no change".
func show_convert_type_popup(card_effects_node: Node, current_type: int) -> void:
	if is_bot_turn: return
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
	if is_bot_turn: return
	var popup = get_node_or_null("_convert_type_popup")
	if popup:
		popup.visible = false

# when player wins
func _build_win_screen():
	win_screen_panel = PanelContainer.new()
	win_screen_panel.visible = false
	win_screen_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_screen_panel.z_index = 100
	var win_style = StyleBoxFlat.new()
	win_style.bg_color = Color(0.02, 0.02, 0.08, 0.92)
	win_style.border_width_top = 4
	win_style.border_width_bottom = 4
	win_style.border_color = Color(1.0, 0.75, 0.15, 0.5)
	win_screen_panel.add_theme_stylebox_override("panel", win_style)

	var win_vbox = VBoxContainer.new()
	win_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	win_vbox.add_theme_constant_override("separation", 12)
	win_screen_panel.add_child(win_vbox)

	# Trophy icon
	var trophy_label = Label.new()
	trophy_label.text = "🏆"
	trophy_label.add_theme_font_size_override("font_size", 80)
	trophy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_vbox.add_child(trophy_label)

	# Main winner text
	win_screen_label = Label.new()
	win_screen_label.text = "PLAYER X WON!"
	win_screen_label.add_theme_font_size_override("font_size", 56)
	win_screen_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	win_screen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_vbox.add_child(win_screen_label)

	# Role subtitle (stored as meta for later update)
	var role_subtitle = Label.new()
	role_subtitle.name = "RoleSubtitle"
	role_subtitle.text = ""
	role_subtitle.add_theme_font_size_override("font_size", 28)
	role_subtitle.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0, 0.9))
	role_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_vbox.add_child(role_subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	win_vbox.add_child(spacer)

	# Return to menu button
	var menu_btn = Button.new()
	menu_btn.text = "  Return to Menu  "
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.custom_minimum_size = Vector2(260, 52)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.35, 0.55, 0.95)
	btn_style.corner_radius_top_left = 10
	btn_style.corner_radius_top_right = 10
	btn_style.corner_radius_bottom_left = 10
	btn_style.corner_radius_bottom_right = 10
	btn_style.content_margin_left = 20
	btn_style.content_margin_right = 20
	btn_style.content_margin_top = 10
	btn_style.content_margin_bottom = 10
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.2, 0.45, 0.7, 0.95)
	btn_hover.corner_radius_top_left = 10
	btn_hover.corner_radius_top_right = 10
	btn_hover.corner_radius_bottom_left = 10
	btn_hover.corner_radius_bottom_right = 10
	btn_hover.content_margin_left = 20
	btn_hover.content_margin_right = 20
	btn_hover.content_margin_top = 10
	btn_hover.content_margin_bottom = 10
	menu_btn.add_theme_stylebox_override("normal", btn_style)
	menu_btn.add_theme_stylebox_override("hover", btn_hover)
	menu_btn.pressed.connect(func():
		GameState.reset()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	win_vbox.add_child(menu_btn)

	add_child(win_screen_panel)

## Fires the moment a player's win condition becomes true. Shows the win
## screen with a pop-in tween, stops the turn timer, freezes the game (via
## GameState.is_game_over), and closes any overlays.
func _trigger_win(player_index: int, role_name: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	# Freeze the game so turns/timer/bots don't continue past the win.
	GameState.is_game_over = true
	if turn_timer:
		turn_timer.stop()
	_set_play_btn_disabled(true)
	hide_instruction()
	if win_screen_panel:
		win_screen_panel.visible = true
		# Fade in animation
		win_screen_panel.modulate = Color(1, 1, 1, 0)
		var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(win_screen_panel, "modulate", Color(1, 1, 1, 1), 0.6)
	if win_screen_label:
		win_screen_label.text = "PLAYER %d WINS!" % (player_index + 1)
	var subtitle = win_screen_panel.find_child("RoleSubtitle", true, false)
	if subtitle:
		subtitle.text = "Role: %s" % role_name
