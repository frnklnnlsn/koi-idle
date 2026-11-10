# Upgrades.gd (autoload "Upgrades")
# The skill tree in play: which skills you own, buying them with skill points
# (Progression), and their effect on the game's numbers. It's a Tuning source:
# every knob a skill changes goes through Tuning.apply(), so the game reads
# upgraded numbers without knowing about skills.
#
# Skills are listed in game_parts/progression/skill_tree.tres. For now the
# only limit is cost (and a skill's `requires`). Prestige will respec for free.
extends Node

## A skill was bought or the tree was reset.
signal changed

const TREE_PATH := "res://game_parts/progression/skill_tree.tres"

## Why a skill can't be bought right now.
enum State { BUYABLE, TOO_EXPENSIVE, LOCKED, MAXED }

var tree: SkillTree


func _ready() -> void:
	tree = load(TREE_PATH) if ResourceLoader.exists(TREE_PATH) else SkillTree.new()
	Tuning.add_source(self)
	SaveManager.save_reset.connect(changed.emit)
	Progression.points_changed.connect(changed.emit.unbind(1))
	_drop_removed_skills()


## A skill taken out of skill_tree.tres can't be refunded on its own (its
## cost is gone), so if the save owns one, respec everything once.
func _drop_removed_skills() -> void:
	for id in SaveManager.load_saved_data().skills.keys():
		if tree.find(id) == null:
			respec()
			return


func skills() -> Array[SkillDef]:
	return tree.skills


func level_of(skill: SkillDef) -> int:
	return int(SaveManager.load_saved_data().skills.get(skill.id, 0))


func is_unlocked(skill: SkillDef) -> bool:
	for r in skill.requires:
		if r and level_of(r) <= 0:
			return false
	return true


func next_cost(skill: SkillDef) -> int:
	return skill.cost_at(level_of(skill))


func state(skill: SkillDef) -> State:
	if level_of(skill) >= skill.max_level:
		return State.MAXED
	if not is_unlocked(skill):
		return State.LOCKED
	if next_cost(skill) > Progression.points():
		return State.TOO_EXPENSIVE
	return State.BUYABLE


## Buys the next level of `skill`. Returns a message for the command line.
func buy(skill: SkillDef) -> String:
	match state(skill):
		State.MAXED:
			return "%s is maxed" % skill.title
		State.LOCKED:
			return "%s needs %s first" % [skill.title, missing_text(skill)]
		State.TOO_EXPENSIVE:
			return "%s costs %s (you have %d)" % [skill.title, points_text(next_cost(skill)), Progression.points()]
	var cost := next_cost(skill)
	if not Progression.spend(cost):
		return "Not enough skill points"
	var sd := SaveManager.load_saved_data()
	var lvl := level_of(skill) + 1
	sd.skills[skill.id] = lvl
	sd.skill_points_spent += cost
	SaveManager.save_current_data(sd)
	changed.emit()
	return "%s %d/%d: %s" % [skill.title, lvl, skill.max_level, skill.effect_text(lvl)]


## Clears every skill and gives the points back. Returns the points refunded.
func respec() -> int:
	var sd := SaveManager.load_saved_data()
	var refund := sd.skill_points_spent
	sd.skills = {}
	sd.skill_points_spent = 0
	SaveManager.save_current_data(sd)
	if refund > 0:
		Progression.refund(refund)
	changed.emit()
	return refund


## "Bigger Bowl and Recycler": the skills `skill` still needs.
func missing_text(skill: SkillDef) -> String:
	var names: PackedStringArray = []
	for r in skill.requires:
		if r and level_of(r) <= 0:
			names.append(r.title)
	return " and ".join(names)


static func points_text(n: int) -> String:
	return "%d point%s" % [n, "" if n == 1 else "s"]


# ------------------------------------------------------------------ Tuning

## Tuning source: the summed effect of owned skills on `knob`.
func tuning_modifier(knob: String) -> Vector2:
	var extra := 0.0
	var mult := 1.0
	var owned: Dictionary = SaveManager.load_saved_data().skills
	if owned.is_empty():
		return Vector2(0.0, 1.0)
	for s in tree.skills:
		if s and s.knob == knob and owned.has(s.id):
			var m := s.modifier_at(int(owned[s.id]))
			extra += m.x
			mult *= m.y
	return Vector2(extra, mult)
