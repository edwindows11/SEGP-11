extends Control

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

func _ready():
	spawn_cards()
	spawn_players()
	if user_role_label:
		user_role_label.text = "My Role: " + player_role
	
	if user_role_label:
		user_role_label.text = "My Role: " + player_role
	
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	turn_timer.timeout.connect(_on_timer_timeout)
	
	# Connect to window resize signal
	get_tree().root.size_changed.connect(_on_window_resize)

func _on_window_resize() -> void:
	# Recalculate card positions
	reposition_cards()

func reposition_cards() -> void:
	var screen_size = get_viewport_rect().size
	var cards = cards_container.get_children()
	var total_current_cards = cards.size()
	
	if total_current_cards == 0:
		return
		
	# Recalculate center
	var start_x = (screen_size.x - (float(total_current_cards) - 1) * CARD_SPACING) / 2.0
	
	# Cards in hand (not pending/played)
	# Assuming all children in container are cards to line up
	# If pending card is still child but moved, we might need filtering. 
	# For simplicity, lining up all children for now or checking a state.
	
	for i in range(total_current_cards):
		var card = cards[i]
		if card == pending_card:
			# Skip pending card (it's centered or played)
			continue
			
		var card_width = card.custom_minimum_size.x
		# Since cards array order might not match index if removed, we use loop index for spacing
		# IF keeping index consistency is important, rely on card.index
		
		var x_pos = start_x + (i * CARD_SPACING) - (card_width / 2.0)
		var y_pos = screen_size.y - card.custom_minimum_size.y - BOTTOM_MARGIN
		
		# Animate or set? Set for resize, animate for nice
		card.position = Vector2(x_pos, y_pos)
		card.original_position = card.position


func _on_timer_timeout():
	time_left -= 1
	if time_left < 0:
		_on_end_turn_pressed() # Auto end turn
	else:
		timer_label.text = str(time_left)



func spawn_players():
	var roles = [
		"Ecotourism Manager", "Environmental Consultant", "Government",
		"Land Developer", "Plantation", "Researcher",
		"Village Head", "Wildfire Department"
	]
	
	# Spawn 3 dummy players
	for i in range(3):
		var player = PLAYER_DISPLAY_SCENE.instantiate()
		players_container.add_child(player)
		player.setup("Player " + str(i + 2), roles.pick_random())

func spawn_cards():
	for i in range(TOTAL_CARDS):
		var card = CARD_SCENE.instantiate()
		cards_container.add_child(card)
		card.set_card_data(i)
		card.card_selected.connect(_on_card_selected)
	
	# Initial positioning
	reposition_cards()

func _on_card_selected(selected_card):
	if cards_played_this_turn >= 1:
		print("Cannot play more than 1 card per turn!")
		return

	cards_played_this_turn += 1
	
	# Track the card awaiting finalization
	pending_card = selected_card
	
	# Move selected card to center
	var screen_size = get_viewport_rect().size
	var target_pos = (screen_size - selected_card.custom_minimum_size) / 2.0
	
	# Bring to front
	selected_card.z_index = 10
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(selected_card, "position", target_pos, 0.5)
	tween.tween_property(selected_card, "scale", Vector2(1.5, 1.5), 0.5)
	
	print("Card selected (pending turn end): ", selected_card.index)

func _on_end_turn_pressed():
	if pending_card:
		print("Finalizing card: ", pending_card.index)
		# Here we would maintain the card on the board. 
		# Since it's already physically there, we just ensure it's removed from 'hand logic' if we had any.
		# For now, we just clear the pending reference so it's 'committed'.
		
	time_left = 60
	timer_label.text = str(time_left)
	cards_played_this_turn = 0
	print("Turn Ended")
