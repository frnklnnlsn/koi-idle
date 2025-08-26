extends MarginContainer

signal hovered(fish_resource:fish_conf)
signal unhovered(fish_resource:fish_conf)
signal selected_deselected(fish_resource:fish_conf)
var fish_resource:fish_conf

var focused:bool = false

func _on_card_button_pressed():
	
	#print(self.has_theme_stylebox("normal"))
	if focused == false:
		focused = true
		
	else:
		focused = false

	selected_deselected.emit(fish_resource)
	


func _on_card_button_mouse_entered():
	hovered.emit(fish_resource)
	self.set_scale(Vector2(1.5,1.5))


func _on_card_button_mouse_exited():
	unhovered.emit(fish_resource)
	self.set_scale(Vector2(1,1))
