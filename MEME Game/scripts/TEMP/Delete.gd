extends Node3D

var totalElephants: int = 0
var totalMeeple: int = 0 
const ELEPHANT_SCENE = preload("res://assets/Pieces/Elephant.tscn")
const MEEPLE_SCENE = preload("res://assets/Pieces/Meeple.tscn")


var value := randi_range(1, 10)

signal delete_Elephant
signal delete_Meeple


func _ready() -> void:
	randomize()
	var elephant1
	var meeple

	for i in range(3):
		var a = randi_range(-10, 10)
		var c = randi_range(-10, 10)
		
		elephant1 = ELEPHANT_SCENE.instantiate()
		elephant1.position = Vector3(a, 0, c)
		totalElephants += 1
		add_child(elephant1)
		elephant1.Del_Elephant.connect(elephantDeleted)

	print(totalElephants)
	
	for i in range(3):
		var a = randi_range(-10, 10)
		var c = randi_range(-10, 10)
		
		meeple = MEEPLE_SCENE.instantiate()
		meeple.position = Vector3(a, 0, c)
		totalMeeple += 1
		add_child(meeple)
		meeple.Del_Meeple.connect(meepleDeleted)

	print(totalMeeple)

	emit_signal ("delete_Elephant")
	emit_signal ("delete_Meeple")



func elephantDeleted():
	totalElephants -= 1
	print("elephant: %d" % totalElephants)

	
func meepleDeleted():
	totalMeeple -= 1
	print("meeple: %d" % totalMeeple)
