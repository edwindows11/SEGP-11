extends Control

@onready var name_label = $NameLabel
@onready var role_panel = $RolePanel
@onready var role_label = $RolePanel/RoleLabel

func _ready():
	# Ensure Control receives mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(player_name: String, role_name: String):
	name_label.text = player_name + " (" + role_name + ")"
	# Hide the separate role panel since we show it in the name now
	role_panel.visible = false

func _on_mouse_entered():
	pass

func _on_mouse_exited():
	pass
