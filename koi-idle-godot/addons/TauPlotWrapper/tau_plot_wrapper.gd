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

const Overlay := TauXYSeriesBinding.PaneOverlayType


## Line chart. `series` maps series name -> Y values (same length as x).
static func line(plot: TauPlot, title: String, x: PackedFloat64Array,
		series: Dictionary, opts := {}) -> void:
	var dataset := TauPlot.Dataset.make_shared_x_continuous(
		_names(series), x, _values(series))
	_plot(plot, title, dataset, TauLineConfig.new(), Overlay.LINE, false, opts)


## Bar chart. `series` maps series name -> one value per category.
static func bar(plot: TauPlot, title: String, categories: PackedStringArray,
		series: Dictionary, opts := {}) -> void:
	var dataset := TauPlot.Dataset.make_shared_x_categorical(
		_names(series), categories, _values(series))
	var cfg := TauBarConfig.new()
	# NOTE: check the enum name against TauBarConfig docs if this errors.
	cfg.mode = TauBarConfig.BarMode.STACKED if opts.get("stacked", false) \
		else TauBarConfig.BarMode.GROUPED
	_plot(plot, title, dataset, cfg, Overlay.BAR, true, opts)


## Scatter chart. `series` maps series name -> [x_values, y_values].
## Each series can have a different number of points.
static func scatter(plot: TauPlot, title: String, series: Dictionary, opts := {}) -> void:
	var xs: Array[PackedFloat64Array] = []
	var ys: Array[PackedFloat64Array] = []
	for key in series:
		xs.append(PackedFloat64Array(series[key][0]))
		ys.append(PackedFloat64Array(series[key][1]))
	var dataset := TauPlot.Dataset.make_per_series_x_continuous(_names(series), xs, ys)
	_plot(plot, title, dataset, TauScatterConfig.new(), Overlay.SCATTER, false, opts)


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

	_plot(plot, title, dataset, overlay, overlay_type, false, opts, true)
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

static func _plot(plot: TauPlot, title: String, dataset: TauPlot.Dataset,
		overlay: TauPaneOverlayConfig, overlay_type, categorical: bool,
		opts: Dictionary, is_live := false) -> void:
	# X axis
	var x_axis := TauAxisConfig.new()
	x_axis.title = opts.get("x_title", "")
	if categorical:
		x_axis.type = TauAxisConfig.Type.CATEGORICAL
	else:
		x_axis.include_zero_in_domain = false
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

	# Pane
	var pane := TauPaneConfig.new()
	pane.y_left_axis = y_axis
	pane.overlays = [overlay]
	if opts.get("grid", true):
		var grid := TauGridLineConfig.new()
		grid.y_major_enabled = true
		pane.grid_line = grid

	# Plot config
	var config := TauXYConfig.new()
	config.x_axis = x_axis
	config.panes = [pane]
	if opts.has("colors"):
		config.style.series_colors = opts["colors"]

	# One binding per series, all into the single pane
	var bindings: Array[TauXYSeriesBinding] = []
	for i in dataset.get_series_count():
		var b := TauXYSeriesBinding.new()
		b.series_id = dataset.get_series_id_by_index(i)
		b.pane_index = 0
		b.overlay_type = overlay_type
		b.y_axis_id = TauPlot.AxisId.LEFT
		bindings.append(b)

	# Plot node
	plot.title = title
	plot.legend_enabled = opts.get("legend", dataset.get_series_count() > 1)
	if opts.has("on_click"):
		var cb: Callable = opts["on_click"]
		if not plot.sample_clicked.is_connected(cb):
			plot.sample_clicked.connect(cb)

	plot.plot_xy(dataset, config, bindings)


static func _names(series: Dictionary) -> PackedStringArray:
	return PackedStringArray(series.keys())


static func _values(series: Dictionary) -> Array[PackedFloat64Array]:
	var out: Array[PackedFloat64Array] = []
	for key in series:
		out.append(PackedFloat64Array(series[key]))
	return out
