# seniority_chart.gd
# Toilet list chart for Old Timers: how each toilet fish's income grows with
# the hours it has worked, a line per fish (rising, then flat at the cap),
# with a dot where each fish is now. The selected fish is drawn in the accent
# colour. The fish list shows it instead of the growth chart for toilet fish
# once Old Timers is owned.
class_name SeniorityChart
extends KoiChart

## Hours shown past the point where the bonus tops out.
@export var extra_hours := 0.25

var _fish: Array = []
var _selected: fish_conf = null


func _ready() -> void:
	_redraw()


## Every toilet fish to draw.
func set_fish_collection(fish: Array) -> void:
	_fish = fish.filter(func(f): return f is fish_conf)
	_redraw()


func set_selected(fish: fish_conf) -> void:
	_selected = fish
	_redraw()


func _redraw_now() -> void:
	if plot == null:
		return
	var pal := UIPalette.get_palette()
	var rate := PassiveSystems.seniority_rate()
	if _fish.is_empty() or rate <= 0.0:
		plot.reset()
		plot.title = "No toilet fish" if rate > 0.0 else "Old Timers not owned"
		return
	var cap := Ranks.table().old_timer_cap
	var cap_hours := cap / rate
	var x_max := cap_hours * (1.0 + extra_hours)
	for f in _fish:
		x_max = maxf(x_max, f.work_time / 3600.0 * 1.05)
	var xs := PackedFloat64Array([0.0, cap_hours, x_max])
	var series := {}
	var colors: Array[Color] = []
	var markers := {}
	# The selected fish last, so its line is on top.
	var order := _fish.duplicate()
	if _selected in order:
		order.erase(_selected)
		order.append(_selected)
	for f in order:
		var base := maxf(Tuning.apply(Tuning.INCOME, f.income), 0.0)
		series[f.ID] = PackedFloat64Array([base, base * (1.0 + cap), base * (1.0 + cap)])
		colors.append(pal.accent if f == _selected else pal.chart_line)
		markers["%s now" % f.ID] = Vector2(f.work_time / 3600.0, PassiveSystems.fish_income(f))
	TauCharts.line(plot, "Income × hours worked", xs, series, {
		"y_log": true, "minimal": true, "hover_nearest": false, "colors": colors,
		"markers": markers, "marker_drops": false, "marker_color": pal.accent,
		"legend": false, "circles": true})
