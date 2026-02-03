extends Node3D

signal delete_Elephant
signal increase_total_Elephant

signal delete_Meeple
signal increase_total_Meeple

const ELEPHANT_SCENE = preload("res://assets/Pieces/Elephant.tscn")
const MEEPLE_SCENE = preload("res://assets/Pieces/Meeple.tscn")

var meeple_count: int = 0
var elephant_count: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# this is for testing
	var elephant1
	var meeple

	# in elephant and meeple tscn, when they are added as child,
	# they are automatically added to the "elephants" and "meeples" groups, respectively.
	
	# add elephant test
	for i in range(3):
		var a = randi_range(-10, 10) # Set random position in 3D space
		var c = randi_range(-10, 10)
		
		elephant1 = ELEPHANT_SCENE.instantiate() 
		elephant1.position = Vector3(a, 0, c)
		emit_signal("increase_total_Elephant") #increase total elephant in card table script
		add_child(elephant1)
		
		# !! important : add this line after you add child for delete to work
		elephant1.Del_Elephant.connect(func(): elephant_count += 1)

	# add meeple test
	for i in range(3):
		var a = randi_range(-10, 10) #randomisation elephant loaction
		var c = randi_range(-10, 10)
		
		meeple = MEEPLE_SCENE.instantiate()
		meeple.position = Vector3(a, 0, c)
		emit_signal("increase_total_Meeple") #increase total meeple in card table script
		add_child(meeple)
		
		
		# !! important : add this line after you add child for delete to work
		meeple.Del_Meeple.connect(func(): meeple_count += 1)
		
	#end of testing

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func del_Elephant():
	emit_signal("delete_Elephant")

func del_Meeple():
	emit_signal("delete_Meeple")
	
	
