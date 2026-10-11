# growth_chart.gd
# Shop / pond chart: a fish's S-shaped growth curve (logistic), with an optional
# marker at its current mass. Replaces SandBox/graph_test/growth_curve.gd and
# keeps its methods so ShopGraphManager needs no changes.
class_name GrowthChart
extends MarginContainer

@onready var plot: TauPlot = $Plot

const _DEFAULT := {"growth_rate": 3.0, "carrying_capacity": 100.0, "mid_point": 5.0, "mass": -1.0}

var _data: Dictionary = _DEFAULT.duplicate()


# --- Chart definition (shared by the game and ChartPreview) -----------------

## data: {"growth_rate", "carrying_capacity", "mid_point", "mass" (-1 = no marker)}
static func draw(p: TauPlot, data: Dictionary) -> void:
	var r: float = max(data.get("growth_rate", 3.0), 0.0001)
	var k: float = max(float(data.get("carrying_capacity", 100.0)), 1.0)
	var mp: float = data.get("mid_point", 5.0)

	# Same visible range as the old graph: from 0 to where the fish is ~99% grown.
	var x_max: float = max((mp + log(99.0) / r) * 1.05, mp * 1.5)
	var xs := PackedFloat64Array()
	var mass := PackedFloat64Array()
	var steps := 100
	for i in steps + 1:
		var x := x_max * i / steps
		xs.append(x)
		mass.append(k / (1.0 + exp(-r * (x - mp))))

	var opts := {"x_title": "Hours", "y_title": "Mass", "include_zero": true}

	var current: float = data.get("mass", -1.0)
	if current >= 0.0:
		var m := clampf(current, k * 0.001, k * 0.999)
		var x_now := mp + log(m / (k - m)) / r   # inverse of the curve
		opts["markers"] = {"Now": Vector2(clampf(x_now, 0.0, x_max), current)}

	TauCharts.line(p, "Growth", xs, {"Mass": mass}, opts)


static func sample_data() -> Dictionary:
	return {"growth_rate": 0.6, "carrying_capacity": 40, "mid_point": 12.0, "mass": 9.0}


static func data_for(fish) -> Dictionary:
	return {
		"growth_rate": fish.growth_rate,
		"carrying_capacity": fish.carrying_capacity,
		"mid_point": fish.mid_point,
		"mass": -1.0,
	}


# --- Shop API (same names as the old growth_curve) ---------------------------

func _ready() -> void:
	_redraw()


func set_fish_growth(fish_res) -> void:
	_data = data_for(fish_res) if fish_res else _DEFAULT.duplicate()
	_redraw()


func clear_fish_growth() -> void:
	_data = _DEFAULT.duplicate()
	_redraw()


## Show a dot at the fish's current mass (pond view).
func set_progress_marker(fish_res) -> void:
	if fish_res:
		_data["mass"] = fish_res.mass
		_redraw()


func clear_progress_marker() -> void:
	_data["mass"] = -1.0
	_redraw()


func _redraw() -> void:
	if plot:
		draw(plot, _data)
