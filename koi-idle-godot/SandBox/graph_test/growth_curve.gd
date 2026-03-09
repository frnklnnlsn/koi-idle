# growth_curve.gd
# Modular S-curve graph. Works standalone (shop) or with a live progress
# marker (pond list). Call set_fish_growth() to load a fish, then optionally
# call set_progress_marker() to show where the fish currently sits on the curve.
extends Control

# ─── Curve Parameters ────────────────────────────────────────────────────────
@export var growth_rate: float        = 3.0
@export var carrying_capacity: float  = 100.0
@export var midpoint: float           = 5.0
@export var x_range: float            = 10.0
@export var x_start: float            = 0.0
@export var y_start: float            = 0.0
@export var num_points: int           = 200

# ─── Layout ───────────────────────────────────────────────────────────────────
@export var margin_percent: Vector2   = Vector2(0.1, 0.2)
@export var curve_height_percent: float = 0.6

# ─── Axes ────────────────────────────────────────────────────────────────────
@export var axis_color: Color         = Color.WHITE
@export var axis_width: float         = 2.0
@export var tick_length: float        = 10.0
@export var num_x_ticks: int          = 6
@export var num_y_ticks: int          = 6

# ─── Curve ───────────────────────────────────────────────────────────────────
@export var curve_color: Color        = Color.WHITE
@export var curve_width: float        = 3.0

# ─── Progress Marker ─────────────────────────────────────────────────────────
## Set to true automatically when set_progress_marker() is called.
## Can also be toggled in the editor for preview.
@export var show_progress_marker: bool = false
@export var marker_color: Color        = Color.YELLOW
@export var marker_radius: float       = 8.0
@export var marker_line_width: float   = 2.0
@export var dash_length: float         = 10.0
@export var dash_gap: float            = 5.0

# ─── Internal State ──────────────────────────────────────────────────────────
var _fish_res              = null   # fish_conf driving the curve shape
var _marker_fish_res       = null   # fish_conf driving the progress marker
var _marker_x: float       = 0.0   # cached curve-space x of the marker

var center_x: float
var center_y: float
var scale_x: float
var scale_y: float

var display_x_min: float
var display_x_max: float
var display_y_min: float
var display_y_max: float

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Load a fish resource and redraw the curve to match its growth parameters.
func set_fish_growth(fish_res) -> void:
	_fish_res = fish_res
	if fish_res:
		growth_rate       = fish_res.growth_rate
		carrying_capacity = fish_res.carrying_capacity
		midpoint          = fish_res.mid_point
		x_range           = fish_res.x_range
		x_start           = fish_res.x_start
		y_start           = fish_res.y_start
	_update_display_ranges()
	queue_redraw()


## Reset the curve to generic defaults and hide any marker.
func clear_fish_growth() -> void:
	_fish_res            = null
	_marker_fish_res     = null
	show_progress_marker = false
	growth_rate          = 3.0
	carrying_capacity    = 100.0
	midpoint             = 5.0
	x_range              = 10.0
	x_start              = 0.0
	y_start              = 0.0
	_update_display_ranges()
	queue_redraw()


## Show a dot on the curve at the fish's current mass.
## Call this every time the fish's mass updates (e.g. on hover refresh).
func set_progress_marker(fish_res) -> void:
	_marker_fish_res     = fish_res
	show_progress_marker = true
	if fish_res:
		_marker_x = _inverse_logistic(fish_res.mass,
				float(fish_res.carrying_capacity),
				fish_res.growth_rate,
				fish_res.mid_point)
	queue_redraw()


## Hide the progress marker without changing the curve.
func clear_progress_marker() -> void:
	_marker_fish_res     = null
	show_progress_marker = false
	queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	await get_tree().process_frame
	_calculate_layout()
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	queue_redraw()


func _on_resized() -> void:
	_calculate_layout()
	queue_redraw()


# ─────────────────────────────────────────────────────────────────────────────
# Layout helpers
# ─────────────────────────────────────────────────────────────────────────────

func _calculate_layout() -> void:
	var sz = get_rect().size
	if sz.x <= 0 or sz.y <= 0:
		return

	var mx = sz.x * margin_percent.x
	var my = sz.y * margin_percent.y
	var aw = sz.x - 2.0 * mx
	var ah = sz.y - 2.0 * my

	center_x = mx + aw * 0.5
	center_y = my + ah * 0.7
	scale_x  = aw * 0.9
	scale_y  = ah * curve_height_percent

	_update_display_ranges()

# ─────────────────────────────────────────────────────────────────────────────
# Coordinate helpers
# ─────────────────────────────────────────────────────────────────────────────

func x_to_screen(x: float) -> float:
	var t = (x - display_x_min) / (display_x_max - display_x_min)
	return center_x - scale_x * 0.45 + t * scale_x * 0.9


func y_to_screen(y: float) -> float:
	var t = (y - display_y_min) / (display_y_max - display_y_min)
	return center_y - t * scale_y


# ─────────────────────────────────────────────────────────────────────────────
# Math
# ─────────────────────────────────────────────────────────────────────────────

func logistic(x: float) -> float:
	return carrying_capacity / (1.0 + exp(-growth_rate * (x - midpoint)))


## Invert the logistic to recover the x-coordinate from a known mass value.
## Used to place the progress marker without needing the fish's raw age.
func _inverse_logistic(mass: float, K: float, r: float, mp: float) -> float:
	var safe_mass = clampf(mass, 0.001, K - 0.001)
	return mp + log(safe_mass / (K - safe_mass)) / r


# ─────────────────────────────────────────────────────────────────────────────
# Drawing
# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if scale_x <= 0.0 or scale_y <= 0.0:
		return
	_draw_axes()
	_draw_curve()
	if show_progress_marker and _marker_fish_res:
		_draw_progress_marker()


func _draw_curve() -> void:
	var pts = PackedVector2Array()
	for i in range(num_points):
		var x = lerpf(display_x_min, display_x_max, i / float(num_points - 1))
		var y = logistic(x)
		pts.append(Vector2(x_to_screen(x), y_to_screen(y)))
	draw_polyline(pts, curve_color, curve_width)


func _draw_axes() -> void:
	var y_axis_x  = x_to_screen(display_x_min)
	var x_axis_y  = y_to_screen(display_y_min)
	var right     = x_to_screen(display_x_max)
	var top       = y_to_screen(display_y_max)

	draw_line(Vector2(y_axis_x, x_axis_y), Vector2(right + 20, x_axis_y), axis_color, axis_width)
	draw_line(Vector2(y_axis_x, x_axis_y), Vector2(y_axis_x, top - 20),  axis_color, axis_width)

	# X ticks & labels
	var x_total = display_x_max - display_x_min
	var x_step = x_total / float(num_x_ticks - 1) if num_x_ticks > 1 else x_total
	for i in range(num_x_ticks):
		var xv = display_x_min + i * x_step
		if xv > display_x_max + 0.001:
			continue
		var sx = x_to_screen(xv)
		draw_line(Vector2(sx, x_axis_y - tick_length * 0.5),
				  Vector2(sx, x_axis_y + tick_length * 0.5), axis_color, axis_width)
		var lbl = str(int(round(xv))) if abs(xv - round(xv)) < 0.01 else "%.1f" % xv
		draw_string(ThemeDB.fallback_font, Vector2(sx - 5, x_axis_y + 25),
					lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, axis_color)

	# Y ticks & labels
	var y_step = (display_y_max - display_y_min) / float(num_y_ticks - 1) if num_y_ticks > 1 else (display_y_max - display_y_min)
	for i in range(num_y_ticks):
		var yv = display_y_min + i * y_step
		if yv > display_y_max + 0.001:
			continue
		var sy = y_to_screen(yv)
		draw_line(Vector2(y_axis_x - tick_length * 0.5, sy),
				  Vector2(y_axis_x + tick_length * 0.5, sy), axis_color, axis_width)
		draw_string(ThemeDB.fallback_font, Vector2(y_axis_x - 40, sy + 5),
					str(int(round(yv))), HORIZONTAL_ALIGNMENT_RIGHT, -1, 14, axis_color)


## Draw dashed crosshair lines + filled dot at the fish's current mass position.
func _draw_progress_marker() -> void:
	var fish = _marker_fish_res
	var K    = float(fish.carrying_capacity)
	var r    = fish.growth_rate
	var mp   = fish.mid_point

	# Recover x-coordinate on the curve from the fish's live mass value
	var marker_x    = _inverse_logistic(fish.mass, K, r, mp)
	var marker_y    = fish.mass 

	var sx = x_to_screen(marker_x)
	var sy = y_to_screen(marker_y)

	var y_axis_x  = x_to_screen(display_x_min)
	var x_axis_y  = y_to_screen(display_y_min)

	# ── Dashed vertical line (from x-axis up to marker) ──────────────────────
	_draw_dashed_line(Vector2(sx, x_axis_y), Vector2(sx, sy), marker_color)

	# ── Dashed horizontal line (from y-axis across to marker) ────────────────
	_draw_dashed_line(Vector2(y_axis_x, sy), Vector2(sx, sy), marker_color)

	# ── Dot on the curve ─────────────────────────────────────────────────────
	draw_circle(Vector2(sx, sy), marker_radius, marker_color)

	# ── Small label showing current mass ─────────────────────────────────────
	var pct = (fish.mass / K) * 100.0
	draw_string(ThemeDB.fallback_font,
				Vector2(sx + marker_radius + 4.0, sy - marker_radius),
				"%.0f%%" % pct,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, marker_color)


func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var dir    = (to - from).normalized()
	var total  = from.distance_to(to)
	var offset = 0.0
	var drawing = true
	while offset < total:
		var seg_len = dash_length if drawing else dash_gap
		var end_pt  = from + dir * min(offset + seg_len, total)
		if drawing:
			draw_line(from + dir * offset, end_pt, color, marker_line_width)
		offset  += seg_len
		drawing  = not drawing

func _update_display_ranges() -> void:
	display_x_min = 0.0
	var x_99 = midpoint + log(99.0) / growth_rate if growth_rate > 0.0 else midpoint * 2.0
	display_x_max = max(x_99 * 1.05, midpoint * 1.5)

	display_y_min = 0.0              # ← always from 0, ignore y_start
	display_y_max = carrying_capacity # ← pure 0 → K range
