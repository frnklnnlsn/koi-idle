# ranks.gd
# Read-only access to the rank table from anywhere, including editor previews:
#   Ranks.count()        how many ranks exist
#   Ranks.max_rank()     the highest rank number
#   Ranks.get_rank(2)    the FishRank for rank 2
# To add a rank, add an entry to game_parts/fish_ranks/rank_table.tres.
class_name Ranks
extends RefCounted

const TABLE: RankTable = preload("res://game_parts/fish_ranks/rank_table.tres")


static func count() -> int:
	return TABLE.ranks.size()


static func max_rank() -> int:
	return TABLE.ranks.size() - 1


static func get_rank(rank: int) -> FishRank:
	return TABLE.ranks[clampi(rank, 0, max_rank())]


static func all() -> Array[FishRank]:
	return TABLE.ranks
