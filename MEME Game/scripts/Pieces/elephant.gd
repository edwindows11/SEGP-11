extends Node3D

@export var mesh: MeshInstance3D
@export var material: StandardMaterial3D

const OUTLINE = preload("res://scripts/Pieces/outline.gd")
var outline_S = OUTLINE.new()

var parent:Node3D
var selected: bool = false

signal Del_Elephant

func _ready() -> void:
	add_to_group("elephants")
	parent = get_parent_node_3d()
	outline_S.new(mesh, material)
	
	if parent != null:
		parent.delete_Elephant.connect(outline_S.deleteFunc)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_static_body_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton \
	  and event.button_index == MOUSE_BUTTON_LEFT \
	  and event.pressed\
	  and outline_S.delete == true:
		emit_signal("Del_Elephant")
		selected = true

func _on_static_body_3d_mouse_entered() -> void:
	outline_S.colour("red")

func _on_static_body_3d_mouse_exited() -> void:
	if selected == false:
		outline_S.colour("black")
