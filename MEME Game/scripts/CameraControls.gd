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

func _ready() -> void:
	# Calculate initial rotation/zoom based on EDITOR transform if you wanted, 
	# but setting defaults is safer for consistent behavior.
	update_camera_transform()

func _process(delta: float) -> void:
	# Smoothly interpolate values
	current_rotation = current_rotation.lerp(target_rotation, smoothing * delta)
	current_zoom = lerp(current_zoom, target_zoom, smoothing * delta)
	
	update_camera_transform()

func update_camera_transform() -> void:
	# Convert spherical coordinates to Cartesian
	# Y is pitch (vertical angle), X is yaw (horizontal angle)
	var x = current_zoom * cos(current_rotation.y) * sin(current_rotation.x)
	var y = current_zoom * sin(current_rotation.y) # Y-up in Godot depends on pitch definition
	# Actually, standard Spherical to Cartesian (Y-up):
	# x = r * sin(theta) * sin(phi)
	# y = r * cos(theta)
	# z = r * sin(theta) * cos(phi)
	# But let's stick to a simpler pivot rotation logic often used in games:
	
	# Reset Position
	position = pivot_point
	rotation = Vector3.ZERO
	
	# Apply rotations (Pitch then Yaw) - Order matters for avoiding roll
	# We'll calculate offset manually to avoid gimbal lock issues if we used Euler directly on the node repeatedly
	
	# Simplified Orbit Logic:
	# 1. Start at (0, 0, zoom)
	# 2. Rotate around X axis (Pitch)
	# 3. Rotate around Y axis (Yaw)
	
	var offset = Vector3(0, 0, current_zoom)
	
	# Pitch (Vertical) - Rotate around X
	# We want pitch to correspond to looking down. 
	# -90 deg (looking straight down) to 0 (horizon) roughly.
	# Let's effectively rotate the offset vector.
	
	var basis = Basis()
	basis = basis.rotated(Vector3(1, 0, 0), -current_rotation.y) # Pitch
	basis = basis.rotated(Vector3(0, 1, 0), -current_rotation.x) # Yaw
	
	position = pivot_point + (basis * offset)
	look_at(pivot_point)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clamp(target_zoom - zoom_speed, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clamp(target_zoom + zoom_speed, zoom_min, zoom_max)
		
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = event.pressed
			if is_dragging:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseMotion and is_dragging:
		# Adjust target rotation based on mouse delta
		target_rotation.x += event.relative.x * rotation_speed * 0.01
		target_rotation.y += event.relative.y * rotation_speed * 0.01
		
		# Clamp Pitch (Vertical look)
		# Prevent flipping over the top (approx 10 degrees to 80 degrees relative to ground)
		target_rotation.y = clamp(target_rotation.y, deg_to_rad(10), deg_to_rad(85))


