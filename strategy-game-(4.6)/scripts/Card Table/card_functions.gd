extends Node3D

signal delete_Elephant
signal increase_total_Elephant

signal delete_Meeple
signal increase_total_Meeple

const ELEPHANT_SCENE = preload("res://assets/Pieces/Elephant.tscn")
const MEEPLE_SCENE = preload("res://assets/Pieces/Meeple.tscn")

var meeple_count: int = 0
var elephant_count: int = 0

func _ready() -> void:
	pass

# Tile-aware spawn — used by CardEffects with a known tile_key
func spawn_piece_on_tile(type: String, pos: Vector3, tile_key: Vector2i) -> void:
	var piece_instance

	if type == "elephant" or type == "Elephant":
		piece_instance = ELEPHANT_SCENE.instantiate()
		emit_signal("increase_total_Elephant")
		add_child(piece_instance)
		piece_instance.Del_Elephant.connect(func():
			elephant_count += 1
			GameState.piece_removed(piece_instance, piece_instance.tile_key, "elephant")
		)

	elif type == "villager" or type == "Meeple":
		piece_instance = MEEPLE_SCENE.instantiate()
		emit_signal("increase_total_Meeple")
		add_child(piece_instance)
		piece_instance.Del_Meeple.connect(func():
			meeple_count += 1
			GameState.piece_removed(piece_instance, piece_instance.tile_key, "villager")
		)

	if piece_instance:
		piece_instance.position = pos
		piece_instance.tile_key = tile_key
		if type in ["villager", "Meeple"]:
			piece_instance.position.y += 0.5
		GameState.piece_placed(
			piece_instance,
			tile_key,
			"elephant" if type in ["Elephant", "elephant"] else "villager"
		)

# Legacy wrapper — used by the manual placement (dropdown mode) flow in card_table.gd
func spawn_piece(type: String, pos: Vector3) -> void:
	var key = _pos_to_tile_key(pos)
	spawn_piece_on_tile(type, pos, key)

func _pos_to_tile_key(pos: Vector3) -> Vector2i:
	for key in GameState.tile_registry:
		var entry = GameState.tile_registry[key]
		if entry["world_pos"].distance_to(pos) < 1.1:
			return key
	return Vector2i(-1, -1)

func del_Elephant():
	emit_signal("delete_Elephant")

func del_Meeple():
	emit_signal("delete_Meeple")
