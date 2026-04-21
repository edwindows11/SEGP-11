extends Node3D

@onready var UI: Control = $CanvasLayer/Control
@onready var Play: Node3D = $Play
@onready var camera: Camera3D = $Camera3D

const ELEPHANT_SCENE = preload("res://assets/Pieces/Elephant.tscn")
const MEEPLE_SCENE = preload("res://assets/Pieces/Meeple.tscn")

var totalElephants: int = 0
var totalMeeple: int = 0
var player_role: String = ""
var player_roles: Array = []
var _current_valid_selection_keys: Array = []
var card_effects: Node = null  # CardEffects instance
var singleplayer_bot_count: int = 3
var human_player_index: int = 0
var bot_speed_preset: String = "Normal"
var bot_difficulty_by_player: Dictionary = {}
var bot_ai: Node = null

func _ready() -> void:
	# --- Connect Play node signals (declared in play_node.gd) ---
	Play.increase_total_Elephant.connect(_on_play_increase_total_elephant)
	Play.increase_total_Meeple.connect(_on_play_increase_total_meeple)

	# --- GameState setup ---
	GameState.player_roles = player_roles
	GameState.player_count = 4
	GameState.current_player_index = 0

	# Build and deal the deck (Board._ready runs first as a child, tiles are registered)
	GameState.build_deck()
	GameState.deal_initial_hands()

	# --- Spawn initial board pieces ---
	_spawn_initial_pieces()

	# --- Initialise Stats Tracking ---
	GameState.setup_stats()

	# --- CardEffects setup (must come early so card_effects is never null) ---
	card_effects = load("res://scripts/Card/CardEffects.gd").new()
	if card_effects == null:
		push_error("card_table.gd: Failed to instantiate CardEffects.gd!")
		return
	card_effects.board = $Board
	card_effects.play = self
	card_effects.action_log = $CanvasLayer/Control/ActionLog
	add_child(card_effects)

	card_effects.effects_complete.connect(_on_card_effects_complete)
	card_effects.request_tile_selection.connect(_on_request_tile_selection)
	card_effects.clear_tile_selection.connect(_on_clear_tile_selection)

	# Role abilities
	card_effects.connect("steal_complete", func():
		if UI.has_method("reposition_cards"):
			UI.reposition_cards()
	)
	card_effects.connect("request_em_choice", _on_request_em_choice)

	# Conversion popups from origin/main
	card_effects.connect("request_steal_popup", _on_request_steal_popup)
	card_effects.connect("request_gov_steal_popup", _on_request_gov_steal_popup)
	card_effects.connect("request_convert_type_popup", _on_request_convert_type_popup)
	if not card_effects.is_connected("steal_complete", _on_steal_complete):
		card_effects.connect("steal_complete", _on_steal_complete)

	# --- Pass role to UI ---
	player_role = player_roles[0] if player_roles.size() > 0 else "Unknown"
	UI.player_role = player_role
	if UI.user_role_label:
		UI.user_role_label.text = "Player 1 (" + player_role + ")"

	# --- Spawn UI player tiles and hand ---
	UI.spawn_cards()
	# Build one goal-tracker panel per player (Player 1 → Player N) populated
	# from RoleEffect — replaces the old fixed nine-role layout.
	UI.build_player_trackers()

	# Show the correct ability button for the first player's role on turn 1
	var initial_role = player_roles[0] if player_roles.size() > 0 else ""
	if UI.special_ability_btn:
		UI.special_ability_btn.visible = RoleEffect.has_button_ability(initial_role)
	# If Player 1 is EC, show the borrow-choice popup immediately
	if initial_role == "Environmental Consultant" and GameState.ec_borrowed_ability == "":
		UI.show_ec_choice_popup.call_deferred()

	# --- Optional singleplayer bots ---
	_setup_singleplayer_bots()

	# --- Wire UI signals ---
	UI.card_activated.connect(_on_card_activated)
	UI.end_turn_requested.connect(_on_end_turn_button_pressed)
	UI.end_turn_timer_expired.connect(_on_end_turn_timer_expired)
	UI.request_po_ability.connect(_on_po_ability_requested)
	UI.request_gov_ability.connect(_on_gov_ability_requested)
	UI.request_cons_ability.connect(_on_cons_ability_requested)
	UI.request_ld_ability.connect(_on_ld_ability_requested)
	UI.request_ec_ability.connect(_on_ec_ability_requested)
	UI.request_em_ability.connect(_on_em_ability_requested)

	# --- Wire GameState turn signal to UI ---
	GameState.turn_changed.connect(_on_turn_changed_for_ui)
	GameState.turn_changed.connect(UI._on_turn_changed)

	if player_roles.size() > 0:
		print("Game Started with roles: ", player_roles)

	UI.pause_btn.pressed.connect(_pause)

	# So wildfire special ability happens on turn 1
	GameState.turn_changed.emit.call_deferred(GameState.current_player_index, player_role, false)



func _process(_delta: float) -> void:
	pass

func _pause():
	var pause_menu = $CanvasLayer/PauseMenu
	if pause_menu:
		pause_menu.toggle_pause()
		return

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause()

	if _is_bot_turn():
		return

	# Land-Use Planning type-choice input (after selecting a tile):
	# 1 = Forest, 2 = Human, 3 = Plantation
	if event is InputEventKey and event.pressed and not event.echo:
		if card_effects and card_effects.state == 3 and card_effects.current_effect.get("op", "") == "convert_any_any":
			match event.keycode:
				KEY_1, KEY_KP_1:
					card_effects.confirm_convert_any_any_type_selected(GameState.TileType.FOREST)
					return
				KEY_2, KEY_KP_2:
					card_effects.confirm_convert_any_any_type_selected(GameState.TileType.HUMAN)
					return
				KEY_3, KEY_KP_3:
					card_effects.confirm_convert_any_any_type_selected(GameState.TileType.PLANTATION)
					return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

		# --- Card effect tile selection mode ---
		# If CardEffects is waiting for a tile click, route here and consume the event.
		if card_effects and card_effects.state != 0:  # 0 = CardEffects.State.IDLE
			var tile_key = _raycast_to_tile_key(event.position)
			if tile_key != Vector2i(-1, -1):
				_route_tile_click_to_effects(tile_key)
			return


# --- Tile selection helpers ---

func _raycast_to_tile_key(screen_pos: Vector2) -> Vector2i:
	var cam = get_viewport().get_camera_3d()
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)
	
	if not result:
		return Vector2i(-1, -1)

	# Walk up from the hit collider looking for a tile OR a piece
	var node = result.collider
	for _i in range(6):
		if node == null:
			break
		
		# Direct tile hit
		if node.has_meta("tile_key"):
			return node.get_meta("tile_key")
			
		# Piece hit — return the tile_key the piece is registered on
		if node.is_in_group("elephants") or node.is_in_group("meeples"):
			if node.has_meta("tile_key") or "tile_key" in node:
				return node.tile_key  # pieces store their tile_key as a var
				
		node = node.get_parent()
		
	return Vector2i(-1, -1)

func _route_tile_click_to_effects(tile_key: Vector2i) -> void:
	if not _current_valid_selection_keys.has(tile_key):
		return

	var op: String = card_effects.current_effect.get("op", "")
	match card_effects.state:
		1:  # WAITING_SOURCE
			if op in ["convert", "convert_any_any"]:
				if op == "convert":
					card_effects.confirm_convert_selected(tile_key)
				else:
					card_effects.confirm_convert_any_any_selected(tile_key)
			else:
				card_effects.confirm_source_selected(tile_key)
		2:  # WAITING_DEST
			card_effects.confirm_dest_selected(tile_key)


# --- Card effect signal handlers ---

func _on_card_activated(card_id: String) -> void:
	if _is_bot_turn():
		return
	_track_card_stats_and_discard(card_id)
	card_effects.execute_card(card_id)

func _on_card_effects_complete() -> void:
	if _is_bot_turn():
		if UI.play_btn: UI.play_btn.disabled = true
	else:
		UI.set_end_turn_ready()  # enables play btn when it's in End Turn mode

func _on_request_tile_selection(_valid_keys: Array, instruction: String) -> void:
	_current_valid_selection_keys = _valid_keys.duplicate()
	UI.show_instruction(instruction)

func _on_clear_tile_selection() -> void:
	_current_valid_selection_keys.clear()
	UI.hide_instruction()
	$Board.clear_all_highlights()

func _on_request_em_choice() -> void:
	if _is_bot_turn():
		return
	UI.show_em_choice_popup(card_effects.confirm_em_choice)
	
func _on_po_ability_requested() -> void:
	var disable_func = func(i):
		return card_effects.lastCard[i] == null
	var callback_func = func(t_idx):
		card_effects.execute_reversed_card(t_idx, UI)
	UI.show_player_select_popup("Reverse player's last card:", disable_func, callback_func, card_effects)

func _on_gov_ability_requested() -> void:
	# Route through the card-effect pipeline (mirrors op:steal flow).
	# _do_gov_steal will emit request_gov_steal_popup, which we handle below.
	card_effects.execute_government_ability(UI)


func _on_request_gov_steal_popup() -> void:
	if _is_bot_turn():
		return
	UI.show_steal_popup(card_effects, "gov")

func _on_cons_ability_requested() -> void:
	card_effects.execute_conservationist_ability(UI)

func _on_ld_ability_requested() -> void:
	card_effects.execute_land_developer_ability(UI)

func _on_em_ability_requested() -> void:
	card_effects.execute_em_ability(UI)

func _on_ec_ability_requested() -> void:
	# Delegate to the handler for the borrowed role's ability
	match GameState.ec_borrowed_ability:
		"Plantation Owner":
			_on_po_ability_requested()
		"Government":
			_on_gov_ability_requested()
		"Conservationist":
			card_effects.execute_conservationist_ability(UI)
		"Land Developer":
			card_effects.execute_land_developer_ability(UI)
		"Ecotourism Manager":
			card_effects.execute_em_ability(UI)
		"Wildlife Department":
			UI.show_instruction("Wildlife Department: Bonus draw happens automatically at turn start.")
		"Village Head":
			UI.show_instruction("Village Head: Passive ability — play up to 2 cards per turn (max 1 villager-increasing).")
		"Researcher":
			UI.show_instruction("Researcher: Passive ability — elephant-adding cards let you move elephants.")
		_:
			UI.show_instruction("No ability selected yet. Please wait for setup.")

	
func _on_request_steal_popup() -> void:
	if _is_bot_turn():
		return
	UI.show_steal_popup(card_effects)

func _on_request_convert_type_popup(current_type: int) -> void:
	if _is_bot_turn():
		return
	UI.show_convert_type_popup(card_effects, current_type)

func _track_card_stats_and_discard(card_id: String) -> void:
	var card_data = CardData.ALL_CARDS.get(card_id, {})
	var card_color = card_data.get("color", Color.WHITE)
	if card_color == Color.GREEN:
		GameState.player_stats[GameState.current_player_index]["green_cards_played"] += 1
	elif card_color == Color.RED:
		GameState.player_stats[GameState.current_player_index]["red_cards_played"] += 1
	elif card_color == Color.YELLOW:
		GameState.player_stats[GameState.current_player_index]["yellow_cards_played"] += 1
		
	# Track researcher stats for cards that increase elephants/humans
	var increases_e = false
	var increases_v = false
	if card_color in [Color.GREEN, Color.RED, Color.YELLOW]:
		for fx in card_data.get("sub_effects", []):
			var op = fx.get("op", "")
			if op == "add_e": increases_e = true
			if op == "add_v" or op == "add_v_in": increases_v = true
			
		if increases_e and increases_v:
			GameState.player_stats[GameState.current_player_index]["both_inc_cards"] += 1
		elif increases_e:
			GameState.player_stats[GameState.current_player_index]["e_inc_cards"] += 1
		elif increases_v:
			GameState.player_stats[GameState.current_player_index]["v_inc_cards"] += 1
	
	# Track if the card played was Green, Yellow, or Red
	if card_color == Color.GREEN or card_color == Color.YELLOW or card_color == Color.RED:
		GameState.player_stats[GameState.current_player_index]["action_cards_played"] += 1
	
	GameState.discard_card(GameState.current_player_index, card_id)


# --- End turn ---

func _on_end_turn_button_pressed() -> void:
	if _is_bot_turn():
		return

	# Timer can expire mid-card-action; fill remaining selections randomly so
	# the effect resolves before the turn actually ends.
	if card_effects and card_effects.state != 0:
		await _auto_complete_card_action()

	# --- Wildlife Department: must discard one bonus card before the turn ends ---
	var cur_role: String = GameState.player_roles[GameState.current_player_index] \
		if GameState.current_player_index < GameState.player_roles.size() else ""
	var _ec_with_wd := (cur_role == "Environmental Consultant" and GameState.ec_borrowed_ability == "Wildlife Department")
	if (cur_role == "Wildlife Department" or _ec_with_wd) and GameState.wildlife_dept_drawn_cards.size() > 0:
		if UI.play_btn: UI.play_btn.disabled = true
		UI.show_wildlife_discard_popup()
		return

	if UI.pending_card and is_instance_valid(UI.pending_card):
		_track_card_stats_and_discard(UI.pending_card.card_id)
	UI.pending_card = null

	# Refill hand up to 5 cards (unless ability skips draw)
	var p_index = GameState.current_player_index
	if p_index >= 0 and p_index < GameState.player_hands.size():
		if not UI.po_used_ability_this_turn and not UI.gov_used_ability_this_turn:
			while GameState.player_hands[p_index].size() < UI.TOTAL_CARDS:
				if GameState.draw_card(p_index) == "":
					break

	GameState.advance_turn()
	UI.currently_viewing_card = false

# randomly complete card action if the user's timer ended
func _on_end_turn_timer_expired() -> void:
	if _is_bot_turn():
		return
	# Wildlife Department: if timer expires with pending bonus cards, auto-discard a random one.
	var cur_role: String = GameState.player_roles[GameState.current_player_index] \
		if GameState.current_player_index < GameState.player_roles.size() else ""
	var ec_with_wd := (cur_role == "Environmental Consultant" and GameState.ec_borrowed_ability == "Wildlife Department")
	if (cur_role == "Wildlife Department" or ec_with_wd) and GameState.wildlife_dept_drawn_cards.size() > 0:
		var random_card: String = GameState.wildlife_dept_drawn_cards.pick_random()
		GameState.wildlife_dept_discard_bonus(GameState.current_player_index, random_card)
		GameState.wildlife_dept_drawn_cards.clear()
		if UI.wildlife_discard_popup:
			UI.wildlife_discard_popup.visible = false
		UI.spawn_cards()
	_on_end_turn_button_pressed()

func _auto_complete_card_action() -> void:
	if card_effects == null:
		return
	var safety := 20
	while card_effects.state != 0 and safety > 0:
		safety -= 1
		var op: String = card_effects.current_effect.get("op", "")
		if card_effects.state == 3:  # WAITING_CHOICE
			if op == "convert_any_any":
				var types := [GameState.TileType.FOREST, GameState.TileType.HUMAN, GameState.TileType.PLANTATION]
				card_effects.confirm_convert_any_any_type_selected(types.pick_random())
			else:
				break
		else:
			if _current_valid_selection_keys.is_empty():
				break
			var random_key: Vector2i = _current_valid_selection_keys.pick_random()
			_route_tile_click_to_effects(random_key)
		await get_tree().process_frame

# setup bots to play
func _setup_singleplayer_bots() -> void:
	var max_bots: int = maxi(0, GameState.player_count - 1)
	var bot_count: int = clampi(singleplayer_bot_count, 0, max_bots)
	if bot_count <= 0:
		return

	var bot_script = load("res://scripts/Card Table/bot.gd")
	if bot_script == null:
		push_warning("Bot script could not be loaded")
		return

	bot_ai = bot_script.new()
	bot_ai.card_effects = card_effects
	bot_ai.play = self
	bot_ai.board = $Board
	bot_ai.ui = UI
	if bot_ai.has_method("set_speed_preset"):
		bot_ai.set_speed_preset(bot_speed_preset)
	add_child(bot_ai)

	var bot_indices: Array = []
	for i in range(bot_count):
		var bot_index := (human_player_index + 1 + i) % GameState.player_count
		bot_indices.append(bot_index)

	for i in range(bot_indices.size()):
		var bot_player_index: int = bot_indices[i]
		var configured_difficulty: int = int(bot_difficulty_by_player.get(bot_player_index, -1))
		var difficulty: int = configured_difficulty
		if difficulty < bot_ai.Difficulty.EASY or difficulty > bot_ai.Difficulty.HARD:
			# Fallback keeps the previous default progression if no pre-game override exists.
			difficulty = bot_ai.Difficulty.MEDIUM
			if i == 0:
				difficulty = bot_ai.Difficulty.HARD
			elif i == 1:
				difficulty = bot_ai.Difficulty.MEDIUM
			else:
				difficulty = bot_ai.Difficulty.EASY
		bot_ai.set_player_difficulty(bot_player_index, difficulty)

	if not bot_ai.bot_turn_started.is_connected(UI._on_bot_turn_started):
		bot_ai.bot_turn_started.connect(UI._on_bot_turn_started)
	if not bot_ai.bot_turn_ended.is_connected(UI._on_bot_turn_ended):
		bot_ai.bot_turn_ended.connect(UI._on_bot_turn_ended)

	if not GameState.turn_changed.is_connected(bot_ai._on_turn_changed):
		GameState.turn_changed.connect(bot_ai._on_turn_changed)

	print("Singleplayer bots enabled for players: ", bot_indices)

func _is_bot_turn() -> bool:
	return _is_bot_turn_for_player(GameState.current_player_index)

func _is_bot_turn_for_player(player_index: int) -> bool:
	if bot_ai == null:
		return false
	return bot_ai.is_bot(player_index)

func _on_turn_changed_for_ui(player_index: int, _role_name: String, is_skipped: bool) -> void:
	var is_bot_turn = _is_bot_turn_for_player(player_index) and not is_skipped
	UI.set_bot_turn(is_bot_turn)
		
# --- Piece spawning (moved from card_functions.gd) ---

func spawn_piece_on_tile(type: String, pos: Vector3, tile_key: Vector2i) -> bool:
	if not GameState.can_place_piece(tile_key, type):
		return false

	var piece_instance

	if type == "elephant" or type == "Elephant":
		piece_instance = ELEPHANT_SCENE.instantiate()
		Play.increase_total_Elephant.emit()
		Play.add_child(piece_instance)
		piece_instance.Del_Elephant.connect(func():
			GameState.piece_removed(piece_instance, piece_instance.tile_key, "elephant")
		)

	elif type == "villager" or type == "Meeple":
		piece_instance = MEEPLE_SCENE.instantiate()
		Play.increase_total_Meeple.emit()
		Play.add_child(piece_instance)
		piece_instance.Del_Meeple.connect(func():
			GameState.piece_removed(piece_instance, piece_instance.tile_key, "villager")
		)

	if piece_instance:
		piece_instance.position = pos + Vector3(0, 0, 0.1)
		piece_instance.tile_key = tile_key
		var placed := GameState.piece_placed(
			piece_instance,
			tile_key,
			"elephant" if type in ["Elephant", "elephant"] else "villager"
		)
		if not placed:
			piece_instance.queue_free()
			return false
		return true

	return false

# --- Initial board setup ---

func _spawn_initial_pieces() -> void:
	var scenario_idx: int = GameState.selected_scenario_index
	var scenario = null
	if scenario_idx >= 0 and scenario_idx < ScenarioData.get_scenario_count():
		scenario = ScenarioData.get_scenario(scenario_idx)

	if scenario:
		# --- Preset scenario: place elephants at defined positions ---
		var elephants: Array = scenario["elephants"]
		for epos in elephants:
			# epos = Vector2i(row, col) → board key = Vector2i(col, row)
			var key := Vector2i(epos.y, epos.x)
			if GameState.tile_registry.has(key):
				var pos: Vector3 = GameState.tile_registry[key]["world_pos"]
				spawn_piece_on_tile("Elephant", pos, key)

		# Place villagers on random Human (village) tiles
		var villager_count: int = scenario["villagers_count"]
		var human_tiles = GameState.get_tiles_of_type(GameState.TileType.HUMAN)
		human_tiles.shuffle()
		var placed := 0
		for key in human_tiles:
			if placed >= villager_count:
				break
			# Allow up to 2 villagers per tile
			var entry = GameState.tile_registry[key]
			while entry["villager_nodes"].size() < 2 and placed < villager_count:
				var pos: Vector3 = entry["world_pos"]
				spawn_piece_on_tile("Meeple", pos, key)
				placed += 1
	else:
		# --- Random scenario: original logic ---
		# 3 elephants on random forest tiles
		var forest_tiles = GameState.get_tiles_of_type(GameState.TileType.FOREST)
		forest_tiles.shuffle()
		for i in range(min(3, forest_tiles.size())):
			var key: Vector2i = forest_tiles[i]
			var pos: Vector3 = GameState.tile_registry[key]["world_pos"]
			spawn_piece_on_tile("Elephant", pos, key)

		# 6 villagers on random human or plantation tiles
		var human_plantation_tiles = GameState.get_tiles_matching(["HUMAN", "PLANTATION"])
		human_plantation_tiles.shuffle()
		for i in range(min(6, human_plantation_tiles.size())):
			var key: Vector2i = human_plantation_tiles[i]
			var pos: Vector3 = GameState.tile_registry[key]["world_pos"]
			spawn_piece_on_tile("Meeple", pos, key)


# --- Play node signal handlers (keep for total tracking) ---

func _on_play_increase_total_elephant() -> void:
	totalElephants += 1

func _on_play_increase_total_meeple() -> void:
	totalMeeple += 1

func _on_play_reduce_total_elephant() -> void:
	totalElephants -= 1

func _on_play_reduce_total_meeple() -> void:
	totalMeeple -= 1

func _on_steal_complete() -> void:
	if UI.has_method("reposition_cards"): UI.reposition_cards()
	UI.spawn_cards()   
	$Board.clear_all_highlights()
