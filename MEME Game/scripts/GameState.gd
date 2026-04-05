extends Node

enum TileType { FOREST, HUMAN, PLANTATION }

const MAX_ELEPHANTS_PER_TILE := 1
const MAX_VILLAGERS_PER_TILE := 2

const VILLAGER_SLOT_OFFSETS := [
	Vector3(-0.45, 0.5, 0.0),
	Vector3(0.45, 0.5, 0.0)
]

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
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0},
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0},
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0},
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0}
]
var cards_played_this_turn: int = 0
var skip_next_turn = false

# Wildlife Department special ability state
var wildlife_dept_drawn_cards: Array = []  # the 2 bonus card IDs drawn each turn

# Government special ability state
# Key: player index (int) -> Array of stolen card IDs still available to replay
var government_stolen_cards: Dictionary = {}
# Card IDs already replayed (cannot be replayed again)
var government_replayed_cards: Array = []

# Environmental Consultant special ability state
# "" = not chosen yet, "None" = chose no ability, otherwise = role name borrowed
var ec_borrowed_ability: String = ""

# Track forest increase
var initial_forest_count: int = 0
var initial_plantation_count: int = 0
var initial_human_count: int = 0

# Deck
var draw_pile: Array = []
var discard_pile: Array = []
var player_hands: Array = [[], [], [], []]

# Elephant immunity: instance_id -> owner player index that applied immunity.
# Expires when turn returns to that same player.
var elephant_immunity_owner_by_id: Dictionary = {}

signal turn_changed(player_index: int, role_name: String, is_skipped: bool)


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
	initial_human_count = count_tiles_of_type(TileType.HUMAN)
	print("GameState: initial_forest_count set to ", initial_forest_count, " plantation: ", initial_plantation_count, " human: ", initial_human_count)

func get_forest_increase() -> int:
	return count_tiles_of_type(TileType.FOREST) - initial_forest_count

func get_plantation_increase() -> int:
	return count_tiles_of_type(TileType.PLANTATION) - initial_plantation_count

func get_human_increase() -> int:
	return count_tiles_of_type(TileType.HUMAN) - initial_human_count

func get_total_villagers() -> int:
	var total = 0
	for key in tile_registry:
		total += tile_registry[key]["villager_nodes"].size()
	return total

func get_valid_add_tiles(piece_type: String) -> Array:
	var result: Array = []
	for key in tile_registry:
		if can_place_piece(key, piece_type):
			result.append(key)
	return result

func get_valid_add_tiles_in(piece_type: String, type_filter: Array) -> Array:
	var result: Array = []
	for key in tile_registry:
		var entry = tile_registry[key]
		if not (entry["type"] in type_filter):
			continue
		if can_place_piece(key, piece_type):
			result.append(key)
	return result

func can_place_piece(tile_key: Vector2i, piece_type: String) -> bool:
	if not tile_registry.has(tile_key):
		return false
	var entry = tile_registry[tile_key]
	var is_elephant = piece_type == "elephant" or piece_type == "Elephant"
	if is_elephant:
		return entry["elephant_nodes"].size() < MAX_ELEPHANTS_PER_TILE
	return entry["villager_nodes"].size() < MAX_VILLAGERS_PER_TILE

func get_shortest_distance_human_elephant() -> int:
	var elephant_tiles: Array = []
	var human_tiles: Array = []
	var min_dist = -1
	for key in tile_registry:
		var entry = tile_registry[key]
		if entry["elephant_nodes"].size() > 0:
			elephant_tiles.append(key)
		if entry["villager_nodes"].size() > 0:
			human_tiles.append(key)
			
	if elephant_tiles.is_empty() or human_tiles.is_empty():
		return -1
		
	for e in elephant_tiles:
		for h in human_tiles:
			var dist = abs(e.x - h.x) + abs(e.y - h.y)
			if min_dist == -1 or dist < min_dist:
				min_dist = dist
	return min_dist

func get_elephants_in_forest() -> int:
	var count = 0
	for key in tile_registry:
		var entry = tile_registry[key]
		if entry["type"] == TileType.FOREST:
			count += entry["elephant_nodes"].size()
	return count

func count_vacant_secondary_met() -> int:
	var met_count = 0
	var roles = [
		"Conservationist", 
		"Village Head", 
		"Plantation Owner", 
		"Land Developer",
		"Ecotourism Manager",
		"Wildfire Department",
		"Researcher"
	]
	
	for role in roles:
		if role in player_roles:
			continue # Not vacant
			
		var is_met = false
		match role:
			"Conservationist":
				is_met = (get_forest_increase() >= 2)
			"Village Head":
				is_met = (get_total_villagers() >= 16)
			"Plantation Owner":
				is_met = (get_plantation_increase() >= 2)
			"Land Developer":
				is_met = (get_human_increase() >= 2)
			"Ecotourism Manager":
				var dist = get_shortest_distance_human_elephant()
				var total_e = 0
				for key in tile_registry:
					if tile_registry[key]["elephant_nodes"].size() > 0:
						total_e += 1
				is_met = (total_e > 0 and dist >= 3)
			"Wildfire Department":
				is_met = (get_elephants_in_forest() >= 4)
			"Researcher":
				is_met = (get_shortest_distance_human_elephant() >= 2)
				
		if is_met:
			met_count += 1
			
	return met_count

# --- Piece Tracking ---

func piece_placed(piece_node: Node3D, tile_key: Vector2i, piece_type: String) -> bool:
	if not tile_registry.has(tile_key):
		return false
	if not can_place_piece(tile_key, piece_type):
		return false
	var entry = tile_registry[tile_key]
	var is_elephant = piece_type == "elephant" or piece_type == "Elephant"
	if is_elephant:
		if not piece_node in entry["elephant_nodes"]:
			entry["elephant_nodes"].append(piece_node)
	else:
		if not piece_node in entry["villager_nodes"]:
			entry["villager_nodes"].append(piece_node)
	_reflow_tile_piece_positions(tile_key)
	return true

func piece_removed(piece_node: Node3D, tile_key: Vector2i, piece_type: String) -> void:
	if not tile_registry.has(tile_key):
		return
	var entry = tile_registry[tile_key]
	var is_elephant = piece_type == "elephant" or piece_type == "Elephant"
	if is_elephant:
		entry["elephant_nodes"].erase(piece_node)
	else:
		entry["villager_nodes"].erase(piece_node)
	_reflow_tile_piece_positions(tile_key)

func piece_moved(piece_node: Node3D, from_key: Vector2i, to_key: Vector2i, piece_type: String) -> void:
	piece_removed(piece_node, from_key, piece_type)
	if not piece_placed(piece_node, to_key, piece_type):
		# Destination was full; restore piece to original tile.
		piece_placed(piece_node, from_key, piece_type)

func _reflow_tile_piece_positions(tile_key: Vector2i) -> void:
	if not tile_registry.has(tile_key):
		return
	var entry = tile_registry[tile_key]
	var world_pos: Vector3 = entry["world_pos"]

	# Elephant stays centered on the tile.
	for elephant in entry["elephant_nodes"]:
		if is_instance_valid(elephant):
			elephant.position = world_pos

	# Villagers occupy fixed slots so two are visually distinct.
	var villagers: Array = entry["villager_nodes"]
	for i in range(villagers.size()):
		var villager = villagers[i]
		if not is_instance_valid(villager):
			continue
		if i < VILLAGER_SLOT_OFFSETS.size():
			villager.position = world_pos + VILLAGER_SLOT_OFFSETS[i]
		else:
			villager.position = world_pos + Vector3(0.0, 0.5, 0.0)


# --- Deck Management ---

func build_deck() -> void:
	draw_pile = []
	discard_pile = []
	# Include all Green, Yellow, and Red card IDs (one copy each)
	for card_id in CardData.ALL_CARDS:
		var color = CardData.ALL_CARDS[card_id].get("color", Color.WHITE)
		if color == Color.GREEN or color == Color.YELLOW or color == Color.RED or color == Color.BLACK:
			draw_pile.append(card_id)
	draw_pile.shuffle()

func deal_initial_hands() -> void:
	player_hands = [[], [], [], []]
	for i in range(player_count):
		for _j in range(5):
			while true:
				var card = _pop_from_draw_pile()
				if card != "":
					var color = CardData.ALL_CARDS[card].get("color", Color.WHITE)
					if color == Color.BLACK:
						draw_pile.insert(0, card)
						draw_pile.shuffle()
						continue
					player_hands[i].append(card)
					break 

func draw_card(player_index: int) -> String:
	var card = _pop_from_draw_pile()
	if card != "":
		player_hands[player_index].append(card)
	return card

# Wildlife Dept: draw 2 bonus cards (any color including black) at turn start
func wildlife_dept_draw_bonus(player_index: int) -> void:
	wildlife_dept_drawn_cards = []
	for _i in range(2):
		var card = _pop_from_draw_pile()
		if card != "":
			player_hands[player_index].append(card)
			wildlife_dept_drawn_cards.append(card)

# Wildlife Dept: discard the chosen bonus card from the player's hand
func wildlife_dept_discard_bonus(player_index: int, card_id: String) -> void:
	if card_id in player_hands[player_index]:
		player_hands[player_index].erase(card_id)
		discard_pile.append(card_id)
	wildlife_dept_drawn_cards.erase(card_id)

func discard_card(player_index: int, card_id: String) -> void:
	player_hands[player_index].erase(card_id)
	discard_pile.append(card_id)

# Government: add a stolen card to the Government player's stash and hand
func government_steal_card(gov_player_index: int, card_id: String) -> void:
	if not government_stolen_cards.has(gov_player_index):
		government_stolen_cards[gov_player_index] = []
	government_stolen_cards[gov_player_index].append(card_id)
	player_hands[gov_player_index].append(card_id)

# Government: mark a stolen card as replayed (can only replay each once)
func government_mark_replayed(card_id: String) -> void:
	government_replayed_cards.append(card_id)
	# Remove from all players' stolen stashes so it won't be replayed again
	for key in government_stolen_cards.keys():
		government_stolen_cards[key].erase(card_id)

# Government: check if a card has already been replayed
func government_can_replay(card_id: String) -> bool:
	return not (card_id in government_replayed_cards)

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
	_expire_elephant_immunity_for_player(current_player_index)
	cards_played_this_turn = 0
	var role_name = player_roles[current_player_index] if current_player_index < player_roles.size() else "Unknown"

	if skip_next_turn:
		skip_next_turn = false
		turn_changed.emit(current_player_index, role_name, true)
	else:
		turn_changed.emit(current_player_index, role_name, false)

# --- Elephant Immunity ---

func apply_elephant_immunity_for_round(owner_player_index: int) -> int:
	var elephants = get_tree().get_nodes_in_group("elephants")
	var applied_count := 0
	for elephant in elephants:
		if not is_instance_valid(elephant):
			continue
		var elephant_id := elephant.get_instance_id()
		elephant_immunity_owner_by_id[elephant_id] = owner_player_index
		elephant.set_meta("is_immune", true)
		elephant.set_meta("immune_owner_player", owner_player_index)
		applied_count += 1
	return applied_count

func is_elephant_immune(elephant: Node) -> bool:
	if not is_instance_valid(elephant):
		return false
	var elephant_id := elephant.get_instance_id()
	if not elephant_immunity_owner_by_id.has(elephant_id):
		return false
	return true

func _expire_elephant_immunity_for_player(player_index: int) -> void:
	var expired_ids: Array = []
	for elephant_id in elephant_immunity_owner_by_id.keys():
		if elephant_immunity_owner_by_id[elephant_id] == player_index:
			expired_ids.append(elephant_id)

	if expired_ids.is_empty():
		return

	for elephant_id in expired_ids:
		elephant_immunity_owner_by_id.erase(elephant_id)

	# Keep node metadata in sync for debugging/inspection.
	var elephants = get_tree().get_nodes_in_group("elephants")
	for elephant in elephants:
		if not is_instance_valid(elephant):
			continue
		var elephant_id := elephant.get_instance_id()
		if expired_ids.has(elephant_id):
			elephant.set_meta("is_immune", false)
			elephant.set_meta("immune_owner_player", -1)


# --- Helpers ---

func _parse_type_string(s: String) -> int:
	match s:
		"FOREST":     return TileType.FOREST
		"HUMAN":      return TileType.HUMAN
		"PLANTATION": return TileType.PLANTATION
	return TileType.FOREST
