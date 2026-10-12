# growth_chart.gd
# Shop / pond chart: a fish's S-shaped growth curve (logistic), with an optional
# marker at its current mass. Replaces SandBox/graph_test/growth_curve.gd and
# keeps its methods so ShopGraphManager needs no changes.
class_name GrowthChart
extends KoiChart

const _GROWTH := preload("res://scripts/Singletons/FishGrowthManager.gd")
const _DEFAULT := {"base": 5.0, "growth_rate": 0.5, "carrying_capacity": 100.0, "mid_point": 12.0, "hours": -1.0, "mass": -1.0}

var _data: Dictionary = _DEFAULT.duplicate()


# --- Chart definition (shared by the game and ChartPreview) -----------------

## data: {"base", "growth_rate", "carrying_capacity", "mid_point",
##        "hours" + "mass" for the "Now" marker (-1 = no marker)}
## Uses FishGrowthManager's curve, so the chart always matches real growth.
static func draw(p: TauPlot, data: Dictionary) -> void:
	var base: float = data.get("base", 5.0)
	var r: float = max(data.get("growth_rate", 0.5), 0.0001)
	var k: float = max(float(data.get("carrying_capacity", 100.0)), base + 1.0)
	var mp: float = data.get("mid_point", 12.0)
	var hours_now: float = data.get("hours", -1.0)

	# From entering the pond until the fish is ~99% grown (or past "now").
	var x_max: float = max((mp + log(99.0) / r) * 1.05, mp * 1.5)
	if hours_now > 0.0:
		x_max = max(x_max, hours_now * 1.05)

	var xs := PackedFloat64Array()
	var mass := PackedFloat64Array()
	var steps := 100
	for i in steps + 1:
		var h := x_max * i / steps
		xs.append(h)
		mass.append(_GROWTH.mass_at(base, k, r, mp, h))

	var opts := {"x_title": "Hours in pond", "y_title": "Mass", "include_zero": true}
	if hours_now >= 0.0:
		opts["markers"] = {"Now": Vector2(hours_now, data.get("mass", base))}

	TauCharts.line(p, "Growth", xs, {"Mass": mass}, opts)


static func sample_data() -> Dictionary:
	return {"base": 6.0, "growth_rate": 0.5, "carrying_capacity": 450, "mid_point": 20.0, "hours": 14.0, "mass": 40.0}


static func data_for(fish) -> Dictionary:
	return {
		# Fish not yet in the pond haven't recorded a base; their mass is it.
		"base": fish.y_start if fish.y_start > 0.0 else fish.mass,
		"growth_rate": fish.growth_rate,
		"carrying_capacity": fish.carrying_capacity,
		"mid_point": fish.mid_point,
		"hours": -1.0,
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
		_data["hours"] = _GROWTH.pond_hours(fish_res)
		_data["mass"] = fish_res.mass
		_redraw()


func clear_progress_marker() -> void:
	_data["hours"] = -1.0
	_data["mass"] = -1.0
	_redraw()


func _redraw() -> void:
	if plot:
		draw(plot, _data)
