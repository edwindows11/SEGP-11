## Track turns, tiles and card in hand. reads from GameState. 
## Tracks the deck (draw pile + discard pile), per-player stats for win conditions,
## role-specific state, and elephant immunity across turns.
extends Node

## The three kinds of tile on the board.
enum TileType { FOREST, HUMAN, PLANTATION }

## Maximum number of elephants that can share one tile.
const MAX_ELEPHANTS_PER_TILE := 1
## Maximum number of villagers that can share one tile.
const MAX_VILLAGERS_PER_TILE := 2

## Local position offsets for up to 2 villagers on the same tile so they don't visually overlap.
const VILLAGER_SLOT_OFFSETS := [
	Vector3(-0.45, 0.5, 0.0),
	Vector3(0.45, 0.5, 0.0)
]

## Maps Vector2i(grid_x, grid_z) - Dictionary with the tile's type, node, world position, and lists of elephant / villager nodes on that tile.
var tile_registry: Dictionary = {}

## Which scenario the player picked (-1 = not chosen, 0..4 = preset, 5 = random).
var selected_scenario_index: int = -1

## Whose turn it is right now. Index into player_roles.
var current_player_index: int = 0
## How many players are in the game (fixed at 4).
var player_count: int = 4
## Role name for each player slot
var player_roles: Array = []
## Per-player stats used for win-condition checking. One dictionary per player.
var player_stats: Array = [
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0},
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0},
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0},
	{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0}
]
## How many cards the current player has played this turn. 
var cards_played_this_turn: int = 0
## When true, the next turn is announced as skipped. Used by effects that freeze a player.
var skip_next_turn = false
## True once someone has met their win condition. 
## Blocks [advance_turn()] so no new turns start after the win screen shows.
var is_game_over: bool = false

## The 2 bonus card IDs Wildlife Department drew this turn. 
## The player must discard one of these before ending the turn.
var wildlife_dept_drawn_cards: Array = []

## Which role's ability the Environmental Consultant borrowed this game.
## "" = not chosen yet, "None" = chose none, otherwise the borrowed role name.
var ec_borrowed_ability: String = ""

## Number of forest tile type when the game started. 
var initial_forest_count: int = 0
## Number of plantation tile type when the game started. 
var initial_plantation_count: int = 0
## Number of human tile type when the game started. 
var initial_human_count: int = 0

## Cards waiting to be drawn, in order.
var draw_pile: Array = []
## Cards played or discarded this game. 
## Shuffled back into draw_pile if draw_pile empties.
var discard_pile: Array = []
## One array of card IDs per player. Length matches player_count.
var player_hands: Array = [[], [], [], []]
## Tracks cards the Government player stole but hasn't replayed yet.
var government_stolen_cards: Dictionary = {}

## Maps elephant instance_id to the player index that gave it immunity.
## Immunity expires when the turn comes back to that player.
var elephant_immunity_owner_by_id: Dictionary = {}

## Emitted when the turn advances. card_table_ui and [bot.gd] listen for this.
signal turn_changed(player_index: int, role_name: String, is_skipped: bool)


## Clears everything so the next game starts fresh. 
## Called from PauseMenu's "Return to Main Menu" button.
func reset() -> void:
	tile_registry.clear()
	selected_scenario_index = -1
	current_player_index = 0
	player_count = 4
	player_roles.clear()
	player_stats = [
		{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0},
		{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0},
		{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0},
		{"green_cards_played": 0, "red_cards_played": 0, "yellow_cards_played": 0, "action_cards_played": 0, "e_inc_cards": 0, "v_inc_cards": 0, "both_inc_cards": 0}
	]
	cards_played_this_turn = 0
	skip_next_turn = false
	is_game_over = false
	wildlife_dept_drawn_cards.clear()
	ec_borrowed_ability = ""
	initial_forest_count = 0
	initial_plantation_count = 0
	initial_human_count = 0
	draw_pile.clear()
	discard_pile.clear()
	player_hands = [[], [], [], []]
	government_stolen_cards.clear()
	elephant_immunity_owner_by_id.clear()


## Adds a new tile to tile_registry. 
## Called by [Board.gd] as it builds the 8x8 grid so other scripts can look up tiles by grid key.
func register_tile(x: int, z: int, tile_type: int, node: Node3D, world_pos: Vector3) -> void:
	var key = Vector2i(x, z)
	tile_registry[key] = {
		"type": tile_type,
		"node": node,
		"world_pos": world_pos,
		"elephant_nodes": [],
		"villager_nodes": []
	}

## Returns every tile key whose type matches [tile_type].
func get_tiles_of_type(tile_type: int) -> Array:
	var result: Array = []
	for key in tile_registry:
		if tile_registry[key]["type"] == tile_type:
			result.append(key)
	return result

## Returns every tile key whose type is in the [types] list. A
## Accepts either int tile types or strings like "FOREST", "HUMAN", "PLANTATION".
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

## Counts how many tiles on the board are of the given type.
func count_tiles_of_type(tile_type: int) -> int:
	var c = 0
	for key in tile_registry:
		if tile_registry[key]["type"] == tile_type:
			c += 1
	return c

## Records the starting tile counts so win conditions to have a baseline to compare against. 
## Called once when the game starts.
func setup_stats() -> void:
	initial_forest_count = count_tiles_of_type(TileType.FOREST)
	initial_plantation_count = count_tiles_of_type(TileType.PLANTATION)
	initial_human_count = count_tiles_of_type(TileType.HUMAN)
	print("GameState: initial_forest_count set to ", initial_forest_count, " plantation: ", initial_plantation_count, " human: ", initial_human_count)

## How many forest tiles have been added since the start.
func get_forest_increase() -> int:
	return count_tiles_of_type(TileType.FOREST) - initial_forest_count

## How many plantation tiles have been added since the start.
func get_plantation_increase() -> int:
	return count_tiles_of_type(TileType.PLANTATION) - initial_plantation_count

## How many human/village tiles have been added since the start.
func get_human_increase() -> int:
	return count_tiles_of_type(TileType.HUMAN) - initial_human_count

## Total number of villagers on the board right now.
func get_total_villagers() -> int:
	var total = 0
	for key in tile_registry:
		total += tile_registry[key]["villager_nodes"].size()
	return total

## Returns every tile where the given piece type ("elephant" / "villager") could be placed right now.
func get_valid_add_tiles(piece_type: String) -> Array:
	var result: Array = []
	for key in tile_registry:
		if can_place_piece(key, piece_type):
			result.append(key)
	return result


## Returns every tile where the given piece type ("elephant" / "villager") could be placed right now with [type_filter].
func get_valid_add_tiles_in(piece_type: String, type_filter: Array) -> Array:
	var result: Array = []
	for key in tile_registry:
		var entry = tile_registry[key]
		if not (entry["type"] in type_filter):
			continue
		if can_place_piece(key, piece_type):
			result.append(key)
	return result

## Returns true if the given piece can be placed on this tile.
## Elephants - empty tile.
## Villagers - no elephant && < 2 villagers.
func can_place_piece(tile_key: Vector2i, piece_type: String) -> bool:
	if not tile_registry.has(tile_key):
		return false
	var entry = tile_registry[tile_key]
	var is_elephant = piece_type == "elephant" or piece_type == "Elephant"
	if is_elephant:
		if entry["villager_nodes"].size() > 0:
			return false
		return entry["elephant_nodes"].size() < MAX_ELEPHANTS_PER_TILE
	if entry["elephant_nodes"].size() > 0:
		return false
	return entry["villager_nodes"].size() < MAX_VILLAGERS_PER_TILE

## Returns the shortest Manhattan distance between any elephant and any villager on the board. 
## Returns -1 if either side is missing.
## Used by Ecotourism Manager and Researcher win conditions.
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

## Counts how many elephants are sitting on forest tiles right now.
## Used by the Wildlife Department win condition.
func get_elephants_in_forest() -> int:
	var count = 0
	for key in tile_registry:
		var entry = tile_registry[key]
		if entry["type"] == TileType.FOREST:
			count += entry["elephant_nodes"].size()
	return count

## Counts how many "vacant" role goals have been met on the board.
## A vacant role is one that isn't assigned to any player. 
## Used by the Environmental Consultant win condition (needs 2 vacant goals met).
func count_vacant_secondary_met() -> int:
	var met_count = 0
	var roles = [
		"Conservationist", 
		"Village Head", 
		"Plantation Owner", 
		"Land Developer",
		"Ecotourism Manager",
		"Wildlife Department",
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
					if tile_registry.has(key) and tile_registry[key]["elephant_nodes"].size() > 0:
						total_e += 1
				is_met = (total_e > 0 and dist >= 3)
			"Wildlife Department":
				is_met = (get_elephants_in_forest() >= 4)
			"Researcher":
				is_met = (get_shortest_distance_human_elephant() >= 2)
				
		if is_met:
			met_count += 1
			
	return met_count

## Registers a piece as now sitting on a tile. 
## Called after spawn / move.
## Returns false if the placement isn't allowed.
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

## Removes a piece from a tile's elephant / villager list.
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

## Moves a piece from one tile to another. 
## If the destination is full the piece is placed back at its original tile.
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


## Builds the draw pile with every Green, Yellow, Red and Black card and shuffles them. 
func build_deck() -> void:
	draw_pile = []
	discard_pile = []
	# Include all Green, Yellow, and Red card IDs 
	for card_id in CardData.ALL_CARDS:
		var color = CardData.ALL_CARDS[card_id].get("color", Color.WHITE)
		if color == Color.GREEN or color == Color.YELLOW or color == Color.RED or color == Color.BLACK:
			draw_pile.append(card_id)
	draw_pile.shuffle()

## Deals 5 cards to each player's hand. 
## Black cards drawn during dealing are put back and the deck is reshuffled so no one starts with one.
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

## Draws one card from the draw pile into the player's hand and returns the drawn card ID. 
## Returns "" if the deck is empty.
func draw_card(player_index: int) -> String:
	var card = _pop_from_draw_pile()
	if card != "":
		player_hands[player_index].append(card)
	return card

## Wildlife Department's passive ability: draws 2 bonus cards at turn start.
## Skips if the hand is already too full (>= 6).
func wildlife_dept_draw_bonus(player_index: int) -> void:
	wildlife_dept_drawn_cards = []
	if player_hands[player_index].size() >= 6:
		return
	for _i in range(2):
		var card = _pop_from_draw_pile()
		if card != "":
			player_hands[player_index].append(card)
			wildlife_dept_drawn_cards.append(card)

## Discards the chosen bonus card at end of a Wildlife Department turn.
func wildlife_dept_discard_bonus(player_index: int, card_id: String) -> void:
	if card_id in player_hands[player_index]:
		player_hands[player_index].erase(card_id)
		discard_pile.append(card_id)
	wildlife_dept_drawn_cards.erase(card_id)

## Removes the card from the player's hand and adds it to the discard pile.
func discard_card(player_index: int, card_id: String) -> void:
	player_hands[player_index].erase(card_id)
	discard_pile.append(card_id)

## Updates a player's stats and discards the card. 
func record_played_card(player_index: int, card_id: String) -> void:
	var card_data: Dictionary = CardData.ALL_CARDS.get(card_id, {})
	var card_color: Color = card_data.get("color", Color.WHITE)
	var stats: Dictionary = player_stats[player_index]

	if card_color == Color.GREEN:
		stats["green_cards_played"] += 1
	elif card_color == Color.RED:
		stats["red_cards_played"] += 1
	elif card_color == Color.YELLOW:
		stats["yellow_cards_played"] += 1

	if card_color in [Color.GREEN, Color.RED, Color.YELLOW]:
		stats["action_cards_played"] += 1

		var increases_e := false
		var increases_v := false
		for fx in card_data.get("sub_effects", []):
			var op: String = fx.get("op", "")
			if op == "add_e":
				increases_e = true
			if op == "add_v" or op == "add_v_in":
				increases_v = true
		if increases_e and increases_v:
			stats["both_inc_cards"] += 1
		elif increases_e:
			stats["e_inc_cards"] += 1
		elif increases_v:
			stats["v_inc_cards"] += 1

	discard_card(player_index, card_id)

## Government ability: gives the stolen card to the Government player and
## remembers it in government_stolen_cards so it can be replayed once.
func government_steal_card(gov_player_index: int, card_id: String) -> void:
	if gov_player_index < player_hands.size():
		if not player_hands[gov_player_index].has(card_id):
			player_hands[gov_player_index].append(card_id)
	if not government_stolen_cards.has(gov_player_index):
		government_stolen_cards[gov_player_index] = []
	if not government_stolen_cards[gov_player_index].has(card_id):
		government_stolen_cards[gov_player_index].append(card_id)

## Call when the Government player plays a stolen card, drops it from
## the stolen-cards stash so it can't be replayed again.
func government_mark_replayed(card_id: String) -> void:
	for key in government_stolen_cards.keys():
		var stolen_list = government_stolen_cards[key]
		if stolen_list.has(card_id):
			stolen_list.erase(card_id)
			government_stolen_cards[key] = stolen_list

func _pop_from_draw_pile() -> String:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return ""
		draw_pile = discard_pile.duplicate()
		discard_pile = []
		draw_pile.shuffle()
	return draw_pile.pop_back()


## Moves to the next player's turn and fires the turn_changed signal.
## Does nothing if the game is already over.
func advance_turn() -> void:
	if is_game_over:
		return
	current_player_index = (current_player_index + 1) % player_count
	_expire_elephant_immunity_for_player(current_player_index)
	cards_played_this_turn = 0
	var role_name = player_roles[current_player_index] if current_player_index < player_roles.size() else "Unknown"

	if skip_next_turn:
		skip_next_turn = false
		turn_changed.emit(current_player_index, role_name, true)
	else:
		turn_changed.emit(current_player_index, role_name, false)

## Marks every elephant on the board as immune until the turn comes back to [owner_player_index]. 
## Used by immune-op card.
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

## Returns true if the given elephant is currently immune.
func is_elephant_immune(elephant: Node) -> bool:
	if not is_instance_valid(elephant):
		return false
	var elephant_id := elephant.get_instance_id()
	if not elephant_immunity_owner_by_id.has(elephant_id):
		return false
	return true

## When player who played the immunity card last turn is playing, expire immunity
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
