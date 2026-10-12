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

## The toilet's own boundary, shared by every toilet fish. The flush shrinks
## this one resource, so all toilet fish follow it without touching the pond's.
const _BASE_AREA: SwimArea = preload("res://game_parts/FishComposition/resources/pond_swim_area.tres")
var _swim_area: SwimArea = _BASE_AREA.duplicate()
var _base_avoidance: float = -1.0   # fish's normal avoidance distance, read on first flush

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
			child.swim_area = _swim_area


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
				fish.force_state(fish.FishState.FAST_SWIM)
		await get_tree().process_frame

	# ② Starting values: the toilet's boundary and the fish's avoidance distance
	var start_radius: float   = _swim_area.size.x
	var start_center: Vector2 = _swim_area.center
	if _base_avoidance < 0.0:
		for fish in _fish_cache:
			if is_instance_valid(fish):
				_base_avoidance = fish.boundary_avoidance_distance
				break

	# ③ One tween drives 0→1 progress; each step shrinks the shared boundary
	#    toward the drain, so every fish follows in sync.
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_apply_flush_progress.bind(start_radius, start_center, _base_avoidance),
		0.0, 1.0, flush_duration)
	await tween.finished

	# ④ Hold at final state
	await get_tree().create_timer(flush_hold_duration).timeout


func _apply_flush_progress(t: float, start_radius: float, start_center: Vector2, start_avoidance: float) -> void:
	_swim_area.size   = Vector2.ONE * lerpf(start_radius, flush_final_radius, t)
	_swim_area.center = start_center.lerp(flush_drain_point, t)
	var a := lerpf(start_avoidance, flush_final_radius * 0.5, t)
	for fish in _fish_cache:
		if is_instance_valid(fish):
			fish.boundary_avoidance_distance = a


# ------------------------------------------------------------------ Clear

func Clear() -> void:
	for fish in _fish_cache:
		if is_instance_valid(fish):
			fish.queue_free()
	_fish_cache.clear()
	# Reset the boundary so the next batch of toilet fish gets the full bowl.
	_swim_area.size   = _BASE_AREA.size
	_swim_area.center = _BASE_AREA.center
