# collection_chart.gd
# Shop chart: one bar per fish in the current selection, sorted by the stat
# picked in the corner tabs: income, starting size or max size.
# Hovering a fish card highlights its bar; clicking a bar emits bar_clicked.
# Replaces SandBox/graph_test/histogram.gd and keeps its methods and signal.
class_name CollectionChart
extends KoiChart

signal bar_clicked(fish_resource: fish_conf, bar_index: int)


## Shown above the bars. Set per scene in the Inspector (e.g. "Selected fish"
## in the shop, "Pond fish" in a list). Empty = name the current stat.
@export var chart_title: String = ""

## [tab label, axis title]
const STATS := [["Income", "Income /s"], ["Size", "Starting mass (g)"], ["Max size", "Max mass (g)"]]

var _fish: Array = []          # fish_conf, as given
var _sorted: Array = []        # fish_conf, sorted by the current stat
var _hovered: fish_conf = null
var _picked: Array = []   # box-selected fish (UIPalette picked colour)
var _stat := 0


# --- Chart definition (shared by the game and ChartPreview) -----------------

## data: {"values": Array[float] sorted ascending, "highlight": int (-1 = none),
##        "picked": Array[int] (box-selected bars), "title": String (optional)}
## Highlighted and picked bars are drawn as their own stacked series so they
## can be coloured.
static func draw(p: TauPlot, data: Dictionary, on_click := Callable()) -> void:
	var values: Array = data.get("values", [])
	if values.is_empty():
		p.reset()
		p.title = "No fish selected"
		return

	var highlight: int = data.get("highlight", -1)
	var labels := PackedStringArray()
	var picked_ids: Array = data.get("picked", [])
	var others := []
	var boxed := []
	var picked := []
	for i in values.size():
		labels.append(str(i + 1))
		var kind := 2 if i == highlight else (1 if i in picked_ids else 0)
		others.append(values[i] if kind == 0 else 0.0)
		boxed.append(values[i] if kind == 1 else 0.0)
		picked.append(values[i] if kind == 2 else 0.0)

	var opts := {
		"y_title": data.get("y_title", "Income /s"),
		"stacked": true,
		"minimal": true,
		"colors": [UIPalette.get_palette().chart_mark, UIPalette.get_palette().picked, UIPalette.get_palette().accent],
	}
	if on_click.is_valid():
		opts["on_click"] = on_click
	TauCharts.bar(p, data.get("title", "Fish by value"), labels, {"Fish": others, "Picked": boxed, "Hovered": picked}, opts)


static func sample_data() -> Dictionary:
	return {"values": [0.4, 0.9, 1.1, 1.3, 1.6, 2.4, 3.8], "highlight": 4}


# --- Shop API (same names as the old histogram) ------------------------------

func _ready() -> void:
	var names := PackedStringArray()
	for s in STATS:
		names.append(s[0])
	add_tabs(names, _on_stat)
	_redraw()


func set_fish_collection(fish_array: Array) -> void:
	_fish = fish_array.filter(func(f): return f is fish_conf)
	_sort()
	_redraw()


func add_fish_to_histogram(fish_res: fish_conf) -> void:
	if fish_res:
		set_fish_collection(_fish + [fish_res])


func clear_histogram() -> void:
	_fish.clear()
	_sorted.clear()
	_hovered = null
	_redraw()


func set_fish_card_hover(fish_res: fish_conf) -> void:
	_hovered = fish_res
	_redraw()


func clear_fish_card_hover() -> void:
	_hovered = null
	_redraw()


## Box selection: show these fish as picked.
func set_picked(fish: Array) -> void:
	if fish == _picked:
		return
	_picked = fish.duplicate()
	_redraw()


## Fish whose bar touches `rect` (screen coordinates).
func fish_in_rect(rect: Rect2) -> Array:
	var out := []
	for i in _sorted.size():
		if rect.intersects(TauCharts.bar_global_rect(plot, i, stat_value(_sorted[i], _stat))):
			out.append(_sorted[i])
	return out


func get_hovered_fish() -> fish_conf:
	return _hovered


## The value a fish shows for stat tab `stat`.
static func stat_value(f: fish_conf, stat: int) -> float:
	match stat:
		1: return f.y_start if f.y_start > 0.0 else f.mass   # starting mass
		2: return f.carrying_capacity                         # max mass
		_: return f.income


func _on_stat(i: int) -> void:
	_stat = i
	_sort()
	_redraw()


func _sort() -> void:
	_sorted = _fish.duplicate()
	_sorted.sort_custom(func(a, b): return stat_value(a, _stat) < stat_value(b, _stat))


func _redraw() -> void:
	if not plot:
		return
	var values := []
	for f in _sorted:
		values.append(stat_value(f, _stat))
	var title := chart_title if chart_title != "" else "By " + String(STATS[_stat][0]).to_lower()
	var picked := []
	for i in _sorted.size():
		if _sorted[i] in _picked:
			picked.append(i)
	draw(plot, {"values": values, "highlight": _sorted.find(_hovered), "picked": picked, "title": title,
		"y_title": STATS[_stat][1]}, _on_plot_clicked)


func _on_plot_clicked(hits: Array) -> void:
	if hits.is_empty():
		return
	var i: int = hits[0].sample_index
	if i >= 0 and i < _sorted.size():
		# Deferred: the shop redraws this chart in response, and rebuilding a
		# TauPlot from inside its own click signal breaks TauPlot mid-click.
		bar_clicked.emit.call_deferred(_sorted[i], i)
