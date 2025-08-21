extends CanvasLayer

@onready var shimmer_rect = $ColorRect
@onready var background = %background

func _process(delta):
	shimmer_rect.material.set_shader_parameter(
		"viewport_size",
		get_viewport().get_visible_rect().size
	)

func _ready():
	background.z_index = -1
