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
var _caught: Array = []   # fishing: on the line now (accent)
var _earlier: Array = []  # fishing: caught earlier this session (faded)
var _stat := 0

# Zoom (when `zoomable`): a window of the sorted bars. Scroll zooms around the
# bar under the mouse, right-drag scrolls sideways, double-click shows all.
## Fewest bars a zoom shows.
@export var min_bars := 5
var _first := 0      # first bar in view
var _count := 0      # bars in view (0 = all)
var _pan_left := 0.0 # sideways drag not yet turned into whole bars


# --- Chart definition (shared by the game and ChartPreview) -----------------

## data: {"values": Array[float] sorted ascending, "highlight": int (-1 = none),
##        "picked": Array[int] (box-selected bars), "caught": Array[int] (fishing:
##        on the line, accent), "earlier": Array[int] (fishing: caught earlier,
##        faded), "title": String (optional), "offset": int (the first value is bar
##        number offset + 1, for a zoomed-in window)}
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
	var caught_ids: Array = data.get("caught", [])
	var earlier_ids: Array = data.get("earlier", [])
	var others := []
	var faded := []
	var boxed := []
	var picked := []
	var offset: int = data.get("offset", 0)
	for i in values.size():
		labels.append(str(i + offset + 1))
		# 2 = accent (hovered or on the line), 1 = box-selected, 3 = caught earlier
		var kind := 0
		if i == highlight or i in caught_ids:
			kind = 2
		elif i in picked_ids:
			kind = 1
		elif i in earlier_ids:
			kind = 3
		others.append(values[i] if kind == 0 else 0.0)
		faded.append(values[i] if kind == 3 else 0.0)
		boxed.append(values[i] if kind == 1 else 0.0)
		picked.append(values[i] if kind == 2 else 0.0)

	var opts := {
		"y_title": data.get("y_title", "Income /s"),
		"stacked": true,
		"minimal": true,
		"colors": [UIPalette.get_palette().chart_mark, UIPalette.get_palette().chart_caught_earlier,
			UIPalette.get_palette().picked, UIPalette.get_palette().accent],
	}
	if on_click.is_valid():
		opts["on_click"] = on_click
	TauCharts.bar(p, data.get("title", "Fish by value"), labels, {"Fish": others, "Earlier": faded, "Picked": boxed, "Hovered": picked}, opts)


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
	var fish := fish_array.filter(func(f): return f is fish_conf)
	if fish == _fish and is_node_ready():
		return   # same fish as before (e.g. a growth tick): nothing to redraw
	_fish = fish
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


## Fish whose bar touches `rect` (screen coordinates).
func fish_in_rect(rect: Rect2) -> Array:
	var out := []
	var w := _window()
	for k in w.y:
		var f: fish_conf = _sorted[w.x + k]
		if rect.intersects(TauCharts.bar_global_rect(plot, k, stat_value(f, _stat))):
			out.append(f)
	return out


## Bars in view: Vector2i(first, count).
func _window() -> Vector2i:
	var n := _sorted.size()
	var c := n if _count <= 0 or _count >= n else _count
	return Vector2i(clampi(_first, 0, maxi(n - c, 0)), c)


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var n := _sorted.size()
	var area := pane_rect()
	if n == 0 or area.size.x <= 0.0:
		return
	var w := _window()
	var frac := clampf((screen_pos.x - area.position.x) / area.size.x, 0.0, 1.0)
	var at := w.x + frac * w.y   # bar position under the mouse
	var c := clampi(roundi(w.y * factor), mini(min_bars, n), n)
	if c == w.y:
		c = clampi(w.y + (-1 if factor < 1.0 else 1), mini(min_bars, n), n)
	_first = clampi(roundi(at - frac * c), 0, n - c)
	_count = 0 if c >= n else c
	_redraw()


func _pan_pixels(relative: Vector2) -> void:
	var w := _window()
	var area := pane_rect()
	if _count <= 0 or area.size.x <= 0.0:
		return
	_pan_left -= relative.x / (area.size.x / w.y)
	var step := int(_pan_left)
	if step != 0:
		_pan_left -= step
		_first = clampi(w.x + step, 0, _sorted.size() - w.y)
		_redraw()


func _reset_zoom() -> void:
	if _count == 0:
		return
	_first = 0
	_count = 0
	_redraw()


func get_hovered_fish() -> fish_conf:
	return _hovered


## The value a fish shows for stat tab `stat`.
static func stat_value(f: fish_conf, stat: int) -> float:
	match stat:
		1: return f.y_start if f.y_start > 0.0 else f.mass   # starting mass
		2: return FishGrowthManager.max_mass(f)               # max mass
		_: return PassiveSystems.fish_income(f)


func _on_stat(i: int) -> void:
	_stat = i
	_first = 0
	_count = 0
	_sort()
	_redraw()


func _sort() -> void:
	_sorted = _fish.duplicate()
	_sorted.sort_custom(func(a, b): return stat_value(a, _stat) < stat_value(b, _stat))


func _redraw_now() -> void:
	if not plot:
		return
	# Only the bars in view (all of them unless zoomed in).
	var w := _window()
	var shown := _sorted.slice(w.x, w.x + w.y)
	var values := []
	for f in shown:
		values.append(stat_value(f, _stat))
	var title := chart_title if chart_title != "" else "By " + String(STATS[_stat][0]).to_lower()
	if w.y < _sorted.size():
		title += "   %d–%d of %d" % [w.x + 1, w.x + w.y, _sorted.size()]
	var picked := []
	var caught := []
	var earlier := []
	for i in shown.size():
		if shown[i] in _picked:
			picked.append(i)
		if shown[i] in _caught:
			caught.append(i)
		elif shown[i] in _earlier:
			earlier.append(i)
	draw(plot, {"values": values, "highlight": shown.find(_hovered), "picked": picked,
		"caught": caught, "earlier": earlier, "title": title, "offset": w.x,
		"y_title": STATS[_stat][1]}, _on_plot_clicked)


func _on_plot_clicked(hits: Array) -> void:
	if hits.is_empty():
		return
	var i: int = hits[0].sample_index + _window().x   # bars in view start at _first
	if i >= 0 and i < _sorted.size():
		# Deferred: the shop redraws this chart in response, and rebuilding a
		# TauPlot from inside its own click signal breaks TauPlot mid-click.
		bar_clicked.emit.call_deferred(_sorted[i], i)
