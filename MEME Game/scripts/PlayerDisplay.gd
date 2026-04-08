extends Control

@onready var name_label = $NameLabel
@onready var role_panel = $RolePanel
@onready var role_label = $RolePanel/RoleLabel

func _ready():
	# Ensure Control receives mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP

func _on_mouse_entered():
	pass

func _on_mouse_exited():
	pass
