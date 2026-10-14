# rank_table.gd
# The list of every fish rank, lowest first. Index in this list = rank number.
class_name RankTable
extends Resource

@export var ranks: Array[FishRank] = []

## What a kept fish pays, relative to its shop price. 1.0 = an average fish of
## its rank, caught at its starting mass, pays back exactly what it cost.
## Fish that rolled bigger pay more, smaller ones a little less, and every
## fish pays more as it grows in the pond.
@export var catch_return: float = 1.0

@export_group("Shop")
## Most fish the shop can hold for screening at once (the buy pool).
@export_range(1, 200) var shop_pool_size: int = 20
## Share of the price kept back when you recycle (sell) a fish from the shop.
## 0.1 = you get 90% back.
@export_range(0.0, 1.0, 0.01) var recycle_fee: float = 0.1

@export_group("Pond growth")
## Each fish rolls one of two growth types when it's made.
##
## Normal fish are slow burners: their growth peaks hours or days after they
## enter the pond, but they can end up many times their starting mass.
## Fast growers are the rare exception: their growth peaks almost as soon as
## they hit the pond, so they pay off within minutes, but they top out lower.
## They're the short-term cash cows for fishing.
##
## "Peak hours" is when growth is fastest (mid_point), "rate" how sharp the
## S-curve is (higher = the growth happens over a shorter window, roughly
## 8 / rate hours from start to finish). How big a fish can end up is its
## own roll per rank (FishRank: Growth potential).

## Chance a new fish is a fast grower (0.05 = 1 in 20).
@export_range(0.0, 1.0, 0.005) var fast_grower_chance: float = 0.05
@export var fast_peak_hours: Vector2 = Vector2(0.0, 1.0)
@export var fast_rate: Vector2 = Vector2(2.0, 4.0)
## Fast growers reach this share of the rank's growth potential
## (0.15 × an average 50× = about 7.5×).
@export_range(0.01, 1.0, 0.01) var fast_size_factor: float = 0.15
@export var normal_peak_hours: Vector2 = Vector2(6.0, 48.0)
@export var normal_rate: Vector2 = Vector2(0.3, 1.5)
# Old max-size ranges, replaced by each rank's growth potential roll. Hidden.
@export_storage var fast_max: Vector2i = Vector2i(3, 12)
@export_storage var normal_max: Vector2i = Vector2i(1, 100)
