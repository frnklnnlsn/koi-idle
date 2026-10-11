# fish_value_chart.gd
# Shop chart: how likely each sell value is for a rank, with a marker for the
# hovered fish. Replaces SandBox/graph_test/bellcurve.gd and keeps its methods
# (set_fish_value / clear_fish_value) so ShopGraphManager needs no changes.
#
# The curve comes straight from FishGenerator's real odds, so if you retune
# RANK_RANGES the chart follows automatically.
class_name FishValueChart
extends MarginContainer

const _GEN := preload("res://scripts/Singletons/FishGenerator.gd")

@onready var plot: TauPlot = $Plot

var _rank: int = 0
var _fish_value: float = -1.0   # -1 = no marker


# --- Chart definition (shared by the game and ChartPreview) -----------------

## data: {"rank": int, "fish_value": float (-1 for no marker)}
static func draw(p: TauPlot, data: Dictionary) -> void:
	var rank: int = clampi(data.get("rank", 0), 0, _GEN.RANK_RANGES.size() - 1)
	var vw := _GEN.value_weights(_GEN.RANK_RANGES[rank])
	var raw: PackedInt32Array = vw["values"]
	var weights: PackedInt32Array = vw["weights"]

	var total := 0.0
	for w in weights:
		total += w

	var xs := PackedFloat64Array()
	var chance := PackedFloat64Array()
	for i in raw.size():
		xs.append(raw[i] * _GEN.FISH_BASE_VALUE)
		chance.append(weights[i] / total * 100.0)

	var opts := {
		"x_title": "Sell value",
		"y_title": "Chance",
		"include_zero": true,
		"y_format": func(label: String) -> String: return label + "%",
	}

	var fish_value: float = data.get("fish_value", -1.0)
	if fish_value >= 0.0:
		var i := clampi(roundi(fish_value / _GEN.FISH_BASE_VALUE) - raw[0], 0, raw.size() - 1)
		opts["markers"] = {"This fish": Vector2(fish_value, chance[i])}

	TauCharts.line(p, "Value odds · Rank %d" % rank, xs, {"Odds": chance}, opts)


static func sample_data() -> Dictionary:
	return {"rank": 0, "fish_value": 1.4}


## Which rank a sell value belongs to (first match; rank edges overlap by one).
static func rank_for_value(value: float) -> int:
	var raw := roundi(value / _GEN.FISH_BASE_VALUE)
	for r in _GEN.RANK_RANGES.size():
		if raw >= _GEN.RANK_RANGES[r][0] and raw <= _GEN.RANK_RANGES[r][1]:
			return r
	return 0


# --- Shop API (same names as the old bellcurve) ------------------------------

func _ready() -> void:
	_redraw()


func set_fish_value(value: float) -> void:
	_fish_value = value
	_rank = rank_for_value(value)
	_redraw()


func clear_fish_value() -> void:
	_fish_value = -1.0   # keep the last rank's curve, drop the marker
	_redraw()


func _redraw() -> void:
	if plot:
		draw(plot, {"rank": _rank, "fish_value": _fish_value})
