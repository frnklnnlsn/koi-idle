# FishGenerator.gd
extends Node

signal new_fish(fish_array: Array)

@onready var fish_res: fish_conf = preload("res://themes/base_fish.tres")

# --- Constants ---
const FISH_BASE_VALUE: float = 0.1
const FISH_BASE_MASS: float = 0.5
const FISH_BASE_INCOME: float = 1.0
## Wide value ranges are sampled at this many steps (see value_weights).
const VALUE_SAMPLES: float = 100.0

var selected_pallet: PackedColorArray = PackedColorArray([
	Color(1.0, 0.0, 0.0),   # Red
	Color(0.0, 0.0, 0.0),   # Black
	Color(1.0, 1.0, 1.0),   # White
	Color(1.0, 0.5, 0.0),   # Orange
	Color(0.96, 0.96, 0.86) # Beige
])

# Per-rank numbers (cost, value range, odds) live in the rank table:
# game_parts/fish_ranks/rank_table.tres, read through Ranks.


## One random source for every roll, so the economy simulator can replay the
## exact same rules with its own seeded generator.
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


# --- Public ---

func generate_fish(num: int, rank: int) -> void:
	var fish_array: Array = []

	for i in range(num):
		fish_array.append(make_fish(rank))

	new_fish.emit(fish_array)


# --- Fish construction ---

## One complete fish of `rank` (stats and visuals) without emitting anything or
## charging for it. generate_fish() uses it, and so do the dev tools.
func make_fish(rank: int) -> fish_conf:
	var fish: fish_conf = _build_fish(_value_for_rank(rank), rank)
	_apply_visuals(fish)
	return fish


func _value_for_rank(rank: int) -> float:
	return roll_raw(Ranks.get_rank(rank), _rng)

func _build_fish(value: float, rank: int) -> fish_conf:
	var fish: fish_conf = fish_res.duplicate(true)

	fish.ID = _generate_id(15)
	fish.rank = rank
	fish.cost = Ranks.get_rank(rank).cost
	fish.value = value * FISH_BASE_VALUE
	fish.mass = value * FISH_BASE_MASS
	fish.income = value * FISH_BASE_INCOME

	var growth := roll_growth(fish.mass, _rng)
	fish.growth_rate = growth["growth_rate"]
	fish.carrying_capacity = growth["carrying_capacity"]
	fish.mid_point = growth["mid_point"]
	fish.x_start = _x_start(fish.growth_rate)
	fish.y_start = fish.mass

	return fish


# --- Rolls (static, so the economy simulator uses exactly the same rules) ---

## A raw value for a new fish of `rank_def`, picked by the rank's odds.
static func roll_raw(rank_def: FishRank, rng: RandomNumberGenerator) -> int:
	var vw := value_weights(rank_def)
	var weights: PackedInt32Array = vw["weights"]
	var total := 0
	for w in weights:
		total += w
	var ticket := rng.randi_range(0, total - 1)
	for i in weights.size():
		ticket -= weights[i]
		if ticket < 0:
			return vw["values"][i]
	return vw["values"][-1]


## Pond growth stats for a fish of base `mass`.
static func roll_growth(mass: float, rng: RandomNumberGenerator) -> Dictionary:
	return {
		"growth_rate": rng.randf_range(0.3, 1.5),
		# hours after entering the pond when growth is fastest
		"mid_point": rng.randf_range(6.0, 48.0),
		# Always leave room to grow: at least one whole unit above the base mass.
		"carrying_capacity": maxi(int(mass * rng.randi_range(1, 100)), ceili(mass) + 1),
	}

func _x_start(_growth_rate: float) -> float:
	return randf_range(-10.0, -4.0) # starts fish on left/early side of S-curve


# --- Stat distribution ---

func _create_right_skewed_array(rank_def: FishRank) -> Array:
	var vw := value_weights(rank_def)
	var weighted: Array = []
	for k in vw["values"].size():
		for j in range(vw["weights"][k]):
			weighted.append(vw["values"][k])
	return weighted


## Every raw value a rank can roll, and its weight (how many lottery tickets it
## gets). Static so charts can read the real odds without the autoload running,
## e.g. the shop's value chart and its editor preview.
##
## Ranges up to 100 wide are weighed one value at a time. Wider ranges (big
## late-game ranks) are sampled at 101 evenly spaced values with the peak and
## decay measured in those steps, so every rank keeps the same curve shape no
## matter how large its numbers get.
static func value_weights(rank_def: FishRank) -> Dictionary:
	var start: int = rank_def.value_min
	var end: int = maxi(rank_def.value_max, start)
	var decay: float = rank_def.value_decay
	var step := maxf(float(end - start) / VALUE_SAMPLES, 1.0)
	var peak_steps := (rank_def.value_peak - start) / step
	var values := PackedInt32Array()
	var weights := PackedInt32Array()

	var count := int(round((end - start) / step)) + 1
	for j in count:
		var weight: int
		if j <= peak_steps:
			var dist: float = peak_steps - j
			weight = int(100 * exp(-pow(dist, 2) / 10.0))
		else:
			var dist: float = j - peak_steps
			weight = int(100 * exp(-decay * dist))

		values.append(roundi(start + j * step))
		weights.append(max(weight, 1))

	return {"values": values, "weights": weights}


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
