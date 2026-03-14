# FishGenerator.gd
extends Node

signal new_fish(fish_array: Array)

@onready var fish_res: fish_conf = preload("res://themes/base_fish.tres")

# --- Constants ---
const FISH_BASE_VALUE: float = 0.1
const FISH_BASE_MASS: float = 0.5
const FISH_BASE_INCOME: float = 1.0

const FISH_COST: Array = [1, 100, 1000, 10000]

var selected_pallet: PackedColorArray = PackedColorArray([
	Color(1.0, 0.0, 0.0),   # Red
	Color(0.0, 0.0, 0.0),   # Black
	Color(1.0, 1.0, 1.0),   # White
	Color(1.0, 0.5, 0.0),   # Orange
	Color(0.96, 0.96, 0.86) # Beige
])

# --- Rank ranges [start_value, end_value, peak_position, decay_rate] ---
const RANK_RANGES: Array = [
	[1,   100, 10,  0.8], # Rank 0
	[100, 200, 110, 0.8], # Rank 1
	[200, 300, 310, 0.8], # Rank 2
	[300, 400, 410, 0.8], # Rank 3
]


# --- Public ---

func generate_fish(num: int, rank: int) -> void:
	var fish_array: Array = []

	for i in range(num):
		var value: float = _value_for_rank(rank)
		var fish: fish_conf = _build_fish(value, rank)
		_apply_visuals(fish)
		fish_array.append(fish)

	new_fish.emit(fish_array)


# --- Fish construction ---

func _value_for_rank(rank: int) -> float:
	var distribution: Array = _create_right_skewed_array(RANK_RANGES[rank])
	return distribution[randi_range(0, distribution.size() - 1)]

func _build_fish(value: float, rank: int) -> fish_conf:
	var fish: fish_conf = fish_res.duplicate(true)

	fish.ID = _generate_id(15)
	fish.rank = rank
	fish.cost = FISH_COST[rank]
	fish.value = value * FISH_BASE_VALUE
	fish.mass = value * FISH_BASE_MASS
	fish.income = value * FISH_BASE_INCOME

	fish.growth_rate = _growth_rate()
	fish.carrying_capacity = _carrying_capacity(fish.mass)
	fish.mid_point = _mid_point()
	fish.x_start = _x_start(fish.growth_rate)
	fish.y_start = fish.mass

	return fish


# --- Growth parameters ---

func _growth_rate() -> float:
	return randf_range(0.3, 1.5)

func _mid_point() -> float:
	return randf_range(6.0, 48.0) # hours until 50% of carrying capacity

func _carrying_capacity(mass: float) -> int:
	return int(mass * randi_range(1, 100))

func _x_start(_growth_rate: float) -> float:
	return randf_range(-10.0, -4.0) # starts fish on left/early side of S-curve


# --- Stat distribution ---

func _create_right_skewed_array(rank_array: Array) -> Array:
	var start: int = rank_array[0]
	var end: int = rank_array[1]
	var peak: int = rank_array[2]
	var decay: float = rank_array[3]
	var weighted: Array = []

	for i in range(start, end + 1):
		var weight: int
		if i <= peak:
			var dist: float = peak - i
			weight = int(100 * exp(-pow(dist, 2) / 10.0))
		else:
			var dist: float = i - peak
			weight = int(100 * exp(-decay * dist))

		weight = max(weight, 1)
		for j in range(weight):
			weighted.append(i)

	return weighted


# --- Visuals ---

func _apply_visuals(fish: fish_conf) -> void:
	var num_colors: int = randi_range(1, 5)
	var palette: PackedColorArray = _unique_colors(num_colors, selected_pallet)

	fish.colors = _pick_colors(num_colors, palette)
	fish.offsets = _generate_offsets(num_colors)
	fish.seed = randi_range(-99, 99)
	fish.frequency = randf_range(0.0001, 0.003)
	fish.noise_type_index = 0
	fish.fin_color = fish.colors[randi_range(0, fish.colors.size() - 1)]

func _unique_colors(count: int, palette: PackedColorArray) -> PackedColorArray:
	var shuffled: Array = Array(palette)
	shuffled.shuffle()
	var result: PackedColorArray = PackedColorArray()
	for i in range(min(count, shuffled.size())):
		result.append(shuffled[i])
	return result

func _pick_colors(count: int, palette: PackedColorArray) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray()
	for i in range(count):
		colors.append(palette[randi_range(0, palette.size() - 1)])
	return colors

func _generate_offsets(count: int) -> PackedFloat32Array:
	var offsets: PackedFloat32Array = PackedFloat32Array()
	for i in range(count):
		offsets.append(randf_range(0.0, 1.0))
	return offsets


# --- Utility ---

func _generate_id(length: int = 15) -> String:
	var chars: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var id: String = ""
	rng.randomize()
	for i in range(length):
		id += chars[rng.randi() % chars.length()]
	return id
