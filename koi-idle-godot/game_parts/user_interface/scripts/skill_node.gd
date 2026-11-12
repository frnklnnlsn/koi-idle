# skill_node.gd
# One box in the skill tree screen (skill_node.tscn): the skill's icon, with
# dots along the bottom for its level (filled = owned). Name, description and
# cost are in the details panel and the tooltip. A skill with no icon shows
# its title instead. Change the size in skill_node.tscn; the colours follow
# the UI palette and the state of the skill:
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
## Level dots: size and gap. Skills with more levels than max_pips show
## "2/10" instead.
@export var pip_size := 6.0
@export var pip_gap := 3.0
@export var max_pips := 6

var skill: SkillDef
var selected := false:
	set(v):
		selected = v
		refresh()

@onready var _icon: TextureRect = %Icon
@onready var _title: Label = %Title


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
	_icon.texture = skill.icon
	_icon.visible = skill.icon != null
	_title.visible = skill.icon == null
	_title.text = skill.title
	# Icon colour: green when maxed, accent once owned, dim when you can't
	# afford the next level yet.
	if st == Upgrades.State.MAXED:
		_icon.modulate = pal.keep.lightened(0.2)
	elif lvl > 0:
		_icon.modulate = pal.accent.lightened(0.15)
	elif st == Upgrades.State.TOO_EXPENSIVE or st == Upgrades.State.LOCKED:
		_icon.modulate = pal.text_dim
	else:
		_icon.modulate = pal.text
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
	var cost := "maxed" if st == Upgrades.State.MAXED else Upgrades.points_text(Upgrades.next_cost(skill))
	tooltip_text = "%s  (%d/%d · %s)\n%s" % [skill.title, lvl, skill.max_level, cost, skill.description]
	queue_redraw()


## Level dots along the bottom edge.
func _draw() -> void:
	if skill == null:
		return
	var pal := UIPalette.get_palette()
	var lvl := Upgrades.level_of(skill)
	var full := pal.keep.lightened(0.2) if lvl >= skill.max_level else pal.accent
	var y := size.y - 6.0 - pip_size * 0.5
	if skill.max_level > max_pips:
		var font := get_theme_default_font()
		var text := "%d/%d" % [lvl, skill.max_level]
		var fs := 10
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) * 0.5, size.y - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, full if lvl > 0 else pal.text_dim)
		return
	var n := skill.max_level
	var total := n * pip_size + (n - 1) * pip_gap
	var x := (size.x - total) * 0.5 + pip_size * 0.5
	for i in n:
		var c := Vector2(x + i * (pip_size + pip_gap), y)
		if i < lvl:
			draw_circle(c, pip_size * 0.5, full)
		else:
			draw_circle(c, pip_size * 0.5, pal.text_dim, false, 1.0)
