# level_table.gd
# Every prestige level, first to last (game_parts/progression/levels.tres).
class_name LevelTable
extends Resource

@export var levels: Array[LevelDef] = []
