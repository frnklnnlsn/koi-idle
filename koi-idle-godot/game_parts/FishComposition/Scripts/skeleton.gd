#procedural_skeleton.gd
extends Line2D

var rotation_offset := PI / 4 
@onready var koi = $".."
@onready var fish_body = %"fish body"
@export var fish_res: fish_conf

@export var fish_scale: float = 0.05

@export var ellipse_size := Vector2(20, 10)
@export var ellipse_spacing := 5
@export var ellipse_offset1 := 20
@export var ellipse_offset2 := 35

@export var fin_index1: int = 2
@export var fin_index2: int = 4

@export var ellipse_color := Color(1, 0.498039, 0.313726, 1)

# State-specific visual parameters
@export var very_slow_ellipse_size := Vector2(16, 7)
@export var accelerating_ellipse_size := Vector2(19, 9)
@export var slow_ellipse_size := Vector2(20, 10)
@export var fast_ellipse_size := Vector2(24, 12)
@export var decelerating_ellipse_size := Vector2(21, 9)

var time := 0.0

func _ready():
	very_slow_ellipse_size     *= fish_scale
	accelerating_ellipse_size  *= fish_scale
	slow_ellipse_size          *= fish_scale
	fast_ellipse_size          *= fish_scale
	decelerating_ellipse_size  *= fish_scale
	ellipse_size               *= fish_scale
	ellipse_offset1            *= fish_scale
	ellipse_offset2            *= fish_scale
	if koi and koi.fish_res:
		ellipse_color = koi.fish_res.fin_color

func _process(delta):
	time += delta
	var parent = get_parent()
	var num_points = parent.num_points
	update_visuals_for_state()
	queue_redraw()

func update_visuals_for_state():
	if not koi:
		return
	
	var current_state = koi.get_current_state()
	
	match current_state:
		koi.FishState.VERY_SLOW_SWIM:
			ellipse_size = very_slow_ellipse_size
		koi.FishState.ACCELERATING:
			var progress = koi.state_timer / koi.acceleration_duration
			var start_size = very_slow_ellipse_size
			var target_size = slow_ellipse_size if koi.target_state == koi.FishState.SLOW_SWIM else fast_ellipse_size
			ellipse_size = start_size.lerp(target_size, ease_out_quad(progress))
		koi.FishState.SLOW_SWIM:
			ellipse_size = slow_ellipse_size
		koi.FishState.FAST_SWIM:
			ellipse_size = fast_ellipse_size
		koi.FishState.DECELERATING:
			var progress = koi.state_timer / koi.deceleration_duration
			var start_size = fast_ellipse_size if koi.start_speed > 0.6 else slow_ellipse_size
			var target_size = very_slow_ellipse_size if koi.target_state == koi.FishState.VERY_SLOW_SWIM else slow_ellipse_size
			ellipse_size = start_size.lerp(target_size, ease_in_quad(progress))
		koi.FishState.EATING:
			ellipse_size = slow_ellipse_size * 1.1

func _draw():
	var parent = get_parent()
	if parent and "fish_res" in parent and parent.fish_res:
		ellipse_color = parent.fish_res.fin_color
	
	draw_ellipses_at_index(fin_index1, ellipse_offset1)

func draw_ellipses_at_index(index: int, ellipse_offset):
	if index < get_point_count() - 1 and ellipse_offset != null:
		var pos = get_point_position(index)
		var next_pos = get_point_position(index + 1)
		var dir = (next_pos - pos).normalized()
		
		var perp_dir = dir.rotated(PI / 2) * ellipse_offset
		
		var ellipse1_pos = pos + perp_dir
		var ellipse2_pos = pos - perp_dir
		
		var angle1 = dir.angle() + PI / 2 + rotation_offset
		var angle2 = dir.angle() + PI / 1 + rotation_offset
		
		draw_rotated_ellipse(ellipse1_pos, angle2 + PI)
		draw_rotated_ellipse(ellipse2_pos, angle1)

func draw_rotated_ellipse(center: Vector2, angle: float):
	var num_points = 32
	var points = PackedVector2Array()
	
	for i in range(num_points):
		var angle_offset = TAU * i / num_points
		var x = ellipse_size.x * cos(angle_offset)
		var y = ellipse_size.y * sin(angle_offset)
		var rotated_x = x * cos(angle) - y * sin(angle)
		var rotated_y = x * sin(angle) + y * cos(angle)
		points.append(center + Vector2(rotated_x, rotated_y))
	
	draw_colored_polygon(points, ellipse_color)

func ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

func ease_in_quad(t: float) -> float:
	return t * t
