extends Node3D

@export var mesh: MeshInstance3D
@export var material: StandardMaterial3D

var delete = false
var parent:Node3D


# before you call any function in this script, always call the new function first
func new(mesh_instance, material_instance) -> void:
	material = material_instance
	mesh = mesh_instance
	
	parent = get_parent_node_3d()
	material = material.duplicate(true)
	mesh.material_overlay= material
	
	if parent != null:
		parent.delete.connect(deleteFunc)	

func colour(new_colour: String):
	if new_colour == "red":
		material.albedo_color = Color("d30000ff")
		material.grow_amount = 0.1 # Visible highlight
	elif new_colour == "white":
		# Optional friendly highlight
		material.albedo_color = Color(1, 1, 1, 1)
		material.grow_amount = 0.1
	elif new_colour == "black":
		material.albedo_color = Color("000000ff")
		material.grow_amount = 0.0 # Invisible
	
func deleteFunc():
	if (delete):
		delete = false
		material.grow_amount = 0
	else:
		delete = true
		material.grow_amount = 0.3
	
