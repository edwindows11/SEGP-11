extends Node

# Card effect executor — state machine that resolves one card's sub-effects in order.

enum State { IDLE, WAITING_SOURCE, WAITING_DEST, WAITING_CHOICE }

var state: State = State.IDLE

# Set by card_table.gd after instantiation
var board: Node3D = null
var play: Node3D = null
var action_log: Node = null

# Internal effect queue
var pending_effects: Array = []
var effect_index: int = 0
var current_effect: Dictionary = {}

# For interactive move operations
var selected_source_key: Vector2i = Vector2i(-1, -1)
var move_count_remaining: int = 0
var _current_piece_type: String = ""

# For interactive add/remove operations
var _interact_count_remaining: int = 0
var _interact_piece_type: String = ""
var _interact_type_filter: Array = []

# For interactive convert operations
var convert_count_remaining: int = 0
var _convert_to_type: int = 0
var _pending_convert_any_key: Vector2i = Vector2i(-1, -1)

signal effects_complete()
signal request_tile_selection(valid_keys: Array, instruction: String)
signal clear_tile_selection()
signal request_steal_target()
signal request_steal_popup()
signal request_convert_type_popup(current_type: int)
signal steal_complete()
signal request_em_choice()

var lastCard = [null, null, null, null]

# Stored UI node reference for ability callbacks that need to set a flag
var _ability_ui_node: Node = null

# --- Entry point ---

func execute_card(card_id: String) -> void:
	var card_def = CardData.ALL_CARDS.get(card_id, {})
	if card_def.is_empty():
		push_error("CardEffects: unknown card_id: " + card_id)
		effects_complete.emit()
		return
	if CardData.ALL_CARDS[card_id].get("color", Color.WHITE) != Color.BLACK:
		lastCard[GameState.current_player_index] = card_id
	pending_effects = card_def["sub_effects"].duplicate(true)
	effect_index = 0
	state = State.IDLE
	
	_log("Played: " + card_def.get("name", "Unknown"), true)
	
	# Researcher Special Ability
	var current_player = GameState.current_player_index
	var role = GameState.player_roles[current_player] if current_player < GameState.player_roles.size() else "Unknown"
	var color = card_def.get("color", Color.WHITE)
	if (role == "Researcher" or (role == "Environmental Consultant" and GameState.ec_borrowed_ability == "Researcher")) and color in [Color.GREEN, Color.YELLOW, Color.RED]:
		var added_elephants = 0
		for fx in pending_effects:
			if fx.get("op", "") == "add_e":
				added_elephants += fx.get("count", 1)
		
		# If elephants were added, give the researcher an extra move action
		if added_elephants > 0:
			pending_effects.append({
				"op": "move_e",
				"count": added_elephants,
				"from": ["ANY"],
				"to": ["ANY"],
				"max_dist": -1 
			})

	# Ecotourism Manager Special Ability
	if (role == "Ecotourism Manager" or (role == "Environmental Consultant" and GameState.ec_borrowed_ability == "Ecotourism Manager")) and color in [Color.BLACK, Color.YELLOW, Color.RED, Color.GREEN]:
		var added_pieces = false
		for fx in pending_effects:
			var op = fx.get("op", "")
			if op in ["add_e", "add_v", "add_v_in"]:
				added_pieces = true
				break
		if added_pieces:
			pending_effects.append({
				"op": "em_extra_move"
			})
	
	_advance_effect()

func execute_reversed_card(target_index: int, ui_node: Node) -> void:
	var stolen = lastCard[target_index]
	if not stolen:
		ui_node.show_instruction("That player hasn't played a valid card yet!")
		return
	
	var card_def = CardData.ALL_CARDS.get(stolen, {})
	var cloned_fx = card_def["sub_effects"].duplicate(true)
	
	# Reverse effects:
	for fx in cloned_fx:
		var op = fx.get("op", "")
		if op == "add_e": fx["op"] = "remove_e"
		elif op == "remove_e": fx["op"] = "add_e"
		elif op == "add_v" or op == "add_v_in": fx["op"] = "remove_v"
		elif op == "remove_v": fx["op"] = "add_v"
		elif op == "convert":
			var f = fx.get("from", -1)
			fx["from"] = fx.get("to", -1)
			fx["to"] = f
			
	ui_node.po_used_ability_this_turn = true
	ui_node.cards_played_this_turn += 1
	ui_node.play_btn.disabled = true
	
	pending_effects = cloned_fx
	effect_index = 0
	state = State.IDLE
	_log("Plantation Owner stole and reversed: " + card_def.get("name", "Card"), true)
	_advance_effect()


# --- Effect dispatcher ---

func _advance_effect() -> void:
	if effect_index >= pending_effects.size():
		state = State.IDLE
		if board:
			board.clear_all_highlights()
		clear_tile_selection.emit()
		effects_complete.emit()
		return

	current_effect = pending_effects[effect_index]
	var op: String = current_effect.get("op", "")

	match op:
		"add_v":          _do_add("villager", current_effect.get("count", 1), [])
		"add_e":          _do_add("elephant", current_effect.get("count", 1), [])
		"add_v_in":       _do_add("villager", current_effect.get("count", 1), _parse_types(current_effect.get("in", [])))
		"remove_v":       _do_remove("villager", current_effect.get("count", 1))
		"remove_e":       _do_remove("elephant", current_effect.get("count", 1))
		"convert":         _begin_convert(current_effect)
		"convert_any_any": _begin_convert_any_any(current_effect)
		"immune":          _do_immune()
		"move_e":          _begin_move("elephant", current_effect)
		"move_v":          _begin_move("villager", current_effect)
		"em_extra_move":   _do_em_extra_move()
		"move_all_e_auto":   _do_move_all_e_auto(current_effect)
		"steal":           _do_steal()
		"return_to_hand":  _do_return_card()
		"skip"          :  _do_skip()
		"cons_expand_forest": _do_cons_expand_forest()
		"ld_expand_human":    _do_ld_expand_human()
		_:
			push_warning("CardEffects: unknown op: " + op)
			effect_index += 1
			_advance_effect()


# --- Automatic effects ---

func _do_add(piece_type: String, count: int, type_filter: Array) -> void:
	var valid_tiles: Array
	if type_filter.is_empty():
		valid_tiles = GameState.get_valid_add_tiles(piece_type)
	else:
		valid_tiles = GameState.get_valid_add_tiles_in(piece_type, type_filter)

	if valid_tiles.is_empty():
		_log("No valid tiles to place " + piece_type, false)
		effect_index += 1
		_advance_effect()
		return

	_interact_piece_type = piece_type
	_interact_count_remaining = count
	_interact_type_filter = type_filter

	state = State.WAITING_SOURCE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles(valid_tiles, Color(0.2, 0.8, 1.0, 0.5))  # Cyan
	request_tile_selection.emit(valid_tiles, "Place " + piece_type + " — " + str(count) + " left")

func _do_remove(piece_type: String, count: int) -> void:
	# Build a list of tile keys that have at least one of this piece type
	var valid_tiles: Array = []
	for key in GameState.tile_registry:
		var entry = GameState.tile_registry[key]
		var node_list = entry["elephant_nodes"] if piece_type == "elephant" else entry["villager_nodes"]
		if node_list.size() > 0:
			valid_tiles.append(key)

	if valid_tiles.is_empty():
		_log("No " + piece_type + " to remove", false)
		effect_index += 1
		_advance_effect()
		return

	_interact_piece_type = piece_type
	_interact_count_remaining = count

	state = State.WAITING_SOURCE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles(valid_tiles, Color(1.0, 0.2, 0.2, 0.5))  # Red
	request_tile_selection.emit(valid_tiles, "Remove " + piece_type + " — " + str(count) + " left")

func _do_immune() -> void:
	var owner_player := GameState.current_player_index
	var affected_count := GameState.apply_elephant_immunity_for_round(owner_player)
	_log("Immune effect applied to " + str(affected_count) + " elephant(s) until this turn comes back to Player " + str(owner_player + 1), true)
	effect_index += 1
	_advance_effect()

func _do_move_all_e_auto(effect: Dictionary) -> void:
	var to_types = _parse_types_or_any(effect.get("to", ["ANY"]))
	var from_types = _parse_types_or_any(effect.get("from", ["ANY"]))
	var is_towards_move := _is_towards_move_effect(to_types, from_types)
	var max_dist: int = effect.get("max_dist", -1)

	var elephants = get_tree().get_nodes_in_group("elephants")
	var moved = 0

	for elephant in elephants:
		var from_key: Vector2i = elephant.tile_key
		# Find nearest valid destination
		var best_key = Vector2i(-1, -1)
		var best_dist = INF
		var blocked_by_immunity := false
		for key in GameState.tile_registry:
			if key == from_key:
				continue
			var entry = GameState.tile_registry[key]
			if not is_towards_move and to_types != null and not (entry["type"] in to_types):
				continue
			if not GameState.can_place_piece(key, "elephant"):
				continue
			var dist = abs(key.x - from_key.x) + abs(key.y - from_key.y)
			if max_dist > 0 and dist > max_dist:
				continue
			if is_towards_move:
				var from_dist := _min_distance_to_types(from_key, to_types)
				var to_dist := _min_distance_to_types(key, to_types)
				if to_dist >= from_dist:
					continue
				if entry["type"] in to_types:
					continue
			if GameState.is_elephant_immune(elephant) and _is_move_closer_to_human_or_plantation(from_key, key):
				blocked_by_immunity = true
				continue
			if dist < best_dist:
				best_dist = dist
				best_key = key

		if best_key != Vector2i(-1, -1):
			var dest_pos = GameState.tile_registry[best_key]["world_pos"]
			elephant.position = dest_pos
			GameState.piece_moved(elephant, from_key, best_key, "elephant")
			elephant.tile_key = best_key
			moved += 1
		elif blocked_by_immunity:
			_log("Move blocked: elephant immunity prevents moving closer to Human/Plantation", false)

	_log("Moved " + str(moved) + " elephants", true)
	effect_index += 1
	_advance_effect()

func _do_em_extra_move() -> void:
	state = State.WAITING_CHOICE
	emit_signal("request_em_choice")

func confirm_em_choice(choice: String) -> void:
	if state != State.WAITING_CHOICE:
		return
	if choice == "elephant":
		pending_effects.insert(effect_index + 1, {"op": "move_e", "count": 1, "from": ["ANY"], "to": ["ANY"], "max_dist": -1})
	elif choice == "villager":
		pending_effects.insert(effect_index + 1, {"op": "move_v", "count": 1, "from": ["ANY"], "to": ["ANY"], "max_dist": -1})
	
	state = State.IDLE
	effect_index += 1
	_advance_effect()

func execute_government_steal(target_index: int, ui_node: Node) -> void:
	var stolen = lastCard[target_index]
	if not stolen:
		ui_node.show_instruction("That player hasn't played a valid card yet!")
		return

	var card_def = CardData.ALL_CARDS.get(stolen, {})
	var card_color = card_def.get("color", Color.WHITE)
	if not card_color in [Color.GREEN, Color.YELLOW, Color.RED]:
		ui_node.show_instruction("Government can only steal yellow, red, or green cards!")
		return

	# Check this card hasn't already been replayed
	if not GameState.government_can_replay(stolen):
		ui_node.show_instruction("That card has already been replayed!")
		return

	GameState.government_steal_card(GameState.current_player_index, stolen)
	ui_node.gov_used_ability_this_turn = true
	var card_name = card_def.get("name", stolen)
	_log("Government stole \"" + card_name + "\" from Player " + str(target_index + 1), true)
	ui_node.spawn_stolen_gov_card()

func execute_conservationist_ability(ui_node: Node) -> void:
	var valid_tiles = _get_cons_valid_tiles()
	if valid_tiles.is_empty():
		ui_node.show_instruction("No valid tiles — needs a non-forest tile adjacent to a forested tile with an elephant!")
		return
	_ability_ui_node = ui_node
	pending_effects = [{"op": "cons_expand_forest"}]
	effect_index = 0
	state = State.IDLE
	_advance_effect()

func execute_land_developer_ability(ui_node: Node) -> void:
	var valid_tiles = _get_ld_valid_tiles()
	if valid_tiles.is_empty():
		ui_node.show_instruction("No valid tiles — needs a non-human tile with at least 3 human-dominated neighbours!")
		return
	_ability_ui_node = ui_node
	pending_effects = [{"op": "ld_expand_human"}]
	effect_index = 0
	state = State.IDLE
	_advance_effect()

func _do_steal() -> void:
	var thief := GameState.current_player_index
	GameState.discard_card(thief, "black_corruption")
	var has_valid_target := false
	for i in range(GameState.player_count):
		if i != thief and GameState.player_hands[i].size() > 0:
			has_valid_target = true
			break

	if not has_valid_target:
		_log("No players have cards to steal", false)
		effect_index += 1
		_advance_effect()
		return

	state = State.WAITING_CHOICE
	emit_signal("request_steal_popup")

## Called by card_table_ui.gd when the player clicks a name button in the steal popup.
func confirm_steal_target(target_player_index: int) -> void:
	if state != State.WAITING_CHOICE:
		return

	var thief := GameState.current_player_index
	var hand : Array = GameState.player_hands[target_player_index]
	if hand.is_empty():
		_log("Player " + str(target_player_index + 1) + " has no cards!", false)
		state = State.IDLE
		effect_index += 1
		_advance_effect()
		return

	var stolen_card: String = hand[randi() % hand.size()]
	hand.erase(stolen_card)
	GameState.player_hands[thief].append(stolen_card)

	var card_name = CardData.ALL_CARDS.get(stolen_card, {}).get("name", stolen_card)
	_log("Stole \"" + card_name + "\" from Player " + str(target_player_index + 1), true)

	state = State.IDLE
	emit_signal("steal_complete")
	effect_index += 1
	_advance_effect()

func _do_return_card() -> void:
	var owner_player := GameState.current_player_index
	for player in GameState.player_count:
		if player != owner_player:
			var prev_card = lastCard[player]
			if prev_card:
				GameState.player_hands[player].append(prev_card)
	_log("Return previously played cards",false)
	effect_index += 1
	_advance_effect()

func _do_skip() -> void:
	var next_index = (GameState.current_player_index + 1) % GameState.player_count
	GameState.skip_next_turn = true
	_log("Skip Player "+ str(next_index + 1) + "'s Turn", false)
	effect_index += 1
	_advance_effect()

# --- Conservationist/LD: Expand ---

func _do_cons_expand_forest() -> void:
	var valid_tiles = _get_cons_valid_tiles()
	if valid_tiles.is_empty():
		_log("No valid tiles for Conservationist ability", false)
		effect_index += 1
		_advance_effect()
		return
	state = State.WAITING_SOURCE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles(valid_tiles, Color(0.1, 1.0, 0.3, 0.55)) 
	request_tile_selection.emit(valid_tiles, "Select a tile adjacent to the elephant's forest to convert to Forest")

func _get_cons_valid_tiles() -> Array:
	var elephant_forest_keys: Array = []
	for key in GameState.tile_registry:
		var entry = GameState.tile_registry[key]
		if entry["type"] == GameState.TileType.FOREST and entry["elephant_nodes"].size() > 0:
			elephant_forest_keys.append(key)
	if elephant_forest_keys.is_empty():
		return []
	var valid: Dictionary = {}
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for fkey in elephant_forest_keys:
		for dir in directions:
			var neighbour = fkey + dir
			if GameState.tile_registry.has(neighbour):
				if GameState.tile_registry[neighbour]["type"] != GameState.TileType.FOREST:
					valid[neighbour] = true
	return valid.keys()

func _do_ld_expand_human() -> void:
	var valid_tiles = _get_ld_valid_tiles()
	if valid_tiles.is_empty():
		_log("No valid tiles for Land Developer ability", false)
		effect_index += 1
		_advance_effect()
		return
	state = State.WAITING_SOURCE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles(valid_tiles, Color(0.9, 0.5, 0.1, 0.55))
	request_tile_selection.emit(valid_tiles, "Select a tile to convert to Human-Dominated (needs 3+ human neighbours)")

func _get_ld_valid_tiles() -> Array:
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var valid: Array = []
	for key in GameState.tile_registry:
		var entry = GameState.tile_registry[key]
		if entry["type"] == GameState.TileType.HUMAN:
			continue
		var human_neighbour_count := 0
		for dir in directions:
			var neighbour = key + dir
			if GameState.tile_registry.has(neighbour):
				if GameState.tile_registry[neighbour]["type"] == GameState.TileType.HUMAN:
					human_neighbour_count += 1
		if human_neighbour_count >= 3:
			valid.append(key)
	return valid

# --- Interactive: Move ---

func _begin_move(piece_type: String, effect: Dictionary) -> void:
	_current_piece_type = piece_type
	move_count_remaining = effect.get("count", 1)
	_request_source_selection_move(effect)

func _request_source_selection_move(effect: Dictionary) -> void:
	var from_types = _parse_types_or_any(effect.get("from", ["ANY"]))
	var is_away_move := _is_away_move_effect(effect, from_types)

	var valid_source_keys: Array = []
	var source_piece_count := 0
	var immunity_blocked_sources := 0
	for key in GameState.tile_registry:
		var entry = GameState.tile_registry[key]
		if from_types != null:
			if not is_away_move and not (entry["type"] in from_types):
				continue
		var node_list = entry["elephant_nodes"] if _current_piece_type == "elephant" else entry["villager_nodes"]
		if node_list.is_empty():
			continue
		source_piece_count += 1
		var piece_node = node_list[0]
		if not is_instance_valid(piece_node):
			continue
		var preview_dests := _build_valid_dest_keys_for_source(key, effect, _current_piece_type, piece_node, true)
		if not preview_dests.is_empty():
			valid_source_keys.append(key)
		elif _current_piece_type == "elephant" and GameState.is_elephant_immune(piece_node):
			var preview_without_immunity := _build_valid_dest_keys_for_source(key, effect, _current_piece_type, piece_node, false)
			if not preview_without_immunity.is_empty():
				immunity_blocked_sources += 1

	if valid_source_keys.is_empty():
		if _current_piece_type == "elephant" and source_piece_count > 0 and immunity_blocked_sources > 0:
			_log("Move blocked: elephant immunity prevents moving closer to Human/Plantation", false)
		_log("No " + _current_piece_type + " to move", false)
		effect_index += 1
		_advance_effect()
		return

	state = State.WAITING_SOURCE
	if board:
		board.highlight_tiles(valid_source_keys, Color(1.0, 0.8, 0.0, 0.5))
	request_tile_selection.emit(valid_source_keys, "Select " + _current_piece_type + " to move (source)")

func confirm_source_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_SOURCE:
		return

	var op: String = current_effect.get("op", "")

	if op == "cons_expand_forest":
		if board:
			board.convert_tile(tile_key, GameState.TileType.FOREST)
			board.clear_all_highlights()
		_log("Conservationist expanded forest!", true)
		if _ability_ui_node and is_instance_valid(_ability_ui_node):
			_ability_ui_node.cons_used_ability_this_turn = true
			_ability_ui_node = null
		effect_index += 1
		_advance_effect()
		return

	if op == "ld_expand_human":
		if board:
			board.convert_tile(tile_key, GameState.TileType.HUMAN)
			board.clear_all_highlights()
		_log("Land Developer expanded human-dominated area!", true)
		if _ability_ui_node and is_instance_valid(_ability_ui_node):
			_ability_ui_node.ld_used_ability_this_turn = true
			_ability_ui_node = null
		effect_index += 1
		_advance_effect()
		return

	if op in ["convert", "convert_any_any"]:
		return

	if op in ["add_v", "add_e", "add_v_in"]:
		var entry = GameState.tile_registry.get(tile_key, {})
		var placed := false
		if not entry.is_empty() and play:
			var world_pos: Vector3 = entry["world_pos"]
			placed = play.spawn_piece_on_tile(_interact_piece_type, world_pos, tile_key)
		if not placed:
			# Tile is no longer valid — skip this placement and continue
			_log("Could not place " + _interact_piece_type + " on selected tile, skipping", false)
			effect_index += 1
			_advance_effect()
			return
		_log("+1 " + _interact_piece_type, true)
		_interact_count_remaining -= 1
		if _interact_count_remaining > 0:
			_do_add(_interact_piece_type, _interact_count_remaining, _interact_type_filter)
		else:
			effect_index += 1
			_advance_effect()
		return

	if op in ["remove_v", "remove_e"]:
		var entry = GameState.tile_registry.get(tile_key, {})
		if not entry.is_empty():
			var node_list = entry["elephant_nodes"] if _interact_piece_type == "elephant" else entry["villager_nodes"]
			if node_list.size() > 0:
				var piece = node_list[0]
				GameState.piece_removed(piece, tile_key, _interact_piece_type)
				piece.queue_free()
				_log("-1 " + _interact_piece_type, false)
		_interact_count_remaining -= 1
		if _interact_count_remaining > 0:
			_do_remove(_interact_piece_type, _interact_count_remaining)
		else:
			effect_index += 1
			_advance_effect()
		return

	selected_source_key = tile_key
	if board:
		board.clear_all_highlights()

	var effect = current_effect
	var source_entry = GameState.tile_registry.get(selected_source_key, {})
	var source_node_list = source_entry["elephant_nodes"] if _current_piece_type == "elephant" else source_entry["villager_nodes"]
	var raw = source_node_list[0] if source_node_list.size() > 0 else null
	var source_piece_node = raw if is_instance_valid(raw) else null
	var valid_dest_keys: Array = _build_valid_dest_keys_for_source(selected_source_key, effect, _current_piece_type, source_piece_node, true)

	if valid_dest_keys.is_empty():
		_log("No valid destination for move", false)
		move_count_remaining -= 1
		if move_count_remaining <= 0:
			effect_index += 1
			_advance_effect()
		else:
			_request_source_selection_move(current_effect)
		return

	state = State.WAITING_DEST
	if board:
		board.highlight_tiles(valid_dest_keys, Color(0.0, 0.6, 1.0, 0.5))
	request_tile_selection.emit(valid_dest_keys, "Select destination tile")

func confirm_dest_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_DEST:
		return
	
	var valid_dest_now: Array = _build_valid_dest_keys_for_source(selected_source_key, current_effect, _current_piece_type, null, true)
	if not valid_dest_now.has(tile_key):
		if valid_dest_now.is_empty():
			# No destinations left at all — skip this move
			_log("No valid destinations remain, skipping move", false)
			effect_index += 1
			_advance_effect()
		# else: player clicked invalid tile, let them re-select
		return

	var source_entry = GameState.tile_registry.get(selected_source_key, {})
	if source_entry.is_empty():
		effect_index += 1
		_advance_effect()
		return

	var node_list = source_entry["elephant_nodes"] if _current_piece_type == "elephant" else source_entry["villager_nodes"]
	if not node_list.is_empty():
		var piece_node = node_list[0]
		if is_instance_valid(piece_node):
			var dest_world_pos = GameState.tile_registry[tile_key]["world_pos"]
			piece_node.position = dest_world_pos
			if _current_piece_type == "villager":
				piece_node.position.y += 0.5
			GameState.piece_moved(piece_node, selected_source_key, tile_key, _current_piece_type)
			piece_node.tile_key = tile_key
			_log("Moved " + _current_piece_type, true)
		move_count_remaining -= 1

	if board:
		board.clear_all_highlights()

	if move_count_remaining > 0:
		_request_source_selection_move(current_effect)
	else:
		effect_index += 1
		_advance_effect()

# --- Interactive: Convert ---

func _begin_convert(effect: Dictionary) -> void:
	var condition: String = effect.get("condition", "")
	if condition == "forest_lt_12":
		if GameState.count_tiles_of_type(GameState.TileType.FOREST) >= 12:
			_log("Condition not met (forest >= 12), skipping convert", false)
			effect_index += 1
			_advance_effect()
			return

	convert_count_remaining = effect.get("count", 1)
	_convert_to_type = _parse_type_string(effect.get("to", "FOREST"))
	_request_convert_click(effect)

func _request_convert_click(effect: Dictionary) -> void:
	var from_types = _parse_types_or_any(effect.get("from", ["ANY"]))
	var valid_keys: Array = GameState.get_tiles_matching(effect.get("from", [])) if from_types != null else GameState.tile_registry.keys()

	if valid_keys.is_empty():
		_log("No tiles to convert", false)
		effect_index += 1
		_advance_effect()
		return

	state = State.WAITING_SOURCE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles(valid_keys, Color(0.4, 1.0, 0.2, 0.5))
	request_tile_selection.emit(valid_keys, "Select tile to convert to " + effect.get("to", "?") + " (" + str(convert_count_remaining) + " left)")

func confirm_convert_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_SOURCE:
		return
	if board:
		board.convert_tile(tile_key, _convert_to_type)
		board.clear_all_highlights()
	_log("Converted tile", true)
	convert_count_remaining -= 1
	if convert_count_remaining > 0:
		_request_convert_click(current_effect)
	else:
		effect_index += 1
		_advance_effect()

func _begin_convert_any_any(effect: Dictionary) -> void:
	convert_count_remaining = effect.get("count", 2)
	_request_convert_any_any_click()

func _request_convert_any_any_click() -> void:
	var all_keys: Array = GameState.tile_registry.keys()
	state = State.WAITING_SOURCE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles(all_keys, Color(1.0, 0.5, 0.0, 0.4))
	request_tile_selection.emit(all_keys, "Select any tile to change its type (" + str(convert_count_remaining) + " left)")

func confirm_convert_any_any_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_SOURCE:
		return
	var entry = GameState.tile_registry.get(tile_key, {})
	if entry.is_empty(): return
	var current_type: int = entry["type"]
	_pending_convert_any_key = tile_key
	state = State.WAITING_CHOICE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles([tile_key], Color(1.0, 0.8, 0.0, 0.55))
	request_tile_selection.emit([], "Choose the new tile type from the popup")
	request_convert_type_popup.emit(current_type)

func confirm_convert_any_any_type_selected(new_type: int) -> void:
	if state != State.WAITING_CHOICE: return
	if _pending_convert_any_key == Vector2i(-1, -1): return
	var entry = GameState.tile_registry.get(_pending_convert_any_key, {})
	if entry.is_empty():
		_pending_convert_any_key = Vector2i(-1, -1)
		_request_convert_any_any_click()
		return
	if new_type == entry["type"]:
		request_tile_selection.emit([], "Tile is already " + _tile_type_name(new_type) + ". Choose a different type.")
		return
	if board:
		board.convert_tile(_pending_convert_any_key, new_type)
		board.clear_all_highlights()
	_log("Converted tile", true)
	_pending_convert_any_key = Vector2i(-1, -1)
	convert_count_remaining -= 1
	if convert_count_remaining > 0:
		_request_convert_any_any_click()
	else:
		effect_index += 1
		_advance_effect()

# --- Helpers ---

func _build_valid_dest_keys_for_source(source_key: Vector2i, effect: Dictionary, piece_type: String, piece_node: Node = null, enforce_immunity: bool = true) -> Array:
	var to_types = _parse_types_or_any(effect.get("to", ["ANY"]))
	var from_types = _parse_types_or_any(effect.get("from", ["ANY"]))
	var is_away_move := _is_away_move_effect(effect, from_types)
	var is_towards_move := _is_towards_move_effect(to_types, from_types)
	var max_dist: int = effect.get("max_dist", -1)

	var valid_dest_keys: Array = []
	for key in GameState.tile_registry:
		if key == source_key: continue
		var entry = GameState.tile_registry[key]
		if not is_towards_move and to_types != null and not (entry["type"] in to_types): continue
		if not GameState.can_place_piece(key, piece_type): continue
		if max_dist > 0:
			var dist = abs(key.x - source_key.x) + abs(key.y - source_key.y)
			if dist > max_dist: continue
		if is_away_move:
			if _min_distance_to_types(key, from_types) <= _min_distance_to_types(source_key, from_types): continue
		if is_towards_move:
			if _min_distance_to_types(key, to_types) >= _min_distance_to_types(source_key, to_types): continue
			if entry["type"] in to_types: continue
		if enforce_immunity and piece_type == "elephant" and piece_node != null and GameState.is_elephant_immune(piece_node):
			if _is_move_closer_to_human_or_plantation(source_key, key): continue
		valid_dest_keys.append(key)
	return valid_dest_keys

func _is_move_closer_to_human_or_plantation(from_key: Vector2i, to_key: Vector2i) -> bool:
	var threat_types = [GameState.TileType.HUMAN, GameState.TileType.PLANTATION]
	return _min_distance_to_types(to_key, threat_types) < _min_distance_to_types(from_key, threat_types)

func _min_distance_to_types(origin_key: Vector2i, target_types: Array) -> int:
	var best_dist := 999999
	for key in GameState.tile_registry:
		if GameState.tile_registry[key]["type"] in target_types:
			best_dist = min(best_dist, abs(key.x - origin_key.x) + abs(key.y - origin_key.y))
	return best_dist

func _is_away_move_effect(effect: Dictionary, from_types: Variant) -> bool:
	return from_types != null and _parse_types_or_any(effect.get("to", ["ANY"])) == null

func _is_towards_move_effect(to_types: Variant, from_types: Variant) -> bool:
	return to_types != null and from_types == null

func _tile_type_name(tile_type: int) -> String:
	match tile_type:
		GameState.TileType.FOREST: return "Forest"
		GameState.TileType.HUMAN: return "Human"
		GameState.TileType.PLANTATION: return "Plantation"
	return "Unknown"

func _parse_types(type_strings: Array) -> Array:
	var result: Array = []
	for s in type_strings: result.append(_parse_type_string(s))
	return result

func _parse_types_or_any(type_input) -> Variant:
	var type_strings: Array = [type_input] if type_input is String else type_input
	if type_strings.is_empty() or (type_strings.size() == 1 and type_strings[0] == "ANY"): return null
	return _parse_types(type_strings)

func _parse_type_string(s) -> int:
	if s is int: return s
	match s:
		"FOREST": return GameState.TileType.FOREST
		"HUMAN": return GameState.TileType.HUMAN
		"PLANTATION": return GameState.TileType.PLANTATION
	return GameState.TileType.FOREST

func preview_func(text:String) -> void:
	pass

func _log(text: String, is_positive: bool) -> void:
	if action_log and action_log.has_method("add_action"): action_log.add_action(text, is_positive)
	else: print("[CardEffects] ", text)
