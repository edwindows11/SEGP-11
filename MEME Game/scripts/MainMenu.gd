extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var how_to_play_button = $VBoxContainer/HowToPlayButton

func _ready():

	start_button.pressed.connect(_on_start_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)

func _on_start_game_pressed():
	get_tree().change_scene_to_file("res://scenes/RoleSelection.tscn")

func _on_settings_pressed():
	print("Settings clicked")

func _on_how_to_play_pressed():
	print("How to Play clicked")
