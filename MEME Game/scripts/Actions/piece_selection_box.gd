extends HBoxContainer
#paths
const ENUM = preload("res://scripts/Actions/enums.gd")

func _ready():
	add_selection_piece(Enums.pieces.ELEPHANT, 0.18)
	add_selection_piece(Enums.pieces.HUMAN, 0.20)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func add_selection_piece(piece_type: int, scale_value: float):
	var texture: Texture
	
	if (piece_type == ENUM.pieces.ELEPHANT):
		texture = Enums.PIECE_PATH.ELEPHANT_2D
	elif (piece_type == ENUM.pieces.HUMAN):
		texture =  Enums.PIECE_PATH.HUMAN_2D
	else:
		return ("Piece type not found")
		
	
	var btn := TextureButton.new()
	
	#button img
	btn.texture_normal = texture
	btn.texture_hover = texture
	btn.texture_pressed = texture
	
	#btn size
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = texture.get_size() * scale_value
	
	btn.pressed.connect(func()->void:
		emit_signal("piece_pressed", piece_type)
		print(piece_type)
		)
	
	add_child(btn)
	
