extends Node

@onready var Booling:bool
# Called when the node enters the scene tree for the first time.
func _ready():
	#change_parent_position(100)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func change_parent_position(X:int):
	var parent = self.get_parent()
	parent.position.x += X
