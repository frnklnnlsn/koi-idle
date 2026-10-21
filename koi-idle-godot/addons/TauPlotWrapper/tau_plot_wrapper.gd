class_name TauCharts
extends RefCounted
## Thin wrapper around TauPlot (written against v0.2.0).
## All TauPlot-specific code lives in this one file, so if TauPlot's API
## changes before 1.0, you only fix it here instead of in every game.
##
## Usage:
##   TauCharts.line($Plot, "Resources", days, {"Gold": gold, "Food": food},
##       {"x_title": "Day", "y_title": "Amount"})
##   TauCharts.bar($Plot, "Kills", PackedStringArray(["Sword", "Bow"]),
##       {"Player 1": [12, 4], "Player 2": [7, 9]}, {"stacked": true})
##   TauCharts.scatter($Plot, "Loot", {"Common": [xs, ys], "Rare": [xs2, ys2]})
##   var fps := TauCharts.live($Plot, "FPS", PackedStringArray(["FPS"]))
##   fps.push(time, [Engine.get_frames_per_second()])   # in _process
##
## Options (all optional), passed as a Dictionary:
##   x_title: String, y_title: String
##   colors: Array[Color]       series palette, in series order
##   grid: bool                 horizontal grid lines (default true)
##   legend: bool               default: shown when there is more than one series
##   include_zero: bool         force Y axis to include 0 (default: bars yes, others no)
##   y_format: Callable         func(label: String) -> String, e.g. add units
##   on_click: Callable         func(hits: Array[TauPlot.SampleHit]) -> void
##   stacked: bool              bar charts only
##   lookahead: float           live charts only: X padding in data units (default 1.0)
##   markers: Dictionary        line charts only: name -> Vector2, highlighted points
##                              drawn on top (e.g. "where this fish sits on the curve")
##   marker_color: Color        colour for markers and their guide lines
##   marker_drops: bool         dashed line from each marker down to y = 0 (default true)
##   y_log / x_log: bool        logarithmic axis (values must be > 0)
##   x_range / y_range: Vector2 fixed axis range (min, max) instead of fitting the data
##   x_format: Callable         like y_format, for the X axis tick labels
##   minimal: bool              only the title, the data and the axis lines with major
##                              tick marks: no axis titles, numbers, grid, legend or
##                              minor ticks
##   circles: bool              scatter only: every series drawn as round dots
##   hover_nearest: bool        hover/click picks the single nearest point (default:
##                              line charts pick every series at the cursor's X)

const Overlay := TauXYSeriesBinding.PaneOverlayType


## Line chart. `series` maps series name -> Y values (same length as x).
static func line(plot: TauPlot, title: String, x: PackedFloat64Array,
		series: Dictionary, opts := {}) -> void:
	if not opts.get("markers", {}).is_empty():
		_line_with_markers(plot, title, x, series, opts)
		return
	var dataset := TauPlot.Dataset.make_shared_x_continuous(
		_names(series), x, _values(series))
	_plot(plot, title, dataset, [TauLineConfig.new()], [Overlay.LINE], false, opts)


## Bar chart. `series` maps series name -> one value per category.
static func bar(plot: TauPlot, title: String, categories: PackedStringArray,
		series: Dictionary, opts := {}) -> void:
	var dataset := TauPlot.Dataset.make_shared_x_categorical(
		_names(series), categories, _values(series))
	var cfg := TauBarConfig.new()
	# NOTE: check the enum name against TauBarConfig docs if this errors.
	cfg.mode = TauBarConfig.BarMode.STACKED if opts.get("stacked", false) \
		else TauBarConfig.BarMode.GROUPED
	_plot(plot, title, dataset, [cfg], [Overlay.BAR], true, opts)


## Scatter chart. `series` maps series name -> [x_values, y_values].
## Each series can have a different number of points.
static func scatter(plot: TauPlot, title: String, series: Dictionary, opts := {}) -> void:
	var xs: Array[PackedFloat64Array] = []
	var ys: Array[PackedFloat64Array] = []
	for key in series:
		xs.append(PackedFloat64Array(series[key][0]))
		ys.append(PackedFloat64Array(series[key][1]))
	var dataset := TauPlot.Dataset.make_per_series_x_continuous(_names(series), xs, ys)
	var cfg := TauScatterConfig.new()
	if opts.get("circles", false):
		cfg.style.marker_shapes = [TauScatterStyle.MarkerShape.CIRCLE]
	_plot(plot, title, dataset, [cfg], [Overlay.SCATTER], false, opts)


## Live streaming chart. Returns a LiveChart; call push() to add samples.
## Oldest samples are dropped once `capacity` is reached.
## `style` is "line" or "scatter".
static func live(plot: TauPlot, title: String, series_names: PackedStringArray,
		capacity := 200, style := "line", opts := {}) -> LiveChart:
	var dataset := TauPlot.Dataset.new(
		TauPlot.Dataset.Mode.SHARED_X,
		TauPlot.Dataset.XElementType.NUMERIC,
		capacity)
	for n in series_names:
		dataset.add_series(n)

	var overlay: TauPaneOverlayConfig
	var overlay_type
	if style == "scatter":
		overlay = TauScatterConfig.new()
		overlay_type = Overlay.SCATTER
	else:
		overlay = TauLineConfig.new()
		overlay_type = Overlay.LINE

	_plot(plot, title, dataset, [overlay], [overlay_type], false, opts, true)
	return LiveChart.new(dataset)


## Handle returned by live(). Keep a reference to it in your script.
class LiveChart extends RefCounted:
	var dataset: TauPlot.Dataset

	func _init(ds: TauPlot.Dataset) -> void:
		dataset = ds

	## Push one sample: an X value and one Y value per series, in series order.
	func push(x: float, values: Array) -> void:
		dataset.append_shared_sample(x, PackedFloat64Array(values))


# --- Internals ---------------------------------------------------------------

## Line chart plus highlighted marker points. Markers have their own X values,
## so this uses a per-series-X dataset with a line overlay and a scatter overlay
## sharing one pane. Series order: lines, marker guide lines, marker points.
static func _line_with_markers(plot: TauPlot, title: String, x: PackedFloat64Array,
		series: Dictionary, opts: Dictionary) -> void:
	var markers: Dictionary = opts["markers"]
	var marker_color: Color = opts.get("marker_color", Color(1.0, 0.85, 0.2))
	var drops: bool = opts.get("marker_drops", true)

	var palette: Array[Color] = []
	palette.assign(opts.get("colors", TauXYStyle.new().series_colors))

	var names := _names(series)
	var ys := _values(series)
	var xs: Array[PackedFloat64Array] = []
	var types := []
	var colors: Array[Color] = []
	var dashes: Array[int] = []
	for i in names.size():
		xs.append(x)
		types.append(Overlay.LINE)
		colors.append(palette[i % palette.size()])
		dashes.append(0)

	if drops:
		for m in markers:
			var p: Vector2 = markers[m]
			names.append("%s (guide)" % m)
			xs.append(PackedFloat64Array([p.x, p.x]))
			ys.append(PackedFloat64Array([0.0, p.y]))
			types.append(Overlay.LINE)
			colors.append(marker_color)
			dashes.append(6)

	for m in markers:
		var p: Vector2 = markers[m]
		names.append(str(m))
		xs.append(PackedFloat64Array([p.x]))
		ys.append(PackedFloat64Array([p.y]))
		types.append(Overlay.SCATTER)
		colors.append(marker_color)

	var dataset := TauPlot.Dataset.make_per_series_x_continuous(names, xs, ys)
	var line_cfg := TauLineConfig.new()
	line_cfg.style.dash_lengths_px = dashes

	var o := opts.duplicate()
	o["colors"] = colors
	if not o.has("legend"):
		o["legend"] = series.size() > 1
	var dot_cfg := TauScatterConfig.new()
	# "circles": every marker a round dot (otherwise each gets its own shape).
	if opts.get("circles", false):
		dot_cfg.style.marker_shapes = [TauScatterStyle.MarkerShape.CIRCLE]
	_plot(plot, title, dataset, [line_cfg, dot_cfg], types, false, o)


## overlays: one config per overlay type used in the pane.
## overlay_types: one entry per series, or a single entry shared by all series.
static func _plot(plot: TauPlot, title: String, dataset: TauPlot.Dataset,
		overlays: Array, overlay_types: Array, categorical: bool,
		opts: Dictionary, is_live := false) -> void:
	if opts.get("minimal", false):
		opts = opts.duplicate()
		opts["x_title"] = ""
		opts["y_title"] = ""
		opts["x_format"] = _blank
		opts["y_format"] = _blank
		opts["grid"] = false
		opts["legend"] = false
	# X axis
	var x_axis := TauAxisConfig.new()
	x_axis.title = opts.get("x_title", "")
	if categorical:
		x_axis.type = TauAxisConfig.Type.CATEGORICAL
	else:
		x_axis.include_zero_in_domain = false
	if opts.get("x_log", false):
		x_axis.scale = TauAxisConfig.Scale.LOGARITHMIC
	if opts.has("x_range"):
		var xr: Vector2 = opts["x_range"]
		x_axis.range_override_enabled = true
		x_axis.min_override = xr.x
		x_axis.max_override = xr.y
	if opts.has("x_format"):
		x_axis.format_tick_label = opts["x_format"]
	if is_live:
		# Padding ahead of the data means fewer axis recomputes per second.
		x_axis.domain_padding_mode = TauAxisConfig.DomainPaddingMode.DATA_UNITS
		x_axis.domain_padding_min = 0.0
		x_axis.domain_padding_max = opts.get("lookahead", 1.0)

	# Y axis
	var y_axis := TauAxisConfig.new()
	y_axis.title = opts.get("y_title", "")
	y_axis.include_zero_in_domain = opts.get("include_zero", categorical)
	if opts.has("y_format"):
		y_axis.format_tick_label = opts["y_format"]
	if opts.get("y_log", false):
		y_axis.scale = TauAxisConfig.Scale.LOGARITHMIC
		y_axis.include_zero_in_domain = false
	if opts.has("y_range"):
		var yr: Vector2 = opts["y_range"]
		y_axis.range_override_enabled = true
		y_axis.min_override = yr.x
		y_axis.max_override = yr.y

	# Pane
	var pane := TauPaneConfig.new()
	pane.y_left_axis = y_axis
	pane.overlays.assign(overlays)
	if opts.get("grid", true):
		var grid := TauGridLineConfig.new()
		grid.y_major_enabled = true
		pane.grid_line = grid

	# Plot config
	var config := TauXYConfig.new()
	config.x_axis = x_axis
	config.panes = [pane]
	if opts.has("colors"):
		var colors: Array[Color] = []
		colors.assign(opts["colors"])
		config.style.series_colors = colors
	if opts.get("minimal", false):
		config.style.minor_tick_length_ratio = 0.0   # major ticks only

	# One binding per series, all into the single pane
	var bindings: Array[TauXYSeriesBinding] = []
	for i in dataset.get_series_count():
		var b := TauXYSeriesBinding.new()
		b.series_id = dataset.get_series_id_by_index(i)
		b.pane_index = 0
		b.overlay_type = overlay_types[i] if overlay_types.size() > 1 else overlay_types[0]
		b.y_axis_id = TauPlot.AxisId.LEFT
		bindings.append(b)

	# Plot node
	plot.title = title
	plot.legend_enabled = opts.get("legend", dataset.get_series_count() > 1)
	if opts.has("hover_nearest"):
		var hc := TauHoverConfig.new()
		hc.hover_mode = TauHoverConfig.HoverMode.NEAREST if opts["hover_nearest"] else TauHoverConfig.HoverMode.AUTO
		plot.hover_config = hc
	if opts.has("on_click"):
		var cb: Callable = opts["on_click"]
		if not plot.sample_clicked.is_connected(cb):
			plot.sample_clicked.connect(cb)

	plot.plot_xy(dataset, config, bindings)
	# TauPlot lays the new plot out on the next frame. On frames with no physics
	# step (the game running faster than the physics rate) Godot hasn't sized
	# the plot's inner panes by then, so that layout is skipped and the chart
	# stays blank. Queue one more refresh after Godot has sized everything.
	plot.queue_refresh.call_deferred()


static func _blank(_label: String) -> String:
	return ""


static func _names(series: Dictionary) -> PackedStringArray:
	return PackedStringArray(series.keys())


static func _values(series: Dictionary) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	for key in series:
		out.append(PackedFloat64Array(series[key]))
	return out


# --- Screen positions (for box selection over a chart) --------------------------
# These read TauPlot's internal layout (not public API in v0.2.0), so if a TauPlot
# update breaks box selection, this is the place to fix.

## The plot's internal XY plot, or null before it has been laid out.
static func _xy(plot: TauPlot):
	var xy = plot.get("_xy_plot")
	if xy == null or xy._xy_layout == null or not xy._xy_layout.has_pane_layouts():
		return null
	return xy


## Where the data point (x, y) is drawn, in screen (global) coordinates.
## Vector2.INF if the plot isn't laid out yet.
static func data_to_global(plot: TauPlot, x: float, y: float) -> Vector2:
	var xy = _xy(plot)
	if xy == null:
		return Vector2.INF
	var pl = xy._xy_layout.pane_layouts[0]
	var ys: Array = pl.y_mappings.values()
	if pl.x_mapping == null or ys.is_empty():
		return Vector2.INF
	var local: Vector2 = xy._xy_layout.map_point_to_screen(pl.x_mapping.to_px(x), ys[0].to_px(y))
	return xy._pane_renderers[0].get_global_transform() * local


## Screen rectangle of bar `index` of a bar chart (from 0 up to `value`),
## `width` = share of its slot the bar fills. Empty Rect2 if not laid out.
static func bar_global_rect(plot: TauPlot, index: int, value: float, width := 0.8) -> Rect2:
	var xy = _xy(plot)
	if xy == null:
		return Rect2()
	var layout = xy._xy_layout
	var pl = layout.pane_layouts[0]
	var ys: Array = pl.y_mappings.values()
	var n: int = layout.domain.x_categories.size()
	if ys.is_empty() or n == 0:
		return Rect2()
	var step: float = pl.pane_rect.size.x / n
	var cx: float = layout.map_x_category_center_to_px(0, index)
	var y0: float = ys[0].to_px(0.0)
	var y1: float = ys[0].to_px(value)
	# At least a few pixels tall, so tiny bars can still be boxed.
	var top := minf(minf(y0, y1), maxf(y0, y1) - 3.0)
	var local := Rect2(cx - step * width / 2.0, top, step * width, maxf(y0, y1) - top)
	return xy._pane_renderers[0].get_global_transform() * local
