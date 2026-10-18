# fish_value_chart.gd
# Shop chart: the income odds for a rank (its bell curve), with a marker for
# the hovered fish. Replaces SandBox/graph_test/bellcurve.gd and keeps its
# methods (set_fish_value / clear_fish_value), plus set_fish().
#
# The curve comes straight from the rank table (income_avg / income_spread),
# so if you retune a rank the chart follows automatically.
class_name FishValueChart
extends KoiChart

## Points along the curve.
const SAMPLES := 121

var _rank: int = 0
var _fish_value: float = -1.0   # -1 = no marker


# --- Chart definition (shared by the game and ChartPreview) -----------------

## data: {"rank": int, "fish_value": float (the fish's income; -1 = no marker)}
static func draw(p: TauPlot, data: Dictionary) -> void:
	var rank: int = clampi(data.get("rank", 0), 0, Ranks.max_rank())
	var r := Ranks.get_rank(rank)
	var avg := r.income_avg
	var spread := maxf(r.income_spread, 0.0)

	var xs := PackedFloat64Array()
	var chance := PackedFloat64Array()
	if spread <= 0.0001:
		xs.append(avg)                # every fish identical
		chance.append(100.0)
	else:
		# Share of fish per step along the curve, in percent.
		var dz := 2.0 * FishStats.CLIP_Z / (SAMPLES - 1)
		for i in SAMPLES:
			var z := -FishStats.CLIP_Z + i * dz
			xs.append(FishStats.value_from_z(avg, spread, z))
			chance.append(FishStats.density(z) / sqrt(TAU) * dz * 100.0)

	var opts := {
		"x_title": "Income per second",
		"y_title": "Chance",
		"include_zero": true,
		"y_format": func(label: String) -> String: return label + "%",
	}

	var fish_value: float = data.get("fish_value", -1.0)
	if fish_value >= 0.0 and xs.size() > 1:
		var z := ((fish_value / avg) - 1.0) / spread if avg > 0.0 else 0.0
		var i := clampi(roundi((z + FishStats.CLIP_Z) / (2.0 * FishStats.CLIP_Z) * (SAMPLES - 1)), 0, SAMPLES - 1)
		opts["markers"] = {"This fish": Vector2(fish_value, chance[i])}

	TauCharts.line(p, "Income odds · %s" % r.display_name, xs, {"Odds": chance}, opts)


static func sample_data() -> Dictionary:
	return {"rank": 0, "fish_value": Ranks.get_rank(0).income_avg * 1.2}


# --- Shop API ------------------------------------------------------------------

func _ready() -> void:
	_redraw()


## Show this fish's rank and mark its income.
func set_fish(fish: fish_conf) -> void:
	_rank = fish.rank
	_fish_value = fish.income
	_redraw()


## Old API: marks a value on the current rank's curve.
func set_fish_value(value: float) -> void:
	_fish_value = value
	_redraw()


func clear_fish_value() -> void:
	_fish_value = -1.0   # keep the last rank's curve, drop the marker
	_redraw()


func _redraw_now() -> void:
	if plot:
		draw(plot, {"rank": _rank, "fish_value": _fish_value})
