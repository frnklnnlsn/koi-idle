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
## Points per curve. Hovering searches every point of every curve, so with
## many fish fewer points = snappier hover (50 still draws smooth S-curves).
const STEPS := 50
## The All view stops here even if a slow grower takes longer.
const MAX_HOURS := 96.0

var _data: Dictionary = _DEFAULT.duplicate()
var _fish: Array = []
var _selected: fish_conf = null
var _all_view := true
var _series_fish: Array = []   # series index -> fish (All view clicks)
var _picked: Array = []   # box-selected fish (UIPalette picked colour)
var _collection_mode := false   # given a collection (shop / fishing), not just one fish (list view)
## Pond fish shown with a "Now" dot on their curve (their current growth):
## the fish on the fishing line, or the fish picked in the pond list.
var _now_fish: Array = []
var _drawn_now: Array = []     # Vector2(hours, mass) per dot, as last drawn
var _drawn_x_max := 1.0        # hours the x axis spanned when they were drawn
var _caught: Array = []   # fishing: on the line now (accent)
var _earlier: Array = []  # fishing: caught earlier this session (faded)

# Zoom (when `zoomable`): the view in (hours, log10 mass), so zooming up and
# down spreads curves that sit on top of each other. Empty = whole chart.
## Deepest zoom, as a share of the whole chart (0.02 = 50×).
@export_range(0.005, 0.5, 0.005) var min_zoom_share := 0.02
var _view := Rect2()
var _full := Rect2()   # the whole chart, as last drawn


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

	var xs := _xs_for(data, x_max)
	var mass := PackedFloat64Array()
	for h in xs:
		mass.append(_mass(data, h))

	var opts := {"y_log": true, "minimal": true, "hover_nearest": false, "colors": [UIPalette.get_palette().accent], "marker_color": now_color()}
	_apply_view(opts, data)
	if hours_now >= 0.0:
		opts["markers"] = {"Now": Vector2(hours_now, maxf(data.get("mass", base), base))}
		opts["marker_drops"] = false

	TauCharts.line(p, "Growth" + data.get("suffix", ""), xs, {"Mass": mass}, opts)


## Many fish. data: {"curves": Array of curve dicts (as draw()), "selected": int
## (-1 = none), "picked": Array[int], "caught": Array[int], "earlier": Array[int],
## "now": Array of [curve index, hours] (a dot on that curve at that age)}.
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
	var now: Array = data.get("now", [])
	var x_max := all_x_max(curves, now)
	var xs := _xs_for(data, x_max)

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
	_apply_view(opts, data)
	if on_click.is_valid():
		opts["on_click"] = on_click
	# "Now" dots: on the curve at the fish's age (past the axis end: at the end).
	var markers := {}
	for k in now.size():
		var i: int = now[k][0]
		var h := minf(now[k][1], x_max)
		markers["Now %d" % (k + 1)] = Vector2(h, _mass(curves[i], h))
	if not markers.is_empty():
		opts["markers"] = markers
		opts["marker_color"] = now_color()
		opts["marker_drops"] = false
	TauCharts.line(p, "Growth · all fish" + data.get("suffix", ""), xs, series, opts)


## Hours to sample: the zoomed view's span if data has a "view" (Rect2 in
## hours, log10 mass), else 0..x_max.
static func _xs_for(data: Dictionary, x_max: float) -> PackedFloat64Array:
	var view: Rect2 = data.get("view", Rect2())
	if view.size.x <= 0.0:
		return _hours(x_max)
	var xs := PackedFloat64Array()
	var a := maxf(view.position.x, 0.0)
	for i in STEPS + 1:
		xs.append(lerpf(a, maxf(view.end.x, a + 0.001), float(i) / STEPS))
	return xs


## Fixed axis ranges for a zoomed view.
static func _apply_view(opts: Dictionary, data: Dictionary) -> void:
	var view: Rect2 = data.get("view", Rect2())
	if view.size.x <= 0.0:
		return
	opts["x_range"] = Vector2(view.position.x, view.end.x)
	opts["y_range"] = Vector2(pow(10.0, view.position.y), pow(10.0, view.end.y))


## Hours the All view's x axis spans: until the slowest curve is grown (at
## most MAX_HOURS), stretched to fit "Now" dots within that cap.
static func all_x_max(curves: Array, now: Array = []) -> float:
	var x_max := 1.0
	for c in curves:
		x_max = maxf(x_max, grown_hours(c))
	x_max = minf(x_max, MAX_HOURS)
	for n in now:
		x_max = maxf(x_max, minf(float(n[1]) * 1.05, MAX_HOURS))
	return x_max


## Colour of the "Now" dot: the palette's text colour, so it stands out on the
## accent-coloured curve of the selected / caught fish.
static func now_color() -> Color:
	return UIPalette.get_palette().text


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
		"carrying_capacity": FishGrowthManager.max_mass(fish),
		"mid_point": fish.mid_point,
		"hours": -1.0,
		"mass": -1.0,
	}


# --- Shop API ------------------------------------------------------------------

func _ready() -> void:
	add_tabs(PackedStringArray(["All", "This fish"]), _on_view)
	# As fish grow, move their "Now" dots (only redraws if a dot visibly moved).
	var growth := get_node_or_null("/root/FishGrowthManager")
	if growth and not Engine.is_editor_hint():
		growth.growth_updated.connect(_on_growth_tick)
	_redraw()


## The fish shown in the All view (e.g. the shop's current batch).
func set_fish_collection(fish_array: Array) -> void:
	var fish := fish_array.filter(func(f): return f is fish_conf)
	if fish == _fish and _collection_mode and is_node_ready():
		return   # same fish as before (e.g. a growth tick): nothing to redraw
	_collection_mode = true
	_fish = fish
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
	_now_fish = []
	_redraw()


## Show a dot at the fish's current growth (pond list: the picked fish).
func set_progress_marker(fish_res) -> void:
	set_now_fish([fish_res] if fish_res else [])


func clear_progress_marker() -> void:
	set_now_fish([])


## Pond fish to show with a "Now" dot on their curve, in both views (fishing:
## the fish on the line). Fish that aren't in the pond yet get no dot.
func set_now_fish(fish_array: Array) -> void:
	var fish := fish_array.filter(func(f): return f is fish_conf and f.y_start > 0.0)
	if fish == _now_fish and not _now_moved():
		return
	_now_fish = fish
	_redraw()


func _on_growth_tick() -> void:
	if not _now_fish.is_empty() and is_visible_in_tree() and _now_moved():
		_redraw()


## Where a fish's dot goes: Vector2(hours in the pond, mass on its curve).
static func now_point(fish: fish_conf) -> Vector2:
	var h := FishGrowthManager.pond_hours(fish)
	return Vector2(h, _mass(data_for(fish), h))


## Has any dot moved enough to see since it was drawn (1% of the axis, or 2%
## in mass)? Growth ticks every few seconds; redrawing a chart for an
## invisible move would only make it blink.
func _now_moved() -> bool:
	if _now_fish.size() != _drawn_now.size():
		return true
	for k in _now_fish.size():
		var a := now_point(_now_fish[k])
		var b: Vector2 = _drawn_now[k]
		if absf(a.x - b.x) > maxf(_drawn_x_max, 1.0) * 0.01:
			return true
		if absf(log(maxf(a.y, 0.0001) / maxf(b.y, 0.0001))) > 0.02:
			return true
	return false


func _on_view(i: int) -> void:
	_all_view = i == 0
	_view = Rect2()   # each view starts zoomed out
	_redraw()


# --- Zoom -----------------------------------------------------------------------

## The whole chart for these curves: Rect2 in (hours, log10 mass).
static func _extent(curves: Array, x_max: float) -> Rect2:
	var lo := INF
	var hi := -INF
	for c in curves:
		lo = minf(lo, _mass(c, 0.0))
		hi = maxf(hi, _mass(c, x_max))
	if not is_finite(lo) or hi <= 0.0:
		return Rect2(0, 0, maxf(x_max, 1.0), 1)
	var y0 := log(maxf(lo, 1e-6)) / log(10.0)
	var y1 := log(maxf(hi, 1e-6)) / log(10.0)
	return Rect2(0.0, y0, maxf(x_max, 1.0), maxf(y1 - y0, 0.1))


func _add_view(d: Dictionary) -> void:
	if _view.size.x <= 0.0:
		return
	d["view"] = _view
	d["suffix"] = "   %.1f×" % (_full.size.x / _view.size.x)


## Screen pixels per hour (x) and per tenfold of mass (y, negative: up).
func _pixels_per_unit() -> Vector2:
	var p0 := TauCharts.data_to_global(plot, 0.0, 1.0)
	var p1 := TauCharts.data_to_global(plot, 1.0, 10.0)
	if not p0.is_finite() or not p1.is_finite() or p1.x == p0.x or p1.y == p0.y:
		return Vector2.ZERO
	return p1 - p0


func _screen_to_view(pos: Vector2) -> Vector2:
	var p0 := TauCharts.data_to_global(plot, 0.0, 1.0)
	var ppu := _pixels_per_unit()
	if ppu == Vector2.ZERO:
		return Vector2.INF
	return (pos - p0) / ppu


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	if _full.size.x <= 0.0:
		return
	var v := _view if _view.size.x > 0.0 else _full
	var at := _screen_to_view(screen_pos)
	if not at.is_finite():
		return
	var new_size := (v.size * factor).clamp(_full.size * min_zoom_share, _full.size)
	var k := new_size / v.size
	_set_view(Rect2(at - (at - v.position) * k, new_size))


func _pan_pixels(relative: Vector2) -> void:
	if _view.size.x <= 0.0:
		return
	var ppu := _pixels_per_unit()
	if ppu == Vector2.ZERO:
		return
	_set_view(Rect2(_view.position - relative / ppu, _view.size))


func _reset_zoom() -> void:
	_set_view(Rect2())


func _set_view(v: Rect2) -> void:
	if v.size.x > 0.0:
		# Stay inside the whole chart; fully zoomed out = no zoom.
		v.position = v.position.clamp(_full.position, _full.end - v.size)
		if v.size.x >= _full.size.x * 0.999 and v.size.y >= _full.size.y * 0.999:
			v = Rect2()
	if v.is_equal_approx(_view):
		return
	_view = v
	_redraw()


func _redraw_now() -> void:
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
		var now := []
		_drawn_now.clear()
		for f in _now_fish:
			var i := _fish.find(f)
			if i >= 0:
				var pt := now_point(f)
				now.append([i, pt.x])
				_drawn_now.append(pt)
		_drawn_x_max = all_x_max(curves, now)
		_full = _extent(curves, _drawn_x_max)
		var d := {"curves": curves, "selected": _fish.find(_selected), "picked": picked,
			"caught": caught, "earlier": earlier, "now": now}
		_add_view(d)
		draw_all(plot, d, _on_plot_clicked)
	else:
		# One fish: the hovered / selected one, else the newest "Now" fish
		# (fishing: the fish just caught), with its dot if it has one.
		var shown: fish_conf = _selected
		var data := _data.duplicate()
		if shown == null and not _now_fish.is_empty():
			shown = _now_fish.back()
			data = data_for(shown)
		_drawn_now.clear()
		if shown != null and shown in _now_fish:
			var pt := now_point(shown)
			data["hours"] = pt.x
			data["mass"] = pt.y
			_drawn_now.append(pt)
			_drawn_x_max = maxf(grown_hours(data), pt.x * 1.05)
		var x_max := maxf(grown_hours(data), 1.0)
		if data.get("hours", -1.0) > 0.0:
			x_max = maxf(x_max, data["hours"] * 1.05)
		_full = _extent([data], x_max)
		_add_view(data)
		draw(plot, data)


func _on_plot_clicked(hits: Array) -> void:
	if hits.is_empty() or not _all_view:
		return
	# Curves are named "1", "2", ...; skip the "Now" dots.
	var best = null
	for h in hits:
		if String(h.series_name).is_valid_int() and (best == null or h.distance_px < best.distance_px):
			best = h
	if best == null:
		return
	var i := int(best.series_name) - 1
	if i >= 0 and i < _series_fish.size():
		fish_clicked.emit.call_deferred(_series_fish[i])
