# tuning.gd
# One place every adjustable gameplay number goes through:
#
#     final = (base + extra) × multiplier
#
# The base is the game's normal value (rank table, constants). Sources add
# extra and multipliers: the current prestige level (levels get harder in
# their own chosen ways) and the skill tree (upgrades push back). With no
# sources, every number is unchanged.
#
# A source is any object with
#     func tuning_modifier(knob: String) -> Vector2   # x = extra, y = multiplier
# registered with Tuning.add_source(). Return Vector2(0, 1) for "no change".
#
# Knobs (where the game reads them):
#   price             fish price (FishGenerator, shop, rank meter, fishing)
#   income            a new fish's income (FishGenerator)
#   bite_time         fishing bite times (FishingLine.bite_range)
#   growth_speed      how fast pond fish age (FishGrowthManager)
#   growth_potential  how big a new fish can grow (FishGenerator)
#   toilet_capacity   toilet slots (FishHandler.capacity)
#   shop_pool         shop buy pool size (Ranks.pool_size)
#   recycle_fee       share kept back on recycling (PassiveSystems)
#   pond_sale_rate    share Sell Pond pays (FishingLine)
# To add a knob: pick a name, add a constant below, and read the number
# through Tuning.apply() where the game uses it.
class_name Tuning
extends RefCounted

const PRICE := "price"
const INCOME := "income"
const BITE_TIME := "bite_time"
const GROWTH_SPEED := "growth_speed"
const GROWTH_POTENTIAL := "growth_potential"
const TOILET_CAPACITY := "toilet_capacity"
const SHOP_POOL := "shop_pool"
const RECYCLE_FEE := "recycle_fee"
const POND_SALE_RATE := "pond_sale_rate"

static var _sources: Array = []


static func add_source(source: Object) -> void:
	if source not in _sources:
		_sources.append(source)


static func remove_source(source: Object) -> void:
	_sources.erase(source)


## Total (extra, multiplier) on a knob from every source.
static func modifier(knob: String) -> Vector2:
	var extra := 0.0
	var mult := 1.0
	for s in _sources:
		if is_instance_valid(s) and s.has_method("tuning_modifier"):
			var m: Vector2 = s.tuning_modifier(knob)
			extra += m.x
			mult *= m.y
	return Vector2(extra, mult)


## `base` adjusted by every source.
static func apply(knob: String, base: float) -> float:
	if _sources.is_empty():
		return base
	var m := modifier(knob)
	return (base + m.x) * m.y


## The same, rounded to a whole number (slots, sizes), at least `minimum`.
static func apply_int(knob: String, base: int, minimum: int = 0) -> int:
	return maxi(roundi(apply(knob, float(base))), minimum)


## The same for a share (0..1), kept in range.
static func apply_share(knob: String, base: float) -> float:
	return clampf(apply(knob, base), 0.0, 1.0)
