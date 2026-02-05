extends Node3D

signal delete_Elephant
signal increase_total_Elephant

signal delete_Meeple
signal increase_total_Meeple

const ELEPHANT_SCENE = preload("res://assets/Pieces/Elephant.tscn")
const MEEPLE_SCENE = preload("res://assets/Pieces/Meeple.tscn")

var meeple_count: int = 0
var elephant_count: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Clean slate - no initial spawning
	pass

func spawn_piece(type: String, pos: Vector3) -> void:
	var piece_instance
	
	if type == "Elephant":
		piece_instance = ELEPHANT_SCENE.instantiate()
		emit_signal("increase_total_Elephant")
		add_child(piece_instance)
		piece_instance.Del_Elephant.connect(func(): elephant_count += 1)
		
	elif type == "Meeple":
		piece_instance = MEEPLE_SCENE.instantiate()
		emit_signal("increase_total_Meeple")
		add_child(piece_instance)
		piece_instance.Del_Meeple.connect(func(): meeple_count += 1)
	
	if piece_instance:
		piece_instance.position = pos
		if type == "Meeple":
			# Bump up slightly to avoid clipping (pivot is likely center)
			# Scale 0.25 -> 2 units tall? -> 0.5 tall -> offset 0.25?
			# Trial and error value, 0.5 should be safe above ground
			piece_instance.position.y += 0.5

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func del_Elephant():
	emit_signal("delete_Elephant")

func del_Meeple():
	emit_signal("delete_Meeple")
	
	
