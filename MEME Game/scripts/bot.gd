## BotAI.gd
## Attach this node to CardTable (or add_child it from card_table.gd).
## It intercepts turn_changed, decides which card to play, then feeds
## synthetic tile selections into CardEffects — exactly as if a human clicked.
##
## SETUP in card_table.gd _ready():
##
##   var bot_ai = load("res://scripts/BotAI.gd").new()
##   bot_ai.card_effects = card_effects
##   bot_ai.play       = Play
##   bot_ai.board      = $Board
##   add_child(bot_ai)
##   bot_ai.ui = UI
##   bot_ai.set_bot_players([1, 2, 3], BotAI.Difficulty.MEDIUM)
##   # or per-player:  bot_ai.set_player_difficulty(2, BotAI.Difficulty.HARD)
##
##   # Also hook the turn signal AFTER connecting the UI one:
##   GameState.turn_changed.connect(bot_ai._on_turn_changed)

extends Node

signal bot_turn_started
signal bot_turn_ended

# ── Difficulty enum ──────────────────────────────────────────────────────────
enum Difficulty { EASY, MEDIUM, HARD }

# ── Public references (set from card_table.gd) ───────────────────────────────
var card_effects: Node = null   # CardEffects instance
var play: Node3D    = null      # card_functions node
var board: Node3D   = null      # Board node
var ui: Control     = null      # card_table_ui node

# ── Per-player config ────────────────────────────────────────────────────────
# Maps player_index (int) -> Difficulty
var bot_players: Dictionary = {}

# ── Timing ───────────────────────────────────────────────────────────────────
# Small delays so the bot "thinks" instead of acting instantly (feels natural).
var think_delay: float = 2.0
var card_reveal_delay: float = 1.4
var action_delay: float = 0.85
var end_turn_delay: float = 1.8

var _pending_selections: Array = []   # Queue of tile keys to feed to CardEffects
var _action_timer: float = 0.0
var _waiting_for_action: bool = false
var _bot_is_acting: bool = false      # True while a bot is mid-turn

# ── Internal ─────────────────────────────────────────────────────────────────
var _current_bot_player: int = -1


# ────────────────────────────────────────────────────────────────────────────
# Public API
# ────────────────────────────────────────────────────────────────────────────

## Mark a list of player indices as bots, all with the same difficulty.
func set_bot_players(indices: Array, difficulty: Difficulty = Difficulty.MEDIUM) -> void:
	for idx in indices:
		bot_players[idx] = difficulty

## Set the difficulty for a single bot player.
func set_player_difficulty(player_index: int, difficulty: Difficulty) -> void:
	bot_players[player_index] = difficulty

## Configure overall bot pacing from pre-game setup.
func set_speed_preset(preset: String) -> void:
	var normalized: String = preset.strip_edges().to_lower()
	match normalized:
		"slow":
			think_delay = 3.0
			card_reveal_delay = 2.0
			action_delay = 1.2
			end_turn_delay = 2.4
		"fast":
			think_delay = 1.1
			card_reveal_delay = 0.7
			action_delay = 0.35
			end_turn_delay = 0.9
		_:
			think_delay = 2.0
			card_reveal_delay = 1.4
			action_delay = 0.85
			end_turn_delay = 1.8

## Returns true if the given player index is a bot.
func is_bot(player_index: int) -> bool:
	return bot_players.has(player_index)


# ────────────────────────────────────────────────────────────────────────────
# Turn signal handler
# ────────────────────────────────────────────────────────────────────────────

func _on_turn_changed(player_index: int, _role_name: String, is_skipped: bool) -> void:
	_bot_is_acting = false
	_pending_selections.clear()
	_waiting_for_action = false
	_action_timer = 0.0

	if not is_bot(player_index):
		return

	if is_skipped:
		await get_tree().create_timer(end_turn_delay, false).timeout
		GameState.advance_turn()
		return

	_current_bot_player = player_index
	_bot_is_acting = true
	bot_turn_started.emit()

	if ui and ui.has_method("show_instruction"):
		ui.show_instruction("Player " + str(player_index + 1) + " (Bot) is thinking...")

	# Wait a beat so the UI can refresh, then begin thinking.
	await get_tree().create_timer(think_delay, false).timeout
	_bot_take_turn(player_index)


# ────────────────────────────────────────────────────────────────────────────
# Core bot turn logic
# ────────────────────────────────────────────────────────────────────────────

func _bot_take_turn(player_index: int) -> void:
	if not _bot_is_acting:
		return

	var difficulty: Difficulty = bot_players.get(player_index, Difficulty.EASY)
	var hand: Array = GameState.player_hands[player_index]

	if hand.is_empty():
		_announce_bot_message(player_index, "has no cards and passes", false)
		await get_tree().create_timer(end_turn_delay, false).timeout
		_end_bot_turn()
		return

	# --- Black card rule ---
	# If the hand contains ANY black cards, the bot MUST play one of them
	# and cannot play anything else this turn
	var black_cards_in_hand: Array = hand.filter(
		func(cid): return CardData.ALL_CARDS[cid].get("color", Color.WHITE) == Color.BLACK
	)
	var must_play_black: bool = not black_cards_in_hand.is_empty()

	var chosen_card_id: String = ""

	if must_play_black:
		# Bot must play a black card — pick one (random for all difficulties,
		# hard bot picks the "best" black card if there are multiple)
		if difficulty == Difficulty.HARD and black_cards_in_hand.size() > 1:
			# Hard bot picks the black card with the most sub_effects (most impactful)
			black_cards_in_hand.sort_custom(func(a, b):
				return CardData.ALL_CARDS[a].get("sub_effects", []).size() > \
					   CardData.ALL_CARDS[b].get("sub_effects", []).size()
			)
			chosen_card_id = black_cards_in_hand[0]
		else:
			chosen_card_id = black_cards_in_hand[randi() % black_cards_in_hand.size()]
		_announce_bot_message(player_index, "is forced to play a black card!", false)
	else:
		# Normal pick — difficulty-based, black cards are excluded inside each picker
		match difficulty:
			Difficulty.EASY:
				chosen_card_id = _pick_card_easy(hand, player_index)
			Difficulty.MEDIUM:
				chosen_card_id = _pick_card_medium(hand, player_index)
			Difficulty.HARD:
				chosen_card_id = _pick_card_hard(hand, player_index)

	if chosen_card_id == "":
		_announce_bot_message(player_index, "passes (no valid action card)", false)
		await get_tree().create_timer(end_turn_delay, false).timeout
		_end_bot_turn()
		return

	var card_def: Dictionary = CardData.ALL_CARDS.get(chosen_card_id, {})
	var card_name: String = str(card_def.get("name", chosen_card_id))
	_announce_bot_message(player_index, "plays: " + card_name, true)
	await get_tree().create_timer(card_reveal_delay, false).timeout
	if not _bot_is_acting:
		return

	_bot_played_card_id = chosen_card_id

	if not card_effects.effects_complete.is_connected(_on_bot_effects_complete):
		card_effects.effects_complete.connect(_on_bot_effects_complete)

	if not card_effects.request_tile_selection.is_connected(_on_bot_tile_selection_requested):
		card_effects.request_tile_selection.connect(_on_bot_tile_selection_requested)

	card_effects.execute_card(chosen_card_id)

func _announce_bot_message(player_index: int, message: String, is_positive: bool) -> void:
	var text := "Player " + str(player_index + 1) + " (Bot) " + message

	if ui and ui.has_method("show_instruction"):
		ui.show_instruction(text)

	if card_effects:
		var action_log_node = card_effects.get("action_log")
		if action_log_node and action_log_node.has_method("add_action"):
			action_log_node.add_action(text, is_positive)

func _show_bot_card_preview(card_id: String) -> bool:
	if ui == null:
		return false

	var cards_container: Node = ui.get_node_or_null("CardsContainer")
	if cards_container == null:
		return false

	for child in cards_container.get_children():
		if child == null or child.is_queued_for_deletion():
			continue
		var child_card_id: String = str(child.get("card_id"))
		if child_card_id != card_id:
			continue
		if ui.has_method("_on_card_selected"):
			ui.call("_on_card_selected", child)
			return true

	return false

func _mark_preview_card_as_played(card_id: String) -> void:
	if ui == null:
		return

	var pending_card: Variant = ui.get("pending_card")
	if pending_card == null:
		return

	var pending_card_id: String = str(pending_card.get("card_id"))
	if pending_card_id != card_id:
		return

	pending_card.visible = false
	if ui.has_method("_set_play_btn_disabled"):
		ui._set_play_btn_disabled(true)

var _bot_played_card_id: String = ""


# ────────────────────────────────────────────────────────────────────────────
# Card selection strategies
# ────────────────────────────────────────────────────────────────────────────

## EASY — random non-black card. Black cards are only played when forced (see _bot_take_turn).
func _pick_card_easy(hand: Array, _player_index: int) -> String:
	# Filter out black cards entirely — those are handled upstream in _bot_take_turn
	var playable = hand.filter(
		func(cid): return CardData.ALL_CARDS[cid].get("color", Color.WHITE) != Color.BLACK
	)
	if playable.is_empty():
		return ""
	playable.shuffle()
	return playable[0]




## MEDIUM — prefers green, avoids harmful red, no black cards.
func _pick_card_medium(hand: Array, player_index: int) -> String:
	var role: String = GameState.player_roles[player_index] if player_index < GameState.player_roles.size() else ""

	var best_id   := ""
	var best_score := -9999.0

	for card_id in hand:
		var color = CardData.ALL_CARDS[card_id].get("color", Color.WHITE)
		# Skip black cards — handled upstream in _bot_take_turn
		if color == Color.BLACK:
			continue
		var score := _score_card_medium(card_id, role)
		if score > best_score:
			best_score = score
			best_id = card_id

	return best_id
	
	
func _score_card_medium(card_id: String, role: String) -> float:
	var card    = CardData.ALL_CARDS[card_id]
	var color   = card.get("color", Color.WHITE)
	var effects = card.get("sub_effects", [])

	var score := 0.0

	# Base preference by colour
	if color == Color.GREEN:  score += 10.0
	if color == Color.YELLOW: score += 5.0
	if color == Color.RED:    score -= 5.0

	# Scan sub-effects for generally desirable operations
	for fx in effects:
		var op: String = fx.get("op", "")
		match op:
			"add_e":
				score += 4.0
			"add_v":
				score += 3.0
			"remove_e":
				# Good only if elephants are near humans
				if _elephants_near_humans():
					score += 6.0
				else:
					score -= 2.0
			"remove_v":
				score -= 4.0
			"immune":
				if _elephants_near_humans():
					score += 8.0
				else:
					score += 2.0
			"convert":
				var to_type: String = fx.get("to", "")
				if to_type == "FOREST":
					score += 6.0
				elif to_type == "PLANTATION" or to_type == "HUMAN":
					score -= 3.0
			"move_e":
				var to_type = fx.get("to", "ANY")
				if to_type == "FOREST" or to_type == "ANY":
					if _elephants_near_humans():
						score += 5.0
					else:
						score += 1.0
			"move_all_e_to":
				var to_arr = fx.get("to", [])
				if "PLANTATION" in to_arr or "HUMAN" in to_arr:
					score -= 6.0
				else:
					score += 3.0

	# Light role bonus
	score += _role_bonus_medium(card_id, role)

	# Small random jitter so medium isn't perfectly predictable
	score += randf_range(-1.5, 1.5)
	return score

func _role_bonus_medium(card_id: String, role: String) -> float:
	var card    = CardData.ALL_CARDS[card_id]
	var effects = card.get("sub_effects", [])
	var bonus   := 0.0
	for fx in effects:
		var op: String = fx.get("op", "")
		match role:
			"Conservationist":
				if op == "convert" and fx.get("to","") == "FOREST": bonus += 5.0
				if op == "add_e": bonus += 2.0
			"Village Head":
				if op == "add_v" or op == "add_v_in": bonus += 4.0
			"Plantation Owner":
				if op == "convert" and fx.get("to","") == "PLANTATION": bonus += 5.0
			"Land Developer":
				if op == "convert" and fx.get("to","") == "HUMAN": bonus += 5.0
			"Wildlife Department":
				if op == "add_e": bonus += 3.0
			"Ecotourism Manager":
				if op == "move_e" and fx.get("to","") != "HUMAN": bonus += 3.0
			"Researcher":
				if op == "add_e" or op == "add_v": bonus += 2.0
	return bonus

## HARD — evaluates every non-black card against board state and role win condition.
func _pick_card_hard(hand: Array, player_index: int) -> String:
	var role: String = GameState.player_roles[player_index] if player_index < GameState.player_roles.size() else ""

	var best_id    := ""
	var best_score := -9999.0

	for card_id in hand:
		var color = CardData.ALL_CARDS[card_id].get("color", Color.WHITE)
		# Skip black cards — handled upstream in _bot_take_turn
		if color == Color.BLACK:
			continue
		var score := _score_card_hard(card_id, role, player_index)
		if score > best_score:
			best_score = score
			best_id = card_id

	return best_id
	
func _score_card_hard(card_id: String, role: String, player_index: int) -> float:
	var card    = CardData.ALL_CARDS[card_id]
	var color   = card.get("color", Color.WHITE)
	var effects = card.get("sub_effects", [])

	var score := 0.0

	# Strong color preference
	if color == Color.GREEN:  score += 15.0
	if color == Color.YELLOW: score += 8.0
	if color == Color.RED:    score -= 8.0

	var forest_count      := GameState.count_tiles_of_type(GameState.TileType.FOREST)
	var plantation_count  := GameState.count_tiles_of_type(GameState.TileType.PLANTATION)
	var human_count       := GameState.count_tiles_of_type(GameState.TileType.HUMAN)
	var total_elephants   := _count_all_elephants()
	var near_humans       := _elephants_near_humans()
	var e_in_forest       := GameState.get_elephants_in_forest()
	var total_villagers   := GameState.get_total_villagers()
	var shortest_dist     := GameState.get_shortest_distance_human_elephant()

	for fx in effects:
		var op: String = fx.get("op", "")
		var count: int  = fx.get("count", 1)
		match op:
			"add_e":
				# More elephants is always good, extra good if in forest
				score += 5.0 * count
				if forest_count > plantation_count:
					score += 3.0
			"add_v":
				score += 3.0 * count
			"add_v_in":
				score += 3.0 * count
			"remove_e":
				# Only good if elephants are threatening humans
				if near_humans:
					score += 7.0 * count
				else:
					score -= 4.0 * count
			"remove_v":
				score -= 5.0 * count
			"immune":
				if near_humans:
					score += 12.0
				elif total_elephants > 0:
					score += 4.0
			"convert":
				var to_type: String = fx.get("to","")
				var from_arr: Array = fx.get("from",[])
				if to_type == "FOREST":
					score += 8.0 * count
					if forest_count < 10:   score += 4.0    # board is short on forest
				elif to_type == "PLANTATION":
					score -= 5.0 * count
					if "FOREST" in from_arr: score -= 4.0   # destroying forest is very bad
				elif to_type == "HUMAN":
					score -= 4.0 * count
			"convert_any_any":
				# Hard bot uses this cleverly: if forest is low, it's high value
				if forest_count < 10:
					score += 10.0
				else:
					score += 4.0
			"move_e":
				var to_type = fx.get("to","ANY")
				if near_humans:
					# Moving away from humans is great
					if to_type == "FOREST" or to_type == "ANY":
						score += 8.0 * count
					else:
						score -= 2.0
				else:
					score += 2.0 * count
			"move_v":
				score += 1.0 * count
			"move_all_e_to":
				var to_arr = fx.get("to",[])
				if "HUMAN" in to_arr or "PLANTATION" in to_arr:
					# Moving elephants toward humans is terrible
					score -= 14.0
				else:
					score += 5.0

	# ── Role-specific win condition scoring ──────────────────────────────────
	score += _role_win_score_hard(role, effects,
		forest_count, plantation_count, human_count,
		total_elephants, total_villagers, shortest_dist,
		e_in_forest, player_index)

	# No jitter — hard bot plays optimally
	return score

func _role_win_score_hard(
		role: String, effects: Array,
		forest_count: int, plantation_count: int, human_count: int,
		total_elephants: int, total_villagers: int, shortest_dist: int,
		e_in_forest: int, player_index: int) -> float:

	var bonus := 0.0
	var stats  = GameState.player_stats[player_index]

	for fx in effects:
		var op: String = fx.get("op","")
		var count: int  = fx.get("count", 1)

		match role:
			# ── Conservationist: 4 green cards + forest increase ≥ 2
			"Conservationist":
				if op == "convert" and fx.get("to","") == "FOREST":
					bonus += 12.0 * count
				if op == "add_e":
					bonus += 3.0

			# ── Village Head: 7 action cards + 16 villagers
			"Village Head":
				if op in ["add_v","add_v_in"]:
					var deficit: int = maxi(0, 16 - total_villagers)
					bonus += 6.0 * min(count, deficit)

			# ── Plantation Owner: plantation increase ≥ 2 + 7 action cards
			"Plantation Owner":
				if op == "convert" and fx.get("to","") == "PLANTATION":
					bonus += 12.0 * count

			# ── Land Developer: human increase ≥ 2
			"Land Developer":
				if op == "convert" and fx.get("to","") == "HUMAN":
					bonus += 12.0 * count

			# ── Wildlife Department: 4 elephants in forest
			"Wildlife Department":
				if op == "add_e":
					var deficit: int = maxi(0, 4 - e_in_forest)
					bonus += 8.0 * min(count, deficit)
				if op == "convert" and fx.get("to","") == "FOREST":
					bonus += 4.0

			# ── Ecotourism Manager: elephants exist + dist ≥ 3
			"Ecotourism Manager":
				if op == "add_e" and total_elephants == 0:
					bonus += 15.0   # desperately need an elephant
				if op in ["move_e","move_all_e_to"] and shortest_dist < 3:
					bonus += 10.0   # push elephants away from humans

			# ── Researcher: 5 both_inc cards + dist ≥ 2
			"Researcher":
				var increases_e := op == "add_e"
				var increases_v := op in ["add_v","add_v_in"]
				if increases_e and increases_v:
					bonus += 10.0
				elif increases_e or increases_v:
					bonus += 4.0

			# ── Environmental Consultant: 2 vacant secondary goals met
			"Environmental Consultant":
				# Benefits from diverse board states — treat add_e and add_v as good
				if op in ["add_e","add_v","add_v_in","convert"]:
					bonus += 3.0

			# ── Government: flexible, reward green play
			"Government":
				if op in ["add_e","add_v","convert"] and fx.get("to","") == "FOREST":
					bonus += 4.0

	return bonus


# ────────────────────────────────────────────────────────────────────────────
# Interactive effect handler — feeds tile selections to CardEffects
# ────────────────────────────────────────────────────────────────────────────

func _on_bot_tile_selection_requested(valid_keys: Array, _instruction: String) -> void:
	if not _bot_is_acting:
		return
	if valid_keys.is_empty():
		return

	var difficulty: Difficulty = bot_players.get(_current_bot_player, Difficulty.EASY)
	var op: String = card_effects.current_effect.get("op","")

	var chosen_key: Vector2i
	match difficulty:
		Difficulty.EASY:
			chosen_key = _select_tile_easy(valid_keys, op)
		Difficulty.MEDIUM:
			chosen_key = _select_tile_medium(valid_keys, op)
		Difficulty.HARD:
			chosen_key = _select_tile_hard(valid_keys, op)

	# Queue the selection with a short delay so the game engine can process it.
	_pending_selections.append(chosen_key)
	_action_timer = action_delay
	_waiting_for_action = true


# ── Tile selection heuristics ────────────────────────────────────────────────

func _select_tile_easy(valid_keys: Array, _op: String) -> Vector2i:
	# Completely random
	return valid_keys[randi() % valid_keys.size()]


func _select_tile_medium(valid_keys: Array, op: String) -> Vector2i:
	# Simple heuristics: prefer forest tiles for placing elephants,
	# human tiles for placing villagers, tiles furthest from humans for move_e.
	match op:
		"add_e":
			var forest_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.FOREST)
			if not forest_keys.is_empty():
				return forest_keys[randi() % forest_keys.size()]
		"add_v", "add_v_in":
			var human_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.HUMAN)
			if not human_keys.is_empty():
				return human_keys[randi() % human_keys.size()]
		"remove_e":
			# Remove elephant closest to humans
			return _key_closest_to_human(valid_keys)
		"remove_v":
			# Remove from plantation (less painful)
			var plant_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.PLANTATION)
			if not plant_keys.is_empty():
				return plant_keys[randi() % plant_keys.size()]
		"convert":
			return valid_keys[randi() % valid_keys.size()]
		"move_e", "move_all_e_to":
			# Source: pick elephant closest to humans; Dest: pick forest tile farthest from humans
			if card_effects.state == 1:  # WAITING_SOURCE
				return _key_closest_to_human(valid_keys)
			else:  # WAITING_DEST
				return _key_farthest_from_human(valid_keys)
	return valid_keys[randi() % valid_keys.size()]


func _select_tile_hard(valid_keys: Array, op: String) -> Vector2i:
	var role: String = ""
	if _current_bot_player < GameState.player_roles.size():
		role = GameState.player_roles[_current_bot_player]

	match op:
		"add_e":
			# Prefer forest tiles; among those, pick the one farthest from humans
			var forest_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.FOREST)
			var pool: Array = valid_keys
			if not forest_keys.is_empty():
				pool = forest_keys
			return _key_farthest_from_human(pool)

		"add_v", "add_v_in":
			# Prefer human tiles
			var human_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.HUMAN)
			var pool: Array = valid_keys
			if not human_keys.is_empty():
				pool = human_keys
			return pool[randi() % pool.size()]

		"remove_e":
			# Always remove the elephant that is nearest to a human tile
			return _key_closest_to_human(valid_keys)

		"remove_v":
			# Remove from plantation first (less strategically costly)
			var plant_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.PLANTATION)
			if not plant_keys.is_empty():
				return plant_keys[randi() % plant_keys.size()]
			return valid_keys[randi() % valid_keys.size()]

		"convert":
			var to_type_str: String = card_effects.current_effect.get("to","")
			if to_type_str == "FOREST":
				# Convert the human/plantation tile that is adjacent to the most forest
				return _key_most_adjacent_forest(valid_keys)
			elif to_type_str == "PLANTATION":
				# Convert the non-forest tile with the fewest neighbours (minimal damage)
				return _key_least_valuable(valid_keys)
			elif to_type_str == "HUMAN":
				return _key_least_valuable(valid_keys)
			return valid_keys[randi() % valid_keys.size()]

		"convert_any_any":
			# Pick the non-forest tile with the lowest strategic value and will be converted to forest
			var non_forest = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] != GameState.TileType.FOREST)
			if not non_forest.is_empty():
				return _key_least_valuable(non_forest)
			return valid_keys[randi() % valid_keys.size()]

		"move_e", "move_v":
			if card_effects.state == 1:  # WAITING_SOURCE — pick source
				# Source: elephant or villager closest to a human tile
				return _key_closest_to_human(valid_keys)
			else:  # WAITING_DEST — pick destination
				# Dest: forest tile farthest from humans
				var forest_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.FOREST)
				var pool: Array = valid_keys
				if not forest_keys.is_empty():
					pool = forest_keys
				return _key_farthest_from_human(pool)

	return valid_keys[randi() % valid_keys.size()]


# ── convert_any_any type confirmation ────────────────────────────────────────
# Called from _process when state == WAITING_CHOICE and op == convert_any_any

func _bot_confirm_convert_any_any_type() -> void:
	# Hard always picks FOREST; medium and easy may vary
	var difficulty: Difficulty = bot_players.get(_current_bot_player, Difficulty.EASY)
	var forest_count := GameState.count_tiles_of_type(GameState.TileType.FOREST)
	match difficulty:
		Difficulty.EASY:
			var choice = randi() % 3
			card_effects.confirm_convert_any_any_type_selected(choice)
		Difficulty.MEDIUM:
			if forest_count < 12:
				card_effects.confirm_convert_any_any_type_selected(GameState.TileType.FOREST)
			else:
				card_effects.confirm_convert_any_any_type_selected(GameState.TileType.PLANTATION)
		Difficulty.HARD:
			card_effects.confirm_convert_any_any_type_selected(GameState.TileType.FOREST)

func _bot_confirm_steal_target() -> void:
	var thief := _current_bot_player
	var candidates: Array = []

	for i in range(GameState.player_count):
		if i == thief:
			continue
		var hand_size: int = GameState.player_hands[i].size()
		if hand_size > 0:
			candidates.append({"player": i, "hand_size": hand_size})

	if candidates.is_empty():
		return

	var difficulty: Difficulty = bot_players.get(_current_bot_player, Difficulty.EASY)
	var target_player: int = candidates[0]["player"]

	match difficulty:
		Difficulty.EASY:
			target_player = candidates[randi() % candidates.size()]["player"]
		Difficulty.MEDIUM, Difficulty.HARD:
			candidates.sort_custom(func(a, b): return a["hand_size"] > b["hand_size"])
			target_player = candidates[0]["player"]

	card_effects.confirm_steal_target(target_player)


# ────────────────────────────────────────────────────────────────────────────
# _process — drains the _pending_selections queue with delays
# ────────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _bot_is_acting:
		return

	# Handle popup-style choices in WAITING_CHOICE.
	if card_effects and card_effects.state == 3:
		var wait_op: String = card_effects.current_effect.get("op", "")
		if wait_op == "convert_any_any":
			_bot_confirm_convert_any_any_type()
			return
		if wait_op == "steal":
			_bot_confirm_steal_target()
			return

	if not _waiting_for_action:
		return

	_action_timer -= delta
	if _action_timer > 0.0:
		return

	_action_timer = action_delay
	_waiting_for_action = false

	if _pending_selections.is_empty():
		return

	var tile_key: Vector2i = _pending_selections.pop_front()
	_feed_tile_to_effects(tile_key)


func _feed_tile_to_effects(tile_key: Vector2i) -> void:
	if not card_effects:
		return

	var op: String = card_effects.current_effect.get("op","")
	match card_effects.state:
		1:  # WAITING_SOURCE
			if op in ["convert"]:
				card_effects.confirm_convert_selected(tile_key)
			elif op == "convert_any_any":
				card_effects.confirm_convert_any_any_selected(tile_key)
			else:
				card_effects.confirm_source_selected(tile_key)
		2:  # WAITING_DEST
			card_effects.confirm_dest_selected(tile_key)


# ────────────────────────────────────────────────────────────────────────────
# Effects complete → end turn
# ────────────────────────────────────────────────────────────────────────────

func _on_bot_effects_complete() -> void:
	if not _bot_is_acting:
		return
	# Small pause before ending the turn
	await get_tree().create_timer(end_turn_delay, false).timeout
	_end_bot_turn()


func _end_bot_turn() -> void:
	if not _bot_is_acting:
		return
	_bot_is_acting = false
	_pending_selections.clear()
	bot_turn_ended.emit()

	# Mirror what card_table.gd _on_end_turn_button_pressed does:
	if _bot_played_card_id != "":
		var card_id := _bot_played_card_id
		_bot_played_card_id = ""
		var card_data  = CardData.ALL_CARDS.get(card_id, {})
		var card_color = card_data.get("color", Color.WHITE)
		var p          := _current_bot_player

		# Update stats
		if card_color == Color.GREEN:
			GameState.player_stats[p]["green_cards_played"] += 1
		elif card_color == Color.RED:
			GameState.player_stats[p]["red_cards_played"] += 1
		elif card_color == Color.YELLOW:
			GameState.player_stats[p]["yellow_cards_played"] += 1

		var increases_e := false
		var increases_v := false
		if card_color in [Color.GREEN, Color.RED, Color.YELLOW]:
			for fx in card_data.get("sub_effects",[]):
				var op = fx.get("op","")
				if op == "add_e": increases_e = true
				if op in ["add_v","add_v_in"]: increases_v = true
			if increases_e and increases_v:
				GameState.player_stats[p]["both_inc_cards"] += 1
			elif increases_e:
				GameState.player_stats[p]["e_inc_cards"] += 1
			elif increases_v:
				GameState.player_stats[p]["v_inc_cards"] += 1

		if card_color in [Color.GREEN, Color.YELLOW, Color.RED]:
			GameState.player_stats[p]["action_cards_played"] += 1

		# Discard and draw a replacement
		if ui and ui.has_method("add_recent_card_for_player"):
			ui.add_recent_card_for_player(p, card_id)
		GameState.discard_card(p, card_id)
		if GameState.player_hands[p].size() < 5:
			GameState.draw_card(p)

	# Advance to next player
	GameState.advance_turn()


# ────────────────────────────────────────────────────────────────────────────
# Tile-scoring helpers
# ────────────────────────────────────────────────────────────────────────────

func _key_closest_to_human(keys: Array) -> Vector2i:
	var best_key: Vector2i = Vector2i(keys[0])
	var best_dist: int = 999999
	for k in keys:
		var d: int = _min_dist_to_type(k, GameState.TileType.HUMAN)
		if d < best_dist:
			best_dist = d
			best_key = k
	return best_key

func _key_farthest_from_human(keys: Array) -> Vector2i:
	var best_key: Vector2i = Vector2i(keys[0])
	var best_dist: int = -1
	for k in keys:
		var d: int = _min_dist_to_type(k, GameState.TileType.HUMAN)
		if d > best_dist:
			best_dist = d
			best_key = k
	return best_key

func _key_most_adjacent_forest(keys: Array) -> Vector2i:
	# Among valid keys, pick the one with the most neighbouring forest tiles.
	var best_key: Vector2i = Vector2i(keys[0])
	var best_count: int = -1
	for k in keys:
		var count: int = 0
		for neighbour in _get_neighbours(k):
			if GameState.tile_registry.has(neighbour) and \
					GameState.tile_registry[neighbour]["type"] == GameState.TileType.FOREST:
				count += 1
		if count > best_count:
			best_count = count
			best_key = k
	return best_key

func _key_least_valuable(keys: Array) -> Vector2i:
	# Plantation > human > forest for "least strategically costly to lose".
	var plantation_keys = keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.PLANTATION)
	if not plantation_keys.is_empty():
		return plantation_keys[randi() % plantation_keys.size()]
	var human_keys = keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.HUMAN)
	if not human_keys.is_empty():
		return human_keys[randi() % human_keys.size()]
	return keys[randi() % keys.size()]

func _min_dist_to_type(origin: Vector2i, tile_type: int) -> int:
	var best: int = 999999
	for k in GameState.tile_registry:
		if GameState.tile_registry[k]["type"] == tile_type:
			var d: int = abs(k.x - origin.x) + abs(k.y - origin.y)
			if d < best:
				best = d
	return best

func _get_neighbours(key: Vector2i) -> Array:
	return [
		Vector2i(key.x + 1, key.y),
		Vector2i(key.x - 1, key.y),
		Vector2i(key.x, key.y + 1),
		Vector2i(key.x, key.y - 1),
	]

func _elephants_near_humans() -> bool:
	var dist := GameState.get_shortest_distance_human_elephant()
	return dist >= 0 and dist <= 2

func _count_all_elephants() -> int:
	var count := 0
	for k in GameState.tile_registry:
		count += GameState.tile_registry[k]["elephant_nodes"].size()
	return count
