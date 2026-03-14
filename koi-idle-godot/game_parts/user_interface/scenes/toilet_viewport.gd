## class_name Toilet
extends SubViewport

@export var flush_drain_point:      Vector2 = Vector2(0, -60)
@export var flush_final_radius:     float   = 10.0
@export var flush_duration:         float   = 2.0
@export var flush_hold_duration:    float   = 0.5
@export var flush_stagger_per_frame: int    = 3

var _display:     FishDisplay
var _is_flushing: bool  = false
var _fish_cache:  Array = []

@onready var fish_container_toilet: Node2D = %FishContainerToilet


func _ready() -> void:
	DisplayManager.display_fish_toilet.connect(Display)
	DisplayManager.flush_fish.connect(Flush)

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


# ------------------------------------------------------------------ Flush

func Flush() -> void:
	if _is_flushing:
		return
	_is_flushing = true
	DisplayManager.is_flushing = true
	await _play_flush_animation()
	Clear()
	_is_flushing = false
	DisplayManager.flush_completed.emit()



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
				fish.state_locked  = true
				fish.current_state = 3
				fish.current_speed = fish.fast_speed
				fish._apply_state_wave_params(3)
		await get_tree().process_frame

	# ② Snapshot starting values from first valid fish
	var first        = _fish_cache[0]
	var start_radius:    float   = first.circle_radius
	var start_center:    Vector2 = first.circle_center
	var start_avoidance: float   = first.boundary_avoidance_distance

	# ③ Use a single tween to drive a 0→1 progress value,
	#    then apply it to all fish each step — keeps everything in sync
	var progress := 0.0
	var tween    := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "flush_final_radius", flush_final_radius, flush_duration)\
		.from(start_radius)  # dummy — we use the step callback below

	# Reset — we'll drive fish props manually via the tween's step signal
	tween.kill()

	# Actually use a method tween so we get a callback each frame
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_apply_flush_progress.bind(start_radius, start_center, start_avoidance),
		0.0, 1.0, flush_duration)

	await tween.finished

	# ④ Hold at final state
	await get_tree().create_timer(flush_hold_duration).timeout


func _apply_flush_progress(t: float, start_radius: float, start_center: Vector2, start_avoidance: float) -> void:
	var r: float   = lerp(start_radius,    flush_final_radius,       t)
	var c: Vector2 = start_center.lerp(flush_drain_point,            t)
	var a: float   = lerp(start_avoidance, flush_final_radius * 0.5, t)

	for fish in _fish_cache:
		if is_instance_valid(fish):
			fish.circle_radius               = r
			fish.circle_center               = c
			fish.boundary_avoidance_distance = a
# ------------------------------------------------------------------ Clear

func Clear() -> void:
	for fish in _fish_cache:
		if is_instance_valid(fish):
			fish.queue_free()
	_fish_cache.clear()
