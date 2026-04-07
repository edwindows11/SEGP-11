extends CharacterBody3D

# --- Exports ---

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.25
# Pitch clamps so the camera can't flip past straight up/down.
@export var tilt_upper_limit := PI / 3.0
@export var tilt_lower_limit := -PI / 6.0

# --- State ---
# Per-frame mouse delta consumed by _physics_process.
var _camera_input_direction := Vector2.ZERO

@onready var _camera_pivot: Node3D = $CameraPivot


# --- Input handling ---

# Toggle mouse capture: Esc releases, left-click recaptures for camera control.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# Capture mouse motion deltas to feed into the pivot rotation next physics tick.
func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


# --- Camera update ---

# Apply accumulated mouse delta to pivot, clamp pitch, then reset the delta.
func _physics_process(delta: float) -> void:
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit)
	_camera_pivot.rotation.y -= _camera_input_direction.x * delta

	_camera_input_direction = Vector2.ZERO
