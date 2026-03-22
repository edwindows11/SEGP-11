extends Node

enum TileType { FOREST, HUMAN, PLANTATION }

# Tile registry
# Key: Vector2i(grid_x, grid_z)
# Value: {
#   "type": TileType int,
#   "node": Node3D,
#   "world_pos": Vector3,
#   "elephant_nodes": Array,
#   "villager_nodes": Array
# }
var tile_registry: Dictionary = {}

# Scenario selection (-1 = not chosen yet, 0..4 = preset, 5 = random)
var selected_scenario_index: int = -1

# Turn state
var current_player_index: int = 0
var player_count: int = 4
var player_roles: Array = []
var player_stats: Array = [
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0},
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0},
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0},
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0}
]
var cards_played_this_turn: int = 0

# Track forest increase
var initial_forest_count: int = 0
var initial_plantation_count: int = 0

# Deck
var draw_pile: Array = []
var discard_pile: Array = []
var player_hands: Array = [[], [], [], []]

signal turn_changed(player_index: int, role_name: String)


# --- Tile Registration ---

func register_tile(x: int, z: int, tile_type: int, node: Node3D, world_pos: Vector3) -> void:
	var key = Vector2i(x, z)
	tile_registry[key] = {
		"type": tile_type,
		"node": node,
		"world_pos": world_pos,
		"elephant_nodes": [],
		"villager_nodes": []
	}

func get_tiles_of_type(tile_type: int) -> Array:
	var result: Array = []
	for key in tile_registry:
		if tile_registry[key]["type"] == tile_type:
			result.append(key)
	return result

func get_tiles_matching(types: Array) -> Array:
	var int_types: Array = []
	for t in types:
		if t is int:
			int_types.append(t)
		else:
			int_types.append(_parse_type_string(t))
	var result: Array = []
	for key in tile_registry:
		if tile_registry[key]["type"] in int_types:
			result.append(key)
	return result

func count_tiles_of_type(tile_type: int) -> int:
	var c = 0
	for key in tile_registry:
		if tile_registry[key]["type"] == tile_type:
			c += 1
	return c

func setup_stats() -> void:
	initial_forest_count = count_tiles_of_type(TileType.FOREST)
	initial_plantation_count = count_tiles_of_type(TileType.PLANTATION)
	print("GameState: initial_forest_count set to ", initial_forest_count, " plantation: ", initial_plantation_count)

func get_forest_increase() -> int:
	return count_tiles_of_type(TileType.FOREST) - initial_forest_count

func get_plantation_increase() -> int:
	return count_tiles_of_type(TileType.PLANTATION) - initial_plantation_count

func get_total_villagers() -> int:
	var total = 0
	for key in tile_registry:
		total += tile_registry[key]["villager_nodes"].size()
	return total

func get_valid_add_tiles(piece_type: String) -> Array:
	var result: Array = []
	for key in tile_registry:
		var entry = tile_registry[key]
		if piece_type == "elephant" and entry["elephant_nodes"].size() < 1:
			result.append(key)
		elif piece_type == "villager" and entry["villager_nodes"].size() < 2:
			result.append(key)
	return result

func get_valid_add_tiles_in(piece_type: String, type_filter: Array) -> Array:
	var result: Array = []
	for key in tile_registry:
		var entry = tile_registry[key]
		if not (entry["type"] in type_filter):
			continue
		if piece_type == "elephant" and entry["elephant_nodes"].size() < 1:
			result.append(key)
		elif piece_type == "villager" and entry["villager_nodes"].size() < 2:
			result.append(key)
	return result


# --- Piece Tracking ---

func piece_placed(piece_node: Node3D, tile_key: Vector2i, piece_type: String) -> void:
	if not tile_registry.has(tile_key):
		return
	var entry = tile_registry[tile_key]
	if piece_type == "elephant":
		if not piece_node in entry["elephant_nodes"]:
			entry["elephant_nodes"].append(piece_node)
	else:
		if not piece_node in entry["villager_nodes"]:
			entry["villager_nodes"].append(piece_node)

func piece_removed(piece_node: Node3D, tile_key: Vector2i, piece_type: String) -> void:
	if not tile_registry.has(tile_key):
		return
	var entry = tile_registry[tile_key]
	if piece_type == "elephant":
		entry["elephant_nodes"].erase(piece_node)
	else:
		entry["villager_nodes"].erase(piece_node)

func piece_moved(piece_node: Node3D, from_key: Vector2i, to_key: Vector2i, piece_type: String) -> void:
	piece_removed(piece_node, from_key, piece_type)
	piece_placed(piece_node, to_key, piece_type)


# --- Deck Management ---

func build_deck() -> void:
	draw_pile = []
	discard_pile = []
	# Include all Green, Yellow, and Red card IDs (one copy each)
	for card_id in CardData.ALL_CARDS:
		var color = CardData.ALL_CARDS[card_id].get("color", Color.WHITE)
		if color == Color.GREEN or color == Color.YELLOW or color == Color.RED:
			draw_pile.append(card_id)
	draw_pile.shuffle()

func deal_initial_hands() -> void:
	player_hands = [[], [], [], []]
	for i in range(player_count):
		for _j in range(5):
			var card = _pop_from_draw_pile()
			if card != "":
				player_hands[i].append(card)

func draw_card(player_index: int) -> String:
	var card = _pop_from_draw_pile()
	if card != "":
		player_hands[player_index].append(card)
	return card

func discard_card(player_index: int, card_id: String) -> void:
	player_hands[player_index].erase(card_id)
	discard_pile.append(card_id)

func _pop_from_draw_pile() -> String:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return ""
		draw_pile = discard_pile.duplicate()
		discard_pile = []
		draw_pile.shuffle()
	return draw_pile.pop_back()


# --- Turn Management ---

func advance_turn() -> void:
	current_player_index = (current_player_index + 1) % player_count
	cards_played_this_turn = 0
	var role_name = player_roles[current_player_index] if current_player_index < player_roles.size() else "Unknown"
	turn_changed.emit(current_player_index, role_name)


# --- Helpers ---

func _parse_type_string(s: String) -> int:
	match s:
		"FOREST":     return TileType.FOREST
		"HUMAN":      return TileType.HUMAN
		"PLANTATION": return TileType.PLANTATION
	return TileType.FOREST
