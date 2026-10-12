# growth_model.gd
# The pond growth curve as plain maths, with no dependencies, so the growth
# chart, its editor preview and the economy simulator can all use it.
# FishGrowthManager applies it to the real pond fish.
#
#   mass = base + (K - base) * (S(h) - S(0)) / (1 - S(0))
#   S(h) = 1 / (1 + e^(-growth_rate * (h - mid_point)))
class_name GrowthModel
extends RefCounted


## Mass on a fish's curve after `hours` in the pond.
static func mass_at(base: float, k: float, growth_rate: float, mid_point: float, hours: float) -> float:
	if k <= base:
		return base
	var s0 := s(0.0, growth_rate, mid_point)
	var span := maxf(1.0 - s0, 0.000001)
	return base + (k - base) * (s(hours, growth_rate, mid_point) - s0) / span


static func s(hours: float, r: float, mid: float) -> float:
	return 1.0 / (1.0 + exp(-r * (hours - mid)))
