# Progression.gd (autoload "Progression")
# Skill points and the milestones that earn them. Points are kept across
# prestige; per-level milestones (like "first fish of each rank") can be
# earned again on each new level.
#
# Milestones are listed in game_parts/progression/milestones.tres. Checks run
# when things happen (a fish is bought, ...), not every frame.
extends Node

## A skill point was earned (or spent / refunded): new unspent total.
signal points_changed(points: int)
## A milestone was earned. first_ever = the very first point of the game.
signal milestone_earned(title: String, points: int, first_ever: bool)
## Points credited for an older save's progress (shown once).
signal credited_existing(count: int, points: int)

const MILESTONES_PATH := "res://game_parts/progression/milestones.tres"

var _list: MilestoneList


func _ready() -> void:
	_list = load(MILESTONES_PATH) if ResourceLoader.exists(MILESTONES_PATH) else MilestoneList.new()
	FishGenerator.new_fish.connect(_on_fish_bought)
	SaveManager.save_reset.connect(func(): points_changed.emit(points()))
	_credit_older_save.call_deferred()


## Unspent skill points.
func points() -> int:
	return SaveManager.load_saved_data().skill_points


func points_earned() -> int:
	return SaveManager.load_saved_data().points_earned


func level() -> int:
	return SaveManager.load_saved_data().level


## Spend points (the skill tree). False if there aren't enough.
func spend(amount: int) -> bool:
	var sd := SaveManager.load_saved_data()
	if amount > sd.skill_points:
		return false
	sd.skill_points -= amount
	SaveManager.save_current_data(sd)
	points_changed.emit(sd.skill_points)
	return true


## Give points back (respec).
func refund(amount: int) -> void:
	var sd := SaveManager.load_saved_data()
	sd.skill_points += amount
	SaveManager.save_current_data(sd)
	points_changed.emit(sd.skill_points)


func is_claimed(key: String) -> bool:
	return key in SaveManager.load_saved_data().claimed_milestones


## Every milestone, for a list of goals: [{title, points, claimed}].
func overview() -> Array:
	var out := []
	for m in _list.milestones:
		if m.kind == MilestoneDef.Kind.FIRST_RANK_BOUGHT and m.rank < 0:
			for r in Ranks.count():
				out.append({"title": _title(m, r), "points": m.points, "claimed": is_claimed(_key(m, r))})
		else:
			out.append({"title": _title(m, m.rank), "points": m.points, "claimed": is_claimed(_key(m, m.rank))})
	return out


# ------------------------------------------------------------------ Earning

func _on_fish_bought(fish_array: Array) -> void:
	for f in fish_array:
		if f is fish_conf:
			_check_rank_bought(f.rank, false)


func _check_rank_bought(rank: int, quiet: bool) -> int:
	var earned := 0
	for m in _list.milestones:
		if m.kind == MilestoneDef.Kind.FIRST_RANK_BOUGHT and (m.rank < 0 or m.rank == rank):
			earned += _claim(m, rank, quiet)
	return earned


## Earns `m` (for `rank`) if it isn't yet. Returns the points given.
func _claim(m: MilestoneDef, rank: int, quiet: bool) -> int:
	var key := _key(m, rank)
	var sd := SaveManager.load_saved_data()
	if key in sd.claimed_milestones:
		return 0
	var first_ever := sd.points_earned == 0
	sd.claimed_milestones.append(key)
	sd.skill_points += m.points
	sd.points_earned += m.points
	SaveManager.save_current_data(sd)
	if not quiet:
		milestone_earned.emit(_title(m, rank), m.points, first_ever)
		points_changed.emit(sd.skill_points)
	return m.points


## The saved name of a milestone: per-level ones include the level.
func _key(m: MilestoneDef, rank: int) -> String:
	var k := m.id
	if m.rank < 0:
		k += ":r%d" % rank
	if m.per_level:
		k += "@L%d" % level()
	return k


func _title(m: MilestoneDef, rank: int) -> String:
	return m.title % rank if "%d" in m.title else m.title


## Saves from before skill points: credit the ranks already owned, once.
func _credit_older_save() -> void:
	var sd := SaveManager.load_saved_data()
	if sd.progression_started:
		return
	var ranks := {}
	for list in [sd.list_of_shop_fish, sd.list_of_work_fish, sd.list_of_retired_fish]:
		for f in list:
			if f is fish_conf:
				ranks[f.rank] = true
	var count := 0
	var pts := 0
	for r in ranks.keys():
		var got := _check_rank_bought(r, true)
		if got > 0:
			count += 1
			pts += got
	sd = SaveManager.load_saved_data()
	sd.progression_started = true
	SaveManager.save_current_data(sd)
	if pts > 0:
		points_changed.emit(sd.skill_points)
		credited_existing.emit(count, pts)
