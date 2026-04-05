extends Node

# Card effect executor — state machine that resolves one card's sub-effects in order.
#
# Usage:
#   var fx = load("res://scripts/CardEffects.gd").new()
#   fx.board = $Board
#   fx.play = $Play
#   fx.action_log = $CanvasLayer/Control/ActionLog
#   add_child(fx)
#   fx.execute_card("green_reforestation")

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
signal request_steal_popup()
signal request_convert_type_popup(current_type: int)
signal steal_complete()

var lastCard = [null, null, null, null]

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
		"move_all_e_to":   _do_move_all_e_auto(current_effect)
		"steal":           _do_steal()
		"return_to_hand":  _do_return_card()
		"skip"          :  _do_skip()
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
				# "Towards" means moving closer, not directly onto the target-type tile.
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

func _do_steal() -> void:
	# Check there is at least one other player who has cards to steal
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

	# Pause here — UI will call confirm_steal_target() once the player picks someone
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
		# Stay in WAITING_CHOICE so the UI can try another button
		return

	# Pick a random card from the target's hand
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
			GameState.player_hands[player].append(prev_card)
	_log("Return previously played cards",false)
	effect_index += 1
	_advance_effect()

func _do_skip() -> void:
	var next_index = (GameState.current_player_index + 1) % GameState.player_count
	var SkipText = get_node("/root/CardTable/CanvasLayer/Control/Skipped")
	GameState.skip_next_turn = true
	_log("Skip Player "+ str(next_index + 1) + "'s Turn", false)
	effect_index += 1
	_advance_effect()

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
		board.highlight_tiles(valid_source_keys, Color(1.0, 0.8, 0.0, 0.5))  # Yellow
	request_tile_selection.emit(valid_source_keys, "Select " + _current_piece_type + " to move (source)")

func confirm_source_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_SOURCE:
		return

	var op: String = current_effect.get("op", "")

	if op in ["convert", "convert_any_any"]:
		# Routed here by mistake — shouldn't happen if card_table.gd routes correctly
		return

	# --- Handle interactive add ---
	if op in ["add_v", "add_e", "add_v_in"]:
		# Spawn piece at the chosen tile
		var entry = GameState.tile_registry.get(tile_key, {})
		var placed := false
		if not entry.is_empty() and play:
			var world_pos: Vector3 = entry["world_pos"]
			placed = play.spawn_piece_on_tile(_interact_piece_type, world_pos, tile_key)
		if not placed:
			return
		_log("+1 " + _interact_piece_type, true)
		_interact_count_remaining -= 1
		if _interact_count_remaining > 0:
			_do_add(_interact_piece_type, _interact_count_remaining, _interact_type_filter)
		else:
			effect_index += 1
			_advance_effect()
		return

	# --- Handle interactive remove ---
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

	# --- Handle interactive move (source selection) ---
	selected_source_key = tile_key
	if board:
		board.clear_all_highlights()

	# Build valid destinations
	var effect = current_effect
	var source_entry = GameState.tile_registry.get(selected_source_key, {})
	var source_node_list = source_entry["elephant_nodes"] if _current_piece_type == "elephant" else source_entry["villager_nodes"]
	var raw = source_node_list[0] if source_node_list.size() > 0 else null
	var source_piece_node = raw if is_instance_valid(raw) else null
	var valid_dest_keys: Array = _build_valid_dest_keys_for_source(selected_source_key, effect, _current_piece_type, source_piece_node, true)

	if valid_dest_keys.is_empty():
		if _current_piece_type == "elephant" and source_piece_node != null and GameState.is_elephant_immune(source_piece_node):
			var valid_without_immunity := _build_valid_dest_keys_for_source(selected_source_key, effect, _current_piece_type, source_piece_node, false)
			if not valid_without_immunity.is_empty():
				_log("Move blocked: elephant immunity prevents moving closer to Human/Plantation", false)
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
		board.highlight_tiles(valid_dest_keys, Color(0.0, 0.6, 1.0, 0.5))  # Blue
	request_tile_selection.emit(valid_dest_keys, "Select destination tile")

func confirm_dest_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_DEST:
		return

	# Re-check destination validity at click time so invalid clicks never consume this move.
	var source_entry_for_validation = GameState.tile_registry.get(selected_source_key, {})
	var source_nodes_for_validation = source_entry_for_validation["elephant_nodes"] if _current_piece_type == "elephant" else source_entry_for_validation["villager_nodes"]
	var raw_piece_for_validation = source_nodes_for_validation[0] if source_nodes_for_validation.size() > 0 else null
	var source_piece_for_validation = raw_piece_for_validation if is_instance_valid(raw_piece_for_validation) else null
	var valid_dest_now: Array = _build_valid_dest_keys_for_source(selected_source_key, current_effect, _current_piece_type, source_piece_for_validation, true)
	if not valid_dest_now.has(tile_key):
		return

	var source_entry = GameState.tile_registry.get(selected_source_key, {})
	if source_entry.is_empty():
		effect_index += 1
		_advance_effect()
		return

	var node_list = source_entry["elephant_nodes"] if _current_piece_type == "elephant" else source_entry["villager_nodes"]
	if node_list.is_empty():
		_log("Source tile has no piece", false)
		move_count_remaining -= 1
	else:
		var piece_node = node_list[0]
		if not is_instance_valid(piece_node):
			_log("Source piece no longer exists", false)
			move_count_remaining -= 1
			if move_count_remaining <= 0:
				effect_index += 1
				_advance_effect()
			else:
				_request_source_selection_move(current_effect)
			return
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
	# Optional condition guard
	var condition: String = effect.get("condition", "")
	if condition == "forest_lt_12":
		if GameState.count_tiles_of_type(GameState.TileType.FOREST) >= 12:
			_log("Condition not met (forest >= 12), skipping convert", false)
			effect_index += 1
			_advance_effect()
			return

	# Initialise count only on entry, then hand off to the re-request helper.
	convert_count_remaining = effect.get("count", 1)
	_convert_to_type = _parse_type_string(effect.get("to", "FOREST"))
	_request_convert_click(effect)

func _request_convert_click(effect: Dictionary) -> void:
	var from_types = _parse_types_or_any(effect.get("from", ["ANY"]))
	var valid_keys: Array
	if from_types == null:
		valid_keys = GameState.tile_registry.keys()
	else:
		valid_keys = GameState.get_tiles_matching(effect.get("from", []))

	if valid_keys.is_empty():
		_log("No tiles to convert", false)
		effect_index += 1
		_advance_effect()
		return

	state = State.WAITING_SOURCE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles(valid_keys, Color(0.4, 1.0, 0.2, 0.5))  # Green
	request_tile_selection.emit(valid_keys, "Select tile to convert to " + effect.get("to", "?") + " (" + str(convert_count_remaining) + " left)")

func confirm_convert_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_SOURCE:
		return

	var from_types = _parse_types_or_any(current_effect.get("from", ["ANY"]))
	if from_types != null:
		var entry = GameState.tile_registry.get(tile_key, {})
		if entry.is_empty() or not (entry["type"] in from_types):
			return

	if board:
		board.convert_tile(tile_key, _convert_to_type)
		board.clear_all_highlights()

	_log("Converted tile to type " + str(_convert_to_type), true)
	convert_count_remaining -= 1

	if convert_count_remaining > 0:
		_request_convert_click(current_effect)  # Re-request WITHOUT resetting the count
	else:
		effect_index += 1
		_advance_effect()


# --- Interactive: Convert Any->Any (Land-Use Planning MVP) ---
# MVP: clicking a tile cycles it through FOREST -> HUMAN -> PLANTATION -> FOREST

func _begin_convert_any_any(effect: Dictionary) -> void:
	# Initialise count only on entry, then hand off to the re-request helper.
	convert_count_remaining = effect.get("count", 2)
	_request_convert_any_any_click()

func _request_convert_any_any_click() -> void:
	var all_keys: Array = GameState.tile_registry.keys()
	state = State.WAITING_SOURCE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles(all_keys, Color(1.0, 0.5, 0.0, 0.4))  # Orange
	request_tile_selection.emit(all_keys, "Select any tile to change its type (" + str(convert_count_remaining) + " left)")

func confirm_convert_any_any_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_SOURCE:
		return

	var entry = GameState.tile_registry.get(tile_key, {})
	if entry.is_empty():
		return
	var current_type: int = entry["type"]

	_pending_convert_any_key = tile_key
	state = State.WAITING_CHOICE

	if board:
		board.clear_all_highlights()
		board.highlight_tiles([tile_key], Color(1.0, 0.8, 0.0, 0.55))

	request_tile_selection.emit([], "Choose the new tile type from the popup")
	request_convert_type_popup.emit(current_type)

func confirm_convert_any_any_type_selected(new_type: int) -> void:
	if state != State.WAITING_CHOICE:
		return

	if _pending_convert_any_key == Vector2i(-1, -1):
		return

	var entry = GameState.tile_registry.get(_pending_convert_any_key, {})
	if entry.is_empty():
		_pending_convert_any_key = Vector2i(-1, -1)
		_request_convert_any_any_click()
		return

	var current_type: int = entry["type"]
	if new_type == current_type:
		request_tile_selection.emit([], "Tile is already " + _tile_type_name(new_type) + ". Choose a different type.")
		return

	if board:
		board.convert_tile(_pending_convert_any_key, new_type)
		board.clear_all_highlights()

	_log("Converted tile to " + _tile_type_name(new_type), true)
	_pending_convert_any_key = Vector2i(-1, -1)
	convert_count_remaining -= 1

	if convert_count_remaining > 0:
		_request_convert_any_any_click()  # Re-request WITHOUT resetting the count
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
		if key == source_key:
			continue
		var entry = GameState.tile_registry[key]
		if not is_towards_move and to_types != null and not (entry["type"] in to_types):
			continue
		# Occupancy + coexistence check
		if not GameState.can_place_piece(key, piece_type):
			continue
		# Distance check
		if max_dist > 0:
			var dist = abs(key.x - source_key.x) + abs(key.y - source_key.y)
			if dist > max_dist:
				continue
		# "Move away" cards: destination must strictly increase distance from nearest target-type tile.
		if is_away_move:
			var from_dist := _min_distance_to_types(source_key, from_types)
			var to_dist := _min_distance_to_types(key, from_types)
			if to_dist <= from_dist:
				continue
		# "Move towards" cards: destination must strictly reduce distance to nearest target-type tile.
		if is_towards_move:
			var from_to_dist := _min_distance_to_types(source_key, to_types)
			var to_to_dist := _min_distance_to_types(key, to_types)
			if to_to_dist >= from_to_dist:
				continue
			# "Towards" means moving closer, not directly onto the target-type tile.
			if entry["type"] in to_types:
				continue
		# Immune elephants cannot be moved to tiles that are closer to Human/Plantation.
		if enforce_immunity and piece_type == "elephant" and piece_node != null and GameState.is_elephant_immune(piece_node):
			if _is_move_closer_to_human_or_plantation(source_key, key):
				continue
		valid_dest_keys.append(key)

	return valid_dest_keys

func _is_move_closer_to_human_or_plantation(from_key: Vector2i, to_key: Vector2i) -> bool:
	var threat_types = [GameState.TileType.HUMAN, GameState.TileType.PLANTATION]
	var from_dist := _min_distance_to_types(from_key, threat_types)
	var to_dist := _min_distance_to_types(to_key, threat_types)
	return to_dist < from_dist

func _min_distance_to_types(origin_key: Vector2i, target_types: Array) -> int:
	var best_dist := 999999
	for key in GameState.tile_registry:
		var entry = GameState.tile_registry[key]
		if not (entry["type"] in target_types):
			continue
		var dist = abs(key.x - origin_key.x) + abs(key.y - origin_key.y)
		if dist < best_dist:
			best_dist = dist
	return best_dist

func _is_away_move_effect(effect: Dictionary, from_types: Variant) -> bool:
	if from_types == null:
		return false
	var to_types = _parse_types_or_any(effect.get("to", ["ANY"]))
	return to_types == null

func _is_towards_move_effect(to_types: Variant, from_types: Variant) -> bool:
	return to_types != null and from_types == null

func _tile_type_name(tile_type: int) -> String:
	match tile_type:
		GameState.TileType.FOREST:
			return "Forest"
		GameState.TileType.HUMAN:
			return "Human"
		GameState.TileType.PLANTATION:
			return "Plantation"
	return "Unknown"

func _parse_types(type_strings: Array) -> Array:
	var result: Array = []
	for s in type_strings:
		result.append(_parse_type_string(s))
	return result

# Returns null for ["ANY"] / "ANY" / empty, otherwise an int array of TileType values.
# Accepts either a String or an Array so card data may use either form.
func _parse_types_or_any(type_input) -> Variant:
	var type_strings: Array
	if type_input is String:
		type_strings = [type_input]
	else:
		type_strings = type_input
	if type_strings.is_empty():
		return null
	if type_strings.size() == 1 and type_strings[0] == "ANY":
		return null
	return _parse_types(type_strings)

func _parse_type_string(s) -> int:
	if s is int:
		return s
	match s:
		"FOREST":     return GameState.TileType.FOREST
		"HUMAN":      return GameState.TileType.HUMAN
		"PLANTATION": return GameState.TileType.PLANTATION
	return GameState.TileType.FOREST

func _log(text: String, is_positive: bool) -> void:
	if action_log and action_log.has_method("add_action"):
		action_log.add_action(text, is_positive)
	else:
		print("[CardEffects] ", text)
