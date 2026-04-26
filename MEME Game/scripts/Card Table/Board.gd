## It generates a grid of forest / human / plantation tiles, and registers each one in GameState. 
## Handles converting tiles between types and highlighting tiles for card actions.
extends Node3D

## The board is 8x8 = 64 tiles.
const BOARD_SIZE = 8
## Size of each tile in world units.
const TILE_SIZE = 2.0

const FOREST_TILE = preload("res://assets/Tiles/ForestTile.glb")
const HUMAN_TILE = preload("res://assets/Tiles/HumanDominatedTile.glb")
const PLANTATION_TILE = preload("res://assets/Tiles/PlantationTile.glb")

## Target tile counts for random boards: 26 Forest, 19 Human, 19 Plantation.
const TILE_QUOTAS = [26, 19, 19]

func _ready() -> void:
	generate_board()

## Builds the 8x8 grid of tiles. 
## Uses the chosen scenario if one was picked, otherwise generates a random layout. 
## Each tile is placed in 3D space, given a collider, and registered in GameState.
func generate_board() -> void:
	var type_map: Dictionary
	var scenario_idx: int = GameState.selected_scenario_index
	if scenario_idx >= 0 and scenario_idx < ScenarioData.get_scenario_count():
		type_map = _type_map_from_scenario(scenario_idx)
	else:
		# Random / default flood-fill generation
		type_map = _generate_type_map()

	for x in range(BOARD_SIZE):
		for z in range(BOARD_SIZE):
			var tile_type: int = type_map[Vector2i(x, z)]
			var tile_scene = _scene_for_type(tile_type)
			var tile_instance = tile_scene.instantiate()
			add_child(tile_instance)

			var offset = (BOARD_SIZE * TILE_SIZE) / 2.0
			var world_pos = Vector3(x * TILE_SIZE - offset, 0, z * TILE_SIZE - offset)
			tile_instance.position = world_pos

			# Tag with grid key for raycast lookup
			tile_instance.set_meta("tile_key", Vector2i(x, z))
			tile_instance.set_meta("tile_type", tile_type)

			create_tile_collider(tile_instance)

			# Register in global GameState
			GameState.register_tile(x, z, tile_type, tile_instance, world_pos)


## Flood Fill Algorithm
## Builds a random tile-type map where same-type tiles group together.
## Plants one seed per type, then grows each region outward in turn until every tile is assigned.
func _generate_type_map() -> Dictionary:
	var type_map: Dictionary = {}
	var remaining: Array = TILE_QUOTAS.duplicate()

	# One seed per type, spread across the grid
	var seed_positions: Array = _pick_spread_seeds(3)
	var frontiers: Array = [[], [], []]

	for i in range(3):
		type_map[seed_positions[i]] = i
		remaining[i] -= 1
		frontiers[i].append(seed_positions[i])

	var total = BOARD_SIZE * BOARD_SIZE

	for _iter in range(total * 20):
		if type_map.size() >= total:
			break

		# Cycle through all three types in random order each round
		var order = [0, 1, 2]
		order.shuffle()

		for t in order:
			if remaining[t] <= 0:
				continue

			# If this type's frontier is exhausted, scan for any neighbour of its tiles
			if frontiers[t].is_empty():
				for key in type_map:
					if type_map[key] == t:
						var nb = _get_unassigned_neighbors(key, type_map)
						if not nb.is_empty():
							frontiers[t].append(key)
							break
				if frontiers[t].is_empty():
					continue

			var src_idx = randi() % frontiers[t].size()
			var src: Vector2i = frontiers[t][src_idx]
			var neighbors: Array = _get_unassigned_neighbors(src, type_map)

			if neighbors.is_empty():
				frontiers[t].remove_at(src_idx)
				continue

			var dest: Vector2i = neighbors[randi() % neighbors.size()]
			type_map[dest] = t
			remaining[t] -= 1
			frontiers[t].append(dest)
			break  # one expansion per round, then cycle to next type

	# Safety net: fill any gaps with whatever type still has quota remaining
	for x in range(BOARD_SIZE):
		for z in range(BOARD_SIZE):
			var k = Vector2i(x, z)
			if not type_map.has(k):
				var best_t = 0
				for t2 in range(1, 3):
					if remaining[t2] > remaining[best_t]:
						best_t = t2
				type_map[k] = best_t
				remaining[best_t] -= 1

	return type_map


## Returns the list of neighbouring cells that don't have a tile type assigned yet. 
func _get_unassigned_neighbors(cell: Vector2i, type_map: Dictionary) -> Array:
	var result: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Vector2i = cell + d
		if nb.x >= 0 and nb.x < BOARD_SIZE and nb.y >= 0 and nb.y < BOARD_SIZE:
			if not type_map.has(nb):
				result.append(nb)
	return result


## Picks starting points for the region-grow loop.
## BOARD_SIZE/2 apart so the regions don't end up on top of each other.
func _pick_spread_seeds(count: int) -> Array:
	# Shuffle all positions then pick ones at least BOARD_SIZE/2 apart (Manhattan)
	var candidates: Array = []
	for x in range(BOARD_SIZE):
		for z in range(BOARD_SIZE):
			candidates.append(Vector2i(x, z))
	candidates.shuffle()

	var chosen: Array = []
	@warning_ignore("integer_division")
	var min_dist: int = BOARD_SIZE / 2

	for c in candidates:
		var ok = true
		for s in chosen:
			if abs(c.x - s.x) + abs(c.y - s.y) < min_dist:
				ok = false
				break
		if ok:
			chosen.append(c)
			if chosen.size() >= count:
				break

	# Fallback: relax distance requirement if not enough spread points found
	if chosen.size() < count:
		for c in candidates:
			if not (c in chosen):
				chosen.append(c)
			if chosen.size() >= count:
				break

	return chosen

## Builds a tile-type map from a preset scenario in ScenarioData.
## Converts from grid[row][col] layout to the Board's Vector2i(x, z) keys.
func _type_map_from_scenario(scenario_idx: int) -> Dictionary:
	var scenario = ScenarioData.get_scenario(scenario_idx)
	var grid: Array = scenario["grid"]
	var type_map: Dictionary = {}
	# ScenarioData grid: grid[row][col], row=0 is top.
	# Board grid: Vector2i(x, z) where x=column, z=row.
	for row in range(BOARD_SIZE):
		for col in range(BOARD_SIZE):
			type_map[Vector2i(col, row)] = grid[row][col]
	return type_map


## Returns the 3D scene for a given tile type (0 = Forest, 1 = Human, 2 = Plantation). Falls back to Forest if the type is unknown.
func _scene_for_type(tile_type: int) -> PackedScene:
	match tile_type:
		1:  return HUMAN_TILE
		2:  return PLANTATION_TILE
	return FOREST_TILE  # 0 = FOREST (default)

## Adds a box collider on top of the tile so mouse raycasts can hit it.
## Used for tile selection during card effects.
func create_tile_collider(tile_node: Node3D) -> void:
	var static_body = StaticBody3D.new()
	tile_node.add_child(static_body)

	var collision_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(TILE_SIZE, 0.2, TILE_SIZE)
	collision_shape.shape = box
	static_body.add_child(collision_shape)

	static_body.collision_layer = 1


## Replaces the tile at `tile_key` with a new tile of `new_type`.
## Used by card effects that change tile types (e.g. "convert").
## Removes the old tile node, spawns the new one at the same position, and updates GameState's tile_registry.
func convert_tile(tile_key: Vector2i, new_type: int) -> void:
	if not GameState.tile_registry.has(tile_key):
		push_warning("convert_tile: key not in registry: " + str(tile_key))
		return

	var entry = GameState.tile_registry[tile_key]
	var old_node: Node3D = entry["node"]
	var world_pos: Vector3 = entry["world_pos"]

	# Instantiate replacement tile
	var new_scene = _scene_for_type(new_type)
	var new_node = new_scene.instantiate()
	add_child(new_node)
	new_node.position = world_pos
	new_node.set_meta("tile_key", tile_key)
	new_node.set_meta("tile_type", new_type)
	create_tile_collider(new_node)

	# Remove old tile
	old_node.queue_free()

	# Update registry
	GameState.tile_registry[tile_key]["node"] = new_node
	GameState.tile_registry[tile_key]["type"] = new_type


## Adds a see-through coloured plane on top of the given tiles so the player can see which tiles are valid for the current card effect.
func highlight_tiles(tile_keys: Array, color: Color) -> void:
	for key in tile_keys:
		if not GameState.tile_registry.has(key):
			continue
		var tile_node: Node3D = GameState.tile_registry[key]["node"]
		if not tile_node:
			continue
		if tile_node.find_child("_highlight", false, false):
			continue  # Already highlighted
		_apply_highlight(tile_node, color)

## Removes every highlight from the board.
func clear_all_highlights() -> void:
	for key in GameState.tile_registry:
		var tile_node: Node3D = GameState.tile_registry[key]["node"]
		if not tile_node:
			continue
		var h = tile_node.find_child("_highlight", false, false)
		if h:
			# Rename so find_child won't match it in the same frame if we re-highlight immediately
			h.name = "_highlight_queued_for_deletion"
			h.queue_free()

func _apply_highlight(tile_node: Node3D, color: Color) -> void:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "_highlight"

	var plane = PlaneMesh.new()
	plane.size = Vector2(TILE_SIZE - 0.05, TILE_SIZE - 0.05)
	mesh_instance.mesh = plane

	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = mat

	# Slightly above tile surface
	mesh_instance.position = Vector3(0, 0.12, 0)

	tile_node.add_child(mesh_instance)
