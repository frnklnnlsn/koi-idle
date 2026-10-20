# milestone_def.gd
# One way to earn skill points, edited in game_parts/progression/milestones.tres.
# Each milestone is a "first time X happens" event, so points can't be
# farmed. New kinds of milestone are added to Kind and checked in
# Progression (scripts/Singletons/Progression.gd).
class_name MilestoneDef
extends Resource

enum Kind {
	## The first fish bought of a rank (rank = -1: every rank, one each).
	FIRST_RANK_BOUGHT,
}

## Short unique name, used to remember it was earned (don't change it once
## players have saves).
@export var id: String = ""
## Shown when earned. %d is replaced by the rank for per-rank milestones.
@export var title: String = ""
@export var kind: Kind = Kind.FIRST_RANK_BOUGHT
## Which rank; -1 = every rank counts separately.
@export var rank: int = -1
@export var points: int = 1
## Earned again on every prestige level (true), or once per game (false).
@export var per_level: bool = true
