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
# Sources so far: Upgrades (the skill tree). Next: the prestige level.
#
# Knobs (where the game reads them):
#   price             fish price (FishGenerator, shop, rank meter, fishing)
#   income            every fish's income (PassiveSystems.income_rate / fish_income)
#   bite_time         fishing bite times (FishingLine.bite_range)
#   growth_speed      how fast pond fish age (FishGrowthManager)
#   growth_potential  how far above its start every fish can grow
#                     (FishGrowthManager.max_mass)
#   toilet_capacity   toilet slots (FishHandler.capacity)
#   shop_pool         shop buy pool size (Ranks.pool_size)
#   recycle_fee       share kept back on recycling (PassiveSystems)
#   pond_sale_rate    share Sell Pond pays (FishingLine)
#   offline_income    money earned while the game is closed (PassiveSystems)
#   offline_growth    pond growth while the game is closed (FishGrowthManager)
#   start_mass        a new fish's starting mass (FishGenerator)
#   chain_bonus       fishing chain snowball, normally 1.5 (FishingLine)
#   swift_ladder      strength of the pay bonus for chains faster than par,
#                     0 = off (FishingLine.speed_multiplier, Swift Ladder)
#   instant_bites     after a Keep, ranks this close to the last chain's top
#                     bite instantly: 1 = up to 3 below, 2 = 2 below, 3 = 1
#                     below; 0 = off (FishingLine.hungry_reach, Hungry Bait)
#   old_timers        income bonus per hour a toilet fish has worked (0.01 =
#                     +1%/h, up to RankTable.old_timer_cap) (PassiveSystems)
#   full_house        income bonus while the toilet is full (0.1 = +10%)
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
const OFFLINE_INCOME := "offline_income"
const OFFLINE_GROWTH := "offline_growth"
const START_MASS := "start_mass"
const CHAIN_BONUS := "chain_bonus"
const SWIFT_LADDER := "swift_ladder"
const INSTANT_BITES := "instant_bites"
const OLD_TIMERS := "old_timers"
const FULL_HOUSE := "full_house"

## Every knob, for pickers in the Inspector (SkillDef.knob uses the same list).
const KNOBS := [PRICE, INCOME, BITE_TIME, GROWTH_SPEED, GROWTH_POTENTIAL,
	TOILET_CAPACITY, SHOP_POOL, RECYCLE_FEE, POND_SALE_RATE,
	OFFLINE_INCOME, OFFLINE_GROWTH, START_MASS, CHAIN_BONUS, SWIFT_LADDER, INSTANT_BITES,
	OLD_TIMERS, FULL_HOUSE]
## How each knob is named to the player.
const LABELS := {
	PRICE: "Fish price",
	INCOME: "Income",
	BITE_TIME: "Bite time",
	GROWTH_SPEED: "Pond growth speed",
	GROWTH_POTENTIAL: "Max fish size",
	TOILET_CAPACITY: "Toilet capacity",
	SHOP_POOL: "Shop pool size",
	RECYCLE_FEE: "Recycle fee",
	POND_SALE_RATE: "Pond sale rate",
	OFFLINE_INCOME: "Income while away",
	OFFLINE_GROWTH: "Pond growth while away",
	START_MASS: "New fish weight",
	CHAIN_BONUS: "Chain bonus",
	SWIFT_LADDER: "Fast chain bonus",
	INSTANT_BITES: "Instant bites",
	OLD_TIMERS: "Seniority",
	FULL_HOUSE: "Full toilet income",
}
## Knobs that are shares (0..1): an extra on these shows as percentage points.
const SHARES := [RECYCLE_FEE, POND_SALE_RATE]

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


## A change in words, e.g. "Toilet capacity +5", "Recycle fee -50%".
static func describe(knob: String, mod: Vector2) -> String:
	# Knobs that count steps read better in words.
	if knob == INSTANT_BITES:
		var n := roundi(mod.x)
		if n <= 0:
			return "No instant bites"
		return "After a Keep, ranks up to %d below your last top bite instantly" % maxi(4 - n, 1)
	if knob == OLD_TIMERS:
		return "Toilet fish earn +%s%% more per hour worked (up to +%d%%)" % [
			_num(mod.x * mod.y * 100.0), roundi(Ranks.table().old_timer_cap * 100.0)]
	if knob == FULL_HOUSE:
		return "+%s%% income while the toilet is full" % _num(mod.x * mod.y * 100.0)
	if knob == SWIFT_LADDER:
		return "Chains faster than par pay more (strength %d%%, up to ×%s)" % [
			roundi(mod.x * mod.y * 100.0), _num(Ranks.table().swift_cap)]
	var parts: PackedStringArray = []
	if not is_zero_approx(mod.x):
		var x := mod.x * 100.0 if knob in SHARES else mod.x
		parts.append("%s%s%s" % ["+" if x > 0 else "-", _num(absf(x)), "%" if knob in SHARES else ""])
	if not is_equal_approx(mod.y, 1.0):
		var pct := (mod.y - 1.0) * 100.0
		parts.append("%s%s%%" % ["+" if pct > 0 else "-", _num(absf(pct))])
	if parts.is_empty():
		parts.append("no change")
	return "%s %s" % [LABELS.get(knob, knob), ", ".join(parts)]


static func _num(x: float) -> String:
	return str(snappedf(x, 0.1)).trim_suffix(".0")
