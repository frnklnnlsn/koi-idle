extends Camera2D


@onready var fish = null

func _ready():
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	follow_subject(fish)
	#print(position.x)
	#print(position.y)
	#print(fish)
	pass



func follow_subject(fish):
	if fish == null:
		pass
	else:
		
		var skeleton:Line2D = fish.get_child(1)
		var pos = skeleton.get_point_position(0)
		var new_pos = Vector2(pos.x, pos.y )
		self.position = new_pos
