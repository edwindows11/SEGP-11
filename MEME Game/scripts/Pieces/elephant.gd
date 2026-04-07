extends Node3D

# --- Exports ---

@export var mesh: MeshInstance3D
@export var material: StandardMaterial3D

# --- Outline helper ---
# Shared outline script instance used to highlight this elephant on hover/select.
const OUTLINE = preload("res://scripts/Pieces/outline.gd")
var outline_S = OUTLINE.new()

# --- State ---
var parent:Node3D
var selected: bool = false
# Grid coordinate this elephant occupies; (-1,-1) means unplaced.
var tile_key: Vector2i = Vector2i(-1, -1)

# --- Signals ---
signal Del_Elephant

# --- Lifecycle ---
func _ready() -> void:
	add_to_group("elephants")
	parent = get_parent_node_3d()
	# Initialise the outline helper with this elephant's mesh + material.
	outline_S.new(mesh, material)

	# Forward parent's delete-mode toggles into the outline helper.
	if parent != null:
		parent.delete_Elephant.connect(outline_S.deleteFunc)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# --- Input / hover callbacks ---

# Click handler: only fires Del_Elephant when delete-mode is active.
func _on_static_body_3d_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton \
	  and event.button_index == MOUSE_BUTTON_LEFT \
	  and event.pressed\
	  and outline_S.delete == true:
		emit_signal("Del_Elephant")
		selected = true

# Highlight red while the cursor is over this elephant.
func _on_static_body_3d_mouse_entered() -> void:
	outline_S.colour("red")

# Restore black outline on exit unless this elephant stays selected.
func _on_static_body_3d_mouse_exited() -> void:
	if selected == false:
		outline_S.colour("black")
