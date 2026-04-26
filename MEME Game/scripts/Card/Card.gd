## Creates a action card in player's hand.
## Contains the name, picture, colour and effect based on the info in [CardData.gd]. 
## When the player clicked, signal "card_selected" to enlarge the view.
##
## The actual effect of the action card is handled by [CardEffects.gd].
extends Control

## Sent when a action card is clicked 
signal card_selected(card)

## Coloured background behind the card picture. (Used to keep the card colour and debugging)
@onready var background = $Background
## In early stages when the card image doesn't show, is used to identify the specific cards.
@onready var label = $Label
## The card's picture.
@onready var display = $TextureRect

## Where this card sits in the hand when it's not selected.
var original_position: Vector2
## True after the card is clicked.
## Prevents the card from getting selected twice.
var is_selected = false
## The key used to look find card in CardData.ALL_CARDS.
var card_id: String = ""

## How big the card grows when the mouse hovers over it.
const HOVER_SCALE = Vector2(1.1, 1.1)
## Normal size when the card is just sitting in the hand.
const NORMAL_SCALE = Vector2(1.0, 1.0)
## How far up the card lifts when hovered (pixels).
const HOVER_OFFSET_Y = -20.0
## How long the hover animation takes (seconds).
const ANIMATION_DURATION = 0.1

func _ready():
	# Make sure clicks on the action card don't go through to the board.
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)

## Fills in the card's name, picture, and background colour using the [CardData.gd]. 
## Picture are in assets/Card/ with the same name as the card.
## If the card is a black card, it selects itself straight.
func set_card_data(id: String) -> void:
	card_id = id
	var card_def = CardData.ALL_CARDS.get(id, {})

	label.text = card_def.get("name", "Unknown Card")
	display.texture = load("res://assets/Card/" + label.text + ".png")
	var color = card_def.get("color", Color.WHITE)
	background.color = color
	label.add_theme_color_override("font_color", Color.BLACK)

	# Black cards are selected immeadiately
	if color == Color.BLACK:
		is_selected = true
		# Wait one frame so the UI has time to listen for the signal first.
		call_deferred("_emit_card_selected")

func _emit_card_selected() -> void:
	card_selected.emit(self)

## Runs when the mouse clicks with left click and when card isn't selected.
func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_selected:
			_select_card()

## Marks this card as selected and tells the rest of the game using card_selected signal.
func _select_card():
	is_selected = true
	card_selected.emit(self)
