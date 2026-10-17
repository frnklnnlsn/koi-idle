# fish_scatter_chart.gd
# Shop chart: every fish in the current selection as a dot, placed by how rare
# two of its stats are. Right / up = rarer; the middle is average, and the
# top-right corner is great at both. The selected fish is yellow.
# Tabs pick which two stats to compare (the title says which axis is which).
# Clicking a dot selects that fish.
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
var _mode := 0
var _series_fish := {}   # series name -> Array of fish, in point order (for clicks)


# --- Chart definition (shared by the game and ChartPreview) -----------------

## data: {"series": {name: [xs, ys]} in draw order, "colors": Array[Color], "title"}
static func draw(p: TauPlot, data: Dictionary, on_click := Callable()) -> void:
	var series: Dictionary = data.get("series", {})
	if series.is_empty():
		p.reset()
		p.title = "No fish selected"
		return
	var opts := {
		"x_range": Vector2(-REACH, REACH),
		"y_range": Vector2(-REACH, REACH),
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
	_fish = fish_array.filter(func(f): return f is fish_conf)
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


func _redraw() -> void:
	if not plot:
		return
	var mode: Array = MODES[_mode]
	var series := {}
	var colors := []
	_series_fish.clear()
	var others := _fish.filter(func(f): return f != _selected)
	if not others.is_empty():
		var plain := others.filter(func(f): return f not in _picked)
		var picked := others.filter(func(f): return f in _picked)
		if not plain.is_empty():
			_add_series(series, "Fish", plain, mode)
			colors.append(UIPalette.get_palette().chart_mark)
		if not picked.is_empty():
			_add_series(series, "Picked", picked, mode)
			colors.append(UIPalette.get_palette().picked)
	if _selected and _selected in _fish:
		_add_series(series, "Selected", [_selected], mode)   # drawn last, on top
		colors.append(UIPalette.get_palette().accent)
	var title := "%s ↑  %s →" % [STAT_NAMES[mode[2]], STAT_NAMES[mode[1]]]
	draw(plot, {"series": series, "colors": colors, "title": title}, _on_plot_clicked)


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
