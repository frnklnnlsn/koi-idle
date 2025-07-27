extends Camera2D

@onready var sprite_2d = $"../Sprite2D"
@onready var fish = $"../fish"
@onready var fish_for_card = $"../fish_for_card"


func _ready():
	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var skeleton:Line2D = fish_for_card.get_child(1)
	var pos = skeleton.get_point_position(0)
	var new_pos = Vector2(pos.x, pos.y +100)
	self.position = new_pos
	
	pass
