# collection_chart.gd
# Shop chart: one bar per fish in the current selection, sorted by sell value.
# Hovering a fish card highlights its bar; clicking a bar emits bar_clicked.
# Replaces SandBox/graph_test/histogram.gd and keeps its methods and signal.
class_name CollectionChart
extends KoiChart

signal bar_clicked(fish_resource: fish_conf, bar_index: int)

const HIGHLIGHT := Color(1.0, 0.85, 0.2)

## Shown above the bars. Set per scene in the Inspector (e.g. "Selected fish"
## in the shop, "Pond fish" in a list).
@export var chart_title: String = "Fish by value"

var _sorted: Array = []        # fish_conf, sorted by value
var _hovered: fish_conf = null


# --- Chart definition (shared by the game and ChartPreview) -----------------

## data: {"values": Array[float] sorted ascending, "highlight": int (-1 = none),
##        "title": String (optional)}
## The highlighted bar is drawn as its own stacked series so it can be coloured.
static func draw(p: TauPlot, data: Dictionary, on_click := Callable()) -> void:
	var values: Array = data.get("values", [])
	if values.is_empty():
		p.reset()
		p.title = "No fish selected"
		return

	var highlight: int = data.get("highlight", -1)
	var labels := PackedStringArray()
	var others := []
	var picked := []
	for i in values.size():
		labels.append(str(i + 1))
		others.append(0.0 if i == highlight else values[i])
		picked.append(values[i] if i == highlight else 0.0)

	var opts := {
		"y_title": "Sell value",
		"stacked": true,
		"legend": false,
		"colors": [TauXYStyle.DEFAULT_SERIES_COLOR, HIGHLIGHT],
	}
	if on_click.is_valid():
		opts["on_click"] = on_click
	TauCharts.bar(p, data.get("title", "Fish by value"), labels, {"Fish": others, "Hovered": picked}, opts)


static func sample_data() -> Dictionary:
	return {"values": [0.4, 0.9, 1.1, 1.3, 1.6, 2.4, 3.8], "highlight": 4}


# --- Shop API (same names as the old histogram) ------------------------------

func _ready() -> void:
	_redraw()


func set_fish_collection(fish_array: Array) -> void:
	_sorted = fish_array.filter(func(f): return f is fish_conf)
	_sorted.sort_custom(func(a, b): return a.value < b.value)
	_redraw()


func add_fish_to_histogram(fish_res: fish_conf) -> void:
	if fish_res:
		set_fish_collection(_sorted + [fish_res])


func clear_histogram() -> void:
	_sorted.clear()
	_hovered = null
	_redraw()


func set_fish_card_hover(fish_res: fish_conf) -> void:
	_hovered = fish_res
	_redraw()


func clear_fish_card_hover() -> void:
	_hovered = null
	_redraw()


func get_hovered_fish() -> fish_conf:
	return _hovered


func _redraw() -> void:
	if not plot:
		return
	var values := []
	for f in _sorted:
		values.append(f.value)
	draw(plot, {"values": values, "highlight": _sorted.find(_hovered), "title": chart_title}, _on_plot_clicked)


func _on_plot_clicked(hits: Array) -> void:
	if hits.is_empty():
		return
	var i: int = hits[0].sample_index
	if i >= 0 and i < _sorted.size():
		# Deferred: the shop redraws this chart in response, and rebuilding a
		# TauPlot from inside its own click signal breaks TauPlot mid-click.
		bar_clicked.emit.call_deferred(_sorted[i], i)
