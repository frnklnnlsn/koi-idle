# FishGrowthManager.gd
# The one place pond growth happens.
#
# A fish's mass is frozen at its base value until it enters the pond (flush).
# From then on its growth clock (fish.age, real seconds in the pond) runs and
# its mass follows an S-curve that starts exactly at the base mass and levels
# off at carrying_capacity:
#
#   mass = base + (K - base) * (S(h) - S(0)) / (1 - S(0))
#   S(h) = 1 / (1 + e^(-growth_rate * (h - mid_point)))
#
# h is hours in the pond, base is fish.y_start, K is fish.carrying_capacity,
# and mid_point is how many hours after entering the pond growth is fastest.
extends Node

signal growth_updated

const UPDATE_INTERVAL: float = 5.0
const MAX_OFFLINE_HOURS: float = 8.0
## Pond hours per real second. 1.0 = real time, 3600.0 = 1 second is 1 hour (debug).
const TIME_SCALE: float = 1.0

var _timer: float = 0.0


func _ready() -> void:
	DisplayManager.flush_fish.connect(_on_flush)
	DisplayManager.fish_caught.connect(_on_fish_caught)
	apply_offline_growth()


func _on_flush() -> void:
	_apply_growth_to_retired_fish(0.0)   # refresh views with the newly entered fish


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_apply_growth_to_retired_fish(_timer)
		_timer = 0.0


# --- Growth model (static so charts and editor previews can use it) -----------

## Call once when a fish moves into the pond. Freezes its current mass as the
## base of its curve and starts its growth clock.
static func enter_pond(fish: fish_conf) -> void:
	fish.y_start = fish.mass
	fish.age = 0.0
	# Its toilet position means nothing in the pond: it arrives by the pipe.
	fish.swim_heading = Vector2.ZERO
	# A curve needs somewhere to grow to. Old saves can hold fish whose
	# carrying capacity rounded down to (or below) their base mass.
	if fish.carrying_capacity <= fish.y_start:
		fish.carrying_capacity = ceili(fish.y_start) + 1


## Pond hours a fish has been growing.
static func pond_hours(fish: fish_conf) -> float:
	return fish.age * TIME_SCALE / 3600.0


## Mass on a fish's curve after `hours` in the pond (see GrowthModel).
static func mass_at(base: float, k: float, growth_rate: float, mid_point: float, hours: float) -> float:
	return GrowthModel.mass_at(base, k, growth_rate, mid_point, hours)


static func mass_for(fish: fish_conf, hours: float) -> float:
	return GrowthModel.mass_at(fish.y_start, float(fish.carrying_capacity), fish.growth_rate, fish.mid_point, hours)


# --- Ticking ---------------------------------------------------------------

func _apply_growth_to_retired_fish(extra_seconds: float) -> void:
	var save_data: SaveData = SaveManager.load_saved_data()
	if not save_data or save_data.list_of_retired_fish.is_empty():
		return

	# Tuning growth_speed: pond time passes faster or slower (from now on;
	# ages already reached stay as they are).
	var aged := extra_seconds * Tuning.apply(Tuning.GROWTH_SPEED, 1.0)
	for fish in save_data.list_of_retired_fish:
		if fish is fish_conf:
			fish.age += aged
			fish.mass = mass_for(fish, pond_hours(fish))

	SaveManager.save_current_data(save_data)
	growth_updated.emit()


## Growth while the game was closed, capped at MAX_OFFLINE_HOURS of real time.
## Returns the real seconds of growth applied.
func apply_offline_growth() -> float:
	var last_timestamp := SaveManager.load_timestamp()
	if last_timestamp < 1577836800.0:
		return 0.0
	var now := Time.get_unix_time_from_system()
	var seconds_away := clampf(now - last_timestamp, 0.0, MAX_OFFLINE_HOURS * 3600.0)
	if seconds_away <= 0.0:
		return 0.0
	_apply_growth_to_retired_fish(seconds_away)
	return seconds_away


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
