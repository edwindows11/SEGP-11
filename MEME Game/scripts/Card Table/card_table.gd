extends Node3D

var UI: Control
var Play: Node3D

var totalElephants: int = 0
var totalMeeple: int = 0 

var player_role: String = "Unknown"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	UI = $Control
	UI.player_role = player_role
	UI.new()
	Play = $Play
	Play.del_Elephant() # cards will call this for delete elephant function
	Play.del_Meeple() # cards will call this for delete meeple function

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


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
	
