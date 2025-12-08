extends Control

@onready var role_label = $VBoxContainer/RoleLabel
@onready var continue_button = $VBoxContainer/ContinueButton

var roles = [
	"Ecotourism Manager",
	"Environmental Consultant",
	"Government",
	"Land Developer",
	"Plantation",
	"Researcher",
	"Village Head",
	"Wildfire Department"
]

func _ready():
	var assigned_role = roles.pick_random()
	role_label.text = assigned_role
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed():
	var card_table_scene = load("res://scenes/CardTable.tscn")
	var card_table = card_table_scene.instantiate()
	
	# Pass the role data
	card_table.player_role = role_label.text
	
	# Switch scene manually
	get_tree().root.add_child(card_table)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = card_table
