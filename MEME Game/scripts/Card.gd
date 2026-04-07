extends Control

# --- Signals ---
signal card_selected(card)

# --- Node refs ---
@onready var background = $Background
@onready var label = $Label
@onready var display = $TextureRect

# --- State ---
var original_position: Vector2
var is_hovered = false
var is_selected = false
var index = 0
# Key into CardData.ALL_CARDS used to look up this card's definition.
var card_id: String = ""

# --- Animation constants ---
const HOVER_SCALE = Vector2(1.1, 1.1)
const NORMAL_SCALE = Vector2(1.0, 1.0)
const HOVER_OFFSET_Y = -20.0
const ANIMATION_DURATION = 0.1

# --- Lifecycle ---
func _ready():
	# Ensure we can receive mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect signals for mouse interaction
	gui_input.connect(_on_gui_input)

# --- Data binding ---

# Populate the visuals from a card id by looking up CardData.ALL_CARDS.
func set_card_data(id: String) -> void:
	card_id = id
	var card_def = CardData.ALL_CARDS.get(id, {})

	label.text = card_def.get("name", "Unknown Card")
	# Texture filename mirrors the card's display name.
	display.texture = load("res://assets/Card/" + label.text + ".png")
	var color = card_def.get("color", Color.WHITE)
	background.color = color
	label.add_theme_color_override("font_color", Color.BLACK)

	# Black-coloured cards are auto-selected (used as placeholder/blank slots).
	if color == Color.BLACK:
		is_selected = true
		call_deferred("_emit_card_selected")

# Deferred so the signal fires after the node is fully wired up by the parent.
func _emit_card_selected() -> void:
	card_selected.emit(self)

# --- Input ---

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_selected:
			_select_card()

func _select_card():
	is_selected = true
	card_selected.emit(self)
