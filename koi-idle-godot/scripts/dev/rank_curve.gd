# rank_curve.gd
# Builds a full set of ranks from EconomyKnobs, and fits rank prices so the
# simulated passive player reaches each rank on the target schedule.
#
# Every rank's value roll has the same shape as rank 0 (rarely low, usually a
# bit above the peak, occasionally a big tail), scaled so its average income is
# rank0_income × income_growth^rank. Prices start from a rough estimate and
# Fit refines them against the simulator.
class_name RankCurve
extends RefCounted

const _GEN := preload("res://scripts/Singletons/FishGenerator.gd")

# Shape of the rank 0 roll relative to its average raw value (17.5):
# min 1, peak 10, max 100.
const MIN_RATIO := 1.0 / 17.5
const PEAK_RATIO := 10.0 / 17.5
const MAX_RATIO := 100.0 / 17.5
const DECAY := 0.8
const START_MONEY := 10.0
const CAPACITY := 20


## Average income per second of a fish of `rank`, as the knobs ask for.
static func target_income(knobs: EconomyKnobs, rank: int) -> float:
	return knobs.rank0_income * pow(knobs.income_growth, rank)


## A fresh set of ranks from the knobs. `previous` (the current table's ranks)
## keeps names and colours where ranks already exist.
static func generate(knobs: EconomyKnobs, previous: Array = []) -> Array[FishRank]:
	var out: Array[FishRank] = []
	for n in knobs.rank_count:
		var r := FishRank.new()
		if n < previous.size():
			r.display_name = previous[n].display_name
			r.color = previous[n].color
		else:
			r.display_name = "Rank %d" % n
			r.color = Color.from_hsv(fmod(0.33 + n * 0.13, 1.0), 0.5, 0.95)
		var avg_raw := target_income(knobs, n) / _GEN.FISH_BASE_INCOME
		r.value_min = maxi(1, roundi(avg_raw * MIN_RATIO))
		r.value_peak = maxi(r.value_min, roundi(avg_raw * PEAK_RATIO))
		r.value_max = maxi(r.value_peak + 1, roundi(avg_raw * MAX_RATIO))
		r.value_decay = DECAY
		r.bite_seconds = knobs.bite_base * pow(knobs.bite_growth, n)
		if n == 0:
			r.cost = knobs.rank0_cost
		else:
			# Rough first guess: half a full toilet of the previous rank,
			# earning for the target gap. Fit() corrects it.
			r.cost = _nice(knobs.target_gap(n) * CAPACITY * target_income(knobs, n - 1) * 0.5)
		out.append(r)
	return out


## A simulator set up from the knobs, for these ranks.
static func make_sim(knobs: EconomyKnobs, ranks: Array) -> EconomySim:
	var sim := EconomySim.new()
	sim.ranks = ranks
	sim.capacity = CAPACITY
	sim.start_money = START_MONEY
	sim.coins_per_gram = knobs.coins_per_gram
	sim.chain_bonus = FishingLine.CHAIN_BONUS
	sim.pond_time_scale = knobs.pond_time_scale
	sim.fish_every_seconds = knobs.fish_every_minutes * 60.0
	sim.restock_fraction = knobs.restock_fraction
	sim.bait_slots = knobs.bait_slots
	var total := 0.0
	for n in range(1, ranks.size()):
		total += knobs.target_gap(n)
	sim.max_seconds = maxf(total * 4.0, 3600.0)
	return sim


## Set prices (rank 1 and up) so the simulated passive player first reaches
## each rank at its target time (the sum of the target gaps up to it). Works
## upward one rank at a time: with the ranks below fixed, a higher price for
## rank n always means reaching it later, so the right price is found by
## halving the search range (~30 quick simulations per rank).
## Changes `ranks` in place. Returns the final passive run.
static func fit(knobs: EconomyKnobs, ranks: Array) -> Dictionary:
	for n in range(1, ranks.size()):
		var target := target_reach(knobs, n)
		# A rank never costs less than the one below it.
		var lo := float(ranks[n - 1].cost) + 1.0
		var hi := maxf(ranks[n].cost, lo) * 1000.0
		for i in 40:
			var mid := sqrt(lo * hi)          # halve the range on a log scale
			ranks[n].cost = maxi(1, roundi(mid))
			if _reach_time(knobs, ranks, n) < target:
				lo = mid
			else:
				hi = mid
			if hi / lo < 1.005:
				break
		ranks[n].cost = _nice(sqrt(lo * hi))
	return make_sim(knobs, ranks).run(false, 1)


## Target seconds from the start of a run to first owning a fish of `rank`.
static func target_reach(knobs: EconomyKnobs, rank: int) -> float:
	var t := 0.0
	for i in range(1, rank + 1):
		t += knobs.target_gap(i)
	return t


## When a passive run first buys rank n (INF if not within a generous limit).
static func _reach_time(knobs: EconomyKnobs, ranks: Array, n: int) -> float:
	var sim := make_sim(knobs, ranks.slice(0, n + 1))
	sim.max_seconds = target_reach(knobs, n) * 6.0 + 60.0
	var t: float = sim.run(false, 1)["reached"][n]
	return INF if t < 0.0 else t


## Rounds a price to 3 significant figures (12,345 -> 12,300).
static func _nice(x: float) -> int:
	if x < 1000.0:
		return maxi(1, roundi(x))
	var mag := pow(10.0, floorf(log(x) / log(10.0)) - 2.0)
	return int(roundf(x / mag) * mag)
