## Handles three sections (How To Play, Glossary, About MEME)
extends Control

## Root of the How To Play section.
var how_to_play_section: Control
## Root of the Glossary section.
var glossary_section: Control
## Root of the About MEME section.
var about_meme_section: Control
## Button for moving to the next page. (How To Play)
var continue_button: Button
## Button for moving to the previous page. Hidden on the first page. (How To Play)
var back_button: Button
## List of page nodes in order.
var pages: Array = []
## Index of the currently-shown page. 0 is the first page.
var current_page: int = 0

## Dark background used when an image is enlarged. Click to close.
var _image_overlay: ColorRect = null
## The TextureRect that shows the enlarged image, centred on screen.
var _image_overlay_rect: TextureRect = null
## Current tween for the enlarge / shrink animation.
var _image_overlay_tween: Tween = null

func _ready() -> void:
	how_to_play_section = get_node("Background/How To Play")
	glossary_section     = get_node("Background/Glossary")
	about_meme_section   = get_node("Background/About MEME")

	# Collect each VBoxContainer page under "How to play pages" .
	# Skips the Label header.
	pages = []
	var pages_container := get_node("Background/How To Play/How to play pages")
	for child in pages_container.get_children():
		if child is VBoxContainer:
			pages.append(child)

	continue_button = get_node("Background/How To Play/Continue")
	back_button = get_node("Background/How To Play/Back")

	get_node("Background/Side Panel/VBoxContainer/How to Play").pressed.connect(_show_how_to_play)
	get_node("Background/Side Panel/VBoxContainer/Glossary").pressed.connect(_show_glossary)
	get_node("Background/Side Panel/VBoxContainer/Cards").pressed.connect(_show_about_meme)
	get_node("Background/Side Panel/Exit").pressed.connect(_go_to_main_menu)
	continue_button.pressed.connect(_on_continue_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_remove_focus_borders(self)
	_build_image_overlay()
	_wire_image_clicks(how_to_play_section)
	_show_how_to_play()

## Don't show a dotted outline when clicked.
func _remove_focus_borders(node: Node) -> void:
	if node is Button:
		node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for child in node.get_children():
		_remove_focus_borders(child)

## Hides all three sections and shows only the given one.
func _show_section(active: Control) -> void:
	how_to_play_section.visible = (active == how_to_play_section)
	glossary_section.visible    = (active == glossary_section)
	about_meme_section.visible  = (active == about_meme_section)

## Shows the How To Play section and jumps back to the first page.
func _show_how_to_play() -> void:
	_show_section(how_to_play_section)
	current_page = 0
	_update_page()

## Shows the Glossary section.
func _show_glossary() -> void:
	_show_section(glossary_section)

## Shows the About MEME section.
func _show_about_meme() -> void:
	_show_section(about_meme_section)


## Goes back to the Main Menu scene.
func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

## Shows only the current page and hides the others. 
## Hides Continue on the last page and Back on the first page.
func _update_page() -> void:
	for i in range(pages.size()):
		pages[i].visible = (i == current_page)
	continue_button.visible = current_page < pages.size() - 1
	back_button.visible = current_page > 0

## Goes to the next page when Continue is clicked.
func _on_continue_pressed() -> void:
	if current_page < pages.size() - 1:
		current_page += 1
		_update_page()

## Goes to the previous page when Back is clicked.
func _on_back_pressed() -> void:
	if current_page > 0:
		current_page -= 1
		_update_page()

## Builds the dark full-screen overlay and the centered TextureRect that shows a picture when it is clicked. 
func _build_image_overlay() -> void:
	_image_overlay = ColorRect.new()
	_image_overlay.color = Color(0, 0, 0, 0.75)
	_image_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image_overlay.visible = false
	_image_overlay.z_index = 200
	_image_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_image_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_hide_image_overlay()
	)
	add_child(_image_overlay)

	_image_overlay_rect = TextureRect.new()
	_image_overlay_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_overlay_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Fill the middle 80% of the viewport
	_image_overlay_rect.anchor_left = 0.1
	_image_overlay_rect.anchor_top = 0.1
	_image_overlay_rect.anchor_right = 0.9
	_image_overlay_rect.anchor_bottom = 0.9
	_image_overlay_rect.offset_left = 0
	_image_overlay_rect.offset_top = 0
	_image_overlay_rect.offset_right = 0
	_image_overlay_rect.offset_bottom = 0
	_image_overlay_rect.scale = Vector2.ZERO
	_image_overlay_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_image_overlay.add_child(_image_overlay_rect)

## Walks every TextureRect under `node` and makes it click-to-enlarge.
## Called with the How To Play section so only its images are wired up.
func _wire_image_clicks(node: Node) -> void:
	if node is TextureRect and node != _image_overlay_rect:
		var tex_rect: TextureRect = node
		tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		tex_rect.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_show_image_overlay(tex_rect.texture)
		)
	for child in node.get_children():
		_wire_image_clicks(child)

## Enlarges the given texture in the center of the screen with a pop-in tween.
func _show_image_overlay(tex: Texture2D) -> void:
	if tex == null:
		return
	_image_overlay_rect.texture = tex
	_image_overlay.modulate = Color(1, 1, 1, 0)
	_image_overlay_rect.scale = Vector2(0.1, 0.1)
	_image_overlay.visible = true
	if _image_overlay_tween:
		_image_overlay_tween.kill()
	_image_overlay_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_image_overlay_tween.tween_property(_image_overlay, "modulate", Color(1, 1, 1, 1), 0.3)
	_image_overlay_tween.tween_property(_image_overlay_rect, "scale", Vector2(1, 1), 0.4)

## Shrinks and hides the enlarged image overlay.
func _hide_image_overlay() -> void:
	if _image_overlay_tween:
		_image_overlay_tween.kill()
	_image_overlay_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	_image_overlay_tween.tween_property(_image_overlay, "modulate", Color(1, 1, 1, 0), 0.25)
	_image_overlay_tween.tween_property(_image_overlay_rect, "scale", Vector2(0.1, 0.1), 0.25)
	await _image_overlay_tween.finished
	_image_overlay.visible = false
