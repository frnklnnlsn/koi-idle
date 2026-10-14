# economy_knobs.gd
# The few numbers the Economy tab generates every rank from. Saved next to the
# rank table (economy_knobs.tres) so the tool remembers your settings.
class_name EconomyKnobs
extends Resource

@export_group("Ranks")
## How many ranks to generate.
@export_range(2, 30) var rank_count: int = 6
## Average income per second of a rank 0 fish (sets the scale of everything).
@export var rank0_income: float = 17.5
## Price of a rank 0 fish.
@export var rank0_cost: int = 1
## Each rank's fish earn this many times the previous rank's.
@export var income_growth: float = 4.0
## Width of every rank's bell curves (income, starting size, growth
## potential), as a share of the average: 0.25 = most fish within ±25%.
## Each rank's own spreads can be changed in the rank table afterwards.
@export_range(0.0, 1.0, 0.01) var roll_spread: float = 0.25

@export_group("Pacing targets (passive income)")
## Minutes from the first rank 0 fish to the first rank 1 fish.
@export var first_rank_minutes: float = 2.0
## Each later rank takes this many times longer to reach than the one before.
@export var time_growth: float = 2.0
## Per-rank stretch of the target gap (index = rank). 1 = on the curve,
## 2 = this rank takes twice as long to reach, 0.5 = half.
@export var stretch: PackedFloat32Array = PackedFloat32Array()

@export_group("Fishing")
## How much faster you want a fishing player to reach the top rank than a
## passive one (2 = in half the time). The Economy tab shows the speed-up the
## simulation actually gets next to this target; tune catch return and bait
## per upgrade to close the gap.
@export var fishing_speedup: float = 2.0
## What a kept fish pays relative to its price: 1.0 = an average fish at its
## starting mass pays back exactly what it cost (more if bigger or grown).
@export var catch_return: float = 1.0
## Share of new fish that are fast growers (see the rank table's Pond growth).
@export_range(0.0, 1.0, 0.005) var fast_grower_chance: float = 0.05
## Bite time for rank 0 as (min, max) seconds; each rank multiplies it.
@export var bite_base: Vector2 = Vector2(1.0, 2.0)
@export var bite_growth: float = 1.25

@export_group("Simulated player")
## How often the simulated player goes fishing, in minutes.
@export var fish_every_minutes: float = 5.0
## Pond hours per real second in the simulation. Keep 1.0 for real pacing
## (the game's FishGrowthManager.TIME_SCALE is a separate, debug-speed value).
@export var pond_time_scale: float = 1.0
## Share of the toilet the player must be able to restock with a better rank
## before flushing.
@export_range(0.05, 1.0, 0.05) var restock_fraction: float = 0.25
## Bait flush: each time the fishing player upgrades, after flushing its
## earners it buys this many rank 0 fish and flushes them straight into the
## pond, so every fishing chain has a rank 0 to start from. They never take
## an income slot; they only cost their (small) price.
@export_range(0, 100) var bait_per_upgrade: int = 5
## How long the fishing player leaves a fish in the pond before it will catch
## it, in minutes. Longer = bigger fish = bigger payouts, but later.
@export var grow_minutes: float = 0.0


func stretch_for(rank: int) -> float:
	return stretch[rank] if rank < stretch.size() and stretch[rank] > 0.0 else 1.0


## Target seconds from reaching `rank - 1` to reaching `rank` (rank >= 1).
func target_gap(rank: int) -> float:
	return first_rank_minutes * 60.0 * pow(time_growth, rank - 1) * stretch_for(rank)
