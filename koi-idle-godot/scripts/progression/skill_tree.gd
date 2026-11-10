# skill_tree.gd
# The list of skills (game_parts/progression/skill_tree.tres). Add a skill in
# the Inspector: Skills > Add Element > New SkillDef, fill it in, and give it
# a free grid_pos. Lines in the tree screen follow each skill's `requires`.
class_name SkillTree
extends Resource

@export var skills: Array[SkillDef] = []


func find(id: String) -> SkillDef:
	for s in skills:
		if s and s.id == id:
			return s
	return null
