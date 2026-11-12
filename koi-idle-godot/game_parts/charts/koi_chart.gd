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


# --- Zoom and pan (charts that turn on `zoomable`) ----------------------------
# Scroll over the chart to zoom in / out around the mouse, drag with the right
# mouse button to pan, double-click to see everything again. (A plain left
# drag is box selection in the shop.) What zooming means is up to each chart:
# it implements _zoom_at, _pan_pixels and _reset_zoom.
## Zoom with the mouse (scroll / right-drag / double-click).
@export var zoomable := false
## Zoom per scroll step.
@export_range(1.05, 2.0, 0.05) var zoom_step := 1.25
var _panning := false

var _tab_buttons: Array[Button] = []
var _tab_row: HBoxContainer
var _redraw_queued := false


## Asks for the chart to be rebuilt. Rebuilding a TauPlot is expensive and
## leaves it blank for a frame, so however many changes arrive in one frame
## (new fish, highlight, selection...), the chart is rebuilt once, at the end
## of the frame.
func _redraw() -> void:
	if _redraw_queued:
		return
	_redraw_queued = true
	_flush_redraw.call_deferred()


func _flush_redraw() -> void:
	_redraw_queued = false
	if is_inside_tree():
		_redraw_now()


## Builds the chart from its current data. Each chart implements this.
func _redraw_now() -> void:
	pass


func _input(event: InputEvent) -> void:
	if not zoomable or not is_visible_in_tree() or plot == null:
		return
	var mb := event as InputEventMouseButton
	if mb:
		var inside := plot.get_global_rect().has_point(mb.global_position)
		if mb.pressed and inside and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(mb.global_position, 1.0 / zoom_step if mb.button_index == MOUSE_BUTTON_WHEEL_UP else zoom_step)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = mb.pressed and inside
			if inside:
				get_viewport().set_input_as_handled()
		elif mb.pressed and inside and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			_reset_zoom()
	elif event is InputEventMouseMotion and _panning:
		_pan_pixels(event.relative)
		get_viewport().set_input_as_handled()


## Zoom by `factor` (< 1 = in) keeping the point under `screen_pos` still.
func _zoom_at(_screen_pos: Vector2, _factor: float) -> void:
	pass


## Move the view with the mouse by `relative` screen pixels.
func _pan_pixels(_relative: Vector2) -> void:
	pass


## Back to the whole chart.
func _reset_zoom() -> void:
	pass


## The chart's plotting area in screen coordinates (empty before layout).
func pane_rect() -> Rect2:
	return TauCharts.pane_global_rect(plot) if plot else Rect2()


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
