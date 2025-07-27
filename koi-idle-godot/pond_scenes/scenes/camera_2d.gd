# StaticMinimapCamera.gd
# Attach this to your minimap camera (Camera2D) inside the SubViewport

extends Camera2D

@export var zoom_scale: float = 0.1  # How zoomed out the minimap should be
@export var minimap_position: Vector2 = Vector2.ZERO  # Center position of the minimap view

func _ready():
	# Enable this camera
	enabled = true
	
	# Set zoom for minimap view
	zoom = Vector2(zoom_scale, zoom_scale)
	
	# Set the static position
	global_position = minimap_position
