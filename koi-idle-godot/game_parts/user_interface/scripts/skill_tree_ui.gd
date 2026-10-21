# skill_tree_ui.gd
# The skill tree screen (skill_tree_ui.tscn), opened with T or the sidebar's
# Skills button. One box per skill from Upgrades.tree, placed on a grid by
# each skill's grid_pos, with lines to the skills it requires and a heading
# over each branch (SkillDef.branch). The panel on the right shows the
# selected skill and buys it.
#
# Layout of the branches: Passive grows to the left from the middle, Active
# to the right; each column further out is the next tier.
#
# Keys (through the command line while this is open):
#   h / l   previous / next skill      0 / $   first / last
#   b       buy a level of the selected skill
class_name SkillTreeUI
extends Control

## Messages for the command line (main_ui connects this).
signal action_message(text: String)

const SKILL_NODE := preload("res://game_parts/user_interface/scenes/skill_node.tscn")

## Space each grid step takes (a box sits in the middle of its cell).
@export var cell_size := Vector2(140, 96)
## Width of the lines between skills.
@export var link_width := 3.0
## Room for the branch headings above the boxes.
@export var header_height := 34.0
## Heading shown over each branch.
@export var branch_titles := {"passive": "Passive", "active": "Active"}
## Font size of the branch headings.
@export var header_font_size := 18

@onready var _canvas: Control = %Canvas
@onready var _points: Label = %PointsLabel
@onready var _title: Label = %SkillTitle
@onready var _level: Label = %SkillLevel
@onready var _description: Label = %Description
@onready var _effect: Label = %Effect
@onready var _requires: Label = %Requires
@onready var _buy: Button = %BuySkill

var _nodes: Array[SkillNodeButton] = []   # in key order (row by row)
var _selected := 0


func _ready() -> void:
	_build()
	_canvas.draw.connect(_draw_links)
	_buy.pressed.connect(func(): _say(_buy_selected()))
	Upgrades.changed.connect(_refresh)
	visibility_changed.connect(func(): if visible: _refresh())
	_refresh()


func _say(text: String) -> void:
	action_message.emit(text)


func _build() -> void:
	var skills: Array = Upgrades.skills().filter(func(s): return s != null)
	skills.sort_custom(func(a, b): return a.grid_pos.y < b.grid_pos.y \
		or (a.grid_pos.y == b.grid_pos.y and a.grid_pos.x < b.grid_pos.x))
	var extent := Vector2i.ZERO
	var columns := {}   # branch -> Vector2i(first column, last column)
	var top := Vector2(0.0, header_height)
	for s in skills:
		var n: SkillNodeButton = SKILL_NODE.instantiate()
		_canvas.add_child(n)
		n.setup(s)
		n.position = top + Vector2(s.grid_pos) * cell_size + (cell_size - n.custom_minimum_size) * 0.5
		n.size = n.custom_minimum_size
		n.picked.connect(_on_picked)
		_nodes.append(n)
		extent = Vector2i(maxi(extent.x, s.grid_pos.x), maxi(extent.y, s.grid_pos.y))
		var c: Vector2i = columns.get(s.branch, Vector2i(s.grid_pos.x, s.grid_pos.x))
		columns[s.branch] = Vector2i(mini(c.x, s.grid_pos.x), maxi(c.y, s.grid_pos.x))
	_canvas.custom_minimum_size = top + Vector2(extent + Vector2i.ONE) * cell_size
	# A heading centred over each branch's columns.
	for b in columns:
		if not branch_titles.has(b):
			continue
		var l := Label.new()
		l.text = branch_titles[b]
		l.theme_type_variation = &"Prompt"
		l.add_theme_font_size_override("font_size", header_font_size)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(columns[b].x * cell_size.x, 0.0)
		l.size = Vector2((columns[b].y - columns[b].x + 1) * cell_size.x, header_height)
		_canvas.add_child(l)


func _refresh() -> void:
	if not is_node_ready():
		return
	_points.text = "%s to spend" % Upgrades.points_text(Progression.points())
	for i in _nodes.size():
		_nodes[i].selected = i == _selected
	_show_selected()
	_canvas.queue_redraw()


func _show_selected() -> void:
	var s := _selected_skill()
	if s == null:
		_title.text = "No skills yet"
		for l in [_level, _description, _effect, _requires]:
			l.text = ""
		_buy.disabled = true
		return
	var lvl := Upgrades.level_of(s)
	var st := Upgrades.state(s)
	_title.text = s.title
	_level.text = "Bought %d of %d" % [lvl, s.max_level]
	_description.text = s.description
	var lines: PackedStringArray = []
	lines.append("Now:  " + (s.effect_text(lvl) if lvl > 0 else "nothing yet"))
	if lvl < s.max_level:
		lines.append("Next: " + s.effect_text(lvl + 1))
	_effect.text = "\n".join(lines)
	_requires.text = "Needs " + Upgrades.missing_text(s) if st == Upgrades.State.LOCKED else ""
	_buy.disabled = st != Upgrades.State.BUYABLE
	_buy.text = "Maxed" if st == Upgrades.State.MAXED \
		else "Buy  (%s)" % Upgrades.points_text(Upgrades.next_cost(s))


func _selected_skill() -> SkillDef:
	return _nodes[_selected].skill if _selected < _nodes.size() else null


func _on_picked(skill: SkillDef) -> void:
	for i in _nodes.size():
		if _nodes[i].skill == skill:
			_selected = i
	_refresh()


func _buy_selected() -> String:
	var s := _selected_skill()
	return Upgrades.buy(s) if s else "No skill selected"


## Lines from each skill to the skills it needs: accent once the needed
## skill is owned, border colour while it isn't. Skills side by side get a
## sideways elbow, skills above / below a downward one.
func _draw_links() -> void:
	var pal := UIPalette.get_palette()
	for n in _nodes:
		for r in n.skill.requires:
			var from := _node_for(r)
			if from == null:
				continue
			var col := pal.accent if Upgrades.level_of(r) > 0 else pal.border
			var fc := from.position + from.size * 0.5
			var tc := n.position + n.size * 0.5
			var pts: PackedVector2Array
			if absf(tc.x - fc.x) > absf(tc.y - fc.y):
				var dir := signf(tc.x - fc.x)
				var a := fc + Vector2(from.size.x * 0.5 * dir, 0.0)
				var b := tc - Vector2(n.size.x * 0.5 * dir, 0.0)
				var mid := (a.x + b.x) * 0.5
				pts = PackedVector2Array([a, Vector2(mid, a.y), Vector2(mid, b.y), b])
			else:
				var dir := signf(tc.y - fc.y)
				var a := fc + Vector2(0.0, from.size.y * 0.5 * dir)
				var b := tc - Vector2(0.0, n.size.y * 0.5 * dir)
				var mid := (a.y + b.y) * 0.5
				pts = PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b])
			_canvas.draw_polyline(pts, col, link_width)


func _node_for(skill: SkillDef) -> SkillNodeButton:
	for n in _nodes:
		if n.skill == skill:
			return n
	return null


# ------------------------------------------------------------------ Keys

## Command line: keys while the tree is open.
func run_command(cmd: Dictionary) -> String:
	if _nodes.is_empty():
		return "No skills yet"
	match cmd["cmd"]:
		"move":
			_selected = clampi(_selected + int(cmd["by"]), 0, _nodes.size() - 1)
		"first":
			_selected = 0
		"last":
			_selected = _nodes.size() - 1
		"buy":
			# "3b" buys up to 3 levels.
			var msg := _buy_selected()
			for i in maxi(int(cmd.get("count", 1)), 1) - 1:
				if Upgrades.state(_selected_skill()) != Upgrades.State.BUYABLE:
					break
				msg = _buy_selected()
			_refresh()
			return msg
		_:
			return "Not in the skill tree (h / l move, b buys, Esc closes)"
	_refresh()
	return ""


func command_status() -> String:
	return "skills · %s · b buys" % Upgrades.points_text(Progression.points())


func command_info() -> String:
	var s := _selected_skill()
	if s == null:
		return ""
	return "%s  %d/%d\n%s" % [s.title, Upgrades.level_of(s), s.max_level, s.description]
