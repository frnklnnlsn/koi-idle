# rank_meter.gd
# The rank picker on the right ShopBar: one bar per rank, stacked upward from
# the cheapest (shortest, at the bottom) to the dearest (longest, at the top).
#   selected rank       filled with the accent colour
#   ranks you can afford  outlined in the accent colour
#   ranks you can't       filled grey
# Click a bar to pick that rank, scroll over it to step up / down, hover for
# the rank's name and price. The meter only reports what was clicked
# (rank_clicked / rank_scrolled); main_ui.gd runs it through the shop's rank
# command, so the same "can't afford" rule applies as for [ ] and :rank N.
#
# Sizes are the exported variables below (Inspector, node ShopBar/Items/
# RankMeter). Colours come from UIPalette (ui_palette.tres).
@tool
class_name RankMeter
extends Control

## A bar was clicked: the rank it stands for.
signal rank_clicked(rank: int)
## The wheel turned over the meter: +1 = up (dearer rank), -1 = down.
signal rank_scrolled(step: int)

enum Align { LEFT, CENTER, RIGHT }

## Thickness of each bar (pixels, top to bottom).
@export_range(1, 20) var bar_thickness: int = 5:
	set(v):
		bar_thickness = v
		_relayout()
## Space between bars.
@export_range(0, 20) var gap: int = 3:
	set(v):
		gap = v
		_relayout()
## Length of the bottom (cheapest) bar.
@export_range(1, 200) var min_length: float = 8.0:
	set(v):
		min_length = v
		queue_redraw()
## Length of the top (dearest) bar. Bars longer than the meter are cut to fit.
@export_range(1, 200) var max_length: float = 26.0:
	set(v):
		max_length = v
		queue_redraw()
## Which side the bars line up against.
@export var align: Align = Align.RIGHT:
	set(v):
		align = v
		queue_redraw()
## Space kept clear at the edges (left/right from the aligned side, and top/bottom).
@export var padding := Vector2(4, 4):
	set(v):
		padding = v
		_relayout()
## Outline width for ranks you can afford.
@export_range(0.5, 4.0, 0.5) var outline_width: float = 1.0:
	set(v):
		outline_width = v
		queue_redraw()
## How strong the grey of ranks you can't afford is (0 = invisible).
@export_range(0.0, 1.0, 0.05) var locked_alpha: float = 0.35:
	set(v):
		locked_alpha = v
		queue_redraw()

## The selected rank (set by main_ui.gd from the shop).
var rank: int = 2:
	set(v):
		if v != rank:
			rank = v
			queue_redraw()
## How many ranks you can afford (set by main_ui.gd from your money).
var affordable: int = 4:
	set(v):
		if v != affordable:
			affordable = v
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Tooltips only show when this isn't empty; _get_tooltip fills in the rank.
	if tooltip_text == "":
		tooltip_text = "Rank"
	_relayout()


func _count() -> int:
	return Ranks.count()


func _relayout() -> void:
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var n := _count()
	var h := n * bar_thickness + maxi(n - 1, 0) * gap + padding.y * 2.0
	return Vector2(0, h)


## The rectangle of rank i's bar (rank 0 at the bottom).
func _bar_rect(i: int) -> Rect2:
	var n := _count()
	var t := float(i) / maxf(n - 1, 1)
	var room := maxf(size.x - padding.x * 2.0, 1.0)
	var length := minf(lerpf(min_length, max_length, t), room)
	var x := padding.x
	match align:
		Align.CENTER:
			x = (size.x - length) / 2.0
		Align.RIGHT:
			x = size.x - padding.x - length
	# Stack centred vertically in whatever height the container gives us.
	var stack := n * bar_thickness + maxi(n - 1, 0) * gap
	var bottom := (size.y + stack) / 2.0
	var y := bottom - (i + 1) * bar_thickness - i * gap
	return Rect2(x, y, length, bar_thickness)


func _draw() -> void:
	var pal := UIPalette.get_palette()
	var locked := Color(pal.text_dim, locked_alpha)
	for i in _count():
		var r := _bar_rect(i)
		if i == rank:
			draw_rect(r, pal.accent)
		elif i < affordable:
			# Inset by half the line so the outline stays inside the bar's box.
			var h := outline_width / 2.0
			draw_rect(r.grow(-h), pal.accent, false, outline_width)
		else:
			draw_rect(r, locked)


## Which bar is under a point, or -1. Each bar's row includes half the gap
## on either side and the full width, so thin bars are easy to hit.
func bar_at(p: Vector2) -> int:
	for i in _count():
		var r := _bar_rect(i)
		if p.y >= r.position.y - gap / 2.0 - 0.5 and p.y <= r.end.y + gap / 2.0 + 0.5:
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			var i := bar_at(mb.position)
			if i >= 0:
				rank_clicked.emit(i)
				accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			rank_scrolled.emit(1)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			rank_scrolled.emit(-1)
			accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var i := bar_at(at_position)
	if i < 0:
		return "Rank: click a bar or scroll"
	var r := Ranks.get_rank(i)
	var note := "" if i < affordable else "  (can't afford yet)"
	return "%s · $%s%s" % [r.display_name, FishLabelDisplay.num(Ranks.price(i)), note]
