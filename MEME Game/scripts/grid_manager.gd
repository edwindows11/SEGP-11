extends Node3D

@export var grid_size: float = 2.0
@export var elephant_scene: PackedScene

var current_dragged_unit: Node3D = null

var placed_unit: Node3D = null

func _unhandled_input(event):
	# Handle Mouse Button Inputs (Press/Release)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start Dragging
			start_dragging(event.position)
		elif current_dragged_unit:
			# Stop Dragging (Place)
			finish_dragging()
	
	# Handle Mouse Motion (Dragging)
	elif event is InputEventMouseMotion and current_dragged_unit:
		update_drag_position(event.position)

func start_dragging(screen_pos: Vector2):
	if placed_unit:
		# Pick up existing unit
		current_dragged_unit = placed_unit
	elif elephant_scene:
		# Spawn new unit if none exists
		placed_unit = elephant_scene.instantiate()
		add_child(placed_unit)
		current_dragged_unit = placed_unit
	
	update_drag_position(screen_pos)

func update_drag_position(screen_pos: Vector2):
	var world_pos = get_world_position_from_screen(screen_pos)
	if world_pos:
		var grid_pos = world_to_grid(world_pos)
		current_dragged_unit.global_position = grid_to_world(grid_pos)

func finish_dragging():
	current_dragged_unit = null

func get_world_position_from_screen(screen_pos: Vector2):
	var camera = get_viewport().get_camera_3d()
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		return result.position
	return null

func world_to_grid(world_pos: Vector3) -> Vector2i:
	var x = floor(world_pos.x / grid_size)
	var z = floor(world_pos.z / grid_size)
	return Vector2i(x, z)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var x = grid_pos.x * grid_size + grid_size / 2.0
	var z = grid_pos.y * grid_size + grid_size / 2.0
	return Vector3(x, 0, z)
