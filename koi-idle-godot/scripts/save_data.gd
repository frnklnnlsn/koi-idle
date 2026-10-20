# SaveData.gd
extends Resource
class_name SaveData

## Bump when the save layout changes, so old saves can be upgraded on load.
const CURRENT_VERSION := 1

@export var save_version: int = CURRENT_VERSION
@export var list_of_work_fish: Array
@export var list_of_retired_fish: Array
@export var list_of_shop_fish: Array
@export var income: float
@export var net_worth: float

### progression (skill points; kept across prestige)
## Prestige level (0 = the first). Prestige comes later; per-level milestones
## are remembered per level.
@export var level: int = 0
## Skill points not spent yet.
@export var skill_points: int = 0
## Every skill point ever earned.
@export var points_earned: int = 0
## Milestones already earned (keys from Progression).
@export var claimed_milestones: PackedStringArray = PackedStringArray()
## False on saves from before skill points: Progression then credits the
## ranks already owned, once.
@export var progression_started: bool = false
