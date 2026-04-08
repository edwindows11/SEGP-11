extends Control

var how_to_play_section: Control
var glossary_section: Control
var about_meme_section: Control
var continue_button: Button
var pages: Array = []
var current_page: int = 0

func _ready() -> void:
	how_to_play_section = get_node("Background/How To Play")
	glossary_section     = get_node("Background/Glossary")
	about_meme_section   = get_node("Background/About MEME")

	pages = [
		get_node("Background/How To Play/How to Play First Page"),
		get_node("Background/How To Play/How to Play second Page"),
		get_node("Background/How To Play/How to Play third Page2"),
	]

	continue_button = get_node("Background/How To Play/Button")

	get_node("Background/Side Panel/VBoxContainer/How to Play").pressed.connect(_show_how_to_play)
	get_node("Background/Side Panel/VBoxContainer/Glossary").pressed.connect(_show_glossary)
	get_node("Background/Side Panel/VBoxContainer/Cards").pressed.connect(_show_about_meme)
	get_node("Background/Side Panel/Exit").pressed.connect(_go_to_main_menu)
	continue_button.pressed.connect(_on_continue_pressed)

	_remove_focus_borders(self)
	_show_how_to_play()

func _remove_focus_borders(node: Node) -> void:
	if node is Button:
		node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for child in node.get_children():
		_remove_focus_borders(child)

func _show_how_to_play() -> void:
	how_to_play_section.visible = true
	glossary_section.visible    = false
	about_meme_section.visible  = false
	current_page = 0
	_update_page()

func _show_glossary() -> void:
	how_to_play_section.visible = false
	glossary_section.visible    = true
	about_meme_section.visible  = false

func _show_about_meme() -> void:
	how_to_play_section.visible = false
	glossary_section.visible    = false
	about_meme_section.visible  = true
	

func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _update_page() -> void:
	for i in range(pages.size()):
		pages[i].visible = (i == current_page)
	# Hide Continue on the last page
	continue_button.visible = current_page < pages.size() - 1

func _on_continue_pressed() -> void:
	if current_page < pages.size() - 1:
		current_page += 1
		_update_page()
