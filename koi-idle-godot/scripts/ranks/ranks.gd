# ranks.gd
# Read-only access to the rank table from anywhere, including editor previews:
#   Ranks.count()        how many ranks exist
#   Ranks.max_rank()     the highest rank number
#   Ranks.get_rank(2)    the FishRank for rank 2
# To add a rank, add an entry to game_parts/fish_ranks/rank_table.tres.
class_name Ranks
extends RefCounted

const TABLE_PATH := "res://game_parts/fish_ranks/rank_table.tres"

# A static var, not a const: GDScript pre-computes expressions on constants
# when the script compiles, so code reading a const table wouldn't see ranks
# the Economy dev tab applies while the game runs.
static var _table: RankTable = preload("res://game_parts/fish_ranks/rank_table.tres")


## The table itself, for code that edits it (the Economy dev tab).
static func table() -> RankTable:
	return _table


static func count() -> int:
	return _table.ranks.size()


static func max_rank() -> int:
	return _table.ranks.size() - 1


static func get_rank(rank: int) -> FishRank:
	return _table.ranks[clampi(rank, 0, max_rank())]


static func all() -> Array[FishRank]:
	return _table.ranks
