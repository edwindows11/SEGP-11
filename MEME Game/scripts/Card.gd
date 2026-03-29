extends Control

signal card_selected(card)

@onready var background = $Background
@onready var label = $Label
@onready var display = $TextureRect

var original_position: Vector2
var is_hovered = false
var is_selected = false
var index = 0
var card_id: String = ""

const HOVER_SCALE = Vector2(1.1, 1.1)
const NORMAL_SCALE = Vector2(1.0, 1.0)
const HOVER_OFFSET_Y = -20.0
const ANIMATION_DURATION = 0.1

func _ready():
	# Ensure we can receive mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect signals for mouse interaction
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func set_card_data(id: String) -> void:
	card_id = id
	var card_def = CardData.ALL_CARDS.get(id, {})
	
	label.text = card_def.get("name", "Unknown Card")
	display.texture = load("res://assets/Card/" + label.text + ".png")
	var color = card_def.get("color", Color.WHITE)
	background.color = color
	label.add_theme_color_override("font_color", Color.BLACK)
	
	if color == Color.BLACK:
		is_selected = true
		call_deferred("_emit_card_selected")

func _emit_card_selected() -> void:
	card_selected.emit(self)

func _on_mouse_entered():
	if is_selected: return
	is_hovered = true
	z_index = 1 # Bring to front

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", HOVER_SCALE, ANIMATION_DURATION)
	tween.tween_property(self, "position:y", original_position.y + HOVER_OFFSET_Y, ANIMATION_DURATION)

func _on_mouse_exited():
	if is_selected: return
	is_hovered = false
	z_index = 0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", NORMAL_SCALE, ANIMATION_DURATION)
	tween.tween_property(self, "position:y", original_position.y, ANIMATION_DURATION)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_selected:
			_select_card()

func _select_card():
	is_selected = true
	card_selected.emit(self)
