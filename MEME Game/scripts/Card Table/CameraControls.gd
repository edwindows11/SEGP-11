extends Camera3D

# Camera Settings
var rotation_speed: float = 0.5
var zoom_speed: float = 2.0
var zoom_min: float = 5.0
var zoom_max: float = 30.0
var smoothing: float = 10.0

# State
var pivot_point: Vector3 = Vector3(0, 0, 0)
var current_rotation: Vector2 = Vector2(0, deg_to_rad(45)) # Yaw (X), Pitch (Y)
var target_rotation: Vector2 = Vector2(0, deg_to_rad(45))
var current_zoom: float = 15.0
var target_zoom: float = 15.0
var is_dragging: bool = false
var _mouse_held: bool = false
var _drag_total: float = 0.0
const DRAG_THRESHOLD: float = 5.0  # pixels mouse must move before rotation begins

func _ready() -> void:
	# Calculate initial rotation/zoom 
	update_camera_transform()

func _process(delta: float) -> void:
	# Smoothly interpolate values
	current_rotation = current_rotation.lerp(target_rotation, smoothing * delta)
	current_zoom = lerp(current_zoom, target_zoom, smoothing * delta)
	
	update_camera_transform()

func update_camera_transform() -> void:
	# Convert spherical coordinates to Cartesian
	var x = current_zoom * cos(current_rotation.y) * sin(current_rotation.x)
	var y = current_zoom * sin(current_rotation.y) # Y-up in Godot depends on pitch definition
	
	# Reset Position
	position = pivot_point
	rotation = Vector3.ZERO
	
	# calculate offset manually to avoid gimbal lock issues if we used Euler directly on the node repeatedly
	

	# Start at (0, 0, zoom), 
	#r otate around X axis (Pitch), rotate around Y axis
	
	var offset = Vector3(0, 0, current_zoom)
	
	# start position
	var cam_basis = Basis()
	cam_basis = cam_basis.rotated(Vector3(1, 0, 0), -current_rotation.y)
	cam_basis = cam_basis.rotated(Vector3(0, 1, 0), -current_rotation.x)

	position = pivot_point + (cam_basis * offset)
	look_at(pivot_point)


func _unhandled_input(event: InputEvent) -> void:
	if _is_board_input_blocked():
		return
	if event is InputEventMouseButton:
		#zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom - zoom_speed, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom + zoom_speed, zoom_min, zoom_max)
		
		# drag
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_held = true
				_drag_total = 0.0
				is_dragging = false
			else:
				_mouse_held = false
				is_dragging = false

	if event is InputEventMouseMotion and _mouse_held:
		_drag_total += event.relative.length()
		if _drag_total >= DRAG_THRESHOLD:
			is_dragging = true
		if is_dragging:
			target_rotation.x += event.relative.x * rotation_speed * 0.01
			target_rotation.y += event.relative.y * rotation_speed * 0.01
			target_rotation.y = clamp(target_rotation.y, deg_to_rad(10), deg_to_rad(85))

	# Q / E to snap-rotate 90° 
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_snap_rotate(-90.0)
		elif event.keycode == KEY_E:
			_snap_rotate(90.0)


func _is_board_input_blocked() -> bool:
	for node in get_tree().get_nodes_in_group("blocks_board_input"):
		if node is Control and node.visible:
			return true
	return false

# Snap to the nearest multiple of 90°
func _snap_rotate(degrees: float) -> void:
	var step: float = deg_to_rad(90.0)
	var snapped_rot: float = round(target_rotation.x / step) * step
	target_rotation.x = snapped_rot + deg_to_rad(degrees)
