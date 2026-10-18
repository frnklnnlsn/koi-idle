# growth_chart.gd
# Shop / pond chart: fish growth curves (S-shaped, from GrowthModel), on a log
# mass scale so a fish's starting mass is as visible as its final size.
#
# Two views (tabs in the corner):
#   All        every fish in the current selection, the selected one
#              highlighted. Click a curve to select that fish.
#   This fish  just the selected fish, with a "Now" marker in the pond.
#
# Keeps the old growth_curve methods (set_fish_growth, clear_fish_growth,
# set_progress_marker, ...) so ShopGraphManager and the list view need no
# changes; set_fish_collection() feeds the All view.
class_name GrowthChart
extends KoiChart

signal fish_clicked(fish: fish_conf)

const _DEFAULT := {"base": 5.0, "growth_rate": 0.5, "carrying_capacity": 100.0, "mid_point": 12.0, "hours": -1.0, "mass": -1.0}
const STEPS := 100
## The All view stops here even if a slow grower takes longer.
const MAX_HOURS := 96.0

var _data: Dictionary = _DEFAULT.duplicate()
var _fish: Array = []
var _selected: fish_conf = null
var _all_view := true
var _series_fish: Array = []   # series index -> fish (All view clicks)
var _picked: Array = []   # box-selected fish (UIPalette picked colour)
var _collection_mode := false   # given a collection (shop / fishing), not just one fish (list view)
var _caught: Array = []   # fishing: on the line now (accent)
var _earlier: Array = []  # fishing: caught earlier this session (faded)


# --- Chart definitions (shared by the game and ChartPreview) ----------------

## One fish. data: {"base", "growth_rate", "carrying_capacity", "mid_point",
##        "hours" + "mass" for the "Now" marker (-1 = no marker)}
## Uses GrowthModel (the same curve FishGrowthManager applies), so the chart always matches real growth.
static func draw(p: TauPlot, data: Dictionary) -> void:
	var base: float = maxf(data.get("base", 5.0), 0.0001)
	var hours_now: float = data.get("hours", -1.0)
	var x_max := maxf(grown_hours(data), 1.0)
	if hours_now > 0.0:
		x_max = maxf(x_max, hours_now * 1.05)

	var xs := _hours(x_max)
	var mass := PackedFloat64Array()
	for h in xs:
		mass.append(_mass(data, h))

	var opts := {"y_log": true, "minimal": true, "hover_nearest": false, "colors": [UIPalette.get_palette().accent], "marker_color": UIPalette.get_palette().accent}
	if hours_now >= 0.0:
		opts["markers"] = {"Now": Vector2(hours_now, maxf(data.get("mass", base), base))}
		opts["marker_drops"] = false

	TauCharts.line(p, "Growth", xs, {"Mass": mass}, opts)


## Many fish. data: {"curves": Array of curve dicts (as draw()), "selected": int
## (-1 = none), "picked": Array[int], "caught": Array[int], "earlier": Array[int]}.
## The selected curve is drawn last, in colour; picked (box-selected) curves in
## the palette's picked colour; caught ones (fishing) in the accent colour,
## earlier catches faded.
static func draw_all(p: TauPlot, data: Dictionary, on_click := Callable()) -> void:
	var curves: Array = data.get("curves", [])
	if curves.is_empty():
		p.reset()
		p.title = "No fish selected"
		return
	var selected: int = data.get("selected", -1)
	var picked: Array = data.get("picked", [])
	var caught: Array = data.get("caught", [])
	var earlier: Array = data.get("earlier", [])
	var x_max := 1.0
	for c in curves:
		x_max = maxf(x_max, grown_hours(c))
	x_max = minf(x_max, MAX_HOURS)
	var xs := _hours(x_max)

	var pal := UIPalette.get_palette()
	var series := {}
	var colors := []
	var order := range(curves.size())
	for group in [earlier, picked, caught]:   # each group above the ones before
		for i in group:
			order.erase(i)
			order.append(i)
	if selected >= 0:
		order.erase(selected)
		order.append(selected)   # drawn last = on top
	for i in order:
		var m := PackedFloat64Array()
		for h in xs:
			m.append(_mass(curves[i], h))
		series[str(i + 1)] = m
		var c: Color = pal.chart_line
		if i == selected or i in caught:
			c = pal.accent
		elif i in picked:
			c = pal.picked
		elif i in earlier:
			c = pal.chart_caught_earlier
		colors.append(c)

	var opts := {"y_log": true, "minimal": true, "colors": colors, "hover_nearest": true}
	if on_click.is_valid():
		opts["on_click"] = on_click
	TauCharts.line(p, "Growth · all fish", xs, series, opts)


## Hours until the curve is ~99% grown.
static func grown_hours(c: Dictionary) -> float:
	var r: float = maxf(c.get("growth_rate", 0.5), 0.0001)
	var mp: float = c.get("mid_point", 12.0)
	return maxf((mp + log(99.0) / r) * 1.05, mp * 1.5)


static func _hours(x_max: float) -> PackedFloat64Array:
	var xs := PackedFloat64Array()
	for i in STEPS + 1:
		xs.append(x_max * i / STEPS)
	return xs


static func _mass(c: Dictionary, h: float) -> float:
	var base: float = maxf(c.get("base", 5.0), 0.0001)
	var k: float = maxf(float(c.get("carrying_capacity", 100.0)), base * 1.0001)
	return GrowthModel.mass_at(base, k, maxf(c.get("growth_rate", 0.5), 0.0001), c.get("mid_point", 12.0), h)


static func sample_data() -> Dictionary:
	return {"base": 6.0, "growth_rate": 0.5, "carrying_capacity": 450, "mid_point": 20.0, "hours": 14.0, "mass": 40.0}


static func data_for(fish) -> Dictionary:
	return {
		# Fish not yet in the pond haven't recorded a base; their mass is it.
		"base": fish.y_start if fish.y_start > 0.0 else fish.mass,
		"growth_rate": fish.growth_rate,
		"carrying_capacity": fish.carrying_capacity,
		"mid_point": fish.mid_point,
		"hours": -1.0,
		"mass": -1.0,
	}


# --- Shop API ------------------------------------------------------------------

func _ready() -> void:
	add_tabs(PackedStringArray(["All", "This fish"]), _on_view)
	_redraw()


## The fish shown in the All view (e.g. the shop's current batch).
func set_fish_collection(fish_array: Array) -> void:
	_collection_mode = true
	_fish = fish_array.filter(func(f): return f is fish_conf)
	_redraw()


## Fishing: fish on the line now (accent colour) and fish caught earlier this
## session (UIPalette chart_caught_earlier, faded). Earlier fish have left the
## pond, so the fishing panel adds them to the collection too.
func set_caught(on_line: Array, earlier: Array) -> void:
	if on_line == _caught and earlier == _earlier:
		return
	_caught = on_line.duplicate()
	_earlier = earlier.duplicate()
	_redraw()


## Box selection: show these fish as picked.
func set_picked(fish: Array) -> void:
	if fish == _picked:
		return
	_picked = fish.duplicate()
	_redraw()


func set_fish_growth(fish_res) -> void:
	_selected = fish_res
	_data = data_for(fish_res) if fish_res else _DEFAULT.duplicate()
	_redraw()


func clear_fish_growth() -> void:
	_selected = null
	_data = _DEFAULT.duplicate()
	_redraw()


## Show a dot at the fish's current mass (pond view).
func set_progress_marker(fish_res) -> void:
	if fish_res:
		_data["hours"] = fish_res.age * FishGrowthManager.TIME_SCALE / 3600.0
		_data["mass"] = fish_res.mass
		_redraw()


func clear_progress_marker() -> void:
	_data["hours"] = -1.0
	_data["mass"] = -1.0
	_redraw()


func _on_view(i: int) -> void:
	_all_view = i == 0
	_redraw()


func _redraw() -> void:
	if not plot:
		return
	# No collection given (e.g. the list view): always the single-fish view,
	# without tabs. Nothing at all (an empty shop): an empty chart the same
	# size as the others, so the tabs keep their space but aren't shown.
	var empty := _collection_mode and _fish.is_empty()
	if _tab_row:
		_tab_row.visible = not _fish.is_empty() or empty
		_tab_row.modulate.a = 0.0 if empty else 1.0
		for b in _tab_buttons:
			b.disabled = empty
	if empty:
		plot.reset()
		plot.title = "No fish selected"
	elif _all_view and not _fish.is_empty():
		var curves := []
		_series_fish = _fish.duplicate()
		for f in _fish:
			curves.append(data_for(f))
		var picked := []
		for i in _fish.size():
			if _fish[i] in _picked:
				picked.append(i)
		var caught := []
		var earlier := []
		for i in _fish.size():
			if _fish[i] in _caught:
				caught.append(i)
			elif _fish[i] in _earlier:
				earlier.append(i)
		draw_all(plot, {"curves": curves, "selected": _fish.find(_selected), "picked": picked,
			"caught": caught, "earlier": earlier}, _on_plot_clicked)
	else:
		draw(plot, _data)


func _on_plot_clicked(hits: Array) -> void:
	if hits.is_empty() or not _all_view:
		return
	var best = hits[0]
	for h in hits:
		if h.distance_px < best.distance_px:
			best = h
	var i := int(best.series_name) - 1   # series are named "1", "2", ...
	if i >= 0 and i < _series_fish.size():
		fish_clicked.emit.call_deferred(_series_fish[i])
