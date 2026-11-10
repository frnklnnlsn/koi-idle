# fish_scatter_chart.gd
# Shop chart: every fish in the current selection as a dot, placed by how rare
# two of its stats are. Right / up = rarer; the middle is average, and the
# top-right corner is great at both. The selected fish is yellow.
# Tabs pick which two stats to compare (the title says which axis is which).
# Clicking a dot selects that fish. Scroll to zoom, right-drag to pan,
# double-click to reset (see "Zoom and pan" below).
#
# Same method names as the old value chart (set_fish / clear_fish_value), plus
# set_fish_collection(), so ShopGraphManager can drive it.
class_name FishScatterChart
extends KoiChart

signal fish_clicked(fish: fish_conf)

## [tab label, x stat, y stat]. Stats: "income", "mass" (starting size),
## "size" (growth potential).
const MODES := [
	["Income × Growth", "size", "income"],
	["Income × Size", "mass", "income"],
	["Size × Growth", "size", "mass"],
]
const STAT_NAMES := {"income": "Income", "mass": "Size", "size": "Growth"}
## Axis reach in spreads either side of average (rolls stop at 3).
const REACH := 3.2

var _fish: Array = []
var _selected: fish_conf = null
var _picked: Array = []   # box-selected fish (UIPalette picked colour)
var _caught: Array = []   # fishing: on the line now (accent)
var _earlier: Array = []  # fishing: caught earlier this session (faded)
var _mode := 0
var _series_fish := {}   # series name -> Array of fish, in point order (for clicks)

# --- Zoom and pan ---------------------------------------------------------------
# Scroll over the chart to zoom in / out around the mouse, drag with the right
# mouse button to pan, double-click to see everything again. (A plain left
# drag is box selection in the shop.)
## Zoom per scroll step.
@export_range(1.05, 2.0, 0.05) var zoom_step := 1.25
## Deepest zoom: the view's width in spreads (full view = 2 × REACH).
@export var min_view_width := 0.25
var _view := Rect2(-REACH, -REACH, 2.0 * REACH, 2.0 * REACH)
var _panning := false


# --- Chart definition (shared by the game and ChartPreview) -----------------

## data: {"series": {name: [xs, ys]} in draw order, "colors": Array[Color], "title",
##        "view": Rect2 (optional; the part of the chart to show)}
static func draw(p: TauPlot, data: Dictionary, on_click := Callable()) -> void:
	var series: Dictionary = data.get("series", {})
	if series.is_empty():
		p.reset()
		p.title = "No fish selected"
		return
	var view: Rect2 = data.get("view", Rect2(-REACH, -REACH, 2.0 * REACH, 2.0 * REACH))
	var opts := {
		"x_range": Vector2(view.position.x, view.end.x),
		"y_range": Vector2(view.position.y, view.end.y),
		"colors": data.get("colors", []),
		"minimal": true,
		"circles": true,
	}
	if on_click.is_valid():
		opts["on_click"] = on_click
	TauCharts.scatter(p, data.get("title", "Rarity"), series, opts)


static func sample_data() -> Dictionary:
	return {
		"series": {"Fish": [[1.2, -0.4, -0.5, 0.3], [0.8, 1.6, 0.2, -1.1]], "Selected": [[0.1], [0.6]]},
		"colors": [UIPalette.get_palette().chart_mark, UIPalette.get_palette().accent],
		"title": "Income ↑  Growth →",
	}


# --- Shop API ------------------------------------------------------------------

func _ready() -> void:
	var names := PackedStringArray()
	for m in MODES:
		names.append(m[0])
	add_tabs(names, _on_mode)
	_redraw()


func set_fish_collection(fish_array: Array) -> void:
	var fish := fish_array.filter(func(f): return f is fish_conf)
	if fish == _fish and is_node_ready():
		return   # same fish as before (e.g. a growth tick): nothing to redraw
	_fish = fish
	_redraw()


## Highlight one fish (the hovered or selected one).
func set_fish(fish: fish_conf) -> void:
	_selected = fish
	_redraw()


func set_fish_value(_value: float) -> void:
	pass   # old API; this chart shows rarity, not one value


func clear_fish_value() -> void:
	_selected = null
	_redraw()


func _on_mode(i: int) -> void:
	_mode = i
	_redraw()


func _redraw_now() -> void:
	if not plot:
		return
	var mode: Array = MODES[_mode]
	var series := {}
	var colors := []
	_series_fish.clear()
	var pal := UIPalette.get_palette()
	var others := _fish.filter(func(f): return f != _selected)
	# Groups in draw order (later = on top): [name, fish, colour].
	var groups := [
		["Fish", others.filter(func(f): return f not in _picked and f not in _caught and f not in _earlier), pal.chart_mark],
		["Earlier", others.filter(func(f): return f in _earlier and f not in _caught and f not in _picked),pal.chart_caught_earlier],
		["Picked", others.filter(func(f): return f in _picked and f not in _caught), pal.picked],
		["Caught", others.filter(func(f): return f in _caught), pal.accent],
	]
	for g in groups:
		if not g[1].is_empty():
			_add_series(series, g[0], g[1], mode)
			colors.append(g[2])
	if _selected and _selected in _fish:
		_add_series(series, "Selected", [_selected], mode)   # drawn last, on top
		colors.append(UIPalette.get_palette().accent)
	var title := "%s ↑  %s →" % [STAT_NAMES[mode[2]], STAT_NAMES[mode[1]]]
	var zoom := 2.0 * REACH / _view.size.x
	if zoom > 1.01:
		title += "   %.1f×" % zoom
	draw(plot, {"series": series, "colors": colors, "title": title, "view": _view}, _on_plot_clicked)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or plot == null:
		return
	var mb := event as InputEventMouseButton
	if mb:
		var inside := plot.get_global_rect().has_point(mb.global_position)
		if mb.pressed and inside and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var f := 1.0 / zoom_step if mb.button_index == MOUSE_BUTTON_WHEEL_UP else zoom_step
			zoom_at(mb.global_position, f)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = mb.pressed and inside
			if inside:
				get_viewport().set_input_as_handled()
		elif mb.pressed and inside and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			reset_view()
	elif event is InputEventMouseMotion and _panning:
		var scale := _data_per_pixel()
		if scale != Vector2.ZERO:
			_set_view(Rect2(_view.position - event.relative * scale, _view.size))
		get_viewport().set_input_as_handled()


## Zoom by `factor` (< 1 = in) keeping the point under `screen_pos` still.
func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var at := _to_data(screen_pos)
	if not at.is_finite():
		return
	var w := clampf(_view.size.x * factor, min_view_width, 2.0 * REACH)
	var k := w / _view.size.x
	_set_view(Rect2(at - (at - _view.position) * k, _view.size * k))


## Back to the whole chart.
func reset_view() -> void:
	_set_view(Rect2(-REACH, -REACH, 2.0 * REACH, 2.0 * REACH))


func _set_view(v: Rect2) -> void:
	# Stay inside the full chart.
	v.size = v.size.clamp(Vector2.ONE * min_view_width, Vector2.ONE * 2.0 * REACH)
	v.position = v.position.clamp(Vector2.ONE * -REACH, Vector2.ONE * REACH - v.size)
	if v.is_equal_approx(_view):
		return
	_view = v
	_redraw()


## Chart units per screen pixel (y is negative: up the screen = bigger).
func _data_per_pixel() -> Vector2:
	var p0 := TauCharts.data_to_global(plot, 0.0, 0.0)
	var p1 := TauCharts.data_to_global(plot, 1.0, 1.0)
	if not p0.is_finite() or not p1.is_finite() or p1.x == p0.x or p1.y == p0.y:
		return Vector2.ZERO
	return Vector2(1.0 / (p1.x - p0.x), 1.0 / (p1.y - p0.y))


func _to_data(screen_pos: Vector2) -> Vector2:
	var p0 := TauCharts.data_to_global(plot, 0.0, 0.0)
	var scale := _data_per_pixel()
	if scale == Vector2.ZERO:
		return Vector2.INF
	return (screen_pos - p0) * scale


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


## Fish whose dot touches `rect` (screen coordinates).
func fish_in_rect(rect: Rect2) -> Array:
	var mode: Array = MODES[_mode]
	var hit := rect.grow(4.0)   # about a dot's radius
	return _fish.filter(func(f): return hit.has_point(TauCharts.data_to_global(plot, _z(f, mode[1]), _z(f, mode[2]))))


func _add_series(series: Dictionary, name: String, fish: Array, mode: Array) -> void:
	var xs := []
	var ys := []
	for f in fish:
		xs.append(_z(f, mode[1]))
		ys.append(_z(f, mode[2]))
	series[name] = [xs, ys]
	_series_fish[name] = fish


static func _z(f: fish_conf, stat: String) -> float:
	match stat:
		"income": return f.income_z
		"mass": return f.mass_z
		_: return f.size_z


func _on_plot_clicked(hits: Array) -> void:
	if hits.is_empty():
		return
	var fish: Array = _series_fish.get(hits[0].series_name, [])
	var i: int = hits[0].sample_index
	if i >= 0 and i < fish.size():
		# Deferred: the shop redraws this chart in response, which must not
		# happen inside TauPlot's own click handling.
		fish_clicked.emit.call_deferred(fish[i])
