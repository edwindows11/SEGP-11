extends Node3D

const BOARD_SIZE = 10
const TILE_SIZE = 2.0 # Adjust based on your tile mesh size

# Preload tile scenes/assets
const FOREST_TILE = preload("res://assets/Tiles/ForestTile.glb")
const HUMAN_TILE = preload("res://assets/Tiles/HumanDominatedTile.glb")
const PLANTATION_TILE = preload("res://assets/Tiles/PlantationTile.glb")

func _ready() -> void:
	generate_board()

func generate_board():
	for x in range(BOARD_SIZE):
		for z in range(BOARD_SIZE):
			var tile_instance = FOREST_TILE.instantiate()
			add_child(tile_instance)
			
			# Center the board
			var offset = (BOARD_SIZE * TILE_SIZE) / 2.0
			tile_instance.position = Vector3(x * TILE_SIZE - offset, 0, z * TILE_SIZE - offset)
			
			# Optional: Add collision for raycasting if tiles don't have it
			create_tile_collider(tile_instance)

func create_tile_collider(tile_node: Node3D):
	# Check if collider exists, if not add one
	# primitives usually need a StaticBody3D with CollisionShape3D
	var static_body = StaticBody3D.new()
	tile_node.add_child(static_body)
	
	var collision_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(TILE_SIZE, 0.2, TILE_SIZE) # Thin floor
	collision_shape.shape = box
	static_body.add_child(collision_shape)
	
	# Set layers/collision if needed
	static_body.collision_layer = 1
