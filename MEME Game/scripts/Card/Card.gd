extends Control

signal card_selected(card)

@onready var background = $MarginContainer/Background
@onready var colour: String
@onready var title = $MarginContainer/Background/Title
@onready var desc = $MarginContainer/Background/Desc
@onready var action = $MarginContainer/Background/Action
@onready var icons = $MarginContainer/Background/Icons


const Card_details = preload("res://scripts/Card/card_details.gd")

var original_position: Vector2
var is_hovered = false
var is_selected = false
var index = 0
var card_enum = null
var card_name = null

const HOVER_SCALE = Vector2(1.1, 1.1)
const NORMAL_SCALE = Vector2(1.0, 1.0)
const HOVER_OFFSET_Y = -20.0
const ANIMATION_DURATION = 0.1

func _ready():
	# Ensure we can receive mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_card_data(1)
	# Connect signals for mouse interaction
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func set_card_data(idx: int):
	card_enum = Card_details.CardID.LIGHT_BASED_REPELLENT
	colour = Card_details.CARDS[card_enum]["colour"]
	background.texture = load("res://assets/Card/%s.png" % colour)
	
	card_name = Card_details.CARDS[card_enum]["name"]
	title.text = card_name
	
	match colour:
		"black":
			title.add_theme_color_override("font_color", Color8(107, 98, 91) )  # #6b625b
		"red":
			title.add_theme_color_override("font_color",  Color8(255, 49, 49))   # #ff3131
		"yellow":
			title.add_theme_color_override("font_color",  Color8(255, 189, 89))  # #ffbd59
		"green":
			title.add_theme_color_override("font_color", Color8(87, 97, 42))    # #57612a

	desc.text = Card_details.CARDS[card_enum]["desc"]
	action.text = Card_details.CARDS[card_enum]["action"]
	
	for icon_name in Card_details.CARDS[card_enum]["icons"]:
		add_icon(icon_name)

func add_icon(texture: String):
	var tex = load("res://assets/Card/%s.png" % texture) as Texture2D
	if not tex:
		push_error("Failed to load texture: %s" % texture)
		return
	
	var icon = TextureRect.new()
	icon.texture = tex
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL    
	if texture == "elephant":
		icon.size_flags_stretch_ratio = 1.5
	if Card_details.CARDS[card_enum].has("flip") and Card_details.CARDS[card_enum]["flip"] == texture:
		icon.flip_h = true
	icons.add_child(icon)

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
	# Visual feedback is handled by the table manager usually, but we can do a quick flash or sound here if needed
