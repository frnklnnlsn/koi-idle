# skill_node.gd
# One box in the skill tree screen (skill_node.tscn): title, level and cost.
# Change its size and fonts in skill_node.tscn; the frame colours follow the
# UI palette and the state of the skill:
#   maxed        keep green
#   owned        accent
#   buyable      bright border
#   too costly   dim cost
#   locked       faded (locked_alpha)
class_name SkillNodeButton
extends Button

## Clicked: the tree screen selects it.
signal picked(skill: SkillDef)

@export var border_width := 1
## Frame width of the selected box.
@export var selected_border_width := 3
## How much lighter the box gets under the mouse.
@export_range(0.0, 0.5, 0.01) var hover_lighten := 0.08
## How see-through a locked skill is (1 = not at all).
@export_range(0.0, 1.0, 0.05) var locked_alpha := 0.45

var skill: SkillDef
var selected := false:
	set(v):
		selected = v
		refresh()

@onready var _title: Label = %Title
@onready var _level: Label = %Level
@onready var _cost: Label = %Cost


func _ready() -> void:
	pressed.connect(func(): picked.emit(skill))
	refresh()


func setup(s: SkillDef) -> void:
	skill = s
	if is_node_ready():
		refresh()


func refresh() -> void:
	if skill == null or not is_node_ready():
		return
	var pal := UIPalette.get_palette()
	var st := Upgrades.state(skill)
	var lvl := Upgrades.level_of(skill)
	_title.text = skill.title
	_level.text = "%d / %d" % [lvl, skill.max_level]
	_cost.text = "MAX" if st == Upgrades.State.MAXED else Upgrades.points_text(Upgrades.next_cost(skill))
	_cost.modulate = pal.text_dim if st == Upgrades.State.TOO_EXPENSIVE else Color.WHITE
	var edge := pal.border
	if st == Upgrades.State.MAXED:
		edge = pal.keep
	elif lvl > 0:
		edge = pal.accent
	elif st == Upgrades.State.BUYABLE:
		edge = pal.text_dim
	if selected:
		edge = edge.lightened(0.3) if lvl > 0 else pal.accent
	var w := selected_border_width if selected else border_width
	var hover := pal.panel.lightened(hover_lighten)
	add_theme_stylebox_override("normal", UIPalette._box(pal.panel, edge, w, 4, 6))
	add_theme_stylebox_override("hover", UIPalette._box(hover, edge, w, 4, 6))
	add_theme_stylebox_override("pressed", UIPalette._box(hover, edge, w, 4, 6))
	add_theme_stylebox_override("hover_pressed", UIPalette._box(hover, edge, w, 4, 6))
	modulate.a = locked_alpha if st == Upgrades.State.LOCKED else 1.0
	tooltip_text = "%s\n%s" % [skill.title, skill.description]
