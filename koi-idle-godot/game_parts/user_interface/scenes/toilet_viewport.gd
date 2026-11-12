## class_name Toilet
extends SubViewport

## The fish have swirled down to the drain (near the end of the flush): the
## flush cut scene starts closing in here.
signal flush_draining

## Where the water drains (the dark oval at the top of the bowl), in toilet
## pixels. The fish spiral in to it and the flush water swirls around it.
## If the toilet has a ToiletArea/Underwater/Drain node, its position is used
## instead, so moving or scaling the toilet keeps the drain in the right place.
@export var flush_drain_point:      Vector2 = Vector2(0, -60)
@export var flush_final_radius:     float   = 10.0
@export var flush_duration:         float   = 2.0
@export var flush_hold_duration:    float   = 0.5
@export var flush_stagger_per_frame: int    = 3

@export_group("Flush spiral")
## Which way the water turns: 1 or -1.
@export var flush_spin: float = 1.0
## How steeply fish head in while circling: degrees off the circle at the
## start and at the end of the flush (0 = round and round, 90 = straight in).
@export_range(0.0, 90.0, 1.0) var spiral_inward_start: float = 5.0
@export_range(0.0, 90.0, 1.0) var spiral_inward_end: float = 40.0
## How hard fish are steered along the spiral (their usual is 1.2).
@export var spiral_steer_strength: float = 4.0
## The flush water carries the fish round the drain, speeding up to this
## many turns a second (on top of their own swimming).
@export var swirl_turns_per_second: float = 0.7
## Fish fade out within this distance of the drain.
@export var drain_fade_radius: float = 26.0
## Swirling water over the bowl while flushing (the FlushWater node).
@export var flush_water_fade_in: float = 0.4
## How fast the swirl water turns when the flush starts, as a share of its
## full speed (spin_speed on flush_water.tres); it builds to full speed over
## the flush and stays there while the water calms.
@export_range(0.0, 1.0, 0.01) var swirl_start_speed: float = 0.1
@export_group("Flush button")
## How long the button takes to go down / come back up, and the least time
## it stays down (an empty flush is over at once).
@export var button_press_seconds: float = 0.08
@export var button_release_seconds: float = 0.18
@export var button_min_hold: float = 0.4
@export_group("")
## Keep the water effects (sparkles, underwater bend and light) inside the
## swim area, so the porcelain around the water stays clean.
@export var clip_water_to_swim_area: bool = true

var _display:     FishDisplay
var _is_flushing: bool  = false
var _fish_cache:  Array = []
var _draining_sent := false
var _flush_t := -1.0   # flush progress 0..1 while the spiral runs, else -1
var _swirl_phase := 0.0
var _swirl_speed_k := 0.0   # 0..1 share of the swirl's full speed

## The toilet's own boundary, shared by every toilet fish, built from the
## ToiletArea/SwimShape node (drag / resize it in toilet_area.tscn). The flush
## shrinks this one resource, so all toilet fish follow it.
const _FALLBACK_AREA: SwimArea = preload("res://game_parts/FishComposition/resources/pond_swim_area.tres")
var _base_area: SwimArea
var _swim_area: SwimArea
var _base_avoidance: float = -1.0   # fish's normal avoidance distance, read on first flush

@onready var fish_container_toilet: Node2D = %FishContainerToilet


func _ready() -> void:
	var drain := get_node_or_null("ToiletArea/Underwater/Drain") as Node2D
	if drain:
		flush_drain_point = drain.global_position
	var swim_shape := get_node_or_null("ToiletArea/SwimShape") as SwimShape
	_base_area = swim_shape.make_swim_area() if swim_shape else _FALLBACK_AREA
	_swim_area = _base_area.duplicate()
	# Water layers (WaterSurface sparkles, ToiletArea/Underwater bowl bottom)
	# get the bowl's shape. The full shape, not the one the flush shrinks.
	_base_area.setup_water_layers([get_node_or_null("WaterSurface"), get_node_or_null("ToiletArea/Underwater"),
		get_node_or_null("ToiletArea/Underwater/WaterFloor"),
		get_node_or_null("FlushWater")], clip_water_to_swim_area)
	_set_flush_water(0.0)
	# Every toilet fish gets the toilet's boundary as it's added.
	fish_container_toilet.child_entered_tree.connect(func(n):
		if "swim_area" in n:
			n.swim_area = _swim_area)
	DisplayManager.display_fish_toilet.connect(Display)
	DisplayManager.flush_fish.connect(Flush)
	DisplayManager.toilet_cleared.connect(Clear)

	var factory = FishFactory.new()
	_display    = FishDisplay.new(factory)

	var save_data = SaveManager.load_saved_data()
	if save_data == null:
		push_warning("No save data found.")
		return
	_display.display_all(save_data.list_of_work_fish, fish_container_toilet)
	_rebuild_fish_cache()


func Display(list: Array) -> void:
	if _display == null:
		return
	_display.display_all(list, fish_container_toilet)
	_rebuild_fish_cache()


func _rebuild_fish_cache() -> void:
	_fish_cache.clear()
	for child in fish_container_toilet.get_children():
		if child.is_in_group("fish"):
			_fish_cache.append(child)
			child.swim_area = _swim_area


# ------------------------------------------------------------------ Flush

func Flush() -> void:
	if _is_flushing:
		return
	_is_flushing = true
	_animate_button()
	DisplayManager.is_flushing = true
	await _play_flush_animation()
	Clear()
	_is_flushing = false
	DisplayManager.is_flushing = false   # shared flag: the pond waits on it
	DisplayManager.flush_completed.emit()



## The flush button on the tank (ToiletArea/Underwater/Body), or null.
func flush_button() -> ToiletBody:
	return get_node_or_null("ToiletArea/Underwater/Body") as ToiletBody


## True if the screen point is on the flush button.
func is_over_flush_button(screen_pos: Vector2) -> bool:
	var body := flush_button()
	return body != null and body.is_visible_in_tree() and body.is_over_button(screen_to_world(screen_pos))


## A point on screen, in toilet pixels.
func screen_to_world(screen_pos: Vector2) -> Vector2:
	var c := get_parent() as SubViewportContainer
	var shrink := float(c.stretch_shrink) if c else 1.0
	var local := (c.get_global_transform().affine_inverse() * screen_pos if c else screen_pos) / shrink
	return canvas_transform.affine_inverse() * local


## Push the button in, keep it in while the toilet flushes, let it back up.
func _animate_button() -> void:
	var body := flush_button()
	if body == null:
		return
	var tw := create_tween()
	tw.tween_property(body, "button_press", 1.0, button_press_seconds).set_ease(Tween.EASE_OUT)
	var t0 := Time.get_ticks_msec()
	while _is_flushing:
		await get_tree().process_frame
	var left := button_min_hold - (Time.get_ticks_msec() - t0) / 1000.0
	if left > 0.0:
		await get_tree().create_timer(left).timeout
	if not is_instance_valid(body):
		return
	tw = create_tween()
	tw.tween_property(body, "button_press", 0.0, button_release_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_flush_animation() -> void:
	if _fish_cache.is_empty():
		return

	# ① Stagger forcing fish into FAST_SWIM across frames
	var queued := _fish_cache.duplicate()
	while not queued.is_empty():
		var batch_size := mini(flush_stagger_per_frame, queued.size())
		for i in batch_size:
			var fish = queued.pop_front()
			if is_instance_valid(fish):
				fish.force_state(fish.FishState.FAST_SWIM)
		await get_tree().process_frame
		if not is_inside_tree():   # scene reloaded mid-flush
			return

	# ② Starting values: the toilet's boundary and the fish's avoidance distance
	var start_size: Vector2   = _swim_area.size
	var start_center: Vector2 = _swim_area.center
	if _base_avoidance < 0.0:
		for fish in _fish_cache:
			if is_instance_valid(fish):
				_base_avoidance = fish.boundary_avoidance_distance
				break

	# ③ One tween drives 0→1 progress; each step shrinks the shared boundary
	#    toward the drain and steers every fish along the spiral around it.
	_draining_sent = false
	_swirl_speed_k = swirl_start_speed
	var water := create_tween()
	water.tween_method(_set_flush_water, 0.0, 1.0, flush_water_fade_in)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_apply_flush_progress.bind(start_size, start_center, _base_avoidance),
		0.0, 1.0, flush_duration)
	await tween.finished

	# ④ Hold at final state, the water calming as the last fish go down
	#    (the current keeps its full speed until the flush is over).
	_flush_t = 1.0
	if is_inside_tree():
		var calm := create_tween()
		calm.tween_method(_set_flush_water, 1.0, 0.0, flush_hold_duration + 0.6)
		await get_tree().create_timer(flush_hold_duration).timeout
	_flush_t = -1.0


func _apply_flush_progress(t: float, start_size: Vector2, start_center: Vector2, start_avoidance: float) -> void:
	# Whatever the shape, it shrinks to a small blob at the drain. It stays
	# centred on the bowl at first, so the fish swirl round before being
	# drawn up to the drain.
	_swim_area.size   = start_size.lerp(Vector2.ONE * flush_final_radius, pow(t, 1.4))
	_swim_area.center = start_center.lerp(flush_drain_point, smoothstep(0.35, 1.0, t))
	var a := lerpf(start_avoidance, flush_final_radius * 0.5, t)
	# Spiral: each fish steers around the drain, heading in more steeply as
	# the flush goes on, and fades out as it reaches the drain.
	_flush_t = t
	var inward := deg_to_rad(lerpf(spiral_inward_start, spiral_inward_end, t))
	for fish in _fish_cache:
		if not is_instance_valid(fish):
			continue
		fish.boundary_avoidance_distance = a
		var head: Vector2 = fish.to_global(fish.fish_body.get_point_position(0)) if "fish_body" in fish else fish.global_position
		var d := head - flush_drain_point
		if d.length() > 0.5:
			var around := Vector2(-d.y, d.x).normalized() * flush_spin
			var into := -d.normalized()
			fish.set_follow_direction((around * cos(inward) + into * sin(inward)).normalized())
			fish.get_node("FishSteering").follow_strength = spiral_steer_strength
		if t > 0.4:
			fish.modulate.a = clampf((d.length() - 4.0) / drain_fade_radius, 0.0, 1.0)
	if t >= 0.8 and not _draining_sent:
		_draining_sent = true
		flush_draining.emit()


## The flush current: every fish is carried round the drain, faster as the
## flush builds (their own steering follows the same spiral).
func _process(delta: float) -> void:
	_turn_flush_water(delta)
	if _flush_t < 0.0:
		return
	var turn := TAU * swirl_turns_per_second * smoothstep(0.0, 0.6, _flush_t) * delta * flush_spin
	for fish in _fish_cache:
		if not is_instance_valid(fish):
			continue
		# A fish's node stays put while its body swims, so move the whole
		# fish by however far its head is carried round the drain.
		var head: Vector2 = fish.to_global(fish.fish_body.get_point_position(0)) if "fish_body" in fish else fish.global_position
		var d := head - flush_drain_point
		fish.position += d.rotated(turn) - d


## Turns the swirl water: slow when the flush starts, building to full speed.
func _turn_flush_water(delta: float) -> void:
	var fw := get_node_or_null("FlushWater") as CanvasItem
	if fw == null or not fw.visible or not (fw.material is ShaderMaterial):
		return
	var mat: ShaderMaterial = fw.material
	if _flush_t >= 0.0:
		_swirl_speed_k = lerpf(swirl_start_speed, 1.0, smoothstep(0.0, 1.0, _flush_t))
	var full = mat.get_shader_parameter("spin_speed")
	_swirl_phase += delta * (full if full != null else 6.0) * _swirl_speed_k
	mat.set_shader_parameter("swirl_phase", _swirl_phase)


## How much the flush water shows (0..1).
func _set_flush_water(k: float) -> void:
	var fw := get_node_or_null("FlushWater") as CanvasItem
	if fw and fw.material is ShaderMaterial:
		fw.material.set_shader_parameter("strength", k)
		fw.material.set_shader_parameter("drain", flush_drain_point)
		fw.material.set_shader_parameter("spin", flush_spin)
		fw.visible = k > 0.0


## The drain on screen (for the flush cut scene).
func drain_screen_position() -> Vector2:
	var c := get_parent() as SubViewportContainer
	var shrink := float(c.stretch_shrink) if c else 1.0
	var local := (canvas_transform * flush_drain_point) * shrink
	return c.get_global_transform() * local if c else local


# ------------------------------------------------------------------ Clear

func Clear() -> void:
	for fish in _fish_cache:
		if is_instance_valid(fish):
			fish.queue_free()
	_fish_cache.clear()
	# Reset the boundary so the next batch of toilet fish gets the full bowl.
	_swim_area.size   = _base_area.size
	_swim_area.center = _base_area.center
