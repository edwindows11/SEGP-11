extends Control

var current_player = 0
var max_players = 4
var selected_roles = []

# Map role name to image
var role_images = {
	"Conservationist": preload("res://assets/RoleCards/16.png"),
	"EcotourismManager": preload("res://assets/RoleCards/22.png"),
	"EnvironmentalConsultant": preload("res://assets/RoleCards/20.png"),
	"Government": preload("res://assets/RoleCards/14.png"),
	"LandDeveloper": preload("res://assets/RoleCards/18.png"),
	"PlantationOwner": preload("res://assets/RoleCards/12.png"),
	"Researcher": preload("res://assets/RoleCards/8.png"),
	"VillageHead": preload("res://assets/RoleCards/10.png"),
	"WildlifeDepartment": preload("res://assets/RoleCards/6.png"),
}

@onready var start_button = $StartGameButton

@onready var player_slots = [
	$PlayerSlots/Player1,
	$PlayerSlots/Player2,
	$PlayerSlots/Player3,
	$PlayerSlots/Player4
]

@onready var info_label = $InfoLabel


func _ready():
	info_label.text = "Selecting for Player 1"
	
	start_button.disabled = true
	start_button.modulate = Color(0.5,0.5,0.5)

	for button in $RoleButtons.get_children():
		button.mouse_entered.connect(_on_role_hovered.bind(button))
		button.pressed.connect(_on_role_selected.bind(button))
		


func _on_role_hovered(button):
	if current_player >= max_players:
		return

	var role_name = button.name

	if role_images.has(role_name):
		var slot = player_slots[current_player]
		slot.get_node("CardLabel").text = role_name
		slot.get_node("CardImage").texture = role_images[role_name]


func _on_role_selected(button):
	if current_player >= max_players:
		return

	var role_name = button.name

	if role_images.has(role_name):
		selected_roles.append(role_name)
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5)

		var slot = player_slots[current_player]
		slot.get_node("CardImage").texture = role_images[role_name]
		slot.get_node("CardLabel").text = role_name

		current_player += 1

		if current_player < max_players:
			info_label.text = "Selecting for Player " + str(current_player + 1)
		else:
			info_label.text = "All players selected!"
			start_button.modulate = Color(1,1,1)
			start_button.disabled = false
			


func _on_start_game_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
