# fishing_line.gd
# The rules of the fishing ladder, kept apart from the UI so they're easy to
# test and tune. The fish on your line is bait for the next rank up:
#
#   empty line   -> only a rank 0 will bite
#   rank 0 on    -> only a rank 1 will bite
#   rank 1 on    -> only a rank 2 will bite ... up to the top rank
#
# Keeping pays once, for the whole chain, with a snowball bonus. The first
# fish is worth its normal value; each fish hooked after it adds its value and
# then the whole lot is multiplied by CHAIN_BONUS:
#
#   value = worth(first)
#   value = (value + worth(next)) * CHAIN_BONUS     for every later catch
#
# A single fish's worth is its shop price, scaled by how heavy it is compared
# with an average fish of its rank at starting mass (see catch_value):
#   worth = price × catch_return × mass / average starting mass of its rank
#
# so climbing never loses what the bait was worth, and longer chains pay off
# more than keeping the same fish one by one.
class_name FishingLine
extends RefCounted

const CHAIN_BONUS: float = 1.5

# Bite times per rank live in the rank table (FishRank.bite_seconds).

## Fail-safe "Sell Pond": every pond fish sold at this fraction of its normal
## worth, so a player stuck without a rank 0 can always turn the pond into cash.
const POND_SALE_RATE: float = 0.5

## Fish on the line, bait first, newest last. Masses are as they were when
## hooked; a fish out of the water stops growing.
var chain: Array = []


static func max_rank() -> int:
	return Ranks.max_rank()


func is_empty() -> bool:
	return chain.is_empty()


func top() -> fish_conf:
	return null if chain.is_empty() else chain[-1]


## The rank that will bite next.
func target_rank() -> int:
	return 0 if chain.is_empty() else chain[-1].rank + 1


## False once the top rank is on the line.
func can_climb() -> bool:
	return target_rank() <= max_rank()


## Pond fish that could bite right now: the target rank, and not already hooked.
func candidates(pond_fish: Array) -> Array:
	var rank := target_rank()
	var on_line := chain.map(func(f): return f.ID)
	return pond_fish.filter(func(f): return f is fish_conf and f.rank == rank and f.ID not in on_line)


func bite_range() -> Vector2:
	var r: Vector2 = Ranks.get_rank(target_rank()).bite_seconds
	return Vector2(Tuning.apply(Tuning.BITE_TIME, r.x), Tuning.apply(Tuning.BITE_TIME, r.y))


func roll_bite_time() -> float:
	var r := bite_range()
	return randf_range(r.x, r.y)


func hook(fish: fish_conf) -> void:
	chain.append(fish)


func clear() -> void:
	chain.clear()


func worth(fish: fish_conf) -> float:
	return catch_value_of(fish)


## What `fish` pays if caught now: like catch_value, but from the price this
## fish was bought at (so a harder level's prices carry through).
static func catch_value_of(fish: fish_conf) -> float:
	var rank_def := Ranks.get_rank(fish.rank)
	var price: float = fish.cost if fish.cost > 0.0 else Ranks.price(fish.rank)
	return price * Ranks.table().catch_return * fish.mass / avg_start_mass(rank_def)


## What a caught fish of `rank_def` weighing `mass` pays when kept on its own.
## An average fish at its starting mass pays price × catch_return.
static func catch_value(rank_def: FishRank, mass: float, catch_return: float) -> float:
	return rank_def.cost * catch_return * mass / avg_start_mass(rank_def)


## The average starting mass of a new fish of `rank_def`.
static func avg_start_mass(rank_def: FishRank) -> float:
	return maxf(rank_def.mass_avg, 0.0001)


## What Keep pays for the whole chain.
func value() -> float:
	var v := 0.0
	for i in chain.size():
		v = worth(chain[i]) if i == 0 else (v + worth(chain[i])) * CHAIN_BONUS
	return v


## What the same fish would be worth kept one at a time (for comparison).
func value_if_separate() -> float:
	var v := 0.0
	for f in chain:
		v += worth(f)
	return v


## What Sell Pond pays for every fish in the pond, after the discount.
func pond_sale_value(pond_fish: Array) -> float:
	var v := 0.0
	for f in pond_fish:
		if f is fish_conf:
			v += worth(f)
	return v * Tuning.apply_share(Tuning.POND_SALE_RATE, POND_SALE_RATE)
