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

@export_group("Value roll")
## Raw value range a new fish rolls in. Sell value = raw × FISH_BASE_VALUE,
## base mass = raw × FISH_BASE_MASS, income = raw × FISH_BASE_INCOME.
@export var value_min: int = 1
@export var value_max: int = 100
## The most likely raw value. Keep it between value_min and value_max.
@export var value_peak: int = 10
## How quickly the odds fall off above the peak. Higher = rarer big rolls.
@export_range(0.01, 5.0, 0.01) var value_decay: float = 0.8

@export_group("Fishing")
## Seconds until a fish of this rank bites, as (min, max).
@export var bite_seconds: Vector2 = Vector2(1.0, 2.0)

@export_group("Look")
## Rank colour for UI (cards, labels, charts). Not used everywhere yet.
@export var color: Color = Color.WHITE
