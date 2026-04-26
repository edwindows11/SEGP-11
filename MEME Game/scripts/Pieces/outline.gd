## Helper for drawing a coloured outline around a 3D piece.

## Used to show a hover highlight (red).
## Call [new()] first to bind the outline to a mesh and material.
extends Node3D

## The mesh the outline is drawn on top of.
@export var mesh: MeshInstance3D
## The material used to colour the outline. 
## Duplicated in [new()] so each piece has its own copy.
@export var material: StandardMaterial3D

## The Play node that owns this piece.
var parent:Node3D


## Sets up the outline for a specific mesh and material.
## Must be called before using any other function in this script.
func new(mesh_instance, material_instance) -> void:
	material = material_instance
	mesh = mesh_instance

	parent = get_parent_node_3d()
	material = material.duplicate(true)
	mesh.material_overlay= material

## Changes the outline colour. Accepts "red", "white", or "black".
## "black" hides the outline (grow_amount = 0).
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
