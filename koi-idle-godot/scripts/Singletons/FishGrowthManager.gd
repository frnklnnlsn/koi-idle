# FishGrowthManager.gd
extends Node

signal growth_updated

const UPDATE_INTERVAL: float = 5.0
const MAX_OFFLINE_HOURS: float = 8.0
const DEBUG_TIME_SCALE: float = 3600.0

var _timer: float = 0.0

func _ready() -> void:
	DisplayManager.flush_fish.connect(_on_flush)
	DisplayManager.fish_caught.connect(_on_fish_caught)

func _on_flush() -> void:
	_apply_growth_to_retired_fish(0.0)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		var save_data: SaveData = SaveManager.load_saved_data()
		if save_data and not save_data.list_of_retired_fish.is_empty():
			_apply_growth_to_retired_fish(_timer)
			SaveManager.save_current_data(save_data)
		_timer = 0.0

# --- Core logistic growth formula ---
static func logistic_mass(fish: fish_conf, elapsed_seconds: float) -> float:
	var K: float = float(fish.carrying_capacity)
	var r: float = fish.growth_rate
	var elapsed_hours: float = (elapsed_seconds * DEBUG_TIME_SCALE) / 3600.0
	var x: float = fish.x_start + elapsed_hours - fish.mid_point
	return K / (1.0 + exp(-r * x))

# --- Apply elapsed time growth to all retired fish ---
func _apply_growth_to_retired_fish(extra_seconds: float) -> void:
	var save_data: SaveData = SaveManager.load_saved_data()
	if not save_data:
		return
	if save_data.list_of_retired_fish.is_empty():
		return

	for fish in save_data.list_of_retired_fish:
		if fish is fish_conf:
			fish.age += extra_seconds
			fish.mass = logistic_mass(fish, fish.age)

	SaveManager.save_current_data(save_data)
	growth_updated.emit()

# --- Called on load to apply offline growth ---
func apply_offline_growth() -> void:
	var last_timestamp := SaveManager.load_timestamp()
	if last_timestamp < 1577836800.0:
		return
	var now := Time.get_unix_time_from_system()
	var seconds_away := clampf(now - last_timestamp, 0.0, MAX_OFFLINE_HOURS * 3600.0)
	if seconds_away <= 0.0:
		return
	_apply_growth_to_retired_fish(seconds_away)

func _on_fish_caught(fish_list: Array) -> void:
	var save_data: SaveData = SaveManager.load_saved_data()
	if not save_data:
		return
	var caught_ids = fish_list.map(func(f): return f.ID)
	save_data.list_of_retired_fish = save_data.list_of_retired_fish.filter(
		func(f): return f.ID not in caught_ids
	)
	SaveManager.save_current_data(save_data)
	growth_updated.emit()
