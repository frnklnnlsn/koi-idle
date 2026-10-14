# fish_rank.gd
# Everything that makes one rank of fish different from another. Edit the
# ranks in game_parts/fish_ranks/rank_table.tres in the Inspector.
class_name FishRank
extends Resource

## Shown in the shop and the fishing panel.
@export var display_name: String = "Rank 0"

@export_group("Shop")
## Price of one fish of this rank.
@export var cost: int = 1

# Every new fish rolls three independent stats, each on its own bell curve:
# most fish land near the rank's average, fewer the further out, and the rare
# best are the "top 1%". Spread = how wide the bell is, as a share of the
# average: 0.25 means about two thirds of fish land within ±25%, 1 in 20
# beyond ±50%. 0 = every fish identical. Rolls stop at 3 spreads either side.

@export_group("Income")
## Average income per second of a fish of this rank (in the toilet).
@export var income_avg: float = -1.0
@export_range(0.0, 1.0, 0.01) var income_spread: float = 0.25

@export_group("Starting size")
## Average starting mass in grams. Catching pays relative to this: an average
## fish caught at its starting mass pays price × catch return.
@export var mass_avg: float = -1.0
@export_range(0.0, 1.0, 0.01) var mass_spread: float = 0.25

@export_group("Growth potential")
## How many times its starting mass a fish can grow to in the pond, on average.
## Fast growers reach a fraction of this (rank table: fast_size_factor).
@export var size_avg: float = -1.0
@export_range(0.0, 1.0, 0.01) var size_spread: float = 0.25

# Old single-roll settings, hidden. Read once to convert older rank tables
# (see migrate_legacy); otherwise unused.
@export_storage var value_min: int = 1
@export_storage var value_max: int = 100
@export_storage var value_peak: int = 50
@export_storage var value_spread: float = 0.25
@export_storage var value_decay: float = 0.8

@export_group("Fishing")
## Seconds until a fish of this rank bites, as (min, max).
@export var bite_seconds: Vector2 = Vector2(1.0, 2.0)

@export_group("Look")
## Rank colour for UI (cards, labels, charts). Not used everywhere yet.
@export var color: Color = Color.WHITE


## Fills in the per-stat averages for a rank saved before stats were split
## (they load as -1). One roll used to set both income and mass:
## income = roll × base_income, mass = roll × base_mass, centred on value_peak.
func migrate_legacy(base_income: float, base_mass: float) -> void:
	if income_avg < 0.0:
		income_avg = value_peak * base_income
		income_spread = value_spread
	if mass_avg < 0.0:
		mass_avg = value_peak * base_mass
		mass_spread = value_spread
	if size_avg < 0.0:
		size_avg = 50.0   # the old 1-100× range averaged about 50×
