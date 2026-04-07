extends Node
class_name Enums

# --- Piece type enum ---
# Canonical identifiers for every kind of board piece in the game.
enum pieces {
	ELEPHANT,
	HUMAN,
	PLANTATION,
	HUMAN_DOMINATED_LAND,
	FOREST,
}

# --- Asset lookup ---
# 2D sprite assets keyed by piece name, used by UI/HUD elements.
const PIECE_PATH = {
	"ELEPHANT_2D": preload("res://assets/Pieces/Elephant2D.png"),
	"HUMAN_2D":preload("res://assets/Pieces/Meeple2D.png"),
}
