extends Node3D

@onready var UI: Control = $CanvasLayer/Control
@onready var Play: Node3D = $Play
@onready var camera: Camera3D = $Camera3D

var totalElephants: int = 0
var totalMeeple: int = 0 
var player_role: String = ""
var player_roles: Array = [] # Stores all 4 player roles

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# UI and Play are onready, so they are already assigned
	
	# Pass role to UI and update label (since UI._ready() ran before we could set this)
	UI.player_role = player_role
	if player_roles.size() > 0:
		print("Game Started with roles: ", player_roles)
		# Optionally update UI to show all 4? Current request doesn't specify, 
		# but existing logic uses 'player_role' (single). 
		# If user wants 4-player HUD, that's a separate task. 
		# For now, we ensure we don't lose the data.

	if UI.user_role_label:
		UI.user_role_label.text = "My Role: " + player_role
		
	Play.del_Elephant() # cards will call this for delete elephant function
	Play.del_Meeple() # cards will call this for delete meeple function

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Toggle Pause Menu
		# Need reference to PauseMenu instance in CanvasLayer
		var pause_menu = $CanvasLayer/PauseMenu
		if pause_menu:
			pause_menu.toggle_pause()
			return # Consume event

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if UI.pending_card:
			# If we are holding a card, maybe place that? 
			# For now assuming placement mode overrides or runs parallel
			pass
		
		# Check Placement Mode from UI
		var mode_id = UI.placement_options.get_selected_id()
		if mode_id == 0:
			# Select Mode - do nothing or select units (future)
			pass
		else:
			# Placement Mode
			var from = camera.project_ray_origin(event.position)
			var to = from + camera.project_ray_normal(event.position) * 1000
			
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(from, to)
			query.collide_with_areas = true
			
			var result = space_state.intersect_ray(query)
			
			if result:
				print("Placement Click at: ", result.position)
				
				if mode_id == 1 or mode_id == 2:
					# Grid Snapping Logic
					var collider = result.collider
					# Assuming collider is child of Tile Root (Board.gd adds StaticBody as child of Tile)
					var tile_root = collider.get_parent()
					
					# Verify this is actually a tile (Board.gd logic)
					if tile_root and tile_root.get_parent() == $Board: # Assuming tiles are children of Board node
						# Or just trust the hierarchy if only tiles have static bodies in this layer
						# Snap to tile position (Y might need adjustment if tile root is at 0)
						var snap_pos = tile_root.position
						
						# Occupancy Check
						var occupied = false
						var pieces = get_tree().get_nodes_in_group("elephants") + get_tree().get_nodes_in_group("meeples")
						
						for piece in pieces:
							# Check if piece is close to this tile center
							# Using distance squared is faster, threshold e.g. 0.5 units
							if piece.position.distance_to(snap_pos) < 0.5:
								occupied = true
								print("Tile Occupied by: ", piece.name)
								break
						
						if not occupied:
							if mode_id == 1:
								Play.spawn_piece("Elephant", snap_pos)
							elif mode_id == 2:
								Play.spawn_piece("Meeple", snap_pos)
						else:
							print("Cannot place: Tile Occupied")
					else:
						# Fallback if we clicked something else or hierarchy differs
						# Assuming Board > Tile > StaticBody
						# If Board.gd adds tiles efficiently, they are likely direct children of Board.
						# Let's try to proceed with snap_pos if tile_root seems valid enough
						var snap_pos = tile_root.position
						pass # Re-using logic above would be cleaner but let's stick to the happy path for now inside the if

				elif mode_id == 3:
					# Remove Logic
					var collider = result.collider
					
					# Traverse up to find the root piece node
					var candidate = collider
					var piece_found = false
					
					# Check up to 5 levels up to be safe
					for i in range(5):
						if candidate == null:
							break
							
						if candidate.is_in_group("elephants") or candidate.is_in_group("meeples"):
							print("Removing piece: ", candidate.name)
							candidate.queue_free()
							piece_found = true
							break
						
						candidate = candidate.get_parent()
					
					if not piece_found:
						print("Clicked object is not a removable piece (or group not found). Collider: ", collider.name)



func _on_play_increase_total_elephant() -> void:
	totalElephants += 1
	print("elephant: %d" % totalElephants)


func _on_play_increase_total_meeple() -> void:
	totalMeeple += 1
	print("meeple: %d" % totalMeeple)


func _on_play_reduce_total_elephant() -> void:
	totalElephants -= 1
	print("elephant: %d" % totalElephants)


func _on_play_reduce_total_meeple() -> void:
	totalMeeple -= 1
	print("meeple: %d" % totalMeeple)


func _on_end_turn_button_pressed() -> void:
# this is delete function
	totalElephants -= Play.elephant_count
	Play.elephant_count = 0
	for elephant in get_tree().get_nodes_in_group("elephants"):
		if elephant.selected == true:
			elephant.queue_free()
	print("elephant: %d" % totalElephants)
	
	totalMeeple -= Play.meeple_count
	Play.meeple_count = 0
	for meeple in get_tree().get_nodes_in_group("meeples"):
		if meeple.selected == true:
			meeple.queue_free()
	print("meeple: %d" % totalMeeple)
# end
	
