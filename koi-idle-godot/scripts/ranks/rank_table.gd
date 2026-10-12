# rank_table.gd
# The list of every fish rank, lowest first. Index in this list = rank number.
class_name RankTable
extends Resource

@export var ranks: Array[FishRank] = []

## Coins paid per gram when a caught fish is kept (fishing strength).
@export var coins_per_gram: float = 10.0
