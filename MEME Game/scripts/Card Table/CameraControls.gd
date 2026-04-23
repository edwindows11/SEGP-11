## The camera moves around a fixed centre point (the board). 
## Left-click drag rotates the view, mouse wheel zooms, and Q / E snap-rotate by 90 degrees.

extends Camera3D

## How fast drag rotates the camera.
var rotation_speed: float = 0.5
## How much one wheel click changes the zoom.
var zoom_speed: float = 2.0
## Closest the camera can zoom in.
var zoom_min: float = 5.0
## Furthest the camera can zoom out.
var zoom_max: float = 30.0
## How quickly the smoothed values catch up to the target values.
var smoothing: float = 10.0

## The point the camera orbits around (the centre of the board).
var pivot_point: Vector3 = Vector3(0, 0, 0)
## Current rotation: X = yaw (spin around), Y = pitch (up/down).
var current_rotation: Vector2 = Vector2(0, deg_to_rad(45))
## Where the rotation is heading. Smoothing blends current toward target.
var target_rotation: Vector2 = Vector2(0, deg_to_rad(45))
## Current distance from pivot.
var current_zoom: float = 15.0
## Target zoom distance.
var target_zoom: float = 15.0
## True while the mouse is moving enough to count as a rotate drag.
var is_dragging: bool = false
## True while the left mouse button is held down.
var _mouse_held: bool = false
## Total pixels the mouse has moved since the click started.
var _drag_total: float = 0.0
## Mouse must move at least this many pixels before a drag starts rotating.
const DRAG_THRESHOLD: float = 5.0

func _ready() -> void:
	# Calculate initial rotation/zoom 
	update_camera_transform()

## Smoothly blends current rotation / zoom toward target values each frame, then updates the camera position so it feels fluid.
func _process(delta: float) -> void:
	current_rotation = current_rotation.lerp(target_rotation, smoothing * delta)
	current_zoom = lerp(current_zoom, target_zoom, smoothing * delta)

	update_camera_transform()

## Moves and rotates the Camera3D based on the current pivot, rotation and zoom values. 
## Called every frame from _process.
func update_camera_transform() -> void:
	# Convert spherical coordinates to Cartesian
	var x = current_zoom * cos(current_rotation.y) * sin(current_rotation.x)
	var y = current_zoom * sin(current_rotation.y) # Y-up in Godot depends on pitch definition
	
	# Reset Position
	position = pivot_point
	rotation = Vector3.ZERO
	

	# Start at (0, 0, zoom), 
	# rotate around X axis (Pitch), rotate around Y axis
	
	var offset = Vector3(0, 0, current_zoom)
	
	# start position
	var cam_basis = Basis()
	cam_basis = cam_basis.rotated(Vector3(1, 0, 0), -current_rotation.y)
	cam_basis = cam_basis.rotated(Vector3(0, 1, 0), -current_rotation.x)

	position = pivot_point + (cam_basis * offset)
	look_at(pivot_point)


## Handles input for the camera: wheel zoom, left-drag rotate, and Q / E snap-rotate. 
## Skips everything if a UI overlay (like Played Cards) is open.
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


## Returns true if any Control node in the "blocks_board_input" group is visible. 
## While one is open, the camera ignores all input so the overlay can take the clicks.
func _is_board_input_blocked() -> bool:
	for node in get_tree().get_nodes_in_group("blocks_board_input"):
		if node is Control and node.visible:
			return true
	return false

## Rotates the camera by `degrees` (left = -90, right = +90), snapping to
## the nearest multiple of 90 first so repeated presses are predictable.
func _snap_rotate(degrees: float) -> void:
	var step: float = deg_to_rad(90.0)
	var snapped_rot: float = round(target_rotation.x / step) * step
	target_rotation.x = snapped_rot + deg_to_rad(degrees)
