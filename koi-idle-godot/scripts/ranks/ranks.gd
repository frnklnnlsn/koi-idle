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


static var _checked := false


## The table itself, for code that edits it (the Economy dev tab).
static func table() -> RankTable:
	_check()
	return _table


static func count() -> int:
	return _table.ranks.size()


static func max_rank() -> int:
	return _table.ranks.size() - 1


static func get_rank(rank: int) -> FishRank:
	_check()
	return _table.ranks[clampi(rank, 0, max_rank())]


static func all() -> Array[FishRank]:
	_check()
	return _table.ranks


## Converts ranks saved before fish stats were split, once (see
## FishRank.migrate_legacy). Uses the old roll scales from FishGenerator.
static func _check() -> void:
	if _checked:
		return
	_checked = true
	var gen: GDScript = load("res://scripts/Singletons/FishGenerator.gd")
	var base_income: float = gen.FISH_BASE_INCOME
	var base_mass: float = gen.FISH_BASE_MASS
	for r in _table.ranks:
		r.migrate_legacy(base_income, base_mass)
