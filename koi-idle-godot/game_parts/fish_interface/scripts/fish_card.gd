extends MarginContainer

signal hovered(fish_resource:fish_conf)

var fish_resource:fish_conf


func _on_panel_mouse_entered() -> void:
	hovered.emit(fish_resource)
	self.set_scale(Vector2(1.5,1.5))


func _on_panel_mouse_exited() -> void:
	self.set_scale(Vector2(1,1))
