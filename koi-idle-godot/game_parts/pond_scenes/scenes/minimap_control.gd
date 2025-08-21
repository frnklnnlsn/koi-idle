# RealtimeMinimap.gd
# Real-time minimap using SubViewport

# RealtimeMinimap.gd
# Real-time minimap using SubViewport

extends Control

@export var minimap_size: Vector2i = Vector2i(200, 200)
@export var zoom_scale: float = 0.05  # Much more zoomed out to see more
@export var minimap_position: Vector2 = Vector2.ZERO  # Center position
@export var show_border: bool = true  # Add a border to see the minimap bounds

var viewport: SubViewport
var minimap_cam: Camera2D
var texture_rect: TextureRect

func _ready():
	# Set up the control size and position
	custom_minimum_size = minimap_size
	size = minimap_size
	
	# Position the minimap in a visible corner (top-right)
	anchors_preset = Control.PRESET_TOP_RIGHT
	position = Vector2(-minimap_size.x - 20, 20)  # 20px margin from edges
	
	# Create SubViewport
	viewport = SubViewport.new()
	viewport.size = minimap_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Create minimap camera inside viewport
	minimap_cam = Camera2D.new()
	minimap_cam.zoom = Vector2(zoom_scale, zoom_scale)
	minimap_cam.global_position = minimap_position
	minimap_cam.enabled = true
	
	# Create TextureRect to display the minimap
	texture_rect = TextureRect.new()
	texture_rect.size = minimap_size
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.position = Vector2.ZERO
	
	# Add border if enabled
	if show_border:
		add_border()
	
	# Add to scene tree
	add_child(viewport)
	viewport.add_child(minimap_cam)
	add_child(texture_rect)
	
	# Connect the viewport texture to the TextureRect
	texture_rect.texture = viewport.get_texture()

func add_border():
	var border = ColorRect.new()
	border.color = Color.WHITE
	border.size = minimap_size + Vector2i(4, 4)
	border.position = Vector2(-2, -2)
	border.z_index = -1
	add_child(border)
