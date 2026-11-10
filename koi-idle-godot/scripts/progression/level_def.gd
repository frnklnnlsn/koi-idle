# level_def.gd
# One prestige level (game_parts/progression/levels.tres). Each level makes
# some numbers harder (knob_changes) and has a boss: hook a fish weighing at
# least boss_mass and Cast turns into "Challenge the boss". Catching the boss
# starts the next level: money and fish are wiped, skill points come back.
class_name LevelDef
extends Resource

@export var title: String = ""

## How this level changes the game's numbers (e.g. bite_time × 1.25). They
## stack with skills through Tuning.
@export var knob_changes: Array[KnobChange] = []

@export_group("Boss")
## Hook a fish at least this heavy (grams) to challenge the boss.
## 0 = no boss (the last level, for now).
@export var boss_mass: float = 0.0
@export var boss: BossDef

@export_group("Start")
## Starting money: enough for this many rank 0 fish at this level's price.
@export_range(1, 50) var starter_fish: int = 5


func has_boss() -> bool:
	return boss_mass > 0.0 and boss != null


## (extra, multiplier) this level puts on `knob`.
func modifier(knob: String) -> Vector2:
	var extra := 0.0
	var mult := 1.0
	for c in knob_changes:
		if c and c.knob == knob:
			extra += c.extra
			mult *= c.multiplier
	return Vector2(extra, mult)
