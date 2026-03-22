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

enum State { IDLE, WAITING_SOURCE, WAITING_DEST }

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

signal effects_complete()
signal request_tile_selection(valid_keys: Array, instruction: String)
signal clear_tile_selection()


# --- Entry point ---

func execute_card(card_id: String) -> void:
	var card_def = CardData.ALL_CARDS.get(card_id, {})
	if card_def.is_empty():
		push_error("CardEffects: unknown card_id: " + card_id)
		effects_complete.emit()
		return
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
	var group = "elephants" if piece_type == "elephant" else "meeples"
	var pieces = get_tree().get_nodes_in_group(group)
	if pieces.is_empty():
		_log("No " + piece_type + " to remove", false)
		effect_index += 1
		_advance_effect()
		return

	# Build a list of tile keys that have at least one of this piece type
	var valid_tiles: Array = []
	for key in GameState.tile_registry:
		var entry = GameState.tile_registry[key]
		var node_list = entry["elephant_nodes"] if piece_type == "elephant" else entry["villager_nodes"]
		if node_list.size() > 0:
			valid_tiles.append(key)

	_interact_piece_type = piece_type
	_interact_count_remaining = count

	state = State.WAITING_SOURCE
	if board:
		board.clear_all_highlights()
		board.highlight_tiles(valid_tiles, Color(1.0, 0.2, 0.2, 0.5))  # Red
	request_tile_selection.emit(valid_tiles, "Remove " + piece_type + " — " + str(count) + " left")

func _do_immune() -> void:
	_log("Immune effect applied", true)
	effect_index += 1
	_advance_effect()

func _do_move_all_e_auto(effect: Dictionary) -> void:
	var to_types = _parse_types_or_any(effect.get("to", ["ANY"]))
	var max_dist: int = effect.get("max_dist", -1)

	var elephants = get_tree().get_nodes_in_group("elephants")
	var moved = 0

	for elephant in elephants:
		var from_key: Vector2i = elephant.tile_key
		# Find nearest valid destination
		var best_key = Vector2i(-1, -1)
		var best_dist = INF
		for key in GameState.tile_registry:
			if key == from_key:
				continue
			var entry = GameState.tile_registry[key]
			if to_types != null and not (entry["type"] in to_types):
				continue
			if entry["elephant_nodes"].size() >= 1:
				continue
			var dist = abs(key.x - from_key.x) + abs(key.y - from_key.y)
			if max_dist > 0 and dist > max_dist:
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

	_log("Moved " + str(moved) + " elephants", true)
	effect_index += 1
	_advance_effect()


# --- Interactive: Move ---

func _begin_move(piece_type: String, effect: Dictionary) -> void:
	_current_piece_type = piece_type
	move_count_remaining = effect.get("count", 1)
	_request_source_selection_move(effect)

func _request_source_selection_move(effect: Dictionary) -> void:
	var from_types = _parse_types_or_any(effect.get("from", ["ANY"]))

	var valid_source_keys: Array = []
	for key in GameState.tile_registry:
		var entry = GameState.tile_registry[key]
		if from_types != null and not (entry["type"] in from_types):
			continue
		var node_list = entry["elephant_nodes"] if _current_piece_type == "elephant" else entry["villager_nodes"]
		if node_list.size() > 0:
			valid_source_keys.append(key)

	if valid_source_keys.is_empty():
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
	var to_types = _parse_types_or_any(effect.get("to", ["ANY"]))
	var max_dist: int = effect.get("max_dist", -1)

	var valid_dest_keys: Array = []
	for key in GameState.tile_registry:
		if key == selected_source_key:
			continue
		var entry = GameState.tile_registry[key]
		if to_types != null and not (entry["type"] in to_types):
			continue
		# Occupancy check
		if _current_piece_type == "elephant" and entry["elephant_nodes"].size() >= 1:
			continue
		if _current_piece_type == "villager" and entry["villager_nodes"].size() >= 2:
			continue
		# Distance check
		if max_dist > 0:
			var dist = abs(key.x - selected_source_key.x) + abs(key.y - selected_source_key.y)
			if dist > max_dist:
				continue
		valid_dest_keys.append(key)

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
		board.highlight_tiles(valid_dest_keys, Color(0.0, 0.6, 1.0, 0.5))  # Blue
	request_tile_selection.emit(valid_dest_keys, "Select destination tile")

func confirm_dest_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_DEST:
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
		board.highlight_tiles(valid_keys, Color(0.4, 1.0, 0.2, 0.5))  # Green
	request_tile_selection.emit(valid_keys, "Select tile to convert to " + effect.get("to", "?") + " (" + str(convert_count_remaining) + " left)")

func confirm_convert_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_SOURCE:
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
		board.highlight_tiles(all_keys, Color(1.0, 0.5, 0.0, 0.4))  # Orange
	request_tile_selection.emit(all_keys, "Select any tile to change its type (" + str(convert_count_remaining) + " left)")

func confirm_convert_any_any_selected(tile_key: Vector2i) -> void:
	if state != State.WAITING_SOURCE:
		return

	var entry = GameState.tile_registry.get(tile_key, {})
	if entry.is_empty():
		return

	var current_type: int = entry["type"]
	var next_type: int = (current_type + 1) % 3  # 0->1->2->0

	if board:
		board.convert_tile(tile_key, next_type)
		board.clear_all_highlights()

	_log("Converted tile", true)
	convert_count_remaining -= 1

	if convert_count_remaining > 0:
		_request_convert_any_any_click()  # Re-request WITHOUT resetting the count
	else:
		effect_index += 1
		_advance_effect()


# --- Helpers ---

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
