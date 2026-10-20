# FishGenerator.gd
extends Node

signal new_fish(fish_array: Array)

@onready var fish_res: fish_conf = preload("res://themes/base_fish.tres")

# --- Constants ---
# Fish stats are now rolled per stat from the rank table (FishStats). The three
# FISH_BASE_* scales below are only read once, to convert rank tables saved
# before that change (Ranks._check).
const FISH_BASE_VALUE: float = 0.1
const FISH_BASE_MASS: float = 0.005
const FISH_BASE_INCOME: float = 0.01

var selected_pallet: PackedColorArray = PackedColorArray([
	Color(1.0, 0.0, 0.0),   # Red
	Color(0.0, 0.0, 0.0),   # Black
	Color(1.0, 1.0, 1.0),   # White
	Color(1.0, 0.5, 0.0),   # Orange
	Color(0.96, 0.96, 0.86) # Beige
])

# Per-rank numbers (cost, stat averages and spreads) live in the rank table:
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
	var fish: fish_conf = _build_fish(rank)
	_apply_visuals(fish)
	return fish


func _build_fish(rank: int) -> fish_conf:
	var fish: fish_conf = fish_res.duplicate(true)
	var rank_def := Ranks.get_rank(rank)

	fish.ID = _generate_id(15)
	fish.rank = rank
	fish.cost = Ranks.price(rank)

	var stats := roll_stats(rank_def, _rng)
	# The fish's own income; skills / levels apply on top when paid
	# (PassiveSystems.income_rate), so they reach fish you already own.
	fish.income = stats["income"]
	fish.income_z = stats["income_z"]
	fish.mass = stats["mass"]
	fish.mass_z = stats["mass_z"]
	fish.value = fish.income   # what the shop's value charts sort and show

	var growth := roll_growth(fish.mass, rank_def, _rng)
	fish.growth_rate = growth["growth_rate"]
	# The fish's own max mass; size skills / levels apply on top as it grows
	# (FishGrowthManager.max_mass), so they reach fish already in the pond.
	fish.carrying_capacity = growth["carrying_capacity"]
	fish.mid_point = growth["mid_point"]
	fish.size_z = growth["size_z"]
	fish.x_start = _x_start(fish.growth_rate)
	fish.y_start = fish.mass

	return fish


# --- Rolls (static, so the economy simulator uses exactly the same rules) ---

## Income and starting mass for a new fish of `rank_def`: two independent
## bell-curve rolls (see FishStats). z = how lucky each roll was.
static func roll_stats(rank_def: FishRank, rng: RandomNumberGenerator) -> Dictionary:
	var iz := FishStats.roll_z(rng)
	var mz := FishStats.roll_z(rng)
	return {
		"income": FishStats.value_from_z(rank_def.income_avg, rank_def.income_spread, iz),
		"income_z": iz,
		"mass": FishStats.value_from_z(rank_def.mass_avg, rank_def.mass_spread, mz),
		"mass_z": mz,
	}


## Pond growth for a fish of starting `mass`. Its growth potential (how many
## times its starting mass it can reach) is its own bell-curve roll from the
## rank (size_avg / size_spread). Most fish are slow, big growers; a few
## (table.fast_grower_chance) are fast growers that peak right after entering
## the pond but only reach fast_size_factor of that potential.
## `table` defaults to the game's.
static func roll_growth(mass: float, rank_def: FishRank, rng: RandomNumberGenerator, table: RankTable = null) -> Dictionary:
	if table == null:
		table = Ranks.table()
	var sz := FishStats.roll_z(rng)
	var fast := rng.randf() < table.fast_grower_chance
	var rate: Vector2 = table.fast_rate if fast else table.normal_rate
	var peak: Vector2 = table.fast_peak_hours if fast else table.normal_peak_hours
	var times := FishStats.value_from_z(rank_def.size_avg, rank_def.size_spread, sz)
	if fast:
		times *= table.fast_size_factor
	return {
		"growth_rate": rng.randf_range(rate.x, rate.y),
		# hours after entering the pond when growth is fastest
		"mid_point": rng.randf_range(peak.x, peak.y),
		# Always some room to grow: at least 10% above the starting mass.
		"carrying_capacity": mass * maxf(times, 1.1),
		"size_z": sz,
		"fast": fast,
	}

func _x_start(_growth_rate: float) -> float:
	return randf_range(-10.0, -4.0) # starts fish on left/early side of S-curve




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
