extends Node3D

@onready var UI: Control = $CanvasLayer/Control
@onready var Play: Node3D = $Play
@onready var camera: Camera3D = $Camera3D

var totalElephants: int = 0
var totalMeeple: int = 0
var player_role: String = ""
var player_roles: Array = []
var _current_valid_selection_keys: Array = []

var card_effects: Node = null  # CardEffects instance

func _ready() -> void:
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

	# --- Pass role to UI ---
	player_role = player_roles[0] if player_roles.size() > 0 else "Unknown"
	UI.player_role = player_role
	if UI.user_role_label:
		UI.user_role_label.text = "Player 1 (" + player_role + ")"

	# --- Spawn UI player tiles and hand ---
	UI.spawn_players()
	UI.spawn_cards()

	# --- CardEffects setup ---
	card_effects = load("res://scripts/CardEffects.gd").new()
	card_effects.board = $Board
	card_effects.play = Play
	card_effects.action_log = $CanvasLayer/Control/ActionLog
	add_child(card_effects)

	card_effects.effects_complete.connect(_on_card_effects_complete)
	card_effects.request_tile_selection.connect(_on_request_tile_selection)
	card_effects.clear_tile_selection.connect(_on_clear_tile_selection)
	card_effects.connect("request_steal_target", _on_request_steal_target)
	card_effects.connect("steal_complete", func(): UI.reposition_cards())

	# --- Wire UI signals ---
	UI.card_activated.connect(_on_card_activated)
	UI.end_turn_requested.connect(_on_end_turn_button_pressed)

	# --- Wire GameState turn signal to UI ---
	GameState.turn_changed.connect(UI._on_turn_changed)

	if player_roles.size() > 0:
		print("Game Started with roles: ", player_roles)


func _process(_delta: float) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var pause_menu = $CanvasLayer/PauseMenu
		if pause_menu:
			pause_menu.toggle_pause()
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

		# --- Manual placement / removal mode (dropdown) ---
		var mode_id = UI.placement_options.get_selected_id()
		if mode_id == 0:
			pass  # Select mode
		else:
			var from = camera.project_ray_origin(event.position)
			var to = from + camera.project_ray_normal(event.position) * 1000

			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(from, to)
			query.collide_with_areas = true
			var result = space_state.intersect_ray(query)

			if result:
				if mode_id == 1 or mode_id == 2:
					var collider = result.collider
					var tile_root = collider.get_parent()

					if tile_root and tile_root.get_parent() == $Board:
						var snap_pos = tile_root.position

						# Use GameState for occupancy check
						var tile_key = _raycast_to_tile_key(event.position)
						var can_place = false
						if tile_key != Vector2i(-1, -1) and GameState.tile_registry.has(tile_key):
							var entry = GameState.tile_registry[tile_key]
							if mode_id == 1 and entry["elephant_nodes"].size() < 1:
								can_place = true
							elif mode_id == 2 and entry["villager_nodes"].size() < 2:
								can_place = true

						if can_place:
							if mode_id == 1:
								Play.spawn_piece("Elephant", snap_pos)
							elif mode_id == 2:
								Play.spawn_piece("Meeple", snap_pos)
						else:
							print("Cannot place: Tile Occupied or invalid")

				elif mode_id == 3:
					var collider = result.collider
					var candidate = collider
					var piece_found = false

					for _i in range(5):
						if candidate == null:
							break
						if candidate.is_in_group("elephants") or candidate.is_in_group("meeples"):
							var ptype = "elephant" if candidate.is_in_group("elephants") else "villager"
							GameState.piece_removed(candidate, candidate.tile_key, ptype)
							candidate.queue_free()
							piece_found = true
							break
						candidate = candidate.get_parent()

					if not piece_found:
						print("Clicked object is not a removable piece")


# --- Tile selection helpers ---

func _raycast_to_tile_key(screen_pos: Vector2) -> Vector2i:
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 1000
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)
	if result:
		var tile_root = result.collider.get_parent()
		if tile_root and tile_root.has_meta("tile_key"):
			return tile_root.get_meta("tile_key")
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
	card_effects.execute_card(card_id)

func _on_card_effects_complete() -> void:
	UI.end_turn_button.disabled = false

func _on_request_tile_selection(_valid_keys: Array, instruction: String) -> void:
	_current_valid_selection_keys = _valid_keys.duplicate()
	UI.show_instruction(instruction)

func _on_clear_tile_selection() -> void:
	_current_valid_selection_keys.clear()
	UI.hide_instruction()
	$Board.clear_all_highlights()

func _on_request_steal_target() -> void:
	UI.show_steal_popup(card_effects)


# --- End turn ---

func _on_end_turn_button_pressed() -> void:
	if UI.pending_card:
		# Track if the card played was a Green card
		var card_id = UI.pending_card.card_id
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
		
		GameState.discard_card(GameState.current_player_index, UI.pending_card.card_id)
		UI.remove_played_card_and_draw_replacement()
	GameState.advance_turn()
	UI.currently_viewing_card = false

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
				Play.spawn_piece_on_tile("Elephant", pos, key)

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
				Play.spawn_piece_on_tile("Meeple", pos, key)
				placed += 1
	else:
		# --- Random scenario: original logic ---
		# 3 elephants on random forest tiles
		var forest_tiles = GameState.get_tiles_of_type(GameState.TileType.FOREST)
		forest_tiles.shuffle()
		for i in range(min(3, forest_tiles.size())):
			var key: Vector2i = forest_tiles[i]
			var pos: Vector3 = GameState.tile_registry[key]["world_pos"]
			Play.spawn_piece_on_tile("Elephant", pos, key)

		# 6 villagers on random human or plantation tiles
		var human_plantation_tiles = GameState.get_tiles_matching(["HUMAN", "PLANTATION"])
		human_plantation_tiles.shuffle()
		for i in range(min(6, human_plantation_tiles.size())):
			var key: Vector2i = human_plantation_tiles[i]
			var pos: Vector3 = GameState.tile_registry[key]["world_pos"]
			Play.spawn_piece_on_tile("Meeple", pos, key)


# --- Play node signal handlers (keep for total tracking) ---

func _on_play_increase_total_elephant() -> void:
	totalElephants += 1
	print("elephant total: %d" % totalElephants)

func _on_play_increase_total_meeple() -> void:
	totalMeeple += 1
	print("meeple total: %d" % totalMeeple)

func _on_play_reduce_total_elephant() -> void:
	totalElephants -= 1
	print("elephant total: %d" % totalElephants)

func _on_play_reduce_total_meeple() -> void:
	totalMeeple -= 1
	print("meeple total: %d" % totalMeeple)
