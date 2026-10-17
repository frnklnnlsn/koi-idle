# koi_chart.gd
# Base for koi-idle's charts. Holds the TauPlot reference and fixes one
# TauPlot quirk: a plot measures itself when it is built, so a chart built
# while hidden (the shop and list start hidden) is laid out at the wrong size
# and shows squashed or blank until something rebuilds it. Re-measuring
# whenever the chart becomes visible fixes that.
class_name KoiChart
extends MarginContainer

# Colours come from UIPalette (ui_palette.tres): picked = box-selected fish,
# accent = the selected / hovered one, chart_mark / chart_line = the rest.

@onready var plot: TauPlot = $Plot


var _tab_buttons: Array[Button] = []
var _tab_row: HBoxContainer


## A small row of toggle buttons above the chart, right-aligned, for charts
## with several views. Calls on_change(index) when the view changes.
func add_tabs(names: PackedStringArray, on_change: Callable, start := 0) -> void:
	# Stack the buttons above the plot instead of over its title.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 2)
	column.add_child(row)
	plot.reparent(column, false)
	plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_row = row
	var group := ButtonGroup.new()
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == start
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(func(): on_change.call(i))
		row.add_child(b)
		_tab_buttons.append(b)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and plot:
		# Deferred so Godot has finished sizing the newly shown containers.
		plot.queue_refresh.call_deferred()
