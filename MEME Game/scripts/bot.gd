extends Node

signal bot_turn_started # signal when bot starts
signal bot_turn_ended # signal when bot ends

enum Difficulty { EASY, MEDIUM, HARD }


var card_effects: Node = null   # CardEffects instance
var play: Node3D    = null      # card_functions node
var board: Node3D   = null      # Board node
var ui: Control     = null      # card_table_ui node

# Maps player_index (int) to difficulty
var bot_players: Dictionary = {}

# Timing 
# Small delays so the bot thinks and not acting instantly
var think_delay: float = 2.0
var card_reveal_delay: float = 1.4
var action_delay: float = 0.85
var end_turn_delay: float = 1.8

var _pending_selections: Array = []   # Queue of tile keys to feed to CardEffects
var _action_timer: float = 0.0
var _waiting_for_action: bool = false
var _bot_is_acting: bool = false      # True while a bot is mid-turn


var _current_bot_player: int = -1 # number of bots
var _em_used_this_turn: bool = false #this is for Ecotourism Manager


# Public API

## mark a list of player indices as bots at the start, default to medium difficulty
func set_bot_players(indices: Array, difficulty: Difficulty = Difficulty.MEDIUM) -> void:
	for idx in indices:
		bot_players[idx] = difficulty

## Set difficulty
func set_player_difficulty(player_index: int, difficulty: Difficulty) -> void:
	bot_players[player_index] = difficulty

## Configure bot pacing
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

func is_bot(player_index: int) -> bool:
	return bot_players.has(player_index)


func _on_turn_changed(player_index: int, _role_name: String, is_skipped: bool) -> void:
	_bot_is_acting = false
	_pending_selections.clear()
	_waiting_for_action = false
	_action_timer = 0.0
	_em_used_this_turn = false

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

	await get_tree().create_timer(think_delay, false).timeout
	_bot_take_turn(player_index)


func _bot_take_turn(player_index: int) -> void:
	if not _bot_is_acting:
		return

	var difficulty: Difficulty = bot_players.get(player_index, Difficulty.EASY)
	var hand: Array = GameState.player_hands[player_index]

	var role: String = GameState.player_roles[player_index] if player_index < GameState.player_roles.size() else ""
	var ability_role = role
	if role == "Environmental Consultant":
		ability_role = GameState.ec_borrowed_ability

	if ability_role == "Conservationist":
		var valid_tiles = card_effects._get_cons_valid_tiles()
		if not valid_tiles.is_empty() and randf() > 0.4:
			_announce_bot_message(player_index, "uses Conservationist Special Ability!", true)
			if not card_effects.request_tile_selection.is_connected(_on_bot_tile_selection_requested):
				card_effects.request_tile_selection.connect(_on_bot_tile_selection_requested)
			card_effects.execute_conservationist_ability(ui)
			await card_effects.effects_complete
			if not _bot_is_acting: return

	elif ability_role == "Land Developer":
		var valid_tiles = card_effects._get_ld_valid_tiles()
		if not valid_tiles.is_empty() and randf() > 0.4:
			_announce_bot_message(player_index, "uses Land Developer Special Ability!", true)
			if not card_effects.request_tile_selection.is_connected(_on_bot_tile_selection_requested):
				card_effects.request_tile_selection.connect(_on_bot_tile_selection_requested)
			card_effects.execute_land_developer_ability(ui)
			await card_effects.effects_complete
			if not _bot_is_acting: return

	if _try_use_special_ability(role, player_index):
		return

	if hand.is_empty():
		_announce_bot_message(player_index, "has no cards and passes", false)
		await get_tree().create_timer(end_turn_delay, false).timeout
		_end_bot_turn()
		return

	var black_cards_in_hand: Array = hand.filter(
		func(cid): return CardData.ALL_CARDS[cid].get("color", Color.WHITE) == Color.BLACK
	)
	var must_play_black: bool = not black_cards_in_hand.is_empty()

	var chosen_card_id: String = ""

	if must_play_black:
		# must play a black card
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
		# in case more than one black cards appear
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

	#execute card effect
	var card_def: Dictionary = CardData.ALL_CARDS.get(chosen_card_id, {})
	var card_name: String = str(card_def.get("name", chosen_card_id))
	_announce_bot_message(player_index, "plays: " + card_name, true)
	if ui and ui.has_method("animate_bot_card_popup"):
		await ui.animate_bot_card_popup(chosen_card_id)
		if not _bot_is_acting:
			return
	await get_tree().create_timer(card_reveal_delay, false).timeout
	if not _bot_is_acting:
		return

	_mark_preview_card_as_played(chosen_card_id)

	_bot_played_card_id = chosen_card_id

	if not card_effects.effects_complete.is_connected(_on_bot_effects_complete):
		card_effects.effects_complete.connect(_on_bot_effects_complete)

	if not card_effects.request_tile_selection.is_connected(_on_bot_tile_selection_requested):
		card_effects.request_tile_selection.connect(_on_bot_tile_selection_requested)

	card_effects.execute_card(chosen_card_id)

# bot message appear on the instruction
func _announce_bot_message(player_index: int, message: String, is_positive: bool) -> void:
	var text := "Player " + str(player_index + 1) + " (Bot) " + message

	if ui and ui.has_method("show_instruction"):
		ui.show_instruction(text)

	if card_effects:
		var action_log_node = card_effects.get("action_log")
		if action_log_node and action_log_node.has_method("add_action"):
			action_log_node.add_action(text, is_positive)

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

func _try_use_special_ability(role: String, player_index: int) -> bool:
	var ability_role = role
	if role == "Environmental Consultant":
		ability_role = GameState.ec_borrowed_ability

	var difficulty: Difficulty = bot_players.get(player_index, Difficulty.EASY)

	match ability_role:
		"Government":
			var best_target = -1
			var best_score = -9999.0
			# Compute board snapshot once — it doesn't change while we score targets.
			var snap: Dictionary = _compute_board_snapshot() if difficulty != Difficulty.EASY else {}
			for i in range(GameState.player_count):
				if i == player_index: continue
				var lastCardeffect = card_effects.lastCard[i]
				if lastCardeffect == null: continue
				var card = CardData.ALL_CARDS.get(lastCardeffect, {})
				var col = card.get("color", Color.WHITE)
				if col in [Color.GREEN, Color.YELLOW, Color.RED]:
					var score = 0.0
					if difficulty == Difficulty.HARD:
						score = _score_card_hard(lastCardeffect, role, player_index, snap)
					elif difficulty == Difficulty.MEDIUM:
						score = _score_card_medium(lastCardeffect, role, snap)
					else:
						score = randf() * 10
					
					if score > best_score:
						best_score = score
						best_target = i
			
			var threshold = 5.0
			if difficulty == Difficulty.EASY: threshold = -9999.0
			if best_target != -1 and best_score >= threshold:
				_announce_bot_message(player_index, "uses Government Special Ability!", true)
				# Government steal does not emit effects_complete and is not an action replacement.
				# We simply execute it and then let the bot proceed to play a normal card.
				card_effects.execute_government_steal(best_target, ui)
				return false

		"Plantation Owner":
			var best_target = -1
			var best_score = -9999.0
			for i in range(GameState.player_count):
				if i == player_index: continue
				var lastCardeffect = card_effects.lastCard[i]
				if lastCardeffect != null:
					var score = randf() * 10
					if score > best_score:
						best_score = score
						best_target = i
			
			if best_target != -1 and randf() > 0.3:
				_announce_bot_message(player_index, "uses Plantation Owner Special Ability!", true)
				if not card_effects.effects_complete.is_connected(_on_bot_effects_complete):
					card_effects.effects_complete.connect(_on_bot_effects_complete)
				card_effects.execute_reversed_card(best_target, ui)
				return true

	return false

var _bot_played_card_id: String = ""



# Chose how likely a bot plays a card
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
	var snap := _compute_board_snapshot()

	for card_id in hand:
		var color = CardData.ALL_CARDS[card_id].get("color", Color.WHITE)
		# Skip black cards — handled upstream in _bot_take_turn
		if color == Color.BLACK:
			continue
		var score := _score_card_medium(card_id, role, snap)
		if score > best_score:
			best_score = score
			best_id = card_id

	return best_id
	
# Snapshot of board-wide statistics that the scoring functions read.
# Loop-invariant within a single decision pass — compute once per pick, not per card.
func _compute_board_snapshot() -> Dictionary:
	return {
		"forest_count":     GameState.count_tiles_of_type(GameState.TileType.FOREST),
		"plantation_count": GameState.count_tiles_of_type(GameState.TileType.PLANTATION),
		"human_count":      GameState.count_tiles_of_type(GameState.TileType.HUMAN),
		"total_elephants":  _all_elephants(),
		"near_humans":      _elephants_near_humans(),
		"e_in_forest":      GameState.get_elephants_in_forest(),
		"total_villagers":  GameState.get_total_villagers(),
		"shortest_dist":    GameState.get_shortest_distance_human_elephant(),
	}

func _score_card_medium(card_id: String, role: String, snap: Dictionary = {}) -> float:
	if snap.is_empty():
		snap = _compute_board_snapshot()
	var card    = CardData.ALL_CARDS[card_id]
	var color   = card.get("color", Color.WHITE)
	var effects = card.get("sub_effects", [])
	var near_humans: bool = snap.near_humans

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
				if near_humans:
					score += 6.0
				else:
					score -= 2.0
			"remove_v":
				score -= 4.0
			"immune":
				if near_humans:
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
					if near_humans:
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
	var snap := _compute_board_snapshot()

	for card_id in hand:
		var color = CardData.ALL_CARDS[card_id].get("color", Color.WHITE)
		# Skip black cards — handled upstream in _bot_take_turn
		if color == Color.BLACK:
			continue
		var score := _score_card_hard(card_id, role, player_index, snap)
		if score > best_score:
			best_score = score
			best_id = card_id

	return best_id
	
func _score_card_hard(card_id: String, role: String, player_index: int, snap: Dictionary = {}) -> float:
	if snap.is_empty():
		snap = _compute_board_snapshot()
	var card    = CardData.ALL_CARDS[card_id]
	var color   = card.get("color", Color.WHITE)
	var effects = card.get("sub_effects", [])

	var score := 0.0

	# Strong color preference
	if color == Color.GREEN:  score += 15.0
	if color == Color.YELLOW: score += 8.0
	if color == Color.RED:    score -= 8.0

	var forest_count: int     = snap.forest_count
	var plantation_count: int = snap.plantation_count
	var human_count: int      = snap.human_count
	var total_elephants: int  = snap.total_elephants
	var near_humans: bool     = snap.near_humans
	var e_in_forest: int      = snap.e_in_forest
	var total_villagers: int  = snap.total_villagers
	var shortest_dist: int    = snap.shortest_dist

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


# choose which tile the bots ill place cards in
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

# EASY - random
func _select_tile_easy(valid_keys: Array, _op: String) -> Vector2i:
	# Completely random
	return valid_keys[randi() % valid_keys.size()]

# MEDIUM 
func _select_tile_medium(valid_keys: Array, op: String) -> Vector2i:
	match op:
		"add_e":
			# prefer forest tiles for placing elephants
			var forest_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.FOREST)
			if not forest_keys.is_empty():
				return forest_keys[randi() % forest_keys.size()]
		"add_v", "add_v_in":
			# human tiles for placing villagers, 
			var human_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.HUMAN)
			if not human_keys.is_empty():
				return human_keys[randi() % human_keys.size()]
		"remove_e":
			# Remove elephant closest to humans
			return _key_closest_to_human(valid_keys)
		"remove_v":
			# Remove from plantation
			var plant_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.PLANTATION)
			if not plant_keys.is_empty():
				return plant_keys[randi() % plant_keys.size()]
		"convert":
			return valid_keys[randi() % valid_keys.size()]
		"move_e", "move_all_e_to":
			# pick elephant closest to humans then pick forest tile farthest from humans
			if card_effects.state == 1:  # WAITING_SOURCE
				return _key_closest_to_human(valid_keys)
			else:  # WAITING_DEST
				return _key_farthest_from_human(valid_keys)
	return valid_keys[randi() % valid_keys.size()]


# HARD
func _select_tile_hard(valid_keys: Array, op: String) -> Vector2i:
	var role: String = ""
	if _current_bot_player < GameState.player_roles.size():
		role = GameState.player_roles[_current_bot_player]

	match op:
		"add_e":
			# prefer forest tiles farthest from humans
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
			# Remove the elephant that is nearest to a human tile
			return _key_closest_to_human(valid_keys)

		"remove_v":
			# Remove from plantation first 
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
				# Convert the non-forest tile with the fewest neighbours
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
				# elephant or villager closest to a human tile
				return _key_closest_to_human(valid_keys)
			else:
				# forest tile farthest from humans
				var forest_keys = valid_keys.filter(func(k): return GameState.tile_registry[k]["type"] == GameState.TileType.FOREST)
				var pool: Array = valid_keys
				if not forest_keys.is_empty():
					pool = forest_keys
				return _key_farthest_from_human(pool)

	return valid_keys[randi() % valid_keys.size()]


# convert_any_any type confirmation 

# Called from _process when state == WAITING_CHOICE and op == convert_any_any
func _bot_confirm_convert_any_any_type() -> void:
	# Hard always picks FOREST; medium and easy vary
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
			#append player with hand size more than 0
			candidates.append({"player": i, "hand_size": hand_size})

	if candidates.is_empty():
		return

	var difficulty: Difficulty = bot_players.get(_current_bot_player, Difficulty.EASY)
	var target_player: int = candidates[0]["player"]

	match difficulty:
		Difficulty.EASY:
			target_player = candidates[randi() % candidates.size()]["player"] #random
		Difficulty.MEDIUM, Difficulty.HARD:
			candidates.sort_custom(func(a, b): return a["hand_size"] > b["hand_size"]) #take from the largest hand size
			target_player = candidates[0]["player"]

	card_effects.confirm_steal_target(target_player)

# ecotourism manager choose base on a 50% chance
func _bot_confirm_em_choice() -> void:
	var choice = "skip"
	if randf() > 0.5:
		choice = "elephant"
	else:
		choice = "villager"
	card_effects.confirm_em_choice(choice)

func _process(delta: float) -> void:
	if not _bot_is_acting:
		return

	# Handle popup-style choices
	if card_effects and card_effects.state == 3:
		var wait_op: String = card_effects.current_effect.get("op", "")
		if wait_op == "convert_any_any":
			_bot_confirm_convert_any_any_type()
			return
		if wait_op == "steal":
			_bot_confirm_steal_target()
			return
		if wait_op == "em_extra_move":
			_bot_confirm_em_choice()
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
	_tile_effect_bot(tile_key)

# card effect on tiles
func _tile_effect_bot(tile_key: Vector2i) -> void:
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


func _on_bot_effects_complete() -> void:
	if not _bot_is_acting:
		return
		
	# Environmental Consultant borrow another role's ability for the round,
	# use the borrowed role if applicable
	var role: String = GameState.player_roles[_current_bot_player] if _current_bot_player < GameState.player_roles.size() else ""
	var ability_role = GameState.ec_borrowed_ability if role == "Environmental Consultant" else role

	if ability_role == "Ecotourism Manager" and not _em_used_this_turn and _bot_played_card_id != "" and card_effects.state == 0:
		# Look up the just-played card's definition so we can inspect its colour
		# and sub-effects.
		var lastCardeffect = _bot_played_card_id
		var card_def = CardData.ALL_CARDS.get(lastCardeffect, {})
		var col = card_def.get("color", Color.WHITE)

		# only react to action cards 
		# Color.WHITE is excluded.
		if col in [Color.BLACK, Color.YELLOW, Color.RED, Color.GREEN]:
			# scan the sub-effects for any add_e / add_v / add_v_in op.
			var added = false
			for fx in card_def.get("sub_effects", []):
				if fx.get("op", "") in ["add_e", "add_v", "add_v_in"]: added = true

			# 60% chance of playing special ability
			if added and randf() > 0.4:
				_em_used_this_turn = true  # lock it once-per-turn 
				_announce_bot_message(_current_bot_player, "uses Ecotourism Manager Special Ability!", true)
				# Make sure this same handler runs again when the EM ability finishes resolving
				if not card_effects.effects_complete.is_connected(_on_bot_effects_complete):
					card_effects.effects_complete.connect(_on_bot_effects_complete)
				card_effects.execute_em_ability(ui)
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

	# Wildlife Department discard the worst cards of its bonus-drawn cards
	var role: String = GameState.player_roles[_current_bot_player] if _current_bot_player < GameState.player_roles.size() else ""
	var _ec_wd = (role == "Environmental Consultant" and GameState.ec_borrowed_ability == "Wildlife Department")
	if (role == "Wildlife Department" or _ec_wd) and GameState.wildlife_dept_drawn_cards.size() > 0:
		var difficulty = bot_players.get(_current_bot_player, Difficulty.EASY)
		# Only consider bonus cards that are STILL in hand and were NOT the card
		# the bot just played this turn — otherwise wildlife_dept_discard_bonus
		# silently no-ops because the card isn't in player_hands anymore.
		var hand: Array = GameState.player_hands[_current_bot_player]
		var candidates: Array = []
		for c in GameState.wildlife_dept_drawn_cards:
			if c == _bot_played_card_id:
				continue
			if c in hand:
				candidates.append(c)
		if candidates.is_empty():
			# Nothing valid to discard — clear stale state and bail.
			GameState.wildlife_dept_drawn_cards.clear()
		else:
			var worst_card: String = candidates[0]
			var worst_score := 9999.0
			# Snapshot once — board doesn't change between scoring iterations.
			var snap: Dictionary = _compute_board_snapshot() if difficulty != Difficulty.EASY else {}
			for c in candidates:
				var score := 0.0
				if difficulty == Difficulty.HARD:
					score = _score_card_hard(c, role, _current_bot_player, snap)
				elif difficulty == Difficulty.MEDIUM:
					score = _score_card_medium(c, role, snap)
				else:
					score = randf()
				if score < worst_score:
					worst_score = score
					worst_card = c
			var worst_card_name = CardData.ALL_CARDS.get(worst_card, {}).get("name", worst_card)
			GameState.wildlife_dept_discard_bonus(_current_bot_player, worst_card)
			GameState.wildlife_dept_drawn_cards.clear()

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

# Tile-scoring

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
	# Plantation first then human then forest to simulate which would be least costly to lose
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

func _all_elephants() -> int:
	var count := 0
	for k in GameState.tile_registry:
		count += GameState.tile_registry[k]["elephant_nodes"].size()
	return count
