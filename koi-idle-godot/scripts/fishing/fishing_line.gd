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
# so climbing never loses what the bait was worth, and longer chains pay off
# more than keeping the same fish one by one.
class_name FishingLine
extends RefCounted

const CHAIN_BONUS: float = 1.5

## Seconds until a bite, as [min, max], indexed by the rank being fished for.
## Short for testing; raise these to make higher ranks take longer.
const BITE_SECONDS: Array[Vector2] = [
	Vector2(1.0, 2.0),   # rank 0
	Vector2(1.5, 3.0),   # rank 1
	Vector2(2.0, 4.0),   # rank 2
	Vector2(2.5, 5.0),   # rank 3
]

const _GEN := preload("res://scripts/Singletons/FishGenerator.gd")

## Coins per gram when a fish is valued. Set from PassiveSystems.fishing_multiplier.
var coins_per_gram: float = 10.0

## Fish on the line, bait first, newest last. Masses are as they were when
## hooked; a fish out of the water stops growing.
var chain: Array = []


static func max_rank() -> int:
	return _GEN.RANK_RANGES.size() - 1


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
	return BITE_SECONDS[clampi(target_rank(), 0, BITE_SECONDS.size() - 1)]


func roll_bite_time() -> float:
	var r := bite_range()
	return randf_range(r.x, r.y)


func hook(fish: fish_conf) -> void:
	chain.append(fish)


func clear() -> void:
	chain.clear()


func worth(fish: fish_conf) -> float:
	return fish.mass * coins_per_gram


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
