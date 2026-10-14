# fish_stats.gd
# Bell-curve rolls and rarity for fish stats, as plain maths with no
# dependencies, so the generator, charts, labels and the economy simulator
# all share one definition.
#
# Every stat (income, starting mass, growth potential) is rolled the same way:
#
#   z     = a standard bell-curve roll, cut off at ±CLIP_Z
#   value = average × (1 + spread × z)
#
# The rank sets the average and spread; z says how lucky this fish was. z is
# kept on the fish, so its rarity ("top 3% income") can always be shown.
class_name FishStats
extends RefCounted

## Rolls are cut off this many spreads from the average (about 1 fish in 400
## would land further out). Keeps every stat positive while spread <= 0.33.
const CLIP_Z := 3.0
## A stat never drops below this share of its average, even with a huge spread.
const FLOOR := 0.02

const STAT_NAMES := {"income": "income", "mass": "size", "size": "growth"}


static func roll_z(rng: RandomNumberGenerator) -> float:
	return clampf(rng.randfn(0.0, 1.0), -CLIP_Z, CLIP_Z)


static func value_from_z(avg: float, spread: float, z: float) -> float:
	return maxf(avg * (1.0 + maxf(spread, 0.0) * z), avg * FLOOR)


## Share of fish (0..1) that roll at or below z.
static func cdf(z: float) -> float:
	return 0.5 * (1.0 + _erf(z / sqrt(2.0)))


## "Top X%": the percentage of fish that roll at least this well.
## z = 0 (average) -> 50, z = 2.33 -> 1.
static func top_percent(z: float) -> float:
	return (1.0 - cdf(z)) * 100.0


## Short rarity label: "top 1%", "top 12%", "average", "bottom 5%".
static func rarity_label(z: float) -> String:
	var top := top_percent(z)
	if top > 40.0 and top < 60.0:
		return "average"
	if top <= 50.0:
		return "top %s%%" % _pct(top)
	return "bottom %s%%" % _pct(100.0 - top)


## True when a roll is in the top `percent` (default the top 1%).
static func is_top(z: float, percent: float = 1.0) -> bool:
	return top_percent(z) <= percent


## Bell-curve height at z (peak 1.0), for drawing.
static func density(z: float) -> float:
	return exp(-0.5 * z * z)


static func _pct(p: float) -> String:
	if p < 1.0:
		return "%.1f" % maxf(p, 0.1)
	return str(roundi(p))


# Abramowitz & Stegun 7.1.26, accurate to about 1e-7.
static func _erf(x: float) -> float:
	var s := signf(x)
	x = absf(x)
	var t := 1.0 / (1.0 + 0.3275911 * x)
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
	return s * y


# --- Combined rarity -------------------------------------------------------------

## Overall luck across all three stats as one bell-curve score: the average
## of the three z's, rescaled so it's a standard bell again. A fish that's good
## at everything scores highest; one great stat with two poor ones is average.
static func combined_z(income_z: float, mass_z: float, size_z: float) -> float:
	return (income_z + mass_z + size_z) / sqrt(3.0)


static func fish_combined_z(fish) -> float:
	return combined_z(fish.income_z, fish.mass_z, fish.size_z)


## Rarity tiers by combined score, rarest first: [name, top %, colour].
const TIERS := [
	["Legendary", 1.0, Color(1.0, 0.78, 0.2)],
	["Epic", 5.0, Color(0.7, 0.4, 0.95)],
	["Rare", 15.0, Color(0.3, 0.55, 1.0)],
	["Uncommon", 35.0, Color(0.35, 0.8, 0.45)],
	["Common", 100.0, Color(0.6, 0.6, 0.6)],
]


## Index into TIERS for a combined score (0 = Legendary).
static func tier_index(cz: float) -> int:
	var top := top_percent(cz)
	for i in TIERS.size():
		if top <= TIERS[i][1]:
			return i
	return TIERS.size() - 1


static func tier_name(cz: float) -> String:
	return TIERS[tier_index(cz)][0]


static func tier_color(cz: float) -> Color:
	return TIERS[tier_index(cz)][2]
