# skill_def.gd
# One skill in the skill tree (game_parts/progression/skill_tree.tres). Edit
# skills there in the Inspector: each one changes one Tuning knob, a step per
# level bought.
#
#   effect at level n = (extra_per_level × n, mult_per_level ^ n)
#
# e.g. income, mult 1.05                 -> +5%, +10.3%, +15.8% (each level
#                                           multiplies again)
#      toilet_capacity, extra 5          -> +5, +10, +15 slots
class_name SkillDef
extends Resource

## Saved name. Don't change it once players own the skill (their levels are
## saved under it).
@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""

@export_group("Effect")
## The number this skill changes (see tuning.gd for where each is used).
@export_enum("price", "income", "bite_time", "growth_speed", "growth_potential",
	"toilet_capacity", "shop_pool", "recycle_fee", "pond_sale_rate",
	"offline_income", "offline_growth", "start_mass", "chain_bonus",
	"swift_ladder", "instant_bites") var knob: String = "income"
## Added per level (slots, seconds...; for shares like recycle_fee, 0.05 = 5%).
@export var extra_per_level: float = 0.0
## Multiplies per level (1 = no change, 0.9 = 10% less each level).
@export var mult_per_level: float = 1.0
@export_range(1, 20) var max_level: int = 1

@export_group("Cost")
## Skill points for the first level.
@export_range(0, 50) var cost: int = 1
## Added to the cost for each level already owned (0 = same cost every level).
@export_range(0, 50) var cost_step: int = 0
## Skills that need at least one level before this one opens.
@export var requires: Array[SkillDef] = []

@export_group("Layout")
## Which branch it belongs to (the tree screen puts a heading over each).
@export_enum("passive", "active", "other") var branch: String = "other"
## Place in the tree: x = column, y = row (row 0 at the top).
@export var grid_pos: Vector2i = Vector2i.ZERO


## Points for the next level when `owned` levels are owned.
func cost_at(owned: int) -> int:
	return cost + cost_step * owned


## (extra, multiplier) on the knob at `level` levels.
func modifier_at(level: int) -> Vector2:
	if level <= 0:
		return Vector2(0.0, 1.0)
	return Vector2(extra_per_level * level, pow(mult_per_level, level))


## The effect at `level` in words, e.g. "Toilet capacity +10".
func effect_text(level: int) -> String:
	return Tuning.describe(knob, modifier_at(level))
