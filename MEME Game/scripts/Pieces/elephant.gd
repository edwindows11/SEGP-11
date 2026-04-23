## An elephant is a 3D piece that sits on one tile. 
## It shows a coloured outline when the mouse hovers over it. 
extends Node3D

## The mesh this piece renders. Used to apply the outline overlay.
@export var mesh: MeshInstance3D
## The material the outline is based on.
@export var material: StandardMaterial3D

const OUTLINE = preload("res://scripts/Pieces/outline.gd")
## Helper that draws and colours the outline around the elephant.
var outline_S = OUTLINE.new()

## The Play node that owns this piece.
var parent:Node3D

## Grid key of the tile this elephant is sitting on. Vector2i(-1, -1) means unassigned.
var tile_key: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	add_to_group("elephants")
	parent = get_parent_node_3d()
	outline_S.new(mesh, material)

func _on_static_body_3d_mouse_entered() -> void:
	outline_S.colour("red")

func _on_static_body_3d_mouse_exited() -> void:
	outline_S.colour("black")
