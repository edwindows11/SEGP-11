extends Control

@onready var my_node = $Panel

func _ready():
	if my_node != null:
		var rect = my_node.get_global_rect()
		print(rect)

func _input(event):
	if not $HowToPlay.visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		$HowToPlay.visible = false
	
	if event is InputEventMouseButton and event.pressed:
		var panel = $HowToPlay
		var mouse_pos = get_viewport().get_mouse_position()
		
		if not panel.get_global_rect().has_point(mouse_pos):
			$HowToPlay.visible = false
